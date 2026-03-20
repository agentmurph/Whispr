import Foundation
import SwiftUI

// MARK: - Markdown Formatter Plugin

/// Detects speech patterns that suggest lists, headers, or emphasis,
/// and wraps the transcription in markdown formatting.
final class MarkdownFormatterPlugin: WhisprPlugin {
    var name: String { "Markdown Formatter" }
    var version: String { "1.0.0" }
    var description: String { "Detects lists and headers from speech patterns and formats as markdown." }

    func onTranscription(text: String, language: String?) -> String {
        var result = text

        // Detect "bullet" / "dash" / "item" at start of lines → markdown list
        result = applyListDetection(result)

        // Detect "heading" / "title" speech patterns → markdown headers
        result = applyHeaderDetection(result)

        // Detect "bold" / "emphasize" patterns → **bold**
        result = applyEmphasisDetection(result)

        return result
    }

    private func applyListDetection(_ text: String) -> String {
        // Patterns like "bullet point X", "item X", "dash X", "next item X"
        let patterns: [(regex: String, replacement: String)] = [
            (#"(?i)\bbullet\s*point\s+"#, "- "),
            (#"(?i)\bnext\s*item\s+"#, "- "),
            (#"(?i)\bdash\s+"#, "- "),
            (#"(?i)\bitem\s*(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s*[,:]\s*"#, "- "),
            (#"(?i)^(?:first|second|third|fourth|fifth)\s*[,:]\s*"#, "- "),
        ]

        var result = text
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        return result
    }

    private func applyHeaderDetection(_ text: String) -> String {
        // Patterns like "heading: X", "title: X", "section: X"
        let patterns: [(regex: String, prefix: String)] = [
            (#"(?i)\bheading\s*[,:]\s*"#, "## "),
            (#"(?i)\btitle\s*[,:]\s*"#, "# "),
            (#"(?i)\bsection\s*[,:]\s*"#, "## "),
            (#"(?i)\bsubtitle\s*[,:]\s*"#, "### "),
        ]

        var result = text
        for (pattern, prefix) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: prefix
                )
            }
        }
        return result
    }

    private func applyEmphasisDetection(_ text: String) -> String {
        // "bold X" or "emphasize X" → **X**
        var result = text
        let boldPattern = #"(?i)\b(?:bold|emphasize)\s+([^,.!?]+)"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "**$1**"
            )
        }
        return result
    }
}

// MARK: - Timestamp Logger Plugin

/// Prepends a timestamp to every transcription and logs all transcriptions to a file.
final class TimestampLoggerPlugin: WhisprPlugin {
    var name: String { "Timestamp Logger" }
    var version: String { "1.0.0" }
    var description: String { "Prepends timestamp to transcriptions and logs them to a file." }

    @Published private var prependEnabled: Bool = true
    @Published private var logToFileEnabled: Bool = true

    private static let logFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispr/transcription-log.txt")
    }()

    private static let prependKey = "plugin.timestampLogger.prepend"
    private static let logFileKey = "plugin.timestampLogger.logToFile"

    init() {
        prependEnabled = UserDefaults.standard.object(forKey: Self.prependKey) as? Bool ?? true
        logToFileEnabled = UserDefaults.standard.object(forKey: Self.logFileKey) as? Bool ?? true
    }

    func onTranscription(text: String, language: String?) -> String {
        let timestamp = Self.currentTimestamp()

        // Log to file
        if logToFileEnabled {
            let logLine = "[\(timestamp)] \(text)\n"
            Self.appendToLog(logLine)
        }

        // Prepend timestamp to output
        if prependEnabled {
            return "[\(timestamp)] \(text)"
        }

        return text
    }

    var settingsView: AnyView? {
        AnyView(TimestampLoggerSettingsView(plugin: self))
    }

    private static func currentTimestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.string(from: Date())
    }

    private static func appendToLog(_ line: String) {
        let fm = FileManager.default
        let url = logFileURL

        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }

    fileprivate func setPrepend(_ value: Bool) {
        prependEnabled = value
        UserDefaults.standard.set(value, forKey: Self.prependKey)
    }

    fileprivate func setLogToFile(_ value: Bool) {
        logToFileEnabled = value
        UserDefaults.standard.set(value, forKey: Self.logFileKey)
    }
}

private struct TimestampLoggerSettingsView: View {
    let plugin: TimestampLoggerPlugin
    @State private var prepend: Bool = true
    @State private var logToFile: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Prepend timestamp to transcription", isOn: $prepend)
                .onChange(of: prepend) { val in plugin.setPrepend(val) }

            Toggle("Log transcriptions to file", isOn: $logToFile)
                .onChange(of: logToFile) { val in plugin.setLogToFile(val) }

            Text("Log file: ~/Library/Application Support/Whispr/transcription-log.txt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            prepend = UserDefaults.standard.object(forKey: "plugin.timestampLogger.prepend") as? Bool ?? true
            logToFile = UserDefaults.standard.object(forKey: "plugin.timestampLogger.logToFile") as? Bool ?? true
        }
    }
}

// MARK: - Profanity Filter Plugin

/// Replaces common profanity with asterisks. Supports normal and strict modes.
final class ProfanityFilterPlugin: WhisprPlugin {
    var name: String { "Profanity Filter" }
    var version: String { "1.0.0" }
    var description: String { "Replaces common profanity with asterisks. Toggleable strictness." }

    private static let strictnessKey = "plugin.profanityFilter.strict"

    /// Normal-mode words (major profanity only).
    private let normalWords: [String] = [
        "fuck", "fucking", "fucked", "fucker",
        "shit", "shitting", "shitty",
        "bitch", "bitches",
        "asshole", "assholes",
        "damn", "damned", "damnit",
        "bastard", "bastards",
        "crap", "crappy",
    ]

    /// Strict-mode adds milder words.
    private let strictWords: [String] = [
        "hell", "crap", "suck", "sucks", "sucked",
        "piss", "pissed", "pissing",
        "ass", "arse",
        "bloody", "bollocks",
        "dumb", "idiot", "stupid",
    ]

    private var isStrict: Bool {
        UserDefaults.standard.object(forKey: Self.strictnessKey) as? Bool ?? false
    }

    func onTranscription(text: String, language: String?) -> String {
        var wordList = normalWords
        if isStrict {
            wordList += strictWords
        }
        return censorWords(in: text, words: wordList)
    }

    var settingsView: AnyView? {
        AnyView(ProfanityFilterSettingsView())
    }

    private func censorWords(in text: String, words: [String]) -> String {
        var result = text
        for word in words {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            let pattern = "\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }

            let censored = censorString(word)
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: censored
            )
        }
        return result
    }

    /// Replace middle characters with asterisks, keeping first and last letter.
    private func censorString(_ word: String) -> String {
        guard word.count > 2 else { return String(repeating: "*", count: word.count) }
        let first = word.first!
        let last = word.last!
        let middle = String(repeating: "*", count: word.count - 2)
        return "\(first)\(middle)\(last)"
    }
}

private struct ProfanityFilterSettingsView: View {
    @State private var strict: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Strict mode (filter mild profanity too)", isOn: $strict)
                .onChange(of: strict) { val in
                    UserDefaults.standard.set(val, forKey: "plugin.profanityFilter.strict")
                }

            Text("Normal mode filters major profanity. Strict mode also filters milder words like \"hell\", \"damn\", etc.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            strict = UserDefaults.standard.object(forKey: "plugin.profanityFilter.strict") as? Bool ?? false
        }
    }
}
