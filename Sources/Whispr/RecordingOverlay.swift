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

struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState
    var onStop: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if appState.isRecording {
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

            // Volume meter
            VolumeMeter(level: appState.audioLevel)
                .frame(height: 8)

            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: onStop) {
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

// MARK: - Volume Meter

struct VolumeMeter: View {
    var level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(level))
                    .animation(.easeOut(duration: 0.05), value: level)
            }
        }
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

    func show(appState: AppState, onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
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
