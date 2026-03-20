import Foundation
import AVFoundation

/// Represents a single file transcription job.
struct FileTranscriptionJob: Identifiable {
    let id: UUID
    let fileURL: URL
    var status: Status
    var progress: Double
    var result: FileTranscriptionResult?
    var error: String?

    enum Status: Equatable {
        case queued
        case converting
        case transcribing
        case completed
        case failed
    }

    var fileName: String { fileURL.lastPathComponent }

    init(fileURL: URL) {
        self.id = UUID()
        self.fileURL = fileURL
        self.status = .queued
        self.progress = 0
        self.result = nil
        self.error = nil
    }
}

/// Result of a file transcription, including segments with timestamps.
struct FileTranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let duration: TimeInterval
    let detectedLanguage: String?
}

/// A single timestamped segment from transcription.
struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let startTime: TimeInterval  // seconds
    let endTime: TimeInterval    // seconds
    let text: String
}

/// Handles converting audio/video files to PCM and transcribing them via WhisperEngine.
@MainActor
final class FileTranscriber: ObservableObject {

    /// All queued/active/completed jobs.
    @Published var jobs: [FileTranscriptionJob] = []

    /// Overall progress across all jobs (0-1).
    @Published var overallProgress: Double = 0

    /// Whether batch transcription is currently running.
    @Published var isProcessing: Bool = false

    /// Index of the currently processing job.
    @Published var currentJobIndex: Int = 0

    /// Supported file extensions.
    static let supportedExtensions: Set<String> = ["mp3", "m4a", "wav", "mp4", "mov", "aac", "flac", "ogg", "wma", "aiff"]

    private var whisperEngine: WhisperEngine?
    private var isCancelled = false

    /// Set the WhisperEngine to use for transcription.
    func setEngine(_ engine: WhisperEngine) {
        self.whisperEngine = engine
    }

