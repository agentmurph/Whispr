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

    /// Speed description for UI.
    var speedLabel: String {
        switch self {
        case .tinyEn:   return "~10× realtime"
        case .baseEn:   return "~7× realtime"
        case .smallEn:  return "~3× realtime"
        case .mediumEn: return "~1× realtime"
        }
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }
}

/// Downloads, stores, and manages Whisper model files.
/// Uses URLSessionDownloadTask for proper progress reporting and cancellation.
@MainActor
final class ModelManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// 0.0–1.0 fraction complete.
    @Published var downloadProgress: Double = 0

    /// Bytes received so far.
    @Published var bytesDownloaded: Int64 = 0

    /// Total expected bytes (-1 if unknown).
    @Published var totalBytes: Int64 = -1

    /// Whether a download is in progress.
    @Published var isDownloading: Bool = false

    /// Which model is currently downloading (nil if none).
    @Published var currentDownload: WhisperModel?

    /// Human-readable error from last attempt.
    @Published var downloadError: String?

    // MARK: - Internals

    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispr/Models", isDirectory: true)
    }()

    override init() {
        super.init()
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

    /// Download a model with progress. Uses URLSessionDownloadTask.
    func download(_ model: WhisperModel) async throws {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        bytesDownloaded = 0
        totalBytes = -1
        downloadError = nil
        currentDownload = model

        defer {
            isDownloading = false
            currentDownload = nil
            downloadTask = nil
        }

        do {
            let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
                self.downloadContinuation = continuation
                let task = self.urlSession.downloadTask(with: model.downloadURL)
                self.downloadTask = task
                task.resume()
            }

            // Move temp file to final destination
            let destination = localURL(for: model)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            downloadProgress = 1.0
        } catch is CancellationError {
            downloadError = "Download cancelled."
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            downloadError = "Download cancelled."
        } catch {
            downloadError = error.localizedDescription
            throw error
        }
    }

    /// Cancel the current download.
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        // Continuation will be resumed with error by the delegate
    }

    /// Delete a downloaded model.
    func delete(_ model: WhisperModel) throws {
        let url = localURL(for: model)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Human-readable string for bytes (e.g., "42.5 MB").
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.bytesDownloaded = totalBytesWritten
            self.totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to a temp location we control (the original will be deleted by the system)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        try? FileManager.default.moveItem(at: location, to: tempURL)

        Task { @MainActor in
            self.downloadContinuation?.resume(returning: tempURL)
            self.downloadContinuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
}
