import Foundation

/// Simple file logger that writes timestamped entries to ~/Library/Logs/Whispr/whispr.log.
/// Thread-safe via a serial dispatch queue.
enum WhisprLogger {

    private static let queue = DispatchQueue(label: "com.whispr.logger")
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static var fileHandle: FileHandle?
    private static var logFileURL: URL?

    /// Set up the log file. Call once at app launch.
    static func setup() {
        queue.sync {
            let logsDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/Whispr")
            try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

            let url = logsDir.appendingPathComponent("whispr.log")
            logFileURL = url

            // Create file if needed
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            // Truncate if over 5 MB
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64, size > 5_000_000 {
                try? "".write(to: url, atomically: true, encoding: .utf8)
            }

            fileHandle = try? FileHandle(forWritingTo: url)
            fileHandle?.seekToEndOfFile()

            writeRaw("--- Whispr launched at \(dateFormatter.string(from: Date())) ---\n")
        }
    }

    static func info(_ message: String, file: String = #fileID, function: String = #function) {
        log(level: "INFO", message: message, file: file, function: function)
    }

    static func error(_ message: String, file: String = #fileID, function: String = #function) {
        log(level: "ERROR", message: message, file: file, function: function)
    }

    static func debug(_ message: String, file: String = #fileID, function: String = #function) {
        log(level: "DEBUG", message: message, file: file, function: function)
    }

    /// Path to the log file for display in settings / sharing.
    static var logFilePath: String {
        logFileURL?.path ?? "~/Library/Logs/Whispr/whispr.log"
    }

    // MARK: - Internal

    private static func log(level: String, message: String, file: String, function: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(file):\(function)] \(message)\n"
        queue.async {
            writeRaw(line)
        }
        // Also print to stdout for Xcode console
        print("[\(level)] \(message)")
    }

    private static func writeRaw(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        fileHandle?.write(data)
    }
}
