import Foundation
import SwiftWhisper
import whisper_cpp

/// Result of a transcription including detected language.
struct TranscriptionResult {
    let text: String
    /// Segment gaps for auto-paragraph support.
    let segmentGaps: [TimeInterval]?
    /// Detected language code (e.g. "en", "es", "fr") — nil for English-only models.
    let detectedLanguage: String?

    /// Human-readable name for the detected language.
    var detectedLanguageName: String? {
        guard let code = detectedLanguage else { return nil }
        return WhisperEngine.languageDisplayName(for: code)
    }
}

/// Wraps SwiftWhisper to transcribe a Float32 PCM buffer into text.
final class WhisperEngine {

    private var whisper: Whisper?

    /// Load (or reload) a model from disk.
    func loadModel(at url: URL) throws {
        whisper = Whisper(fromFileURL: url)
    }

    /// Configure language for transcription.
    /// - For multilingual models: set to a specific language or .auto for detection.
    /// - For English-only models: always set to .english.
    func configureLanguage(_ language: WhisperLanguage, isMultilingual: Bool) {
        guard let whisper else { return }
        if isMultilingual {
            whisper.params.language = language
        } else {
            whisper.params.language = .english
        }
    }

    /// Transcribe with timestamps (used by main app flow). Returns TranscriptionResult with gaps and language.
    func transcribeWithTimestamps(_ audioBuffer: [Float], isMultilingual: Bool = false) async throws -> TranscriptionResult {
        guard let whisper else {
            throw WhisperEngineError.modelNotLoaded
        }

        let segments = try await whisper.transcribe(audioFrames: audioBuffer)
        let text = segments.map(\.text).joined(separator: "  ").trimmingCharacters(in: .whitespacesAndNewlines)

        // Compute gaps between consecutive segments
        var gaps: [TimeInterval] = []
        for i in 1..<segments.count {
            let gap = Double(segments[i].startTime - segments[i - 1].endTime) / 1000.0
            gaps.append(gap)
        }

        // Get detected language for multilingual models
        var detectedLanguage: String?
        if isMultilingual {
            detectedLanguage = whisper.params.language.rawValue
        }

        return TranscriptionResult(text: text, segmentGaps: gaps.isEmpty ? nil : gaps, detectedLanguage: detectedLanguage)
    }

    /// Simple transcribe (backward compat). Returns just the text.
    func transcribe(_ audioBuffer: [Float]) async throws -> String {
        let result = try await transcribeWithTimestamps(audioBuffer)
        return result.text
    }

    var isLoaded: Bool { whisper != nil }

    // MARK: - Language Helpers

    /// Common languages shown in the settings picker.
    static let commonLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("pt", "Portuguese"),
        ("it", "Italian"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("tr", "Turkish"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("no", "Norwegian"),
        ("fi", "Finnish"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
        ("uk", "Ukrainian"),
        ("cs", "Czech"),
        ("ro", "Romanian"),
        ("hu", "Hungarian"),
        ("el", "Greek"),
        ("id", "Indonesian"),
        ("ms", "Malay"),
        ("he", "Hebrew"),
        ("ca", "Catalan"),
    ]

    /// Map a language code to a human-readable display name.
    static func languageDisplayName(for code: String) -> String {
        if let match = commonLanguages.first(where: { $0.code == code }) {
            return match.name
        }
        if let lang = WhisperLanguage(rawValue: code) {
            return lang.displayName.capitalized
        }
        return code.uppercased()
    }

    /// Flag emoji for a language code (best-effort).
    static func languageFlag(for code: String) -> String {
        let flagMap: [String: String] = [
            "en": "🇬🇧", "es": "🇪🇸", "fr": "🇫🇷", "de": "🇩🇪", "zh": "🇨🇳",
            "ja": "🇯🇵", "ko": "🇰🇷", "pt": "🇧🇷", "it": "🇮🇹", "ru": "🇷🇺",
            "ar": "🇸🇦", "hi": "🇮🇳", "nl": "🇳🇱", "pl": "🇵🇱", "tr": "🇹🇷",
            "sv": "🇸🇪", "da": "🇩🇰", "no": "🇳🇴", "fi": "🇫🇮", "th": "🇹🇭",
            "vi": "🇻🇳", "uk": "🇺🇦", "cs": "🇨🇿", "ro": "🇷🇴", "hu": "🇭🇺",
            "el": "🇬🇷", "id": "🇮🇩", "ms": "🇲🇾", "iw": "🇮🇱", "ca": "🏴",
        ]
        return flagMap[code] ?? "🌐"
    }
}

enum WhisperEngineError: Error, LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "No Whisper model loaded. Download one first."
        }
    }
}
