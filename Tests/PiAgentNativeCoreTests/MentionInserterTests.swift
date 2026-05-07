import Foundation
import XCTest
@testable import PiAgentNativeCore

final class MentionInserterTests: XCTestCase {
    func testFormatsFileAndFolderMentions() {
        XCTAssertEqual(
            MentionInserter.replacementText(for: entry("Sources/App.swift", isDirectory: false)),
            "@Sources/App.swift "
        )
        XCTAssertEqual(
            MentionInserter.replacementText(for: entry("Sources/PiAgentNative", isDirectory: true)),
            "@Sources/PiAgentNative/ "
        )
    }

    func testReplacesOnlyActiveQuery() throws {
        let root = temporaryDirectory()
        let file = root.appendingPathComponent("Sources/App.swift")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: file.path, contents: Data())

        let text = "Review @app and summarize"
        let query = MentionQueryDetector.activeQuery(
            in: text,
            selectedRange: NSRange(location: "Review @app".count, length: 0)
        )!
        let updated = MentionInserter.replacing(
            text: text,
            query: query,
            with: entry("Sources/App.swift", resolvedURL: file),
            projectRoot: root
        )

        XCTAssertEqual(updated, "Review @Sources/App.swift and summarize")
    }

    func testRejectsSymlinkOrPrefixEscapesOutsideProject() throws {
        let container = temporaryDirectory()
        let root = container.appendingPathComponent("project")
        let sibling = container.appendingPathComponent("project-other")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)

        XCTAssertFalse(MentionInserter.isInsideProject(sibling, projectRoot: root))
        XCTAssertNil(MentionInserter.replacing(
            text: "@outside",
            query: query("@outside"),
            with: entry("outside", resolvedURL: sibling),
            projectRoot: root
        ))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func query(_ text: String) -> MentionQuery {
        MentionQueryDetector.activeQuery(
            in: text,
            selectedRange: NSRange(location: (text as NSString).length, length: 0)
        )!
    }

    private func entry(
        _ relativePath: String,
        isDirectory: Bool = false,
        resolvedURL: URL? = nil
    ) -> MentionIndexEntry {
        let url = resolvedURL ?? URL(fileURLWithPath: "/tmp/project").appendingPathComponent(relativePath)
        return MentionIndexEntry(
            id: relativePath,
            displayName: url.lastPathComponent,
            relativePath: relativePath,
            isDirectory: isDirectory,
            isSymlink: false,
            isHidden: false,
            resolvedURL: url
        )
    }
}
