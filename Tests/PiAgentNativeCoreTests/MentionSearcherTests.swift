import Foundation
import XCTest
@testable import PiAgentNativeCore

final class MentionSearcherTests: XCTestCase {
    func testRanksDisplayNameBeforePathMatchesAndCapsResults() {
        let entries = [
            entry("Sources/PiAgentNative/PiRPCClient.swift"),
            entry("Sources/PiAgentNative/AppModel.swift"),
            entry("pirpc/a.md"),
            entry("pirpc/b.md"),
            entry("pirpc/c.md"),
            entry("pirpc/d.md"),
            entry("pirpc/e.md"),
            entry("pirpc/f.md"),
            entry("pirpc/g.md"),
            entry("pirpc/h.md"),
            entry("pirpc/i.md"),
            entry("pirpc/j.md"),
            entry("pirpc/k.md"),
            entry("pirpc/l.md")
        ]

        let results = MentionSearcher.search(entries: entries, query: query("@pirpc"))

        XCTAssertEqual(results.count, 12)
        XCTAssertEqual(results.first?.entry.relativePath, "Sources/PiAgentNative/PiRPCClient.swift")
        XCTAssertTrue(results.dropFirst().contains { $0.entry.relativePath == "pirpc/a.md" })
    }

    func testHiddenEntriesOnlyAppearForDotQueries() {
        let entries = [
            entry(".github/workflows/ci.yml", isHidden: true),
            entry("Sources/App.swift")
        ]

        XCTAssertFalse(MentionSearcher.search(entries: entries, query: query("@gi")).contains {
            $0.entry.relativePath.hasPrefix(".github")
        })
        XCTAssertTrue(MentionSearcher.search(entries: entries, query: query("@.g")).contains {
            $0.entry.relativePath.hasPrefix(".github")
        })
    }

    func testEmptyQueryReturnsInitialResultSet() {
        let entries = [
            entry("Sources/PiAgentNative/AppModel.swift"),
            entry("README.md"),
            entry("Package.swift")
        ]

        let results = MentionSearcher.search(entries: entries, query: query("@"))

        XCTAssertEqual(results.map(\.entry.relativePath), ["README.md", "Package.swift", "Sources/PiAgentNative/AppModel.swift"])
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
        isHidden: Bool = false
    ) -> MentionIndexEntry {
        let url = URL(fileURLWithPath: "/tmp/project").appendingPathComponent(relativePath)
        return MentionIndexEntry(
            id: relativePath,
            displayName: url.lastPathComponent,
            relativePath: relativePath,
            isDirectory: isDirectory,
            isSymlink: false,
            isHidden: isHidden,
            resolvedURL: url
        )
    }
}