    /// Add files to the transcription queue.
    func addFiles(_ urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else { continue }
            // Avoid duplicates
            guard !jobs.contains(where: { $0.fileURL == url }) else { continue }
            jobs.append(FileTranscriptionJob(fileURL: url))
        }
    }

    /// Remove a job from the queue (only if not currently processing).
    func removeJob(_ job: FileTranscriptionJob) {
        guard job.status == .queued || job.status == .completed || job.status == .failed else { return }
        jobs.removeAll { $0.id == job.id }
        updateOverallProgress()
    }

    /// Clear all completed/failed jobs.
    func clearCompleted() {
        jobs.removeAll { $0.status == .completed || $0.status == .failed }
        updateOverallProgress()
    }

    /// Start processing all queued jobs sequentially.
    func startBatch() async {
        guard !isProcessing else { return }
        guard whisperEngine?.isLoaded == true else { return }

        isProcessing = true
        isCancelled = false
        currentJobIndex = 0

        let queuedIndices = jobs.indices.filter { jobs[$0].status == .queued }

        for (batchIndex, jobIndex) in queuedIndices.enumerated() {
            guard !isCancelled else { break }
            currentJobIndex = batchIndex

            await processJob(at: jobIndex)
            updateOverallProgress()
        }

        isProcessing = false
    }

    /// Cancel the current batch.
    func cancelBatch() {
        isCancelled = true
    }

    // MARK: - Single Job Processing

    private func processJob(at index: Int) async {
        guard index < jobs.count else { return }

        jobs[index].status = .converting
        jobs[index].progress = 0

        do {
            // Step 1: Convert to PCM
            let (samples, duration) = try await convertToPCM(url: jobs[index].fileURL) { [weak self] progress in
                Task { @MainActor in
                    guard let self, index < self.jobs.count else { return }
                    self.jobs[index].progress = progress * 0.3  // conversion = 30% of total
                    self.updateOverallProgress()
                }
            }

            guard !isCancelled else {
                jobs[index].status = .queued
                return
            }

            // Step 2: Transcribe
            jobs[index].status = .transcribing
            jobs[index].progress = 0.3

            guard let engine = whisperEngine else {
                throw FileTranscriberError.engineNotLoaded
            }

            let result = try await engine.transcribeWithTimestamps(samples)

            guard !isCancelled else {
                jobs[index].status = .queued
                return
            }

            // Parse segments from the result
            // Re-transcribe to get proper segments with timestamps
            let segments = try await transcribeWithSegments(samples: samples, engine: engine)

            jobs[index].progress = 1.0
            jobs[index].status = .completed
            jobs[index].result = FileTranscriptionResult(
                text: result.text,
                segments: segments,
                duration: duration,
                detectedLanguage: result.detectedLanguage
            )

        } catch {
            jobs[index].status = .failed
            jobs[index].error = error.localizedDescription
        }
    }

    /// Transcribe and extract individual segments with timestamps.
    private func transcribeWithSegments(samples: [Float], engine: WhisperEngine) async throws -> [TranscriptionSegment] {
        let result = try await engine.transcribeWithTimestamps(samples)

        // Parse segment gaps from the result to reconstruct segments
        // Since WhisperEngine returns joined text, we split by double-space (segment separator)
        let parts = result.text.components(separatedBy: "  ").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if parts.count <= 1 {
            // Single segment — use full duration
            return [TranscriptionSegment(
                startTime: 0,
                endTime: Double(samples.count) / 16000.0,
                text: result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )]
        }

        // Estimate segment times based on word count distribution
        let totalDuration = Double(samples.count) / 16000.0
        let totalWords = parts.reduce(0) { $0 + $1.split(separator: " ").count }
        var currentTime: TimeInterval = 0
        var segments: [TranscriptionSegment] = []

        for part in parts {
            let wordCount = part.split(separator: " ").count
            let segDuration = totalDuration * Double(wordCount) / Double(max(totalWords, 1))
            segments.append(TranscriptionSegment(
                startTime: currentTime,
                endTime: currentTime + segDuration,
                text: part.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
            currentTime += segDuration
        }

        return segments
    }

    // MARK: - Audio Conversion

    /// Convert an audio or video file to 16kHz mono Float32 PCM samples.
    private func convertToPCM(url: URL, progressCallback: @escaping (Double) -> Void) async throws -> ([Float], TimeInterval) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let asset = AVURLAsset(url: url)

                    // Get audio track
                    guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                        throw FileTranscriberError.noAudioTrack
                    }

                    let duration = CMTimeGetSeconds(asset.duration)

                    // Set up reader
                    let reader = try AVAssetReader(asset: asset)

                    let outputSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16000,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false,
                    ]

                    let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
                    output.alwaysCopiesSampleData = false

                    guard reader.canAdd(output) else {
                        throw FileTranscriberError.readerConfigFailed
                    }
                    reader.add(output)

                    guard reader.startReading() else {
                        throw FileTranscriberError.readingFailed(reader.error?.localizedDescription ?? "Unknown error")
                    }

                    var samples: [Float] = []
                    let expectedSamples = Int(duration * 16000)
                    samples.reserveCapacity(expectedSamples)

                    while let sampleBuffer = output.copyNextSampleBuffer() {
                        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

                        let length = CMBlockBufferGetDataLength(blockBuffer)
                        let floatCount = length / MemoryLayout<Float>.size

                        var data = Data(count: length)
                        data.withUnsafeMutableBytes { rawPtr in
                            guard let ptr = rawPtr.baseAddress else { return }
                            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr)
                        }

                        let floatArray = data.withUnsafeBytes { rawPtr -> [Float] in
                            guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: Float.self) else { return [] }
                            return Array(UnsafeBufferPointer(start: ptr, count: floatCount))
                        }

                        samples.append(contentsOf: floatArray)

                        // Report progress
                        if expectedSamples > 0 {
                            let progress = min(Double(samples.count) / Double(expectedSamples), 1.0)
                            progressCallback(progress)
                        }
                    }

                    if reader.status == .failed {
                        throw FileTranscriberError.readingFailed(reader.error?.localizedDescription ?? "Unknown error")
                    }

                    continuation.resume(returning: (samples, duration))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func updateOverallProgress() {
        guard !jobs.isEmpty else {
            overallProgress = 0
            return
        }
        let total = jobs.reduce(0.0) { $0 + $1.progress }
        overallProgress = total / Double(jobs.count)
    }
}

// MARK: - Errors

enum FileTranscriberError: Error, LocalizedError {
    case noAudioTrack
    case engineNotLoaded
    case readerConfigFailed
    case readingFailed(String)
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "No audio track found in file."
        case .engineNotLoaded: return "Whisper model not loaded."
        case .readerConfigFailed: return "Failed to configure audio reader."
        case .readingFailed(let msg): return "Audio reading failed: \(msg)"
        case .conversionFailed: return "Audio conversion failed."
        }
    }
}
