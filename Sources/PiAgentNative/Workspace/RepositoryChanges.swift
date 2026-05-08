import Foundation

struct RepositoryChangeSnapshot: Equatable {
    let projectPath: String
    let branch: String
    let files: [ChangedFile]
    let loadedAt: Date
    let status: RepositoryChangeSnapshotStatus

    static func unavailable(projectPath: String = "", reason: String) -> RepositoryChangeSnapshot {
        RepositoryChangeSnapshot(
            projectPath: projectPath,
            branch: "",
            files: [],
            loadedAt: Date(timeIntervalSince1970: 0),
            status: .unavailable(reason: reason)
        )
    }
}

enum RepositoryChangeSnapshotStatus: Equatable {
    case unavailable(reason: String)
    case notRepository
    case clean
    case dirty
    case loading
    case failed(message: String)
}

struct ChangedFile: Identifiable, Equatable {
    let id: String
    let path: String
    let originalPath: String?
    let state: ChangedFileState
    let indexStatus: GitFileStatus?
    let worktreeStatus: GitFileStatus?
    var isBinary: Bool
    var hunks: [DiffHunk]
    var diffStatus: DiffLoadStatus

    init(
        path: String,
        originalPath: String? = nil,
        state: ChangedFileState,
        indexStatus: GitFileStatus? = nil,
        worktreeStatus: GitFileStatus? = nil,
        isBinary: Bool = false,
        hunks: [DiffHunk] = [],
        diffStatus: DiffLoadStatus = .notLoaded
    ) {
        self.id = originalPath.map { "\($0)->\(path)" } ?? path
        self.path = path
        self.originalPath = originalPath
        self.state = state
        self.indexStatus = indexStatus
        self.worktreeStatus = worktreeStatus
        self.isBinary = isBinary
        self.hunks = hunks
        self.diffStatus = diffStatus
    }
}

enum ChangedFileState: Equatable {
    case added
    case modified
    case deleted
    case renamed
    case untracked
}

enum GitFileStatus: String, Equatable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case unmerged
    case untracked
}

enum DiffLoadStatus: Equatable {
    case notLoaded
    case loading
    case loaded
    case unavailable(message: String)
    case failed(message: String)
}

struct DiffHunk: Identifiable, Equatable {
    let id: String
    let header: String
    let oldStart: Int?
    let oldCount: Int?
    let newStart: Int?
    let newCount: Int?
    let lines: [DiffLine]
}

struct DiffLine: Identifiable, Equatable {
    let id: String
    let kind: DiffLineKind
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let text: String
}

enum DiffLineKind: Equatable {
    case metadata
    case hunkHeader
    case context
    case addition
    case deletion
}

enum GitStatusParser {
    static func parsePorcelainV1Z(_ data: Data) -> [ChangedFile] {
        let records = data.split(separator: 0).compactMap { String(data: Data($0), encoding: .utf8) }
        var files: [ChangedFile] = []
        var index = 0

        while index < records.count {
            let record = records[index]
            index += 1
            guard record.count >= 3 else { continue }

            let statusCharacters = Array(record.prefix(2))
            let pathStart = record.index(record.startIndex, offsetBy: 3)
            let path = String(record[pathStart...])
            let indexStatus = gitStatus(for: statusCharacters[0])
            let worktreeStatus = gitStatus(for: statusCharacters[1])
            let isRenameRecord = indexStatus == .renamed || indexStatus == .copied || worktreeStatus == .renamed || worktreeStatus == .copied
            let originalPath: String?
            if isRenameRecord, index < records.count {
                originalPath = records[index]
                index += 1
            } else {
                originalPath = nil
            }

            files.append(ChangedFile(
                path: path,
                originalPath: originalPath,
                state: changedFileState(indexStatus: indexStatus, worktreeStatus: worktreeStatus),
                indexStatus: indexStatus,
                worktreeStatus: worktreeStatus,
                diffStatus: .notLoaded
            ))
        }

        return files
    }

    private static func gitStatus(for character: Character) -> GitFileStatus? {
        switch character {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "U": return .unmerged
        case "?": return .untracked
        default: return nil
        }
    }

    private static func changedFileState(indexStatus: GitFileStatus?, worktreeStatus: GitFileStatus?) -> ChangedFileState {
        let statuses = [indexStatus, worktreeStatus]
        if statuses.contains(.renamed) || statuses.contains(.copied) { return .renamed }
        if statuses.contains(.deleted) { return .deleted }
        if statuses.contains(.added) { return .added }
        if statuses.contains(.untracked) { return .untracked }
        return .modified
    }
}

