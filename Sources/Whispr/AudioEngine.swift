import AVFoundation
import Combine

/// Captures microphone audio, buffers 16 kHz mono Float32 PCM, and publishes RMS level.
final class AudioEngine: ObservableObject {

    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    /// Published RMS audio level (0‑1). Observed by the overlay volume meter.
    @Published var level: Float = 0

    // MARK: - Start / Stop

    func start() throws {
        audioBuffer = []

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target: 16 kHz, mono, Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioEngineError.formatCreationFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioEngineError.converterCreationFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] pcmBuffer, _ in
            guard let self else { return }
            self.convert(pcmBuffer, using: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        bufferLock.lock()
        let captured = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        return captured
    }

    // MARK: - Internals

    private func convert(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCount = AVAudioFrameCount(
            Double(inputBuffer.frameLength) * (16_000.0 / inputBuffer.format.sampleRate)
        )
        guard frameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount)
        else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard error == nil, let floatData = outputBuffer.floatChannelData else { return }

        let count = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: count))

        // Append to recording buffer
        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        // Compute RMS for level meter
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(max(count, 1)))
        let clamped = min(max(rms * 5, 0), 1) // amplify a bit, clamp 0‑1

        DispatchQueue.main.async { [weak self] in
            self?.level = clamped
        }
    }
}

enum AudioEngineError: Error, LocalizedError {
    case formatCreationFailed
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .formatCreationFailed: return "Failed to create 16 kHz audio format."
        case .converterCreationFailed: return "Failed to create audio converter."
        }
    }
}
