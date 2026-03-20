import Foundation

/// A text snippet triggered by a voice command.
struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var triggerPhrase: String
    var replacementText: String
    /// If true, replacementText is evaluated dynamically (e.g., date/time).
    var isDynamic: Bool

    init(id: UUID = UUID(), triggerPhrase: String, replacementText: String, isDynamic: Bool = false) {
        self.id = id
        self.triggerPhrase = triggerPhrase
        self.replacementText = replacementText
        self.isDynamic = isDynamic
    }

    /// Resolved replacement text — evaluates dynamic tokens if needed.
    var resolvedText: String {
        guard isDynamic else { return replacementText }
        return Self.evaluateDynamic(replacementText)
    }

    /// Evaluate dynamic placeholders in a string.
    private static func evaluateDynamic(_ template: String) -> String {
        let now = Date()
        switch template {
        case "{{today}}":
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.timeStyle = .none
            return fmt.string(from: now)
        case "{{time}}":
            let fmt = DateFormatter()
            fmt.dateStyle = .none
            fmt.timeStyle = .short
            return fmt.string(from: now)
        default:
            // Replace inline tokens
            var result = template
            if result.contains("{{today}}") {
                let fmt = DateFormatter()
                fmt.dateStyle = .long
                fmt.timeStyle = .none
                result = result.replacingOccurrences(of: "{{today}}", with: fmt.string(from: now))
            }
            if result.contains("{{time}}") {
                let fmt = DateFormatter()
                fmt.dateStyle = .none
                fmt.timeStyle = .short
                result = result.replacingOccurrences(of: "{{time}}", with: fmt.string(from: now))
            }
            return result
        }
    }
}

/// Manages storage, retrieval, and matching of text snippets.
@MainActor
final class SnippetManager: ObservableObject {

    @Published var snippets: [Snippet] = []

    private static let storageKey = "snippetLibrary"

    /// Default built-in snippets provided on first launch.
    static let builtInSnippets: [Snippet] = [
        Snippet(triggerPhrase: "my email", replacementText: "your.email@example.com"),
        Snippet(triggerPhrase: "my address", replacementText: "123 Main Street, City, ST 00000"),
        Snippet(triggerPhrase: "today's date", replacementText: "{{today}}", isDynamic: true),
        Snippet(triggerPhrase: "current time", replacementText: "{{time}}", isDynamic: true),
    ]

    init() {
        loadSnippets()
        if snippets.isEmpty {
            snippets = Self.builtInSnippets
            saveSnippets()
        }
    }

    // MARK: - CRUD

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }

    func update(_ snippet: Snippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            saveSnippets()
        }
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func deleteAt(offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
        saveSnippets()
    }

    func resetToDefaults() {
        snippets = Self.builtInSnippets
        saveSnippets()
    }

    // MARK: - Matching

    /// Check if transcribed text matches a snippet trigger (case-insensitive, trimmed).
    /// Returns the resolved replacement text, or nil if no match.
    func match(_ transcription: String) -> String? {
        let normalized = transcription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            // Strip trailing punctuation that Whisper often appends
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))

        for snippet in snippets {
            let trigger = snippet.triggerPhrase
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if normalized == trigger {
                return snippet.resolvedText
            }
        }
        return nil
    }

    // MARK: - Import / Export

    /// Export snippets as JSON data.
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snippets)
    }

    /// Import snippets from JSON data (replaces current library).
    func importJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode([Snippet].self, from: data)
        snippets = decoded
        saveSnippets()
    }

    /// Merge imported snippets (add new, skip duplicates by trigger phrase).
    func mergeJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode([Snippet].self, from: data)
        let existingTriggers = Set(snippets.map { $0.triggerPhrase.lowercased() })
        for snippet in decoded where !existingTriggers.contains(snippet.triggerPhrase.lowercased()) {
            snippets.append(snippet)
        }
        saveSnippets()
    }

    // MARK: - Persistence

    private func loadSnippets() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return
        }
        snippets = decoded
    }

    private func saveSnippets() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
