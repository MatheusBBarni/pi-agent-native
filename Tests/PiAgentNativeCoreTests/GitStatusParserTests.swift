import Foundation
import XCTest
@testable import PiAgentNativeCore

final class GitStatusParserTests: XCTestCase {
    func testParsesPorcelainV1ZStatusRecords() {
        let data = Data("M  Sources/App.swift\0 D Sources/Removed.swift\0?? Notes.txt\0A  Sources/New.swift\0".utf8)

        let files = GitStatusParser.parsePorcelainV1Z(data)

        XCTAssertEqual(files.map(\.path), [
            "Sources/App.swift",
            "Sources/Removed.swift",
            "Notes.txt",
            "Sources/New.swift"
        ])
        XCTAssertEqual(files.map(\.state), [.modified, .deleted, .untracked, .added])
        XCTAssertEqual(files[0].indexStatus, .modified)
        XCTAssertNil(files[0].worktreeStatus)
        XCTAssertNil(files[1].indexStatus)
        XCTAssertEqual(files[1].worktreeStatus, .deleted)
        XCTAssertEqual(files[2].indexStatus, .untracked)
        XCTAssertEqual(files[2].worktreeStatus, .untracked)
    }

    func testParsesRenameRecordAsNewPathThenOldPath() {
        let data = Data("R  Sources/New.swift\0Sources/Old.swift\0".utf8)

        let files = GitStatusParser.parsePorcelainV1Z(data)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].state, .renamed)
        XCTAssertEqual(files[0].path, "Sources/New.swift")
        XCTAssertEqual(files[0].originalPath, "Sources/Old.swift")
        XCTAssertEqual(files[0].id, "Sources/Old.swift->Sources/New.swift")
    }
}
