import SwiftUI
import AVFoundation

@MainActor
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var modelManager: ModelManager
    var onComplete: @MainActor () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var micGranted = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case microphone
        case accessibility
        case downloadModel
        case ready
    }

    var body: some View {
        VStack(spacing: 24) {
            stepContent
        }
        .padding(40)
        .frame(width: 480, height: 400)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .microphone:
            microphoneStep
        case .accessibility:
            accessibilityStep
        case .downloadModel:
            downloadStep
        case .ready:
            readyStep
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Welcome to Whispr")
                .font(.largeTitle.bold())

            Text("Voice-to-text that runs entirely on your Mac.\nNo cloud. No subscription. No data leaves your machine.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Get Started") { step = .microphone }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Microphone Access")
                .font(.title.bold())

            Text("Whispr needs microphone access to hear you speak.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Grant Microphone Access") {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        micGranted = granted
                        step = .accessibility
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("Accessibility Permission")
                .font(.title.bold())

            Text("Whispr types text into apps using the Accessibility API.\n\nOpen **System Settings → Privacy & Security → Accessibility** and add Whispr.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Continue") { step = .downloadModel }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    private var downloadStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Download Model")
                .font(.title.bold())

            Text("Downloading **Base English** model (≈142 MB).\nThis is a one-time download.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if modelManager.isDownloading {
                ProgressView(value: modelManager.downloadProgress)
                    .progressViewStyle(.linear)
                Text("\(Int(modelManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if modelManager.isDownloaded(.baseEn) {
                Button("Continue") { step = .ready }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else if !modelManager.isDownloading {
                Button("Download Model") {
                    Task {
                        try? await modelManager.download(.baseEn)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle.bold())

            Text("Press **⌥ Space** (Option + Space) to toggle recording.\nSpeak, stop, and your words appear wherever you're typing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start Using Whispr") {
                appState.hasCompletedOnboarding = true
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
