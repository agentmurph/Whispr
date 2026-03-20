import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            modelTab
                .tabItem { Label("Models", systemImage: "brain") }
        }
        .frame(width: 450, height: 320)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Toggle Recording") {
                    Text("⌥ Space")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Audio Input") {
                Text("Default system microphone")
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $appState.launchAtLogin)
            }

            Section("Text Injection") {
                Toggle("Use clipboard paste (Cmd+V) instead of keystrokes", isOn: $appState.useClipboardFallback)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Models

    private var modelTab: some View {
        Form {
            Section("Whisper Model") {
                ForEach(WhisperModel.allCases) { model in
                    modelRow(model)
                }
            }

            if modelManager.isDownloading {
                Section("Download Progress") {
                    ProgressView(value: modelManager.downloadProgress)
                }
            }

            if let error = modelManager.downloadError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func modelRow(_ model: WhisperModel) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.displayName)
                    .font(.headline)
                Text(model.sizeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appState.selectedModel == model {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if modelManager.isDownloaded(model) {
                Button("Select") {
                    appState.selectedModel = model
                }
                .disabled(appState.selectedModel == model)
            } else {
                Button("Download") {
                    Task {
                        try? await modelManager.download(model)
                    }
                }
                .disabled(modelManager.isDownloading)
            }
        }
    }
}
