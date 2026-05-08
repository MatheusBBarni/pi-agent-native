import Foundation

struct AvailableSkill: Identifiable, Equatable {
    var id: String
    var displayName: String?
    var description: String?
    var skillFilePath: String?
    var skillBaseDir: String?
}

enum SkillAvailability: Equatable {
    case notLoaded
    case loaded
    case unavailable(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

struct SkillQuery: Equatable {
    var tokenRange: NSRange
    var searchText: String
}

enum SkillPickerStatus: Equatable {
    case results
    case empty
    case unavailable(String)
}

enum ComposerControlKey {
    case up
    case down
    case returnKey
    case tab
    case escape
}

struct SkillPickerState: Equatable {
    var query: SkillQuery
    var results: [AvailableSkill]
    var highlightedSkillID: String?
    var status: SkillPickerStatus
}

enum SkillSelectionParseResult: Equatable {
    case normalPrompt
    case selection(skillIDs: [String])
    case invalid(String)
}

enum SkillSelectionValidationError: LocalizedError, Equatable {
    case unavailable
    case unknownSkill(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Skills unavailable"
        case .unknownSkill(let id):
            return "Unknown skill: \(id)"
        }
    }
}

enum SkillPromptDecorationError: LocalizedError, Equatable {
    case missingPath(String)
    case unreadablePath(skillID: String, path: String)

    var errorDescription: String? {
        switch self {
        case .missingPath(let id):
            return "Skill \(id) has no readable SKILL.md path."
        case .unreadablePath(let id, let path):
            return "Skill \(id) could not be read from \(path)."
        }
    }
}

enum SkillSelectionLogic {
    static let commandPrefix = "/skill:"
    static let commandNamePrefix = "skill:"
    static let maxResults = 12

    static func parseSubmission(_ text: String) -> SkillSelectionParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .normalPrompt }

        let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let containsSkillCommand = tokens.contains { $0.hasPrefix(commandPrefix) }
        guard containsSkillCommand else { return .normalPrompt }

        guard tokens.allSatisfy({ $0.hasPrefix(commandPrefix) }) else {
            return .invalid("Skill selections cannot be mixed with prompt text.")
        }

        var skillIDs: [String] = []
        for token in tokens {
            let skillID = String(token.dropFirst(commandPrefix.count))
            guard !skillID.isEmpty else {
                return .invalid("Missing skill id.")
            }
            guard !skillID.contains(",") else {
                return .invalid("Use repeated /skill:<skill-id> tokens instead of comma-separated skills.")
            }
            skillIDs.append(skillID)
        }

        return .selection(skillIDs: skillIDs)
    }

    static func detectQuery(in text: String, selectedRange: NSRange) -> SkillQuery? {
        guard selectedRange.length == 0 else { return nil }

        let nsText = text as NSString
        let length = nsText.length
        let cursor = min(max(selectedRange.location, 0), length)

        var start = cursor
        while start > 0, !isWhitespace(nsText.character(at: start - 1)) {
            start -= 1
        }

        var end = cursor
        while end < length, !isWhitespace(nsText.character(at: end)) {
            end += 1
        }

        guard end > start else { return nil }
        let tokenRange = NSRange(location: start, length: end - start)
        let token = nsText.substring(with: tokenRange)
        guard token.hasPrefix(commandPrefix), cursor >= start + commandPrefix.count else {
            return nil
        }

        return SkillQuery(
            tokenRange: tokenRange,
            searchText: String(token.dropFirst(commandPrefix.count))
        )
    }

    static func search(_ query: String, in skills: [AvailableSkill]) -> [AvailableSkill] {
        let normalizedQuery = query.lowercased()
        let rankedSkills: [(skill: AvailableSkill, rank: Int)] = skills.compactMap { skill in
            guard let rank = rank(skill, for: normalizedQuery) else { return nil }
            return (skill, rank)
        }

        return rankedSkills
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank < rhs.rank
                }
                return lhs.skill.id.localizedStandardCompare(rhs.skill.id) == .orderedAscending
            }
            .prefix(maxResults)
            .map(\.skill)
    }

    static func replacement(for skillID: String, in text: String, query: SkillQuery) -> (text: String, selectedRange: NSRange) {
        let replacement = "\(commandPrefix)\(skillID) "
        let nsText = text as NSString
        let nextText = nsText.replacingCharacters(in: query.tokenRange, with: replacement)
        return (
            text: nextText,
            selectedRange: NSRange(location: query.tokenRange.location + (replacement as NSString).length, length: 0)
        )
    }

    static func resolveSelection(
        skillIDs: [String],
        availableSkills: [AvailableSkill],
        existingSkills: [AvailableSkill]
    ) throws -> [AvailableSkill] {
        var availableByID: [String: AvailableSkill] = [:]
        for skill in availableSkills where availableByID[skill.id] == nil {
            availableByID[skill.id] = skill
        }
        let existingIDs = Set(existingSkills.map(\.id))
        var seenIDs = Set<String>()
        var resolved: [AvailableSkill] = []

        for skillID in skillIDs {
            guard let skill = availableByID[skillID] else {
                throw SkillSelectionValidationError.unknownSkill(skillID)
            }
            guard !seenIDs.contains(skillID) else { continue }
            seenIDs.insert(skillID)
            if !existingIDs.contains(skillID) {
                resolved.append(skill)
            }
        }

        return resolved
    }

    static func availableSkills(from commandDictionaries: [[String: Any]]) -> [AvailableSkill] {
        var seenIDs = Set<String>()
        return commandDictionaries.compactMap { command in
            guard
                stringValue(command["source"]) == "skill",
                let name = stringValue(command["name"]),
                name.hasPrefix(commandNamePrefix)
            else { return nil }

            let skillID = String(name.dropFirst(commandNamePrefix.count))
            guard !skillID.isEmpty, !seenIDs.contains(skillID) else { return nil }
            seenIDs.insert(skillID)

            let sourceInfo = command["sourceInfo"] as? [String: Any]
            return AvailableSkill(
                id: skillID,
                displayName: stringValue(command["displayName"]) ?? stringValue(command["title"]),
                description: stringValue(command["description"]),
                skillFilePath: stringValue(sourceInfo?["path"]),
                skillBaseDir: stringValue(sourceInfo?["baseDir"])
            )
        }
        .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    private static func rank(_ skill: AvailableSkill, for normalizedQuery: String) -> Int? {
        guard !normalizedQuery.isEmpty else { return 0 }

        let id = skill.id.lowercased()
        let displayName = skill.displayName?.lowercased()

        if id.hasPrefix(normalizedQuery) { return 0 }
        if id.contains(normalizedQuery) { return 1 }
        if displayName?.hasPrefix(normalizedQuery) == true { return 2 }
        if displayName?.contains(normalizedQuery) == true { return 3 }
        return nil
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        guard let scalar = UnicodeScalar(character) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value { return "\(value)" }
        return nil
    }
}

