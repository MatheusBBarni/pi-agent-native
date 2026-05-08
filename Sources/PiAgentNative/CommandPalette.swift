import Foundation

struct CommandPaletteItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let keywords: [String]
    let iconSystemName: String?
    let keybindingLabel: String?
    let availability: CommandPaletteAvailability
    let invocation: CommandPaletteInvocation
}

enum CommandPaletteAvailability: Equatable {
    case enabled
    case disabled(reason: String)

    var isEnabled: Bool {
        if case .enabled = self {
            return true
        }
        return false
    }

    var disabledReason: String? {
        guard case .disabled(let reason) = self else { return nil }
        return reason
    }
}

enum CommandPaletteInvocation: Equatable {
    case appAction(AppActionID)
    case selectProject(ProjectItem.ID)
    case switchSession(StoredSession.ID)
    case selectModel(provider: String, modelID: String)
    case setThinkingLevel(String)
    case openExternalTarget(ExternalTargetID)
    case showLogin
    case showModelPicker
}

enum CommandPaletteCatalog {
    static let thinkingLevels = ["off", "minimal", "low", "medium", "high", "xhigh"]
}

enum CommandPaletteFilter {
    static func filteredItems(_ items: [CommandPaletteItem], query: String) -> [CommandPaletteItem] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return items }

        return items.enumerated().compactMap { index, item -> RankedCommandPaletteItem? in
            guard let rank = matchRank(item, query: normalizedQuery) else { return nil }
            return RankedCommandPaletteItem(item: item, rank: rank, sourceIndex: index)
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.sourceIndex < rhs.sourceIndex
        }
        .map(\.item)
    }

    private static func matchRank(_ item: CommandPaletteItem, query: String) -> Int? {
        let title = normalize(item.title)
        if title.split(separator: " ").contains(where: { $0 == query }) {
            return 0
        }
        if title.hasPrefix(query) {
            return 1
        }
        if title.contains(query) {
            return 2
        }

        if let subtitle = item.subtitle.map(normalize), subtitle.contains(query) {
            return 3
        }

        let keywordMatches = item.keywords.map(normalize).contains { $0.contains(query) }
        return keywordMatches ? 4 : nil
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct RankedCommandPaletteItem {
    let item: CommandPaletteItem
    let rank: Int
    let sourceIndex: Int
}
