import Foundation
import SwiftWhisper

/// Result of a transcription including text and timing information.
struct TranscriptionResult {
    let text: String
    /// Time gaps (in seconds) between consecutive whisper segments.
    /// Used for auto-paragraph feature. Empty if only one segment.
    let segmentGaps: [TimeInterval]
}

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
        let result = try await transcribeWithTimestamps(audioBuffer)
        return result.text
    }

    /// Transcribe and return full result with segment gap information.
    func transcribeWithTimestamps(_ audioBuffer: [Float]) async throws -> TranscriptionResult {
        guard let whisper else {
            throw WhisperEngineError.modelNotLoaded
        }

        let segments = try await whisper.transcribe(audioFrames: audioBuffer)

        // Join segment texts with double-space as separator (for auto-paragraph splitting)
        let text = segments.map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ")

        // Calculate gaps between consecutive segments
        var gaps: [TimeInterval] = []
        for i in 1..<segments.count {
            let prevEnd = segments[i - 1].endTime
            let currStart = segments[i].startTime
            let gap = TimeInterval(currStart - prevEnd) / 1000.0 // whisper times are in ms
            gaps.append(gap)
        }

        return TranscriptionResult(text: text, segmentGaps: gaps)
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
