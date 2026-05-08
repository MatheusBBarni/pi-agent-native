import Foundation

struct ContextAttachment: Identifiable, Equatable {
    let id: String
    let projectID: ProjectItem.ID
    let projectPath: String
    let relativePath: String
    let displayName: String
    let kind: ContextAttachmentKind
    let createdResolvedURL: URL
    var status: ContextAttachmentStatus

    static func make(
        from entry: MentionIndexEntry,
        selectedProject: ProjectItem,
        status: ContextAttachmentStatus
    ) -> ContextAttachment {
        let kind: ContextAttachmentKind = entry.isDirectory ? .folder : .file
        let normalizedPath = kind.normalized(relativePath: entry.relativePath)
        return ContextAttachment(
            id: "\(selectedProject.id):\(normalizedPath)",
            projectID: selectedProject.id,
            projectPath: selectedProject.path,
            relativePath: normalizedPath,
            displayName: entry.displayName,
            kind: kind,
            createdResolvedURL: entry.resolvedURL,
            status: status
        )
    }
}

enum ContextAttachmentKind: Equatable {
    case file
    case folder

    var label: String {
        switch self {
        case .file: return "file"
        case .folder: return "folder"
        }
    }

    var systemImage: String {
        switch self {
        case .file: return "doc.text"
        case .folder: return "folder"
        }
    }

    func normalized(relativePath: String) -> String {
        switch self {
        case .file:
            return relativePath
        case .folder:
            var path = relativePath
            while path.hasSuffix("/") {
                path.removeLast()
            }
            return path + "/"
        }
    }
}

enum ContextAttachmentStatus: Equatable {
    case valid(resolvedURL: URL)
    case missing
    case wrongKind(actualKind: ContextAttachmentKind?)
    case outOfProject
    case projectChanged
    case resolutionFailed(message: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .valid:
            return "Ready"
        case .missing:
            return "Missing"
        case .wrongKind(let actualKind):
            guard let actualKind else { return "Wrong kind" }
            return "Now a \(actualKind.label)"
        case .outOfProject:
            return "Outside project"
        case .projectChanged:
            return "Project changed"
        case .resolutionFailed:
            return "Unavailable"
        }
    }
}

enum ContextAttachmentResolver {
    static func resolve(
        _ attachment: ContextAttachment,
        selectedProject: ProjectItem?,
        fileManager: FileManager = .default
    ) -> ContextAttachmentStatus {
        guard let selectedProject else { return .projectChanged }
        guard selectedProject.id == attachment.projectID,
              selectedProject.path == attachment.projectPath
        else {
            return .projectChanged
        }

        guard isSafeWorkspaceRelativePath(attachment.relativePath) else {
            return .outOfProject
        }

        let projectRoot = URL(fileURLWithPath: selectedProject.path, isDirectory: true)
        let candidate = projectRoot.appendingPathComponent(
            attachment.relativePath,
            isDirectory: attachment.kind == .folder
        )

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) else {
            return .missing
        }

        let actualKind: ContextAttachmentKind = isDirectory.boolValue ? .folder : .file
        guard actualKind == attachment.kind else {
            return .wrongKind(actualKind: actualKind)
        }

        let resolvedURL = candidate.standardizedFileURL.resolvingSymlinksInPath()
        guard MentionInserter.isInsideProject(resolvedURL, projectRoot: projectRoot) else {
            return .outOfProject
        }

        return .valid(resolvedURL: resolvedURL)
    }

    static func refreshed(
        _ attachments: [ContextAttachment],
        selectedProject: ProjectItem?,
        fileManager: FileManager = .default
    ) -> [ContextAttachment] {
        attachments.map { attachment in
            var refreshedAttachment = attachment
            refreshedAttachment.status = resolve(
                attachment,
                selectedProject: selectedProject,
                fileManager: fileManager
            )
            return refreshedAttachment
        }
    }

    private static func isSafeWorkspaceRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        return !components.contains { $0 == "." || $0 == ".." }
    }
}

enum ContextAttachmentPromptDecorator {
    static func decoratedPrompt(userPrompt: String, attachments: [ContextAttachment]) -> String {
        let validAttachments = attachments.filter { $0.status.isValid }
        guard !validAttachments.isEmpty else { return userPrompt }

        let entries = validAttachments.map { attachment in
            "- \(attachment.kind.label): \(escapedPath(for: attachment))"
        }
        let block = """
        <context-attachments>
        \(entries.joined(separator: "\n"))
        </context-attachments>
        """

        guard !userPrompt.isEmpty else { return block }
        return block + "\n\n" + userPrompt
    }

    static func visibleUserPrompt(from rpcPrompt: String) -> String {
        var remaining = rpcPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let blockRange = nativeContextAttachmentBlockPrefixRange(in: remaining) else {
            return rpcPrompt
        }
        remaining.removeSubrange(blockRange)
        return remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func escapedPath(for attachment: ContextAttachment) -> String {
        let path = attachment.kind.normalized(relativePath: attachment.relativePath)
        return path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private static func nativeContextAttachmentBlockPrefixRange(in prompt: String) -> Range<String.Index>? {
        guard prompt.hasPrefix("<context-attachments>\n"),
              let closeRange = prompt.range(of: "\n</context-attachments>")
        else {
            return nil
        }

        let bodyStart = prompt.index(prompt.startIndex, offsetBy: "<context-attachments>\n".count)
        let body = prompt[bodyStart..<closeRange.lowerBound]
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty,
              lines.allSatisfy({ $0.hasPrefix("- file: ") || $0.hasPrefix("- folder: ") })
        else {
            return nil
        }

        return prompt.startIndex..<closeRange.upperBound
    }
}
