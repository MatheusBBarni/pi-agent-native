import Foundation
import XCTest
@testable import PiAgentNativeCore

final class MentionQueryDetectorTests: XCTestCase {
    func testDetectsMentionAtStartWhitespaceAndOpeningDelimiter() {
        XCTAssertEqual(activeSearchText("@pi"), "pi")
        XCTAssertEqual(activeSearchText("Review @pi"), "pi")
        XCTAssertEqual(activeSearchText("Review (@pi"), "pi")
        XCTAssertEqual(activeSearchText("Review [@pi"), "pi")
        XCTAssertEqual(activeSearchText("Review \"@pi"), "pi")
    }

    func testDoesNotDetectEmbeddedEmailLikeMention() {
        XCTAssertNil(activeSearchText("me@example.com"))
        XCTAssertNil(activeSearchText("abc@def"))
    }

    func testQueryEndsAtWhitespace() {
        XCTAssertNil(activeSearchText("Review @path name"))
    }

    func testUsesNearestEligibleQueryBeforeCursor() {
        XCTAssertEqual(activeSearchText("Use @one and @two"), "two")
    }

    func testNonCollapsedSelectionHasNoActiveQuery() {
        let text = "Review @pi"
        let range = NSRange(location: 7, length: 2)
        XCTAssertNil(MentionQueryDetector.activeQuery(in: text, selectedRange: range))
    }

    func testUTF16CursorOffsetDoesNotCorruptQueryRange() {
        let text = "Review 🧪 @PiRPC"
        let query = MentionQueryDetector.activeQuery(in: text, selectedRange: endRange(in: text))
        XCTAssertEqual(query?.searchText, "PiRPC")
        XCTAssertEqual(query.map { String(text[$0.range]) }, "@PiRPC")
    }

    private func activeSearchText(_ text: String) -> String? {
        MentionQueryDetector.activeQuery(in: text, selectedRange: endRange(in: text))?.searchText
    }

    private func endRange(in text: String) -> NSRange {
        NSRange(location: (text as NSString).length, length: 0)
    }
}
