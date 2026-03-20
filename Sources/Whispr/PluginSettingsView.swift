import SwiftUI

/// Settings tab for managing plugins: list, enable/disable, reorder, reload.
@MainActor
struct PluginSettingsView: View {
    @ObservedObject var pluginManager: PluginManager

    @State private var expandedPluginID: String?

    var body: some View {
        Form {
            Section("Installed Plugins") {
                if pluginManager.plugins.isEmpty {
                    Text("No plugins installed.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    List {
                        ForEach(pluginManager.plugins) { loaded in
                            pluginRow(loaded)
                        }
                        .onMove { source, destination in
                            pluginManager.movePlugins(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 150)
                }
            }

            Section {
                HStack {
                    Button {
                        pluginManager.openPluginsFolder()
                    } label: {
                        Label("Open Plugins Folder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        pluginManager.reloadPlugins()
                    } label: {
                        Label("Reload Plugins", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Section {
                Text("Plugins process transcriptions in the order shown above. Drag to reorder. Place plugins in ~/Library/Application Support/Whispr/Plugins/ as .whisprplugin bundles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Plugin Row

    @ViewBuilder
    private func pluginRow(_ loaded: LoadedPlugin) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(loaded.manifest.name)
                            .font(.headline)
                        Text("v\(loaded.manifest.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if loaded.id.hasPrefix("builtin.") {
                            Text("Built-in")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.blue)
                        }
                    }
                    Text(loaded.manifest.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !loaded.manifest.author.isEmpty {
                        Text("by \(loaded.manifest.author)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { loaded.isEnabled },
                    set: { pluginManager.setEnabled($0, for: loaded.id) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                // Expand/collapse button if plugin has settings
                if loaded.plugin.settingsView != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedPluginID = expandedPluginID == loaded.id ? nil : loaded.id
                        }
                    } label: {
                        Image(systemName: expandedPluginID == loaded.id ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Inline settings view when expanded
            if expandedPluginID == loaded.id, let settingsView = loaded.plugin.settingsView {
                Divider()
                settingsView
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
