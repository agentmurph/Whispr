import Foundation

/// Applies optional post-processing transformations to transcribed text.
enum TextPostProcessor {

    struct Options {
        var trimWhitespace: Bool = true
        var autoCapitalize: Bool = true
        var ensurePunctuation: Bool = true
        var smartQuotes: Bool = false
        var numberFormatting: Bool = false
        var removeFillerWords: Bool = false
        var autoParagraph: Bool = false
    }

    /// Apply all enabled transformations in order.
    static func process(_ text: String, options: Options) -> String {
        var result = text

        if options.trimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if options.removeFillerWords {
            result = removeFillerWords(result)
        }

        if options.smartQuotes {
            result = applySmartQuotes(result)
        }

        if options.numberFormatting {
            result = formatNumbers(result)
        }

        if options.autoCapitalize {
            result = capitalizeFirstLetterOfSentences(result)
        }

        if options.ensurePunctuation {
            result = ensureTrailingPunctuation(result)
        }

        return result
    }

    /// Process with whisper segments for timestamp-aware features like auto-paragraph.
    static func process(_ text: String, options: Options, segmentGaps: [TimeInterval]?) -> String {
        var result = text

        if options.trimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if options.removeFillerWords {
            result = removeFillerWords(result)
        }

        if options.smartQuotes {
            result = applySmartQuotes(result)
        }

        if options.numberFormatting {
            result = formatNumbers(result)
        }

        if options.autoParagraph, let gaps = segmentGaps {
            result = insertParagraphBreaks(result, gaps: gaps)
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
        return text.trimmingCharacters(in: .whitespacesAndNewlines) + "."
    }

    // MARK: - Smart Quotes

    /// Replace straight quotes with typographic curly quotes.
    private static func applySmartQuotes(_ text: String) -> String {
        var result = ""
        var inDoubleQuote = false
        var inSingleQuote = false

        for (index, char) in text.enumerated() {
            if char == "\"" {
                if inDoubleQuote {
                    result.append("\u{201D}") // right double quote "
                } else {
                    result.append("\u{201C}") // left double quote "
                }
                inDoubleQuote.toggle()
            } else if char == "'" {
                // Distinguish apostrophes from single quotes:
                // If surrounded by letters, it's an apostrophe (don't, it's, etc.)
                let prevIsLetter = index > 0 && text[text.index(text.startIndex, offsetBy: index - 1)].isLetter
                let nextIndex = text.index(text.startIndex, offsetBy: index + 1, limitedBy: text.endIndex)
                let nextIsLetter = nextIndex != nil && nextIndex! < text.endIndex && text[nextIndex!].isLetter

                if prevIsLetter && nextIsLetter {
                    // Apostrophe
                    result.append("\u{2019}") // right single quote/apostrophe '
                } else if inSingleQuote {
                    result.append("\u{2019}") // right single quote '
                    inSingleQuote.toggle()
                } else {
                    result.append("\u{2018}") // left single quote '
                    inSingleQuote.toggle()
                }
            } else {
                result.append(char)
            }
        }

        return result
    }

    // MARK: - Number Formatting

    /// Spell out small numbers (0-9) when they appear as standalone words.
    /// Keeps larger numbers and numbers in context (e.g., "100", "3.5") as digits.
    private static func formatNumbers(_ text: String) -> String {
        let words = [
            "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
            "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
            "10": "ten"
        ]

        // Match standalone single/double digit numbers (word boundaries)
        let pattern = "\\b(\\d{1,2})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // Process in reverse to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let numberStr = String(result[range])

            // Only spell out 0-10
            if let spelled = words[numberStr] {
                result.replaceSubrange(range, with: spelled)
            }
        }

        return result
    }

    // MARK: - Filler Word Removal

    /// Remove common filler words (um, uh, like, you know, etc.).
    private static func removeFillerWords(_ text: String) -> String {
        // Filler patterns — ordered longest first to avoid partial matches
        let fillerPatterns = [
            "\\byou know\\b",
            "\\bI mean\\b",
            "\\bkind of\\b",
            "\\bsort of\\b",
            "\\bumm\\b",
            "\\buhh\\b",
            "\\bum\\b",
            "\\buh\\b",
            "\\blike\\b(?=\\s*,)",     // "like," as filler
            ",?\\s*\\blike\\b\\s*,",   // ", like," as interjection
        ]

        var result = text
        for pattern in fillerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Clean up multiple spaces left behind
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Clean up leading/trailing commas from removal
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: ",,", with: ",")

        return result
    }

    // MARK: - Auto-Paragraph

    /// Insert paragraph breaks between segments where there's a significant pause.
    /// `gaps` contains the time gap (in seconds) between consecutive whisper segments.
    /// A gap of 2+ seconds inserts a paragraph break.
    private static func insertParagraphBreaks(_ text: String, gaps: [TimeInterval], pauseThreshold: TimeInterval = 2.0) -> String {
        // Split text by the segment separator (space between joined segments)
        let segments = text.components(separatedBy: " ")
        guard segments.count > 1, !gaps.isEmpty else { return text }

        var result = ""
        // We have N segments and N-1 gaps between them
        // But segments from whisper are joined with spaces, and each whisper segment
        // may contain multiple words. We use a simple heuristic: gaps index corresponds
        // to spaces between original whisper segments (not individual words).
        // Since we get segment gaps separately, we re-join based on gap count.

        // If gaps count doesn't match segment count - 1, fall back to simple text
        // The caller should provide one gap per pair of consecutive segments
        if gaps.count == 0 { return text }

        // Re-split by the special paragraph marker (caller should use this approach)
        // For now, we use a simpler approach: split text into parts by segment count
        // and insert breaks at gap positions

        // Each gap corresponds to the space between segment[i] and segment[i+1]
        // We have `gaps.count` transitions
        let parts = text.components(separatedBy: "  ") // double-space as segment separator
        if parts.count - 1 == gaps.count {
            for (i, part) in parts.enumerated() {
                result += part
                if i < gaps.count {
                    if gaps[i] >= pauseThreshold {
                        result += "\n\n"
                    } else {
                        result += " "
                    }
                }
            }
            return result
        }

        // Fallback: no segment info available, return as-is
        return text
    }
}
