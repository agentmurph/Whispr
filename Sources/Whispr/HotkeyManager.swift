import Foundation
import HotKey
import Carbon.HIToolbox

/// Manages the global Option+Space hotkey with TOGGLE behavior.
@MainActor
final class HotkeyManager {

    private var hotKey: HotKey?

    /// Called each time the hotkey is pressed (toggle).
    var onToggle: (() -> Void)?

    func register() {
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.onToggle?()
        }
    }

    func unregister() {
        hotKey = nil
    }
}
