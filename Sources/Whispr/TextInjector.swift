import AppKit
import Carbon.HIToolbox

/// Injects text into the currently focused application.
enum TextInjector {

    /// Smart injection: tries keystrokes first, falls back to clipboard paste if needed.
    /// When `preferClipboard` is true, always uses clipboard paste.
    static func injectText(_ text: String, preferClipboard: Bool = false) {
        // Always copy to clipboard first as a safety net
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if preferClipboard {
            pasteTextWithRestore(text)
        } else if !AXIsProcessTrusted() {
            // No accessibility — clipboard only, notify user
            showNotification(title: "Whispr", body: "Text copied to clipboard (⌘V to paste). Grant Accessibility permission for auto-typing.")
        } else {
            // Try keystroke injection; if the focused element is a secure field, fall back
            if isSecureTextField() {
                pasteTextWithRestore(text)
            } else {
                typeText(text)
            }
        }
    }

    /// Show a macOS notification
    private static func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

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

    /// Paste via clipboard + Cmd+V, preserving and restoring original clipboard contents.
    static func pasteTextWithRestore(_ text: String) {
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard contents
        let savedItems = saveClipboard(pasteboard)

        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        simulatePaste()

        // Restore original clipboard after a short delay (give paste time to complete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            restoreClipboard(pasteboard, items: savedItems)
        }
    }

    /// Legacy paste without clipboard restore (kept for compatibility).
    static func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        simulatePaste()
    }

    /// Inject text word-by-word with configurable delay between words.
    /// Used in streaming mode for natural-looking output.
    static func injectTextWordByWord(_ text: String, wordDelayMicroseconds: UInt32, preferClipboard: Bool = false) {
        guard wordDelayMicroseconds > 0 else {
            // No delay — just inject normally
            injectText(text, preferClipboard: preferClipboard)
            return
        }

        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        for (index, word) in words.enumerated() {
            let chunk = index == 0 ? String(word) : " " + String(word)
            if preferClipboard || isSecureTextField() {
                pasteTextWithRestore(chunk)
            } else {
                typeText(chunk)
            }
            if index < words.count - 1 {
                usleep(wordDelayMicroseconds)
            }
        }
    }

    // MARK: - Private

    /// Simulate Cmd+V keystroke.
    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Detect if the currently focused UI element is a secure text field.
    /// Uses the Accessibility API to check the focused element's role/subrole.
    private static func isSecureTextField() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement else {
            return false
        }

        // Check subrole for "AXSecureTextField"
        var subrole: AnyObject?
        let subroleResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSubroleAttribute as CFString, &subrole)
        if subroleResult == .success, let subroleStr = subrole as? String {
            if subroleStr == "AXSecureTextField" {
                return true
            }
        }

        // Check role for secure text field
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &role)
        if roleResult == .success, let roleStr = role as? String {
            if roleStr == "AXSecureTextField" {
                return true
            }
        }

        return false
    }

    // MARK: - Clipboard Save/Restore

    private struct ClipboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private static func saveClipboard(_ pasteboard: NSPasteboard) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        guard let types = pasteboard.types else { return items }

        for type in types {
            if let data = pasteboard.data(forType: type) {
                items.append(ClipboardItem(type: type, data: data))
            }
        }
        return items
    }

    private static func restoreClipboard(_ pasteboard: NSPasteboard, items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        for item in items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }
}
