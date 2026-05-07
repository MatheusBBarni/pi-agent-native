import Foundation

enum MentionQueryDetector {
    private static let openingDelimiters = Set<Character>(["(", "[", "{", "<", "'", "\""])

    static func activeQuery(in text: String, selectedRange: NSRange) -> MentionQuery? {
        guard selectedRange.length == 0,
              let cursorRange = Range(selectedRange, in: text)
        else { return nil }

        let cursor = cursorRange.lowerBound
        var index = cursor
        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            if character.isWhitespace {
                break
            }
            if character == "@" {
                guard isEligibleStart(at: previous, in: text) else {
                    index = previous
                    continue
                }
                let queryRange = previous..<cursor
                let rawText = String(text[queryRange])
                return MentionQuery(
                    range: queryRange,
                    rawText: rawText,
                    searchText: String(rawText.dropFirst())
                )
            }
            index = previous
        }

        return nil
    }

    private static func isEligibleStart(at index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return previous.isWhitespace || openingDelimiters.contains(previous)
    }
}
