import Foundation
import HotKey
import Carbon.HIToolbox

/// Manages the global Option+Space hotkey with TOGGLE behavior.
@MainActor
final class HotkeyManager {

    private var hotKey: HotKey?

    /// Called each time the hotkey is pressed (toggle).
    /// Must be a @MainActor closure since it will be dispatched to MainActor.
    var onToggle: (@MainActor () -> Void)?

    func register() {
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            // HotKey fires on whatever thread — dispatch to MainActor
            Task { @MainActor in
                self?.onToggle?()
            }
        }
    }

    func unregister() {
        hotKey = nil
    }
}
