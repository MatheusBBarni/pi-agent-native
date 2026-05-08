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
        let lines = addedDiffLines(from: text)
        var diff = [
            "diff --git a/\(path) b/\(path)",
            "new file mode 100644",
            "--- /dev/null",
            "+++ b/\(path)",
            "@@ -0,0 +1,\(lines.count) @@"
        ].joined(separator: "\n")

        if !lines.isEmpty {
            diff += "\n" + lines.map { "+\($0)" }.joined(separator: "\n")
        }
        return diff
    }

    private static func addedDiffLines(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") {
            lines.removeLast()
        }
        return lines
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
            let output = GitProcessOutput(stdout: stdout, stderr: stderr)
            output.readToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return output.stdoutData
        } catch {
            return nil
        }
    }

    private final class GitProcessOutput {
        private let stdout: Pipe
        private let stderr: Pipe
        private let lock = NSLock()
        private var stdoutStorage = Data()

        var stdoutData: Data {
            lock.lock()
            defer { lock.unlock() }
            return stdoutStorage
        }

        init(stdout: Pipe, stderr: Pipe) {
            self.stdout = stdout
            self.stderr = stderr
        }

        func readToEndOfFile() {
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).async { [stdout, weak self] in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                self?.setStdoutData(data)
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .utility).async { [stderr] in
                _ = stderr.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.wait()
        }

        private func setStdoutData(_ data: Data) {
            lock.lock()
            stdoutStorage = data
            lock.unlock()
        }
    }
}
