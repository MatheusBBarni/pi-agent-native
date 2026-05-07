import Foundation

enum MentionInserter {
    static func replacementText(for entry: MentionIndexEntry) -> String {
        var path = entry.relativePath
        if entry.isDirectory, !path.hasSuffix("/") {
            path += "/"
        }
        return "@\(path) "
    }

    static func replacement(
        for entry: MentionIndexEntry,
        query: MentionQuery,
        in text: String,
        projectRoot: URL
    ) -> MentionTextReplacement? {
        guard isInsideProject(entry.resolvedURL, projectRoot: projectRoot) else {
            return nil
        }
        return MentionTextReplacement(
            range: NSRange(query.range, in: text),
            text: replacementText(for: entry, in: text, after: query.range.upperBound)
        )
    }

    static func replacing(
        text: String,
        query: MentionQuery,
        with entry: MentionIndexEntry,
        projectRoot: URL
    ) -> String? {
        guard isInsideProject(entry.resolvedURL, projectRoot: projectRoot) else {
            return nil
        }
        var updated = text
        updated.replaceSubrange(query.range, with: replacementText(for: entry, in: text, after: query.range.upperBound))
        return updated
    }

    static func isInsideProject(_ url: URL, projectRoot: URL) -> Bool {
        let rootComponents = projectRoot.standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents
        let resolvedComponents = url.standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents

        guard resolvedComponents.count >= rootComponents.count else {
            return false
        }
        return Array(resolvedComponents.prefix(rootComponents.count)) == rootComponents
    }

    private static func replacementText(
        for entry: MentionIndexEntry,
        in text: String,
        after queryEnd: String.Index
    ) -> String {
        let base = replacementText(for: entry)
        guard queryEnd < text.endIndex, text[queryEnd].isWhitespace else {
            return base
        }
        return String(base.dropLast())
    }
}
