import Foundation
import SwiftWhisper

/// Wraps SwiftWhisper to transcribe a Float32 PCM buffer into text.
final class WhisperEngine {

    private var whisper: Whisper?

    /// Load (or reload) a model from disk.
    func loadModel(at url: URL) throws {
        whisper = Whisper(fromFileURL: url)
    }

    /// Transcribe an audio buffer (16 kHz mono Float32).
    /// Returns the concatenated transcription text.
    func transcribe(_ audioBuffer: [Float]) async throws -> String {
        guard let whisper else {
            throw WhisperEngineError.modelNotLoaded
        }

        let segments = try await whisper.transcribe(audioFrames: audioBuffer)
        let text = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    var isLoaded: Bool { whisper != nil }
}

enum WhisperEngineError: Error, LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "No Whisper model loaded. Download one first."
        }
    }
}
