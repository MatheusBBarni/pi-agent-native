import AppKit
import XCTest
@testable import PiAgentNativeCore

final class MentionPickerCommandTests: XCTestCase {
    func testArrowAndKeypadEventsIgnoreNonTextAppKitFlags() {
        XCTAssertEqual(command(keyCode: 126, flags: [.function]), .moveUp)
        XCTAssertEqual(command(keyCode: 125, flags: [.function]), .moveDown)
        XCTAssertEqual(command(keyCode: 76, flags: [.numericPad]), .insertHighlighted)
    }

    func testTextNavigationModifiersFallThrough() {
        XCTAssertNil(command(keyCode: 126, flags: [.option]))
        XCTAssertNil(command(keyCode: 125, flags: [.command]))
        XCTAssertNil(command(keyCode: 48, flags: [.shift]))
    }

    private func command(keyCode: UInt16, flags: NSEvent.ModifierFlags = []) -> MentionPickerCommand? {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
        return event.flatMap(MentionPickerCommand.init(event:))
    }
}
