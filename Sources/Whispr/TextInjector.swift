import AppKit
import Carbon.HIToolbox

/// Injects text into the currently focused application.
enum TextInjector {

    /// Primary method: simulate keystrokes via CGEvent for each character.
    static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            let string = String(char)
            let utf16 = Array(string.utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            // Small delay to avoid overwhelming the target app
            usleep(2_000) // 2 ms
        }
    }

    /// Fallback: paste via clipboard + Cmd+V (useful for secure text fields).
    static func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd+V
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
