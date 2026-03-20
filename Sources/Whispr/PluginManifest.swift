import Foundation

/// Represents the manifest.json inside a .whisprplugin bundle.
struct PluginManifest: Codable, Equatable {
    /// Display name of the plugin.
    let name: String

    /// Semantic version (e.g., "1.0.0").
    let version: String

    /// Short description of the plugin's purpose.
    let description: String

    /// Author name or handle.
    let author: String

    /// Minimum Whispr version required (e.g., "2.0.0").
    let minWhisprVersion: String

    /// Entry point file name (e.g., "MyPlugin.swift" or "MyPlugin.dylib").
    let entryPoint: String
}
