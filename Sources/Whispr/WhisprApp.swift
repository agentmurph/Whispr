import SwiftUI
import Combine
import ServiceManagement

@main
struct WhisprApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var hotkeyProfileManager = HotkeyProfileManager()
    @StateObject private var snippetManager = SnippetManager()
    @StateObject private var wordReplacementManager = WordReplacementManager()
    @StateObject private var pluginManager = PluginManager()

    // Non-UI managers stored as let (created once)
    // Using nonisolated(unsafe) to avoid @State wrapping @MainActor classes
    @State private var audioEngine = AudioEngine()
    @State private var whisperEngine = WhisperEngine()
    @State private var hotkeyManager = HotkeyManager()
    @State private var overlayController = OverlayController()
    @State private var streamingTranscriber = StreamingTranscriber()

    @State private var elapsedTimer: Timer?
    @State private var levelCancellable: AnyCancellable?
    @State private var modelCancellable: AnyCancellable?
    @State private var streamingCancellable: AnyCancellable?
    @State private var onboardingWindow: NSWindow?
    @State private var showSettings = false

    var body: some Scene {
        // Menu bar app
        MenuBarExtra {
            menuContent
        } label: {
            menuBarIcon
        }

        // Settings window
        Window("Whispr Settings", id: "settings") {
            SettingsView(appState: appState, modelManager: modelManager, hotkeyProfileManager: hotkeyProfileManager, snippetManager: snippetManager, wordReplacementManager: wordReplacementManager, pluginManager: pluginManager)
        }
        .windowResizability(.contentSize)
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: some View {
        Group {
            switch appState.phase {
            case .idle:
                Image(systemName: "mic")
            case .recording:
                Image(systemName: "mic.fill")
                    .symbolRenderingMode(.multicolor)
            case .transcribing:
                Image(systemName: "ellipsis")
            }
        }
        .onAppear { setupOnAppear() }
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        Group {
            switch appState.phase {
            case .idle:
                Button("Start Recording  ⌥Space") { toggle() }
            case .recording:
                Button("Stop Recording  ⌥Space") { toggle() }
                Button("Cancel Recording") { cancelRecording() }
            case .transcribing:
                Text("Transcribing…")
            }

            Divider()

            if !appState.transcribedText.isEmpty {
                Text("Last: \(appState.transcribedText.prefix(60))…")
                    .lineLimit(1)
                Divider()
            }

            Button("Settings…") {
                showSettings = true
                // Open the settings window via environment
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()
            Button("Quit Whispr") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Setup

    @MainActor
    private func setupOnAppear() {
        // Register global hotkey — ensure callback dispatches to MainActor
        hotkeyManager.onToggle = {
            Task { @MainActor in
                self.toggle()
            }
        }
        hotkeyManager.register()

        // Forward audio level and waveform to app state
        levelCancellable = audioEngine.$level
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevel, on: appState)

        // Forward waveform samples
        audioEngine.$waveformSamples
            .receive(on: DispatchQueue.main)
            .assign(to: &appState.$waveformSamples)

        // Load selected model if available
        loadModelIfNeeded()

        // Reload model when selection changes
        modelCancellable = appState.$selectedModel
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [self] _ in
                self.loadModelIfNeeded()
            }

        // Show onboarding if first launch
        if !appState.hasCompletedOnboarding {
            showOnboardingWindow()
        }
    }

    // MARK: - Toggle (core flow)

    @MainActor
    private func toggle() {
        pluginManager.notifyHotkeyPressed()
        switch appState.phase {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        case .transcribing:
            break // ignore during transcription
        }
    }

    @MainActor
    private func startRecording() {
        do {
            try audioEngine.start()
            appState.phase = .recording
            appState.elapsed = 0
            appState.partialTranscription = ""

            // Start elapsed timer
            let start = Date()
            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    self.appState.elapsed = Date().timeIntervalSince(start)
                }
            }

            // Start streaming transcription if enabled
            if appState.streamingEnabled {
                loadStreamingModelIfNeeded()
                streamingTranscriber.reset()
                streamingTranscriber.start(
                    audioEngine: audioEngine,
                    interval: appState.streamingChunkInterval
                )
                // Forward partial text to appState
                streamingCancellable = streamingTranscriber.$partialText
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.partialTranscription, on: appState)
            }

            // Notify plugins of recording start
            pluginManager.notifyRecordingStart()

            // Show overlay — wrap closures explicitly for MainActor safety
            overlayController.show(
                appState: appState,
                onStop: { @MainActor in self.stopAndTranscribe() },
                onCancel: { @MainActor in self.cancelRecording() }
            )
        } catch {
            print("Failed to start audio: \(error)")
        }
    }

    @MainActor
    private func stopAndTranscribe() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        // Notify plugins of recording stop
        pluginManager.notifyRecordingStop()

        // Stop streaming transcriber
        let streamingPartial = streamingTranscriber.stop()
        streamingCancellable = nil

        let buffer = audioEngine.stop()
        appState.audioLevel = 0

        let isStreaming = appState.streamingEnabled
        let draftAndFinal = appState.streamingDraftAndFinal
        let outputSpeed = appState.streamingOutputSpeed

        // In streaming mode without draft+final, use the partial text directly
        if isStreaming && !draftAndFinal && !streamingPartial.isEmpty {
            appState.phase = .idle

            var processed = TextPostProcessor.process(streamingPartial, options: appState.textProcessingOptions)
            processed = pluginManager.runTranscriptionPipeline(text: processed, language: appState.detectedLanguage)
            let replaced = wordReplacementManager.apply(to: processed)

            var text: String
            if let snippetText = snippetManager.match(replaced) {
                text = snippetText
            } else {
                text = replaced
            }
            text = pluginManager.runBeforeInjectionPipeline(text: text)
            appState.transcribedText = text

            injectFinalText(text, outputSpeed: outputSpeed)
            appState.partialTranscription = ""
            overlayController.hide()
            return
        }

        // Either non-streaming mode or draft+final mode — do full transcription
        appState.phase = .transcribing

        Task { @MainActor in
            do {
                if !whisperEngine.isLoaded {
                    loadModelIfNeeded()
                }

                // Configure language before transcription
                let isMultilingual = appState.selectedModel.isMultilingual
                whisperEngine.configureLanguage(appState.effectiveLanguage, isMultilingual: isMultilingual)

                let engine = whisperEngine
                let result = try await engine.transcribeWithTimestamps(buffer, isMultilingual: isMultilingual)

                // Update detected language state
                appState.detectedLanguage = result.detectedLanguage
                if result.detectedLanguage != nil {
                    appState.showLanguageIndicator = true
                }

                var processed = TextPostProcessor.process(result.text, options: appState.textProcessingOptions, segmentGaps: result.segmentGaps)

                // Run plugin transcription pipeline
                processed = pluginManager.runTranscriptionPipeline(text: processed, language: result.detectedLanguage)

                // Apply custom word replacements
                let replaced = wordReplacementManager.apply(to: processed)

                // Check for snippet match — if a trigger phrase matches, inject the snippet instead
                var text: String
                if let snippetText = snippetManager.match(replaced) {
                    text = snippetText
                } else {
                    text = replaced
                }

                // Run plugin before-injection pipeline
                text = pluginManager.runBeforeInjectionPipeline(text: text)
                appState.transcribedText = text

                // Use word-by-word injection in streaming mode
                if isStreaming {
                    injectFinalText(text, outputSpeed: outputSpeed)
                } else {
                    // Process voice commands if enabled, otherwise inject text directly
                    if appState.voiceCommandsEnabled {
                        let commandResult = VoiceCommandProcessor.process(text)
                        if !commandResult.actions.isEmpty {
                            VoiceCommandProcessor.execute(commandResult.actions, preferClipboard: appState.useClipboardFallback)
                        } else {
                            TextInjector.injectText(text, preferClipboard: appState.useClipboardFallback)
                        }
                    } else {
                        TextInjector.injectText(text, preferClipboard: appState.useClipboardFallback)
                    }
                }
            } catch {
                print("Transcription error: \(error)")
            }

            appState.phase = .idle
            appState.partialTranscription = ""

            // Show detected language briefly before hiding overlay
            if appState.showLanguageIndicator {
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
                appState.showLanguageIndicator = false
                appState.detectedLanguage = nil
            }

            overlayController.hide()
        }
    }

    /// Inject text with word-by-word output speed (or instant).
    @MainActor
    private func injectFinalText(_ text: String, outputSpeed: OutputSpeed) {
        if appState.voiceCommandsEnabled {
            let commandResult = VoiceCommandProcessor.process(text)
            if !commandResult.actions.isEmpty {
                VoiceCommandProcessor.execute(commandResult.actions, preferClipboard: appState.useClipboardFallback)
                return
            }
        }

        let delay = outputSpeed.wordDelayMicroseconds
        if delay > 0 {
            TextInjector.injectTextWordByWord(text, wordDelayMicroseconds: delay, preferClipboard: appState.useClipboardFallback)
        } else {
            TextInjector.injectText(text, preferClipboard: appState.useClipboardFallback)
        }
    }

    @MainActor
    private func cancelRecording() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        _ = streamingTranscriber.stop()
        streamingCancellable = nil
        _ = audioEngine.stop()
        appState.phase = .idle
        appState.audioLevel = 0
        appState.partialTranscription = ""
        overlayController.hide()
    }

    // MARK: - Model Loading

    private func loadModelIfNeeded() {
        let url = modelManager.localURL(for: appState.selectedModel)
        guard modelManager.isDownloaded(appState.selectedModel) else { return }
        try? whisperEngine.loadModel(at: url)
        pluginManager.notifyModelLoaded(model: appState.selectedModel.rawValue)
    }

    /// Load the streaming model (tiny.en for low latency). Falls back to the selected model.
    private func loadStreamingModelIfNeeded() {
        // Prefer tiny.en for streaming (fastest)
        let streamingModel: WhisperModel = modelManager.isDownloaded(.tinyEn) ? .tinyEn : appState.selectedModel
        let url = modelManager.localURL(for: streamingModel)
        guard modelManager.isDownloaded(streamingModel) else { return }
        streamingTranscriber.loadModel(at: url)
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboardingWindow() {
        let onboardingView = OnboardingView(
            appState: appState,
            modelManager: modelManager,
            onComplete: { @MainActor in
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Whispr"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
