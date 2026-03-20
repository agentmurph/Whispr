import AppKit
import Carbon.HIToolbox

/// Processes transcribed text for voice commands (e.g., "new line", "period", "select all").
/// Voice commands are detected and executed instead of being typed as text.
enum VoiceCommandProcessor {

    /// Result of processing text for voice commands.
    struct Result {
        /// The remaining text after extracting voice commands (may be empty).
        let text: String
        /// Ordered list of actions to perform (text insertions and key commands).
        let actions: [Action]
    }

    /// An action to perform — either insert text or execute a keyboard shortcut.
    enum Action {
        case insertText(String)
        case keyboardShortcut(CGKeyCode, CGEventFlags)
        case insertNewline(count: Int)
        case insertPunctuation(String)
    }

    /// All recognized voice commands, ordered longest-first to avoid partial matches.
    private static let commands: [(pattern: String, action: Action)] = [
        // Multi-word commands first
        ("new paragraph",       .insertNewline(count: 2)),
        ("new line",            .insertNewline(count: 1)),
        ("newline",             .insertNewline(count: 1)),
        ("exclamation point",   .insertPunctuation("!")),
        ("exclamation mark",    .insertPunctuation("!")),
        ("question mark",       .insertPunctuation("?")),
        ("open parenthesis",    .insertPunctuation("(")),
        ("close parenthesis",   .insertPunctuation(")")),
        ("open bracket",        .insertPunctuation("[")),
        ("close bracket",       .insertPunctuation("]")),
        ("open quote",          .insertPunctuation("\"")),
        ("close quote",         .insertPunctuation("\"")),
        ("select all",          .keyboardShortcut(0x00, .maskCommand)), // Cmd+A
        ("undo that",           .keyboardShortcut(0x06, .maskCommand)), // Cmd+Z
        ("undo",                .keyboardShortcut(0x06, .maskCommand)), // Cmd+Z
        ("redo",                .keyboardShortcut(0x06, [.maskCommand, .maskShift])), // Cmd+Shift+Z
        ("copy that",           .keyboardShortcut(0x08, .maskCommand)), // Cmd+C
        ("copy",                .keyboardShortcut(0x08, .maskCommand)), // Cmd+C
        ("paste",               .keyboardShortcut(0x09, .maskCommand)), // Cmd+V
        ("cut",                 .keyboardShortcut(0x07, .maskCommand)), // Cmd+X
        // Single-word punctuation
        ("period",              .insertPunctuation(".")),
        ("full stop",           .insertPunctuation(".")),
        ("comma",               .insertPunctuation(",")),
        ("colon",               .insertPunctuation(":")),
        ("semicolon",           .insertPunctuation(";")),
        ("dash",                .insertPunctuation("—")),
        ("hyphen",              .insertPunctuation("-")),
        ("ellipsis",            .insertPunctuation("…")),
    ]

    /// Process transcription text, extracting voice commands and returning actions.
    /// The text between commands becomes insertText actions.
    static func process(_ text: String) -> Result {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return Result(text: "", actions: [])
        }

        var actions: [Action] = []
        var remaining = normalized.lowercased()
        var originalRemaining = normalized
        var resultText = ""

        while !remaining.isEmpty {
            var matched = false

            for (pattern, action) in commands {
                // Check if remaining starts with this command (with word boundary)
                if remaining.hasPrefix(pattern) {
                    let afterCommand = remaining.dropFirst(pattern.count)
                    // Ensure word boundary: next char must be whitespace, punctuation, or end
                    let isWordBoundary = afterCommand.isEmpty ||
                        afterCommand.first!.isWhitespace ||
                        afterCommand.first!.isPunctuation

                    if isWordBoundary {
                        // Flush any accumulated text before this command
                        let textBefore = String(originalRemaining.prefix(originalRemaining.count - remaining.count))
                        let pendingText = textBefore.isEmpty ? "" : resultText
                        if !pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            actions.append(.insertText(pendingText.trimmingCharacters(in: .whitespacesAndNewlines)))
                            resultText = ""
                        }

                        actions.append(action)

                        // Advance past the command and any trailing whitespace
                        remaining = String(afterCommand).trimmingCharacters(in: .init(charactersIn: " "))
                        let charsConsumed = normalized.count - remaining.count -
                            (normalized.count - originalRemaining.count)
                        originalRemaining = String(originalRemaining.dropFirst(
                            min(charsConsumed + (originalRemaining.count - remaining.count - (originalRemaining.count - pattern.count)),
                                originalRemaining.count)
                        ))
                        // Simpler: just rebuild from remaining length
                        let offset = normalized.count - remaining.count
                        if offset <= normalized.count {
                            let idx = normalized.index(normalized.startIndex, offsetBy: offset, limitedBy: normalized.endIndex) ?? normalized.endIndex
                            originalRemaining = String(normalized[idx...])
                        } else {
                            originalRemaining = ""
                        }

                        matched = true
                        break
                    }
                }
            }

            if !matched {
                // No command matched at current position — consume one word
                if let spaceIdx = remaining.firstIndex(of: " ") {
                    let word = String(remaining[remaining.startIndex..<spaceIdx])
                    let origWord = String(originalRemaining.prefix(word.count))
                    resultText += (resultText.isEmpty ? "" : " ") + origWord
                    remaining = String(remaining[remaining.index(after: spaceIdx)...])
                    originalRemaining = String(originalRemaining.dropFirst(word.count + 1))
                } else {
                    // Last word, no more spaces
                    resultText += (resultText.isEmpty ? "" : " ") + originalRemaining
                    remaining = ""
                    originalRemaining = ""
                }
            }
        }

        // Flush any remaining text
        if !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.append(.insertText(resultText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        // Build final text (just the text parts, for display)
        let finalText = actions.compactMap { action -> String? in
            if case .insertText(let t) = action { return t }
            if case .insertPunctuation(let p) = action { return p }
            if case .insertNewline(let count) = action { return String(repeating: "\n", count: count) }
            return nil
        }.joined()

        return Result(text: finalText, actions: actions)
    }

    /// Execute a list of voice command actions.
    static func execute(_ actions: [Action], preferClipboard: Bool = false) {
        for action in actions {
            switch action {
            case .insertText(let text):
                TextInjector.injectText(text, preferClipboard: preferClipboard)
                // Small delay between actions
                usleep(50_000) // 50ms

            case .insertPunctuation(let punct):
                TextInjector.typeText(punct)
                usleep(10_000) // 10ms

            case .insertNewline(let count):
                let newlines = String(repeating: "\n", count: count)
                TextInjector.typeText(newlines)
                usleep(10_000)

            case .keyboardShortcut(let keyCode, let flags):
                executeKeyboardShortcut(keyCode: keyCode, flags: flags)
                usleep(50_000) // 50ms
            }
        }
    }

    /// Execute a keyboard shortcut via CGEvent.
    private static func executeKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
