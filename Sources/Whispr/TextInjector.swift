import AppKit
import Carbon.HIToolbox

/// Injects text into the currently focused application.
enum TextInjector {

    /// Smart injection: tries keystrokes first, falls back to clipboard paste if needed.
    /// When `preferClipboard` is true, always uses clipboard paste.
    static func injectText(_ text: String, preferClipboard: Bool = false) {
        if preferClipboard {
            pasteTextWithRestore(text)
        } else {
            // Try keystroke injection; if the focused element is a secure field, fall back
            if isSecureTextField() {
                pasteTextWithRestore(text)
            } else {
                typeText(text)
            }
        }
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
