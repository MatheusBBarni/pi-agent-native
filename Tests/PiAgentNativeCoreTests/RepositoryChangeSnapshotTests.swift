import Foundation
import XCTest
@testable import PiAgentNativeCore

final class RepositoryChangeSnapshotTests: XCTestCase {
    func testGitServiceLoadsDirtySnapshotWithTrackedAndUntrackedDiffs() throws {
        let root = try makeTemporaryRepository()
        try write("one\n", to: "Tracked.txt", in: root)
        try runGit(["add", "Tracked.txt"], in: root)
        try runGit(["commit", "-m", "Initial"], in: root)

        try write("one\ntwo\n", to: "Tracked.txt", in: root)
        try write("new file\n", to: "Untracked.txt", in: root)

        let snapshot = GitService.repositoryChangeSnapshot(
            for: root.path,
            loadedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(snapshot.projectPath, root.path)
        XCTAssertEqual(snapshot.status, .dirty)
        XCTAssertEqual(snapshot.files.map(\.path), ["Tracked.txt", "Untracked.txt"])
        XCTAssertEqual(snapshot.files.map(\.state), [.modified, .untracked])
        XCTAssertEqual(snapshot.files[0].diffStatus, .loaded)
        XCTAssertTrue(snapshot.files[0].hunks.flatMap(\.lines).contains { $0.kind == .addition && $0.text == "two" })
        XCTAssertEqual(snapshot.files[1].diffStatus, .loaded)
        XCTAssertTrue(snapshot.files[1].hunks.flatMap(\.lines).contains { $0.kind == .addition && $0.text == "new file" })
    }

    func testGitServiceReportsNonRepository() throws {
        let root = try makeTemporaryDirectory()

        let snapshot = GitService.repositoryChangeSnapshot(
            for: root.path,
            loadedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(snapshot.status, .notRepository)
        XCTAssertTrue(snapshot.files.isEmpty)
    }

    func testUntrackedDiffHunkSizeUsesActualAddedLines() throws {
        let root = try makeTemporaryRepository()
        try write("one\n", to: "OneLine.txt", in: root)
        try write("", to: "Empty.txt", in: root)

        let snapshot = GitService.repositoryChangeSnapshot(
            for: root.path,
            loadedAt: Date(timeIntervalSince1970: 1)
        )
        let filesByPath = Dictionary(uniqueKeysWithValues: snapshot.files.map { ($0.path, $0) })

        let oneLine = try XCTUnwrap(filesByPath["OneLine.txt"])
        XCTAssertEqual(oneLine.hunks.first?.newCount, 1)
        XCTAssertEqual(oneLine.hunks.flatMap(\.lines).filter { $0.kind == .addition }.map(\.text), ["one"])

        let empty = try XCTUnwrap(filesByPath["Empty.txt"])
        XCTAssertEqual(empty.hunks.first?.newCount, 0)
        XCTAssertTrue(empty.hunks.flatMap(\.lines).filter { $0.kind == .addition }.isEmpty)
    }

    private func makeTemporaryRepository() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init"], in: root)
        try runGit(["config", "user.email", "test@example.com"], in: root)
        try runGit(["config", "user.name", "Test User"], in: root)
        return root
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pi-agent-native-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ text: String, to relativePath: String, in root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func runGit(_ arguments: [String], in root: URL) throws {
        let process = Process()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = root
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(arguments.joined(separator: " ")) failed: \(detail)")
            return
        }
    }
}