enum SkillPromptDecorator {
    static func decoratedPrompt(userPrompt: String, skills: [AvailableSkill]) throws -> String {
        guard !skills.isEmpty else { return userPrompt }

        let blocks = try skills.map(skillBlock(for:))
        return blocks.joined(separator: "\n\n") + "\n\n" + userPrompt
    }

    static func visibleUserPrompt(from rpcPrompt: String) -> String {
        var remaining = rpcPrompt
        var strippedAnyBlock = false

        while let blockRange = nativeSkillBlockPrefixRange(in: remaining) {
            remaining.removeSubrange(blockRange)
            remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            strippedAnyBlock = true
        }

        let withoutContextAttachments = ContextAttachmentPromptDecorator.visibleUserPrompt(from: remaining)
        if withoutContextAttachments != remaining {
            return withoutContextAttachments
        }
        return strippedAnyBlock ? remaining : rpcPrompt
    }

    static func stripFrontmatter(from markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = normalized.components(separatedBy: "\n")
        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0 == "---" }) else {
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return lines
            .dropFirst(closingIndex + 1)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nativeSkillBlockPrefixRange(in prompt: String) -> Range<String.Index>? {
        guard prompt.hasPrefix("<skill name=\""),
              let firstLineEnd = prompt.firstIndex(of: "\n") else {
            return nil
        }

        let firstLine = prompt[prompt.startIndex..<firstLineEnd]
        guard firstLine.contains("\" location=\""),
              firstLine.hasSuffix("\">") else {
            return nil
        }

        let bodyStart = prompt.index(after: firstLineEnd)
        guard prompt[bodyStart...].hasPrefix("References are relative to "),
              let closeRange = prompt.range(of: "\n</skill>", range: bodyStart..<prompt.endIndex) else {
            return nil
        }

        return prompt.startIndex..<closeRange.upperBound
    }

    private static func skillBlock(for skill: AvailableSkill) throws -> String {
        guard let path = skill.skillFilePath, !path.isEmpty else {
            throw SkillPromptDecorationError.missingPath(skill.id)
        }

        guard let markdown = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw SkillPromptDecorationError.unreadablePath(skillID: skill.id, path: path)
        }

        let content = stripFrontmatter(from: markdown)
        let referencesDirectory = URL(fileURLWithPath: path).deletingLastPathComponent().path

        return """
        <skill name="\(xmlEscapedAttribute(skill.id))" location="\(xmlEscapedAttribute(path))">
        References are relative to \(referencesDirectory).

        \(content)
        </skill>
        """
    }

    private static func xmlEscapedAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
