import Foundation
import AppKit
import Carbon.HIToolbox

/// Represents a hotkey binding (key + modifiers) for serialization.
struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt  // NSEvent.ModifierFlags rawValue

    /// Human-readable description of the hotkey.
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        default:
            // Try to get a character from the key code
            if let char = keyCodeToCharacter(keyCode) {
                return char.uppercased()
            }
            return "Key(\(keyCode))"
        }
    }

    private func keyCodeToCharacter(_ code: UInt32) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self) as Data
        return layoutData.withUnsafeBytes { rawBuf -> String? in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            let result = UCKeyTranslate(
                ptr,
                UInt16(code),
                UInt16(kUCKeyActionDown),
                0, // no modifiers
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard result == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}

/// A per-app hotkey profile: maps a bundle identifier to a custom hotkey.
struct HotkeyProfile: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var appName: String
    var binding: HotkeyBinding
}

/// Manages storage and retrieval of per-app hotkey profiles.
@MainActor
final class HotkeyProfileManager: ObservableObject {

    @Published var profiles: [HotkeyProfile] = []

    private static let storageKey = "hotkeyProfiles"

    init() {
        loadProfiles()
    }

    /// Find the hotkey for the currently active app, or nil to use global.
    func binding(forBundleID bundleID: String?) -> HotkeyBinding? {
        guard let bundleID else { return nil }
        return profiles.first { $0.bundleIdentifier == bundleID }?.binding
    }

    func addProfile(_ profile: HotkeyProfile) {
        // Replace if exists
        profiles.removeAll { $0.bundleIdentifier == profile.bundleIdentifier }
        profiles.append(profile)
        saveProfiles()
    }

    func removeProfile(bundleID: String) {
        profiles.removeAll { $0.bundleIdentifier == bundleID }
        saveProfiles()
    }

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([HotkeyProfile].self, from: data) else {
            return
        }
        profiles = decoded
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