enum GitDiffParser {
    static func parseUnifiedDiff(_ text: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var pendingMetadata: [DiffLine] = []
        var currentHeader: String?
        var currentRange: HunkRange?
        var currentLines: [DiffLine] = []
        var oldLineNumber = 0
        var newLineNumber = 0
        var lineIndex = 0

        func finishCurrentHunk() {
            guard let header = currentHeader else { return }
            let range = currentRange
            hunks.append(DiffHunk(
                id: "\(hunks.count)-\(header)",
                header: header,
                oldStart: range?.oldStart,
                oldCount: range?.oldCount,
                newStart: range?.newStart,
                newCount: range?.newCount,
                lines: currentLines
            ))
            currentHeader = nil
            currentRange = nil
            currentLines = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if rawLine.hasPrefix("@@") {
                finishCurrentHunk()
                let range = parseHunkRange(rawLine)
                currentHeader = rawLine
                currentRange = range
                oldLineNumber = range?.oldStart ?? 0
                newLineNumber = range?.newStart ?? 0
                currentLines = pendingMetadata + [
                    DiffLine(
                        id: "\(lineIndex)",
                        kind: .hunkHeader,
                        oldLineNumber: nil,
                        newLineNumber: nil,
                        text: rawLine
                    )
                ]
                pendingMetadata = []
                lineIndex += 1
                continue
            }

            let parsedLine: DiffLine
            if rawLine.hasPrefix("+"), !rawLine.hasPrefix("+++") {
                parsedLine = DiffLine(
                    id: "\(lineIndex)",
                    kind: .addition,
                    oldLineNumber: nil,
                    newLineNumber: newLineNumber,
                    text: String(rawLine.dropFirst())
                )
                newLineNumber += 1
            } else if rawLine.hasPrefix("-"), !rawLine.hasPrefix("---") {
                parsedLine = DiffLine(
                    id: "\(lineIndex)",
                    kind: .deletion,
                    oldLineNumber: oldLineNumber,
                    newLineNumber: nil,
                    text: String(rawLine.dropFirst())
                )
                oldLineNumber += 1
            } else if rawLine.hasPrefix(" ") {
                parsedLine = DiffLine(
                    id: "\(lineIndex)",
                    kind: .context,
                    oldLineNumber: oldLineNumber,
                    newLineNumber: newLineNumber,
                    text: String(rawLine.dropFirst())
                )
                oldLineNumber += 1
                newLineNumber += 1
            } else {
                parsedLine = DiffLine(
                    id: "\(lineIndex)",
                    kind: .metadata,
                    oldLineNumber: nil,
                    newLineNumber: nil,
                    text: rawLine
                )
            }

            if currentHeader == nil {
                pendingMetadata.append(parsedLine)
            } else {
                currentLines.append(parsedLine)
            }
            lineIndex += 1
        }

        finishCurrentHunk()
        if hunks.isEmpty, !pendingMetadata.isEmpty {
            hunks.append(DiffHunk(
                id: "metadata",
                header: "",
                oldStart: nil,
                oldCount: nil,
                newStart: nil,
                newCount: nil,
                lines: pendingMetadata
            ))
        }
        return hunks
    }

    private struct HunkRange {
        var oldStart: Int?
        var oldCount: Int?
        var newStart: Int?
        var newCount: Int?
    }

    private static func parseHunkRange(_ header: String) -> HunkRange? {
        let parts = header.split(separator: " ")
        guard parts.count >= 3 else { return nil }
        let oldRange = parseRange(String(parts[1]), prefix: "-")
        let newRange = parseRange(String(parts[2]), prefix: "+")
        return HunkRange(
            oldStart: oldRange.start,
            oldCount: oldRange.count,
            newStart: newRange.start,
            newCount: newRange.count
        )
    }

    private static func parseRange(_ value: String, prefix: Character) -> (start: Int?, count: Int?) {
        guard value.first == prefix else { return (nil, nil) }
        let stripped = value.dropFirst()
        let components = stripped.split(separator: ",", maxSplits: 1).map(String.init)
        return (
            components.first.flatMap(Int.init),
            components.dropFirst().first.flatMap(Int.init) ?? 1
        )
    }
}
