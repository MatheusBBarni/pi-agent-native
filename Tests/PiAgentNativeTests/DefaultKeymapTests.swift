import AppKit
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

    func testSidebarHelpUsesSidebarLabelsWithRegistryKeybindings() {
        XCTAssertEqual(DefaultKeymap.helpText(for: .newChat, title: "New chat"), "New chat - Command-N")
        XCTAssertEqual(DefaultKeymap.helpText(for: .openProject, title: "Open project"), "Open project - Command-O")
        XCTAssertEqual(DefaultKeymap.helpText(for: .openProcessLog, title: "Process log"), "Process log - Command-Shift-L")
        XCTAssertEqual(DefaultKeymap.helpText(for: .openKeybindingHelp, title: "Help"), "Help - Command-/")
        XCTAssertEqual(DefaultKeymap.helpText(for: .openSettings, title: "Settings"), "Settings - Command-,")
    }

    func testFocusedComposerKeybindingsMatchThroughRegistry() {
        let returnEvent = keyEvent(keyCode: 36, charactersIgnoringModifiers: "\r")
        let commandReturnEvent = keyEvent(keyCode: 36, charactersIgnoringModifiers: "\r", modifiers: .command)
        let shiftReturnEvent = keyEvent(keyCode: 36, charactersIgnoringModifiers: "\r", modifiers: .shift)
        let shiftTabEvent = keyEvent(keyCode: 48, charactersIgnoringModifiers: "\t", modifiers: .shift)

        XCTAssertTrue(DefaultKeymap.definitions(for: .sendPrompt).contains { $0.matches(returnEvent) })
        XCTAssertTrue(DefaultKeymap.definitions(for: .sendPrompt).contains { $0.matches(commandReturnEvent) })
        XCTAssertFalse(DefaultKeymap.definitions(for: .sendPrompt).contains { $0.matches(shiftReturnEvent) })
        XCTAssertTrue(DefaultKeymap.firstDefinition(for: .insertComposerNewline)?.matches(shiftReturnEvent) == true)
        XCTAssertTrue(DefaultKeymap.firstDefinition(for: .cycleThinkingLevel)?.matches(shiftTabEvent) == true)
    }

    func testEveryAppActionAppearsInDefaultKeymap() {
        let mappedActions = Set(DefaultKeymap.definitions.map(\.actionID))

        XCTAssertEqual(mappedActions, Set(AppActionID.allCases))
    }

    func testGeneratedHelpTextUsesRegistryBindingLabels() {
        XCTAssertEqual(DefaultKeymap.helpText(for: .newChat), "New chat - Command-N")
        XCTAssertEqual(DefaultKeymap.helpText(for: .openKeybindingHelp, title: "Help"), "Help - Command-/")
        XCTAssertEqual(DefaultKeymap.title(for: .toggleInspector), "Toggle inspector")
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
        XCTAssertFalse(model.canPerformAppAction(.newChat))
        XCTAssertFalse(model.canPerformAppAction(.toggleSidebar))
        XCTAssertTrue(model.canPerformAppAction(.closeActiveModal))
        XCTAssertTrue(model.handleEscapeKey())
        XCTAssertFalse(model.isShowingSettings)
        XCTAssertTrue(model.isStreaming)
    }

    @MainActor
    func testActiveModalBlocksNonModalAppActions() {
        let model = AppModel()
        model.projects = [ProjectItem(name: "Repo", path: "/tmp/repo")]
        model.selectedProjectID = model.projects[0].id
        model.workspacePath = model.projects[0].path
        model.messages = [
            ChatMessage(role: .user, title: "You", text: "Keep this conversation")
        ]

        model.isShowingKeybindingHelp = true
        model.performAppAction(.newChat)
        model.performAppAction(.toggleInspector)

        XCTAssertTrue(model.isShowingKeybindingHelp)
        XCTAssertEqual(model.messages.count, 1)
        XCTAssertTrue(model.isInspectorVisible)
    }

    private func keyEvent(
        keyCode: UInt16,
        charactersIgnoringModifiers: String,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: charactersIgnoringModifiers,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}
