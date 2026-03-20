import Foundation
import Combine
import SwiftUI
import ServiceManagement
import SwiftWhisper

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

    /// Detected language after transcription (for multilingual models).
    @Published var detectedLanguage: String?

    /// Whether to show the language indicator flash.
    @Published var showLanguageIndicator: Bool = false

    // MARK: - Model

    @Published var selectedModel: WhisperModel = .baseEn

    // MARK: - Language

    /// Selected language code for transcription.
    /// "auto" means auto-detect (only for multilingual models).
    /// For English-only models, this is ignored and forced to "en".
    @AppStorage("selectedLanguageCode") var selectedLanguageCode: String = "auto"

    /// The effective WhisperLanguage for transcription.
    var effectiveLanguage: SwiftWhisper.WhisperLanguage {
        if selectedModel.isEnglishOnly {
            return .english
        }
        if selectedLanguageCode == "auto" {
            return .auto
        }
        return SwiftWhisper.WhisperLanguage(rawValue: selectedLanguageCode) ?? .auto
    }

    // MARK: - Settings

    @Published var useClipboardFallback: Bool = false
    @Published var launchAtLogin: Bool = false

    // MARK: - Text Processing

    @AppStorage("textProcessing.trimWhitespace") var trimWhitespace: Bool = true
    @AppStorage("textProcessing.autoCapitalize") var autoCapitalize: Bool = true
    @AppStorage("textProcessing.ensurePunctuation") var ensurePunctuation: Bool = true
    @AppStorage("textProcessing.smartQuotes") var smartQuotes: Bool = false
    @AppStorage("textProcessing.numberFormatting") var numberFormatting: Bool = false
    @AppStorage("textProcessing.removeFillerWords") var removeFillerWords: Bool = false
    @AppStorage("textProcessing.autoParagraph") var autoParagraph: Bool = false

    /// Build current post-processing options from settings.
    var textProcessingOptions: TextPostProcessor.Options {
        TextPostProcessor.Options(
            trimWhitespace: trimWhitespace,
            autoCapitalize: autoCapitalize,
            ensurePunctuation: ensurePunctuation,
            smartQuotes: smartQuotes,
            numberFormatting: numberFormatting,
            removeFillerWords: removeFillerWords,
            autoParagraph: autoParagraph
        )
    }

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
