import XCTest
@testable import PiAgentNativeCore

final class DefaultKeymapTests: XCTestCase {
    func testDefaultKeymapHasExpectedDisplayLabels() {
        let labelsByAction = Dictionary(grouping: DefaultKeymap.definitions, by: \.actionID)
            .mapValues { definitions in definitions.map(\.displayLabel) }

        XCTAssertEqual(labelsByAction[.newChat] ?? [], ["Command-N"])
        XCTAssertEqual(labelsByAction[.openProject] ?? [], ["Command-O"])
        XCTAssertEqual(labelsByAction[.focusComposer] ?? [], ["Command-L"])
        XCTAssertEqual(labelsByAction[.refreshState] ?? [], ["Command-R"])
        XCTAssertEqual(labelsByAction[.openSettings] ?? [], ["Command-,"])
        XCTAssertEqual(labelsByAction[.openProcessLog] ?? [], ["Command-Shift-L"])
        XCTAssertEqual(labelsByAction[.openKeybindingHelp] ?? [], ["Command-/"])
        XCTAssertEqual(labelsByAction[.toggleSidebar] ?? [], ["Command-Option-S"])
        XCTAssertEqual(labelsByAction[.toggleInspector] ?? [], ["Command-Option-I"])
        XCTAssertEqual(labelsByAction[.sendPrompt] ?? [], ["Command-Return", "Return"])
        XCTAssertEqual(labelsByAction[.insertComposerNewline] ?? [], ["Shift-Return"])
        XCTAssertEqual(labelsByAction[.cycleThinkingLevel] ?? [], ["Shift-Tab"])
        XCTAssertEqual(labelsByAction[.stopGeneration] ?? [], ["Escape"])
        XCTAssertEqual(labelsByAction[.closeActiveModal] ?? [], ["Escape"])
    }

    func testDefaultKeymapHasNoUnexpectedConflicts() {
        XCTAssertTrue(DefaultKeymap.conflicts().isEmpty)
    }

    func testDefaultKeymapDoesNotContainRemovedProvisionalBindings() {
        let labels = Set(DefaultKeymap.definitions.map(\.displayLabel))

        XCTAssertFalse(labels.contains("Command-Shift-N"))
        XCTAssertFalse(labels.contains("Command-Shift-R"))
    }

    func testEveryHelpGroupHasVisibleKeybindings() {
        for group in KeybindingHelpGroup.allCases {
            XCTAssertFalse(DefaultKeymap.definitions(in: group).isEmpty, "\(group.rawValue) should be visible in Keybinding Help")
        }
    }

    @MainActor
    func testActionAvailabilityForSendPromptAndEscapePriority() {
        let model = AppModel()

        XCTAssertFalse(model.canPerformAppAction(.sendPrompt))
        XCTAssertFalse(model.canPerformAppAction(.closeActiveModal))

        model.projects = [ProjectItem(name: "Repo", path: "/tmp/repo")]
        model.selectedProjectID = model.projects[0].id
        model.workspacePath = model.projects[0].path
        model.composerText = "Build the keymap"

        XCTAssertTrue(model.canPerformAppAction(.sendPrompt))

        model.isStreaming = true
        XCTAssertFalse(model.canPerformAppAction(.sendPrompt))
        XCTAssertTrue(model.canPerformAppAction(.stopGeneration))

        model.isShowingSettings = true
        XCTAssertTrue(model.canPerformAppAction(.closeActiveModal))
        XCTAssertTrue(model.handleEscapeKey())
        XCTAssertFalse(model.isShowingSettings)
    }
}
