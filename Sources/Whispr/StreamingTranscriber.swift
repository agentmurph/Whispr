import Foundation
import SwiftWhisper

/// Handles streaming (chunked) transcription during recording.
/// Periodically pulls audio from AudioEngine, transcribes chunks, and
/// emits partial results with deduplication.
@MainActor
final class StreamingTranscriber: ObservableObject {

    /// Accumulated transcription from completed chunks.
    @Published var partialText: String = ""

    private var chunkTimer: Timer?
    private var whisper: Whisper?
    private var isRunning = false

    /// Number of audio samples (at 16kHz) to overlap between chunks for dedup.
    private let overlapSamples: Int = 16_000 // 1 second overlap

    /// Accumulated text segments from each chunk (for dedup).
    private var accumulatedSegments: [String] = []

    /// Track how many samples we've already transcribed (to avoid re-transcribing everything).
    private var lastTranscribedSampleCount: Int = 0

    // MARK: - Lifecycle

    /// Load a fast model (tiny.en) for streaming chunks.
    func loadModel(at url: URL) {
        whisper = Whisper(fromFileURL: url)
        whisper?.params.language = .english
    }

    var isLoaded: Bool { whisper != nil }

    /// Reference to the audio engine for pulling samples during streaming.
    private weak var activeAudioEngine: AudioEngine?

    /// Start periodic chunk transcription.
    /// - Parameters:
    ///   - audioEngine: The running audio engine to pull samples from.
    ///   - interval: Seconds between chunk transcriptions.
    func start(audioEngine: AudioEngine, interval: TimeInterval) {
        guard !isRunning else { return }
        isRunning = true
        partialText = ""
        accumulatedSegments = []
        lastTranscribedSampleCount = 0
        activeAudioEngine = audioEngine

        chunkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let engine = self.activeAudioEngine else { return }
                await self.transcribeChunk(from: engine)
            }
        }
    }

    /// Stop streaming and return the accumulated partial text.
    func stop() -> String {
        chunkTimer?.invalidate()
        chunkTimer = nil
        isRunning = false
        activeAudioEngine = nil
        let result = partialText
        return result
    }

    /// Reset state for a new recording session.
    func reset() {
        partialText = ""
        accumulatedSegments = []
        lastTranscribedSampleCount = 0
    }

    // MARK: - Chunk Transcription

    private func transcribeChunk(from audioEngine: AudioEngine) async {
        guard let whisper, isRunning else { return }

        // Get current buffer snapshot from audio engine
        let samples = audioEngine.currentBuffer()
        let sampleCount = samples.count

        // Need at least 0.5s of new audio to bother transcribing
        guard sampleCount > lastTranscribedSampleCount + 8_000 else { return }

        // Determine chunk start — include overlap from previous chunk for context
        let chunkStart = max(0, lastTranscribedSampleCount - overlapSamples)
        let chunk = Array(samples[chunkStart...])

        do {
            let segments = try await whisper.transcribe(audioFrames: chunk)
            let chunkText = segments.map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !chunkText.isEmpty else { return }

            // Deduplicate against previous accumulated text
            let deduped = deduplicateText(existing: partialText, new: chunkText)

            if !deduped.isEmpty {
                if partialText.isEmpty {
                    partialText = deduped
                } else {
                    partialText = partialText + " " + deduped
                }
            }

            lastTranscribedSampleCount = sampleCount
        } catch {
            // Silently skip failed chunks — next one will retry
            print("Streaming chunk transcription error: \(error)")
        }
    }

    // MARK: - Text Deduplication

    /// Remove overlapping text between the existing accumulated result and a new chunk.
    /// Returns only the new, non-overlapping portion.
    private func deduplicateText(existing: String, new: String) -> String {
        guard !existing.isEmpty else { return new }

        let existingWords = existing.lowercased().split(separator: " ").map(String.init)
        let newWords = new.lowercased().split(separator: " ").map(String.init)
        let originalNewWords = new.split(separator: " ").map(String.init)

        guard !existingWords.isEmpty, !newWords.isEmpty else { return new }

        // Find the longest suffix of existing that matches a prefix of new
        var bestOverlap = 0
        let maxCheck = min(existingWords.count, newWords.count)

        for overlapLen in 1...maxCheck {
            let existingSuffix = Array(existingWords.suffix(overlapLen))
            let newPrefix = Array(newWords.prefix(overlapLen))

            if existingSuffix == newPrefix {
                bestOverlap = overlapLen
            }
        }

        if bestOverlap > 0 {
            // Return only the non-overlapping tail of the new text
            let remaining = Array(originalNewWords.dropFirst(bestOverlap))
            return remaining.joined(separator: " ")
        }

        return new
    }
}
