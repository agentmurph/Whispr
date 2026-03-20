import SwiftUI
import AppKit

// MARK: - Overlay Panel (NSPanel wrapper)

/// A non-activating, always-on-top panel that doesn't steal focus.
final class OverlayPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

// MARK: - SwiftUI Overlay View

@MainActor
struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState
    var onStop: @MainActor () -> Void
    var onCancel: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if appState.showLanguageIndicator, let lang = appState.detectedLanguage {
                languageFlashContent(lang)
            } else if appState.isRecording {
                recordingContent
            } else if appState.isTranscribing {
                transcribingContent
            }
        }
        .padding(24)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recording State

    private var recordingContent: some View {
        VStack(spacing: 14) {
            // Pulsing red indicator + elapsed time
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .opacity(pulseOpacity)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseOpacity)

                Text(formattedElapsed)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Waveform visualization
            WaveformView(samples: appState.waveformSamples)
                .frame(height: 40)

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }

            // Hotkey hint
            Text("Press ⌥Space to stop")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Transcribing State

    private var transcribingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Transcribing…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Language Flash

    private func languageFlashContent(_ langCode: String) -> some View {
        VStack(spacing: 10) {
            Text(WhisperEngine.languageFlag(for: langCode))
                .font(.system(size: 36))
            Text(WhisperEngine.languageDisplayName(for: langCode))
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Detected language")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    // MARK: - Helpers

    private var pulseOpacity: Double {
        appState.isRecording ? 0.3 : 1.0
    }

    private var formattedElapsed: String {
        let m = Int(appState.elapsed) / 60
        let s = Int(appState.elapsed) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    var samples: [Float]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<samples.count, id: \.self) { index in
                    WaveformBar(level: CGFloat(samples[index]), maxHeight: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WaveformBar: View {
    var level: CGFloat
    var maxHeight: CGFloat

    var body: some View {
        let barHeight = max(2, level * maxHeight)
        RoundedRectangle(cornerRadius: 1.5)
            .fill(barColor)
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.08), value: level)
    }

    private var barColor: Color {
        if level > 0.8 { return .red }
        if level > 0.5 { return .orange }
        return .green
    }
}

// MARK: - Overlay Controller

/// Manages showing/hiding the NSPanel overlay.
@MainActor
final class OverlayController {

    private var panel: OverlayPanel?

    func show(appState: AppState, onStop: @escaping @MainActor () -> Void, onCancel: @escaping @MainActor () -> Void) {
        let view = RecordingOverlayView(appState: appState, onStop: onStop, onCancel: onCancel)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 200)

        // Center on main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelRect = NSRect(
            x: screenFrame.midX - 140,
            y: screenFrame.midY - 100,
            width: 280,
            height: 200
        )

        let p = OverlayPanel(contentRect: panelRect)
        p.contentView = hostingView
        p.orderFrontRegardless()
        panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
