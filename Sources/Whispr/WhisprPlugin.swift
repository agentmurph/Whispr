import SwiftUI
import AppKit

// MARK: - Whispr Plugin Protocol

/// Protocol that all Whispr plugins must conform to.
/// Provides lifecycle hooks, text transformation pipeline, and optional UI.
///
/// All methods have default no-op implementations via protocol extension,
/// so plugins only need to implement what they use.
public protocol WhisprPlugin: AnyObject {

    // MARK: - Identity

    /// Unique display name of the plugin.
    var name: String { get }

    /// Semantic version string (e.g., "1.0.0").
    var version: String { get }

    /// Short description of what the plugin does.
    var description: String { get }

    // MARK: - Text Pipeline Hooks

    /// Called after transcription completes. Transform or annotate the text.
    /// - Parameters:
    ///   - text: The transcribed text.
    ///   - language: Detected language code (e.g., "en"), or nil if unknown.
    /// - Returns: Transformed text (return input unchanged for no-op).
    func onTranscription(text: String, language: String?) -> String

    /// Called just before text is injected/typed into the target app.
    /// Last chance to modify the text.
    /// - Parameter text: The text about to be injected.
    /// - Returns: Modified text (return input unchanged for no-op).
    func onBeforeInjection(text: String) -> String

    // MARK: - Lifecycle Hooks

    /// Called when the user starts recording.
    func onRecordingStart()

    /// Called when the user stops recording (before transcription begins).
    func onRecordingStop()

    // MARK: - Advanced Hooks

    /// Called with raw audio samples during recording.
    /// - Parameter samples: Float32 PCM samples at 16kHz mono.
    func onAudioBuffer(samples: [Float])

    /// Called when a Whisper model is loaded or changed.
    /// - Parameter model: The model identifier string (e.g., "ggml-base.en").
    func onModelLoaded(model: String)

    /// Called when the global hotkey is pressed (before recording toggle).
    func onHotkeyPressed()

    // MARK: - UI

    /// Optional settings view the plugin can provide.
    /// Displayed inline in the Plugins settings tab when the plugin is expanded.
    var settingsView: AnyView? { get }

    /// Optional menu items to add to the menu bar dropdown.
    var customMenuItems: [NSMenuItem] { get }
}

// MARK: - Default Implementations

public extension WhisprPlugin {

    func onTranscription(text: String, language: String?) -> String { text }
    func onBeforeInjection(text: String) -> String { text }

    func onRecordingStart() {}
    func onRecordingStop() {}

    func onAudioBuffer(samples: [Float]) {}
    func onModelLoaded(model: String) {}
    func onHotkeyPressed() {}

    var settingsView: AnyView? { nil }
    var customMenuItems: [NSMenuItem] { [] }
}
