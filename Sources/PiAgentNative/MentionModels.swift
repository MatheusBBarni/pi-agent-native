import Foundation

struct MentionQuery: Equatable {
    let range: Range<String.Index>
    let rawText: String
    let searchText: String
}

struct MentionIndexEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let relativePath: String
    let isDirectory: Bool
    let isSymlink: Bool
    let isHidden: Bool
    let resolvedURL: URL
}

struct MentionSearchResult: Identifiable, Equatable {
    var id: String { entry.id }

    let entry: MentionIndexEntry
    let score: Int
    let displayNameMatched: Bool
}

struct MentionPickerState: Equatable {
    let query: MentionQuery
    let results: [MentionSearchResult]
    let highlightedResultID: MentionSearchResult.ID?
    let status: MentionPickerStatus

    var highlightedResult: MentionSearchResult? {
        guard let highlightedResultID else { return nil }
        return results.first { $0.id == highlightedResultID }
    }
}

enum MentionPickerStatus: Equatable {
    case ready
    case indexing
    case noMatches
    case unavailable
}

struct MentionTextReplacement: Identifiable, Equatable {
    let id: UUID
    let range: NSRange
    let text: String

    init(id: UUID = UUID(), range: NSRange, text: String) {
        self.id = id
        self.range = range
        self.text = text
    }
}
