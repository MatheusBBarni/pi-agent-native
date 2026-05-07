import Foundation

struct MentionIndexProvider {
    enum IndexError: Error {
        case projectUnavailable
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func entries(forProjectAt projectRoot: URL) throws -> [MentionIndexEntry] {
        let root = projectRoot.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw IndexError.projectUnavailable
        }

        if let gitPaths = gitPaths(in: root) {
            return entriesFromGitPaths(gitPaths, projectRoot: root)
        }
        return filesystemEntries(projectRoot: root)
    }

    private func entriesFromGitPaths(_ paths: [String], projectRoot: URL) -> [MentionIndexEntry] {
        var relativePaths = Set<String>()
        for path in paths where !isHardExcluded(path) {
            relativePaths.insert(path)
            var components = path.split(separator: "/").map(String.init)
            while components.count > 1 {
                components.removeLast()
                let directoryPath = components.joined(separator: "/")
                if !isHardExcluded(directoryPath) {
                    relativePaths.insert(directoryPath)
                }
            }
        }

        return relativePaths
            .compactMap { makeEntry(relativePath: $0, projectRoot: projectRoot) }
            .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private func filesystemEntries(projectRoot: URL) -> [MentionIndexEntry] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isRegularFileKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var entries: [MentionIndexEntry] = []
        for case let url as URL in enumerator {
            guard let relativePath = relativePath(for: url, projectRoot: projectRoot) else {
                continue
            }

            if isHardExcluded(relativePath) {
                enumerator.skipDescendants()
                continue
            }

            guard let entry = makeEntry(relativePath: relativePath, projectRoot: projectRoot) else {
                continue
            }
            entries.append(entry)

            if entry.isDirectory, entry.isSymlink {
                enumerator.skipDescendants()
            }
        }

        return entries.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private func makeEntry(relativePath: String, projectRoot: URL) -> MentionIndexEntry? {
        let url = projectRoot.appendingPathComponent(relativePath)
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return nil
        }

        let isDirectory = values.isDirectory ?? false
        let isSymlink = values.isSymbolicLink ?? false
        let displayName = url.lastPathComponent
        guard !displayName.isEmpty else { return nil }

        return MentionIndexEntry(
            id: relativePath,
            displayName: displayName,
            relativePath: relativePath,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            isHidden: isHidden(relativePath),
            resolvedURL: url.standardizedFileURL.resolvingSymlinksInPath()
        )
    }

    private func relativePath(for url: URL, projectRoot: URL) -> String? {
        let rootPath = projectRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path != rootPath, path.hasPrefix(rootPath + "/") else {
            return nil
        }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func gitPaths(in projectRoot: URL) -> [String]? {
        let process = Process()
        let stdout = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        process.currentDirectoryURL = projectRoot
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?
                .split(separator: "\0")
                .map(String.init)
                .filter { !$0.isEmpty }
        } catch {
            return nil
        }
    }

    private func isHardExcluded(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        return components.contains(".git")
            || components.contains(".build")
            || components.contains("DerivedData")
            || components.contains("node_modules")
            || components.contains(".DS_Store")
    }

    private func isHidden(_ relativePath: String) -> Bool {
        relativePath
            .split(separator: "/")
            .contains { $0.hasPrefix(".") }
    }
}
