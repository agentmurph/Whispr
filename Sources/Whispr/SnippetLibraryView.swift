import SwiftUI
import UniformTypeIdentifiers

/// Settings tab for managing the Snippet/Shortcut Library.
@MainActor
struct SnippetLibraryView: View {
    @ObservedObject var snippetManager: SnippetManager

    @State private var showingAddSheet = false
    @State private var editingSnippet: Snippet?
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var alertMessage: String?
    @State private var showingResetConfirm = false

    var body: some View {
        Form {
            Section("Snippets") {
                if snippetManager.snippets.isEmpty {
                    Text("No snippets. Add one or reset to defaults.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(snippetManager.snippets) { snippet in
                        snippetRow(snippet)
                    }
                    .onDelete { offsets in
                        snippetManager.deleteAt(offsets: offsets)
                    }
                }
            }

            Section {
                HStack {
                    Button("Add Snippet") { showingAddSheet = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Spacer()

                    Button("Import…") { showingImportPicker = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Export…") { showingExportPicker = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(snippetManager.snippets.isEmpty)

                    Button("Reset to Defaults") { showingResetConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            Section {
                Text("Snippets replace transcribed text when a trigger phrase is spoken. Dynamic snippets (e.g., date/time) evaluate at the moment of transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            SnippetEditSheet(title: "Add Snippet") { newSnippet in
                snippetManager.add(newSnippet)
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditSheet(title: "Edit Snippet", snippet: snippet) { updated in
                snippetManager.update(updated)
            }
        }
        .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: SnippetJSONDocument(snippetManager: snippetManager),
            contentType: .json,
            defaultFilename: "whispr-snippets.json"
        ) { _ in }
        .alert("Snippets", isPresented: .init(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog("Reset to Defaults?", isPresented: $showingResetConfirm) {
            Button("Reset", role: .destructive) {
                snippetManager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all your snippets with the built-in defaults.")
        }
    }

    // MARK: - Snippet Row

    private func snippetRow(_ snippet: Snippet) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snippet.triggerPhrase)
                        .font(.headline)
                    if snippet.isDynamic {
                        Text("Dynamic")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.blue)
                    }
                }
                Text(snippet.isDynamic ? snippet.resolvedText : snippet.replacementText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                editingSnippet = snippet
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                snippetManager.delete(snippet)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = "Could not access selected file."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                try snippetManager.importJSON(data)
                alertMessage = "Imported \(snippetManager.snippets.count) snippets."
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit / Add Sheet

@MainActor
struct SnippetEditSheet: View {
    let title: String
    var snippet: Snippet?
    var onSave: (Snippet) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var triggerPhrase: String = ""
    @State private var replacementText: String = ""
    @State private var isDynamic: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            Form {
                TextField("Trigger Phrase", text: $triggerPhrase)
                    .textFieldStyle(.roundedBorder)

                TextField("Replacement Text", text: $replacementText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)

                Toggle("Dynamic (evaluates placeholders like {{today}}, {{time}})", isOn: $isDynamic)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let saved = Snippet(
                        id: snippet?.id ?? UUID(),
                        triggerPhrase: triggerPhrase,
                        replacementText: replacementText,
                        isDynamic: isDynamic
                    )
                    onSave(saved)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(triggerPhrase.isEmpty || replacementText.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 300)
        .onAppear {
            if let snippet {
                triggerPhrase = snippet.triggerPhrase
                replacementText = snippet.replacementText
                isDynamic = snippet.isDynamic
            }
        }
    }
}

// MARK: - JSON Document for Export

struct SnippetJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let jsonData: Data

    init(snippetManager: SnippetManager) {
        self.jsonData = (try? snippetManager.exportJSON()) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        jsonData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}
