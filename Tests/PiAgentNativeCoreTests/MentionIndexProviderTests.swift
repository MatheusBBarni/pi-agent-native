import Foundation
import XCTest
@testable import PiAgentNativeCore

final class MentionIndexProviderTests: XCTestCase {
    func testFilesystemIndexExcludesHardNoiseAndMarksHiddenEntries() throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try createFile("Sources/App.swift", in: root)
        try createFile(".github/workflows/ci.yml", in: root)
        try createFile(".build/debug/output.o", in: root)
        try createFile("node_modules/pkg/index.js", in: root)
        try createFile(".DS_Store", in: root)

        let entries = try MentionIndexProvider().entries(forProjectAt: root)
        let paths = Set(entries.map(\.relativePath))

        XCTAssertTrue(paths.contains("Sources/App.swift"))
        XCTAssertTrue(paths.contains(".github"))
        XCTAssertFalse(paths.contains(".build"))
        XCTAssertFalse(paths.contains("node_modules"))
        XCTAssertFalse(paths.contains(".DS_Store"))
        XCTAssertTrue(entries.first { $0.relativePath == ".github" }?.isHidden == true)
    }

    func testDirectorySymlinksAreIndexedButNotTraversed() throws {
        let root = temporaryDirectory()
        let outside = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try createFile("secret.txt", in: outside)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("linked"),
            withDestinationURL: outside
        )

        let entries = try MentionIndexProvider().entries(forProjectAt: root)

        XCTAssertTrue(entries.contains { $0.relativePath == "linked" && $0.isSymlink })
        XCTAssertFalse(entries.contains { $0.relativePath == "linked/secret.txt" })
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func createFile(_ relativePath: String, in root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data())
    }
}
