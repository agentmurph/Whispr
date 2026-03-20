import Foundation
import Combine

/// Available Whisper models (English-only).
enum WhisperModel: String, CaseIterable, Identifiable {
    case tinyEn   = "ggml-tiny.en"
    case baseEn   = "ggml-base.en"
    case smallEn  = "ggml-small.en"
    case mediumEn = "ggml-medium.en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tinyEn:   return "Tiny (English)"
        case .baseEn:   return "Base (English)"
        case .smallEn:  return "Small (English)"
        case .mediumEn: return "Medium (English)"
        }
    }

    var fileName: String { rawValue + ".bin" }

    /// Approximate download size for display.
    var sizeLabel: String {
        switch self {
        case .tinyEn:   return "75 MB"
        case .baseEn:   return "142 MB"
        case .smallEn:  return "466 MB"
        case .mediumEn: return "1.5 GB"
        }
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }
}

/// Downloads, stores, and manages Whisper model files.
@MainActor
final class ModelManager: ObservableObject {

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadError: String?

    static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispr/Models", isDirectory: true)
    }()

    init() {
        try? FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
    }

    /// Local file URL for a model (may or may not exist yet).
    func localURL(for model: WhisperModel) -> URL {
        Self.modelsDirectory.appendingPathComponent(model.fileName)
    }

    /// Whether a model is already downloaded.
    func isDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: model).path)
    }

    /// Download a model. Progress published to `downloadProgress`.
    func download(_ model: WhisperModel) async throws {
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        defer { isDownloading = false }

        let destination = localURL(for: model)

        // Stream download with progress
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: model.downloadURL)
        let totalBytes = response.expectedContentLength
        var data = Data()
        if totalBytes > 0 { data.reserveCapacity(Int(totalBytes)) }

        var received: Int64 = 0
        for try await byte in asyncBytes {
            data.append(byte)
            received += 1
            if totalBytes > 0, received % 65_536 == 0 {
                downloadProgress = Double(received) / Double(totalBytes)
            }
        }

        downloadProgress = 1.0
        try data.write(to: destination, options: .atomic)
    }

    /// Delete a downloaded model.
    func delete(_ model: WhisperModel) throws {
        let url = localURL(for: model)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
