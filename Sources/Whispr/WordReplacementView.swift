import SwiftUI

/// Settings tab for managing custom word/phrase replacements.
@MainActor
struct WordReplacementView: View {
    @ObservedObject var replacementManager: WordReplacementManager

    @State private var showingAddSheet = false
    @State private var editingReplacement: WordReplacement?

    var body: some View {
        Form {
            Section("Word Replacements") {
                if replacementManager.replacements.isEmpty {
                    VStack(spacing: 8) {
                        Text("No custom replacements configured.")
                            .foregroundStyle(.secondary)
                        Text("Add rules to automatically fix words after transcription.\nExample: \"gonna\" → \"going to\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(replacementManager.replacements) { replacement in
                        replacementRow(replacement)
                    }
                    .onDelete { offsets in
                        replacementManager.deleteAt(offsets: offsets)
                    }
                }
            }

            Section {
                HStack {
                    Button("Add Replacement") { showingAddSheet = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Spacer()
                }
            }

            Section {
                Text("Replacements are applied after transcription post-processing but before snippet matching. Use for fixing common misheard words, brand names, or technical terms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            WordReplacementEditSheet(title: "Add Replacement") { newReplacement in
                replacementManager.add(newReplacement)
            }
        }
        .sheet(item: $editingReplacement) { replacement in
            WordReplacementEditSheet(title: "Edit Replacement", replacement: replacement) { updated in
                replacementManager.update(updated)
            }
        }
    }

    // MARK: - Row

    private func replacementRow(_ replacement: WordReplacement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(replacement.original)
                        .font(.headline)
                        .strikethrough(true, color: .red.opacity(0.5))
                    Text("→")
                        .foregroundStyle(.secondary)
                    Text(replacement.replacement)
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                if replacement.caseSensitive {
                    Text("Case-sensitive")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button {
                editingReplacement = replacement
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                replacementManager.delete(replacement)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Edit/Add Sheet

@MainActor
struct WordReplacementEditSheet: View {
    let title: String
    var replacement: WordReplacement?
    var onSave: (WordReplacement) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var original: String = ""
    @State private var replacementText: String = ""
    @State private var caseSensitive: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            Form {
                TextField("Original word/phrase", text: $original)
                    .textFieldStyle(.roundedBorder)

                TextField("Replace with", text: $replacementText)
                    .textFieldStyle(.roundedBorder)

                Toggle("Case-sensitive matching", isOn: $caseSensitive)
            }
            .formStyle(.grouped)

            if !original.isEmpty && !replacementText.isEmpty {
                HStack(spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(original)
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.red)
                    Text("→")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(replacementText)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let saved = WordReplacement(
                        id: replacement?.id ?? UUID(),
                        original: original,
                        replacement: replacementText,
                        caseSensitive: caseSensitive
                    )
                    onSave(saved)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(original.isEmpty || replacementText.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
        .onAppear {
            if let replacement {
                original = replacement.original
                replacementText = replacement.replacement
                caseSensitive = replacement.caseSensitive
            }
        }
    }
}
