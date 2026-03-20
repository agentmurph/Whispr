import AppKit
import Carbon.HIToolbox

/// Processes transcribed text for voice commands (e.g., "new line", "period", "select all").
/// Voice commands are detected and executed instead of being typed as text.
enum VoiceCommandProcessor {

    /// Result of processing text for voice commands.
    struct Result {
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
    static func process(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(actions: [])
        }

        var actions: [Action] = []
        var pendingText = ""
        let lower = trimmed.lowercased()
        var pos = lower.startIndex

        while pos < lower.endIndex {
            var matched = false

            for (pattern, action) in commands {
                let remaining = lower[pos...]
                guard remaining.hasPrefix(pattern) else { continue }

                let afterEnd = lower.index(pos, offsetBy: pattern.count, limitedBy: lower.endIndex) ?? lower.endIndex
                // Check word boundary
                if afterEnd < lower.endIndex {
                    let nextChar = lower[afterEnd]
                    guard nextChar == " " || nextChar.isPunctuation else { continue }
                }
                // Check start boundary
                if pos > lower.startIndex {
                    let prevChar = lower[lower.index(before: pos)]
                    guard prevChar == " " else { continue }
                }

                // Flush pending text
                if !pendingText.isEmpty {
                    actions.append(.insertText(pendingText.trimmingCharacters(in: .whitespaces)))
                    pendingText = ""
                }

                actions.append(action)
                pos = afterEnd
                // Skip trailing space
                if pos < lower.endIndex && lower[pos] == " " {
                    pos = lower.index(after: pos)
                }
                matched = true
                break
            }

            if !matched {
                // Consume character from original text (preserve case)
                let origIdx = trimmed.index(trimmed.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: pos))
                pendingText.append(trimmed[origIdx])
                pos = lower.index(after: pos)
            }
        }

        // Flush remaining text
        if !pendingText.isEmpty {
            let cleaned = pendingText.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                actions.append(.insertText(cleaned))
            }
        }

        return Result(actions: actions)
    }

    /// Execute a list of voice command actions.
    static func execute(_ actions: [Action], preferClipboard: Bool = false) {
        for action in actions {
            switch action {
            case .insertText(let text):
                TextInjector.injectText(text, preferClipboard: preferClipboard)
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
