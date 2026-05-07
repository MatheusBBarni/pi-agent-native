import Foundation

enum GitService {
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

    private static func run(_ arguments: [String], cwd: String) -> String? {
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
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
