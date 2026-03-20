import Foundation
import SwiftUI

/// Tracks the state of a loaded plugin: its manifest, instance, and enabled status.
struct LoadedPlugin: Identifiable {
    let id: String  // Derived from bundle directory name
    let manifest: PluginManifest
    let plugin: WhisprPlugin
    var isEnabled: Bool
    /// Order index for pipeline execution (lower = runs first).
    var order: Int
}

/// Discovers, loads, and manages Whispr plugins.
/// Built-in plugins are registered directly; external plugins are loaded from disk.
@MainActor
final class PluginManager: ObservableObject {

    // MARK: - Published State

    /// All loaded plugins (built-in + external), ordered by pipeline order.
    @Published var plugins: [LoadedPlugin] = []

    // MARK: - Paths

    static let pluginsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispr/Plugins", isDirectory: true)
    }()

    // MARK: - UserDefaults Keys

    private static let enabledKey = "pluginEnabledState"   // [String: Bool]
    private static let orderKey   = "pluginOrderState"     // [String: Int]

    // MARK: - Init

    init() {
        ensurePluginsDirectory()
        registerBuiltInPlugins()
        discoverExternalPlugins()
        applyPersistedState()
        sortByOrder()
    }

    // MARK: - Pipeline

    /// Run the transcription pipeline through all enabled plugins in order.
    func runTranscriptionPipeline(text: String, language: String?) -> String {
        var result = text
        for loaded in plugins where loaded.isEnabled {
            result = loaded.plugin.onTranscription(text: result, language: language)
        }
        return result
    }

    /// Run the before-injection pipeline through all enabled plugins in order.
    func runBeforeInjectionPipeline(text: String) -> String {
        var result = text
        for loaded in plugins where loaded.isEnabled {
            result = loaded.plugin.onBeforeInjection(text: result)
        }
        return result
    }

    /// Notify all enabled plugins that recording started.
    func notifyRecordingStart() {
        for loaded in plugins where loaded.isEnabled {
            loaded.plugin.onRecordingStart()
        }
    }

    /// Notify all enabled plugins that recording stopped.
    func notifyRecordingStop() {
        for loaded in plugins where loaded.isEnabled {
            loaded.plugin.onRecordingStop()
        }
    }

    /// Notify all enabled plugins of raw audio samples.
    func notifyAudioBuffer(samples: [Float]) {
        for loaded in plugins where loaded.isEnabled {
            loaded.plugin.onAudioBuffer(samples: samples)
        }
    }

    /// Notify all enabled plugins that a model was loaded.
    func notifyModelLoaded(model: String) {
        for loaded in plugins where loaded.isEnabled {
            loaded.plugin.onModelLoaded(model: model)
        }
    }

    /// Notify all enabled plugins that the hotkey was pressed.
    func notifyHotkeyPressed() {
        for loaded in plugins where loaded.isEnabled {
            loaded.plugin.onHotkeyPressed()
        }
    }

    /// Collect custom menu items from all enabled plugins.
    func collectCustomMenuItems() -> [NSMenuItem] {
        plugins.filter(\.isEnabled).flatMap { $0.plugin.customMenuItems }
    }

    // MARK: - Enable / Disable

    func setEnabled(_ enabled: Bool, for pluginID: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == pluginID }) else { return }
        plugins[idx].isEnabled = enabled
        persistState()
    }

    func toggleEnabled(for pluginID: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == pluginID }) else { return }
        plugins[idx].isEnabled.toggle()
        persistState()
    }

    // MARK: - Reorder

    func movePlugins(from source: IndexSet, to destination: Int) {
        plugins.move(fromOffsets: source, toOffset: destination)
        reindex()
        persistState()
    }

    // MARK: - Reload

    /// Re-discover external plugins from disk.
    func reloadPlugins() {
        // Keep built-in plugins, re-scan externals
        let builtInIDs = Set(builtInPluginIDs)
        plugins.removeAll { !builtInIDs.contains($0.id) }
        discoverExternalPlugins()
        applyPersistedState()
        sortByOrder()
    }

    /// Open the plugins folder in Finder.
    func openPluginsFolder() {
        NSWorkspace.shared.open(Self.pluginsDirectory)
    }

    // MARK: - Built-In Plugin Registration

    private var builtInPluginIDs: [String] = []

    private func registerBuiltInPlugins() {
        let builtIns: [(String, WhisprPlugin, PluginManifest)] = [
            ("builtin.markdown-formatter", MarkdownFormatterPlugin(), PluginManifest(
                name: "Markdown Formatter",
                version: "1.0.0",
                description: "Detects lists and headers from speech patterns and wraps transcription in markdown.",
                author: "Whispr",
                minWhisprVersion: "2.0.0",
                entryPoint: "built-in"
            )),
            ("builtin.timestamp-logger", TimestampLoggerPlugin(), PluginManifest(
                name: "Timestamp Logger",
                version: "1.0.0",
                description: "Prepends a timestamp to every transcription and logs to a file.",
                author: "Whispr",
                minWhisprVersion: "2.0.0",
                entryPoint: "built-in"
            )),
            ("builtin.profanity-filter", ProfanityFilterPlugin(), PluginManifest(
                name: "Profanity Filter",
                version: "1.0.0",
                description: "Replaces common profanity with asterisks. Toggleable strictness.",
                author: "Whispr",
                minWhisprVersion: "2.0.0",
                entryPoint: "built-in"
            )),
        ]

        for (id, plugin, manifest) in builtIns {
            builtInPluginIDs.append(id)
            plugins.append(LoadedPlugin(
                id: id,
                manifest: manifest,
                plugin: plugin,
                isEnabled: false,  // disabled by default; persisted state overrides
                order: plugins.count
            ))
        }
    }

    // MARK: - External Plugin Discovery

    private func discoverExternalPlugins() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: Self.pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            guard url.pathExtension == "whisprplugin" else { continue }
            let manifestURL = url.appendingPathComponent("manifest.json")
            guard fm.fileExists(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
                continue
            }

            let pluginID = "external.\(url.deletingPathExtension().lastPathComponent)"

            // External plugins are represented as stubs — full dylib loading is future work
            let stub = ExternalPluginStub(manifest: manifest)
            plugins.append(LoadedPlugin(
                id: pluginID,
                manifest: manifest,
                plugin: stub,
                isEnabled: false,
                order: plugins.count
            ))
        }
    }

    // MARK: - Persistence

    private func persistState() {
        var enabledMap: [String: Bool] = [:]
        var orderMap: [String: Int] = [:]
        for (i, p) in plugins.enumerated() {
            enabledMap[p.id] = p.isEnabled
            orderMap[p.id] = i
        }
        UserDefaults.standard.set(enabledMap, forKey: Self.enabledKey)
        UserDefaults.standard.set(orderMap, forKey: Self.orderKey)
    }

    private func applyPersistedState() {
        let enabledMap = UserDefaults.standard.dictionary(forKey: Self.enabledKey) as? [String: Bool] ?? [:]
        let orderMap = UserDefaults.standard.dictionary(forKey: Self.orderKey) as? [String: Int] ?? [:]

        for i in plugins.indices {
            if let enabled = enabledMap[plugins[i].id] {
                plugins[i].isEnabled = enabled
            }
            if let order = orderMap[plugins[i].id] {
                plugins[i].order = order
            }
        }
    }

    private func sortByOrder() {
        plugins.sort { $0.order < $1.order }
        reindex()
    }

    private func reindex() {
        for i in plugins.indices {
            plugins[i].order = i
        }
    }

    // MARK: - Helpers

    private func ensurePluginsDirectory() {
        try? FileManager.default.createDirectory(at: Self.pluginsDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - External Plugin Stub

/// Placeholder for externally loaded plugins (future: dynamic library loading).
private final class ExternalPluginStub: WhisprPlugin {
    let manifest: PluginManifest

    var name: String { manifest.name }
    var version: String { manifest.version }
    var description: String { manifest.description }

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }
}
