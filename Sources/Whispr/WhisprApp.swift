import SwiftUI
import Combine

@main
struct WhisprApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelManager = ModelManager()

    // Non-UI managers (created once, stored as state)
    @State private var audioEngine = AudioEngine()
    @State private var whisperEngine = WhisperEngine()
    @State private var hotkeyManager = HotkeyManager()
    @State private var overlayController = OverlayController()

    @State private var elapsedTimer: Timer?
    @State private var levelCancellable: AnyCancellable?
    @State private var showOnboarding = false
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
            SettingsView(appState: appState, modelManager: modelManager)
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

    private func setupOnAppear() {
        // Register global hotkey
        hotkeyManager.onToggle = { [self] in
            Task { @MainActor in self.toggle() }
        }
        hotkeyManager.register()

        // Forward audio level to app state
        levelCancellable = audioEngine.$level
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevel, on: appState)

        // Load selected model if available
        loadModelIfNeeded()

        // Show onboarding if first launch
        if !appState.hasCompletedOnboarding {
            showOnboardingWindow()
        }
    }

    // MARK: - Toggle (core flow)

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

    private func startRecording() {
        do {
            try audioEngine.start()
            appState.phase = .recording
            appState.elapsed = 0

            // Start elapsed timer
            let start = Date()
            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    appState.elapsed = Date().timeIntervalSince(start)
                }
            }

            // Show overlay
            overlayController.show(
                appState: appState,
                onStop: { stopAndTranscribe() },
                onCancel: { cancelRecording() }
            )
        } catch {
            print("Failed to start audio: \(error)")
        }
    }

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

                let text = try await whisperEngine.transcribe(buffer)
                appState.transcribedText = text

                // Inject text
                if appState.useClipboardFallback {
                    TextInjector.pasteText(text)
                } else {
                    TextInjector.typeText(text)
                }
            } catch {
                print("Transcription error: \(error)")
            }

            appState.phase = .idle
            overlayController.hide()
        }
    }

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

    private func showOnboardingWindow() {
        let onboardingView = OnboardingView(
            appState: appState,
            modelManager: modelManager,
            onComplete: { /* window will close naturally */ }
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
    }
}
