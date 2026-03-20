import Foundation

/// A single word/phrase replacement rule.
struct WordReplacement: Codable, Identifiable, Equatable {
    var id: UUID
    var original: String
    var replacement: String
    /// If true, matching is case-sensitive. Otherwise case-insensitive.
    var caseSensitive: Bool

    init(id: UUID = UUID(), original: String, replacement: String, caseSensitive: Bool = false) {
        self.id = id
        self.original = original
        self.replacement = replacement
        self.caseSensitive = caseSensitive
    }
}

/// Manages a dictionary of word replacements applied after transcription.
@MainActor
final class WordReplacementManager: ObservableObject {

    @Published var replacements: [WordReplacement] = []

    private static let storageKey = "wordReplacements"

    init() {
        loadReplacements()
    }

    // MARK: - CRUD

    func add(_ replacement: WordReplacement) {
        replacements.append(replacement)
        saveReplacements()
    }

    func update(_ replacement: WordReplacement) {
        if let idx = replacements.firstIndex(where: { $0.id == replacement.id }) {
            replacements[idx] = replacement
            saveReplacements()
        }
    }

    func delete(_ replacement: WordReplacement) {
        replacements.removeAll { $0.id == replacement.id }
        saveReplacements()
    }

    func deleteAt(offsets: IndexSet) {
        replacements.remove(atOffsets: offsets)
        saveReplacements()
    }

    // MARK: - Apply Replacements

    /// Apply all word replacements to a transcribed text.
    /// Should be called after post-processing but before snippet matching.
    func apply(to text: String) -> String {
        var result = text

        for rule in replacements {
            guard !rule.original.isEmpty else { continue }

            if rule.caseSensitive {
                result = result.replacingOccurrences(of: rule.original, with: rule.replacement)
            } else {
                // Case-insensitive word boundary replacement
                let escaped = NSRegularExpression.escapedPattern(for: rule.original)
                let pattern = "\\b\(escaped)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: rule.replacement
                    )
                }
            }
        }

        return result
    }

    // MARK: - Persistence

    private func loadReplacements() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([WordReplacement].self, from: data) else {
            return
        }
        replacements = decoded
    }

    private func saveReplacements() {
        guard let data = try? JSONEncoder().encode(replacements) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
