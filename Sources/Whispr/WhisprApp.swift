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

    // Non-UI managers stored as let (created once)
    // Using nonisolated(unsafe) to avoid @State wrapping @MainActor classes
    @State private var audioEngine = AudioEngine()
    @State private var whisperEngine = WhisperEngine()
    @State private var hotkeyManager = HotkeyManager()
    @State private var overlayController = OverlayController()

    @State private var elapsedTimer: Timer?
    @State private var levelCancellable: AnyCancellable?
    @State private var modelCancellable: AnyCancellable?
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
            SettingsView(appState: appState, modelManager: modelManager, hotkeyProfileManager: hotkeyProfileManager, snippetManager: snippetManager, wordReplacementManager: wordReplacementManager)
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

            // Start elapsed timer
            let start = Date()
            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    self.appState.elapsed = Date().timeIntervalSince(start)
                }
            }

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

        let buffer = audioEngine.stop()
        appState.phase = .transcribing
        appState.audioLevel = 0

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

                let processed = TextPostProcessor.process(result.text, options: appState.textProcessingOptions, segmentGaps: result.segmentGaps)

                // Apply custom word replacements
                let replaced = wordReplacementManager.apply(to: processed)

                // Check for snippet match — if a trigger phrase matches, inject the snippet instead
                let text: String
                if let snippetText = snippetManager.match(replaced) {
                    text = snippetText
                } else {
                    text = replaced
                }
                appState.transcribedText = text

                // Inject text (auto-detects secure fields and falls back to clipboard paste)
                TextInjector.injectText(text, preferClipboard: appState.useClipboardFallback)
            } catch {
                print("Transcription error: \(error)")
            }

            appState.phase = .idle
            overlayController.hide()
        }
    }

    @MainActor
    private func cancelRecording() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        _ = audioEngine.stop()
        appState.phase = .idle
        appState.audioLevel = 0
        overlayController.hide()
    }

    // MARK: - Model Loading

    private func loadModelIfNeeded() {
        let url = modelManager.localURL(for: appState.selectedModel)
        guard modelManager.isDownloaded(appState.selectedModel) else { return }
        try? whisperEngine.loadModel(at: url)
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
