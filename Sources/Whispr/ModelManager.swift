import Foundation
import Combine

/// Available Whisper models — both English-only and multilingual.
enum WhisperModel: String, CaseIterable, Identifiable {
    // English-only models
    case tinyEn   = "ggml-tiny.en"
    case baseEn   = "ggml-base.en"
    case smallEn  = "ggml-small.en"
    case mediumEn = "ggml-medium.en"

    // Multilingual models
    case tiny     = "ggml-tiny"
    case base     = "ggml-base"
    case small    = "ggml-small"
    case medium   = "ggml-medium"

    var id: String { rawValue }

    /// Whether this is an English-only model.
    var isEnglishOnly: Bool {
        switch self {
        case .tinyEn, .baseEn, .smallEn, .mediumEn: return true
        case .tiny, .base, .small, .medium: return false
        }
    }

    /// Whether this model supports multiple languages (auto-detect).
    var isMultilingual: Bool { !isEnglishOnly }

    var displayName: String {
        switch self {
        case .tinyEn:   return "Tiny (English)"
        case .baseEn:   return "Base (English)"
        case .smallEn:  return "Small (English)"
        case .mediumEn: return "Medium (English)"
        case .tiny:     return "Tiny (Multilingual)"
        case .base:     return "Base (Multilingual)"
        case .small:    return "Small (Multilingual)"
        case .medium:   return "Medium (Multilingual)"
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
        case .tiny:     return "75 MB"
        case .base:     return "142 MB"
        case .small:    return "466 MB"
        case .medium:   return "1.5 GB"
        }
    }

    /// Speed description for UI.
    var speedLabel: String {
        switch self {
        case .tinyEn, .tiny:     return "~10× realtime"
        case .baseEn, .base:     return "~7× realtime"
        case .smallEn, .small:   return "~3× realtime"
        case .mediumEn, .medium: return "~1× realtime"
        }
    }

    /// Language support label for the model tab.
    var languageLabel: String {
        isEnglishOnly ? "English only" : "99 languages · Auto-detect"
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    /// CoreML encoder model zip URL (for Apple Silicon acceleration).
    var coreMLDownloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(rawValue)-encoder.mlmodelc.zip")!
    }

    /// Expected directory name for the CoreML encoder model.
    var coreMLDirectoryName: String { rawValue + "-encoder.mlmodelc" }

    /// English-only models.
    static var englishOnly: [WhisperModel] {
        [.tinyEn, .baseEn, .smallEn, .mediumEn]
    }

    /// Multilingual models.
    static var multilingual: [WhisperModel] {
        [.tiny, .base, .small, .medium]
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

    /// Whether the current Mac has Apple Silicon (CoreML acceleration available).
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// Whether the CoreML encoder model is available for a given model.
    func isCoreMLAvailable(_ model: WhisperModel) -> Bool {
        let dir = Self.modelsDirectory.appendingPathComponent(model.coreMLDirectoryName, isDirectory: true)
        return FileManager.default.fileExists(atPath: dir.path)
    }

    /// Download a model with progress. Uses URLSessionDownloadTask.
    /// On Apple Silicon, also downloads the CoreML encoder model for acceleration.
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
            // Download GGML model
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

            // On Apple Silicon, also download the CoreML encoder model
            if Self.isAppleSilicon {
                try await downloadCoreMLModel(model)
            }
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

    /// Download and unzip the CoreML encoder model for Apple Silicon acceleration.
    private func downloadCoreMLModel(_ model: WhisperModel) async throws {
        // Reset progress for CoreML download
        downloadProgress = 0
        bytesDownloaded = 0
        totalBytes = -1

        let tempZipURL: URL = try await withCheckedThrowingContinuation { continuation in
            self.downloadContinuation = continuation
            let task = self.urlSession.downloadTask(with: model.coreMLDownloadURL)
            self.downloadTask = task
            task.resume()
        }

        // Unzip to models directory
        let destDir = Self.modelsDirectory
        let coreMLDir = destDir.appendingPathComponent(model.coreMLDirectoryName, isDirectory: true)

        // Remove existing if present
        if FileManager.default.fileExists(atPath: coreMLDir.path) {
            try FileManager.default.removeItem(at: coreMLDir)
        }

        // Unzip using Process (ditto or unzip)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", destDir.path]
        process.standardOutput = nil
        process.standardError = nil
        try process.run()
        process.waitUntilExit()

        // Clean up temp zip
        try? FileManager.default.removeItem(at: tempZipURL)

        downloadProgress = 1.0
    }

    /// Cancel the current download.
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        // Continuation will be resumed with error by the delegate
    }

    /// Delete a downloaded model (including CoreML encoder if present).
    func delete(_ model: WhisperModel) throws {
        let url = localURL(for: model)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Also remove CoreML encoder directory
        let coreMLDir = Self.modelsDirectory.appendingPathComponent(model.coreMLDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: coreMLDir.path) {
            try FileManager.default.removeItem(at: coreMLDir)
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
