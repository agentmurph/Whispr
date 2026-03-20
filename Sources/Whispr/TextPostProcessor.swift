import Foundation

/// Applies optional post-processing transformations to transcribed text.
enum TextPostProcessor {

    struct Options {
        var trimWhitespace: Bool = true
        var autoCapitalize: Bool = true
        var ensurePunctuation: Bool = true
    }

    /// Apply all enabled transformations in order.
    static func process(_ text: String, options: Options) -> String {
        var result = text

        if options.trimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if options.autoCapitalize {
            result = capitalizeFirstLetterOfSentences(result)
        }

        if options.ensurePunctuation {
            result = ensureTrailingPunctuation(result)
        }

        return result
    }

    // MARK: - Transformations

    /// Capitalize the first letter of each sentence.
    private static func capitalizeFirstLetterOfSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = ""
        var capitalizeNext = true

        for char in text {
            if capitalizeNext && char.isLetter {
                result.append(char.uppercased())
                capitalizeNext = false
            } else {
                result.append(char)
            }

            if char == "." || char == "!" || char == "?" {
                capitalizeNext = true
            }
        }

        return result
    }

    /// Ensure the text ends with a period if it doesn't already end with punctuation.
    private static func ensureTrailingPunctuation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        let last = trimmed.last!
        if last == "." || last == "!" || last == "?" || last == ":" || last == ";" {
            return text
        }
        // Append period at the end of the original text (preserve trailing whitespace choice)
        return text.trimmingCharacters(in: .whitespacesAndNewlines) + "."
    }
}
