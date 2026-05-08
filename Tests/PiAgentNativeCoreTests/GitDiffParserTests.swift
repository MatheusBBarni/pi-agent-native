import XCTest
@testable import PiAgentNativeCore

final class GitDiffParserTests: XCTestCase {
    func testParsesUnifiedDiffHunkLinesAndRanges() {
        let diff = """
        diff --git a/Sources/App.swift b/Sources/App.swift
        index 1111111..2222222 100644
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -10,2 +10,3 @@ struct Example
         let oldValue = 1
        -let name = "old"
        +let name = "new"
        +let enabled = true
        \\ No newline at end of file
        """

        let hunks = GitDiffParser.parseUnifiedDiff(diff)

        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks[0].oldStart, 10)
        XCTAssertEqual(hunks[0].oldCount, 2)
        XCTAssertEqual(hunks[0].newStart, 10)
        XCTAssertEqual(hunks[0].newCount, 3)
        XCTAssertEqual(hunks[0].lines.map(\.kind), [
            .metadata,
            .metadata,
            .metadata,
            .metadata,
            .hunkHeader,
            .context,
            .deletion,
            .addition,
            .addition,
            .metadata
        ])
        XCTAssertEqual(hunks[0].lines[5].oldLineNumber, 10)
        XCTAssertEqual(hunks[0].lines[5].newLineNumber, 10)
        XCTAssertEqual(hunks[0].lines[6].oldLineNumber, 11)
        XCTAssertNil(hunks[0].lines[6].newLineNumber)
        XCTAssertNil(hunks[0].lines[7].oldLineNumber)
        XCTAssertEqual(hunks[0].lines[7].newLineNumber, 11)
        XCTAssertEqual(hunks[0].lines[7].text, #"let name = "new""#)
    }

    func testKeepsBinaryDiffAsMetadataOnlyHunk() {
        let diff = "Binary files a/Asset.png and b/Asset.png differ"

        let hunks = GitDiffParser.parseUnifiedDiff(diff)

        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks[0].lines, [
            DiffLine(
                id: "0",
                kind: .metadata,
                oldLineNumber: nil,
                newLineNumber: nil,
                text: diff
            )
        ])
    }
}
