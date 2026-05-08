import Foundation

enum GitService {
    private static let untrackedPreviewByteLimit = 64 * 1024

    static func branchDetails(for workspace: String) -> GitBranchDetails {
        let branch = run(["branch", "--show-current"], cwd: workspace)
        let fallbackHead = run(["rev-parse", "--short", "HEAD"], cwd: workspace)
        let status = run(["status", "--porcelain"], cwd: workspace)

        let resolvedBranch: String
        if let branch, !branch.isEmpty {
            resolvedBranch = branch
        } else if let fallbackHead, !fallbackHead.isEmpty {
            resolvedBranch = "detached \(fallbackHead)"
        } else {
            resolvedBranch = "Not a git repository"
        }

        let changedLines = status?.split(separator: "\n").count ?? 0
        return GitBranchDetails(
            branch: resolvedBranch,
            hasChanges: changedLines > 0,
            changeSummary: changedLines > 0 ? "\(changedLines) changed file\(changedLines == 1 ? "" : "s")" : "No changes"
        )
    }

    static func repositoryChangeSnapshot(for workspace: String, loadedAt: Date = Date()) -> RepositoryChangeSnapshot {
        guard run(["rev-parse", "--is-inside-work-tree"], cwd: workspace) == "true" else {
            return RepositoryChangeSnapshot(
                projectPath: workspace,
                branch: "Not a git repository",
                files: [],
                loadedAt: loadedAt,
                status: .notRepository
            )
        }

        let branch = resolvedBranch(for: workspace)
        guard let statusData = runData(["status", "--porcelain=v1", "-z"], cwd: workspace) else {
            return RepositoryChangeSnapshot(
                projectPath: workspace,
                branch: branch,
                files: [],
                loadedAt: loadedAt,
                status: .failed(message: "Could not read Git status.")
            )
        }

        let parsedFiles = GitStatusParser.parsePorcelainV1Z(statusData)
        guard !parsedFiles.isEmpty else {
            return RepositoryChangeSnapshot(
                projectPath: workspace,
                branch: branch,
                files: [],
                loadedAt: loadedAt,
                status: .clean
            )
        }

        let files = parsedFiles.map { file in
            loadDiff(for: file, workspace: workspace)
        }
        return RepositoryChangeSnapshot(
            projectPath: workspace,
            branch: branch,
            files: files,
            loadedAt: loadedAt,
            status: .dirty
        )
    }

    private static func resolvedBranch(for workspace: String) -> String {
        if let branch = run(["branch", "--show-current"], cwd: workspace), !branch.isEmpty {
            return branch
        }
        if let fallbackHead = run(["rev-parse", "--short", "HEAD"], cwd: workspace), !fallbackHead.isEmpty {
            return "detached \(fallbackHead)"
        }
        return "HEAD unavailable"
    }

    private static func loadDiff(for file: ChangedFile, workspace: String) -> ChangedFile {
        var changedFile = file

        if file.state == .untracked {
            return loadUntrackedDiff(for: changedFile, workspace: workspace)
        }

        guard run(["rev-parse", "--verify", "HEAD"], cwd: workspace) != nil else {
            changedFile.diffStatus = .unavailable(message: "Diff unavailable because this repository has no HEAD yet.")
            return changedFile
        }

        var diffArguments = [
            "diff",
            "--find-renames",
            "--no-ext-diff",
            "--no-color",
            "--unified=3",
            "HEAD",
            "--",
            file.path
        ]
        if let originalPath = file.originalPath {
            diffArguments.append(originalPath)
        }

        guard let diff = runString(diffArguments, cwd: workspace) else {
            changedFile.diffStatus = .failed(message: "Could not load diff for \(file.path).")
            return changedFile
        }

        if diff.contains("Binary files ") {
            changedFile.isBinary = true
            changedFile.diffStatus = .unavailable(message: "Binary file diff is not shown.")
            return changedFile
        }

        changedFile.hunks = GitDiffParser.parseUnifiedDiff(diff)
        changedFile.diffStatus = changedFile.hunks.isEmpty ? .unavailable(message: "No textual diff available.") : .loaded
        return changedFile
    }

    private static func loadUntrackedDiff(for file: ChangedFile, workspace: String) -> ChangedFile {
        var changedFile = file
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(file.path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? NSNumber
        else {
            changedFile.diffStatus = .unavailable(message: "Untracked file is not readable.")
            return changedFile
        }

        if attributes[.type] as? FileAttributeType == .typeDirectory {
            changedFile.diffStatus = .unavailable(message: "Untracked directory diff is not shown.")
            return changedFile
        }

        guard fileSize.intValue <= untrackedPreviewByteLimit else {
            changedFile.diffStatus = .unavailable(message: "Untracked file is too large for native preview.")
            return changedFile
        }

        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            changedFile.diffStatus = .unavailable(message: "Untracked binary file diff is not shown.")
            changedFile.isBinary = true
            return changedFile
        }

        let diff = synthesizedAddedDiff(path: file.path, text: text)
        changedFile.hunks = GitDiffParser.parseUnifiedDiff(diff)
        changedFile.diffStatus = .loaded
        return changedFile
    }

    private static func synthesizedAddedDiff(path: String, text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let count = lines.isEmpty ? 0 : lines.count
        var diff = [
            "diff --git a/\(path) b/\(path)",
            "new file mode 100644",
            "--- /dev/null",
            "+++ b/\(path)",
            "@@ -0,0 +1,\(count) @@"
        ].joined(separator: "\n")

        if !text.isEmpty {
            diff += "\n" + lines.map { "+\($0)" }.joined(separator: "\n")
        }
        return diff
    }

    private static func run(_ arguments: [String], cwd: String) -> String? {
        guard let data = runData(arguments, cwd: cwd) else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runString(_ arguments: [String], cwd: String) -> String? {
        guard let data = runData(arguments, cwd: cwd) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func runData(_ arguments: [String], cwd: String) -> Data? {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return stdout.fileHandleForReading.readDataToEndOfFile()
        } catch {
            return nil
        }
    }
}
