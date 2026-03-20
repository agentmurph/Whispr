import Foundation
import Combine
import SwiftUI
import ServiceManagement

/// Central observable state for the entire app.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Recording / Transcription State

    enum Phase {
        case idle
        case recording
        case transcribing
    }

    @Published var phase: Phase = .idle

    var isRecording: Bool { phase == .recording }
    var isTranscribing: Bool { phase == .transcribing }

    /// 0‑1 RMS audio level published by AudioEngine.
    @Published var audioLevel: Float = 0

    /// Recent waveform samples for visualization (ring buffer from AudioEngine).
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 40)

    /// Seconds elapsed since recording started.
    @Published var elapsed: TimeInterval = 0

    /// Last transcription result.
    @Published var transcribedText: String = ""

    // MARK: - Model

    @Published var selectedModel: WhisperModel = .baseEn

    // MARK: - Settings

    @Published var useClipboardFallback: Bool = false
    @Published var launchAtLogin: Bool = false

    // MARK: - Onboarding

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // MARK: - Init

    init() {
        // Sync launch-at-login state with the system
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
