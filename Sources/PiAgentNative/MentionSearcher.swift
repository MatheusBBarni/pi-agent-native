import Foundation

enum MentionSearcher {
    static let defaultLimit = 12

    static func search(
        entries: [MentionIndexEntry],
        query: MentionQuery,
        limit: Int = defaultLimit
    ) -> [MentionSearchResult] {
        let searchText = query.searchText.lowercased()
        let includeHidden = searchText.hasPrefix(".")
        let eligibleEntries = entries.filter { includeHidden || !$0.isHidden }

        if searchText.isEmpty {
            return eligibleEntries
                .sorted(by: compareEmptyQueryEntries)
                .prefix(limit)
                .map {
                    MentionSearchResult(entry: $0, score: 0, displayNameMatched: true)
                }
        }

        return eligibleEntries
            .compactMap { result(for: $0, searchText: searchText) }
            .sorted(by: compareResults)
            .prefix(limit)
            .map { $0 }
    }

    private static func result(
        for entry: MentionIndexEntry,
        searchText: String
    ) -> MentionSearchResult? {
        let displayName = entry.displayName.lowercased()
        let relativePath = entry.relativePath.lowercased()

        if displayName.hasPrefix(searchText) {
            return MentionSearchResult(entry: entry, score: 0, displayNameMatched: true)
        }
        if displayName.contains(searchText) {
            return MentionSearchResult(entry: entry, score: 1, displayNameMatched: true)
        }
        if relativePath.hasPrefix(searchText) {
            return MentionSearchResult(entry: entry, score: 2, displayNameMatched: false)
        }
        if relativePath.contains(searchText) {
            return MentionSearchResult(entry: entry, score: 3, displayNameMatched: false)
        }
        return nil
    }

    private static func compareResults(_ lhs: MentionSearchResult, _ rhs: MentionSearchResult) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        return compareEntries(lhs.entry, rhs.entry)
    }

    private static func compareEmptyQueryEntries(_ lhs: MentionIndexEntry, _ rhs: MentionIndexEntry) -> Bool {
        let lhsDepth = lhs.relativePath.split(separator: "/").count
        let rhsDepth = rhs.relativePath.split(separator: "/").count
        if lhsDepth != rhsDepth {
            return lhsDepth < rhsDepth
        }
        return compareEntries(lhs, rhs)
    }

    private static func compareEntries(_ lhs: MentionIndexEntry, _ rhs: MentionIndexEntry) -> Bool {
        if lhs.relativePath.count != rhs.relativePath.count {
            return lhs.relativePath.count < rhs.relativePath.count
        }
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
    }
}
