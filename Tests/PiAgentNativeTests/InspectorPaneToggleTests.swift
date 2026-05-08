import Foundation
import XCTest
@testable import PiAgentNativeCore

final class InspectorPaneToggleTests: XCTestCase {
    func testInspectorTogglePresentationDescribesNextActionAndVisibleState() {
        let visible = InspectorToggleButtonPresentation(isInspectorVisible: true, isEnabled: true, language: .english)
        let hidden = InspectorToggleButtonPresentation(isInspectorVisible: false, isEnabled: true, language: .english)

        XCTAssertEqual(visible.iconSystemName, "sidebar.right")
        XCTAssertEqual(visible.helpText, "Toggle inspector - Command-Shift-B")
        XCTAssertEqual(visible.accessibilityLabel, "Hide inspector")
        XCTAssertEqual(visible.accessibilityValue, "Inspector visible")
        XCTAssertEqual(visible.accessibilityHint, "Toggles the inspector pane")
        XCTAssertFalse(visible.isHighlighted)

        XCTAssertEqual(hidden.iconSystemName, "sidebar.right")
        XCTAssertEqual(hidden.helpText, "Toggle inspector - Command-Shift-B")
        XCTAssertEqual(hidden.accessibilityLabel, "Show inspector")
        XCTAssertEqual(hidden.accessibilityValue, "Inspector hidden")
        XCTAssertEqual(hidden.accessibilityHint, "Toggles the inspector pane")
        XCTAssertTrue(hidden.isHighlighted)
    }

    func testInspectorTogglePresentationLocalizesChromeWithoutChangingStateSignal() {
        let visible = InspectorToggleButtonPresentation(isInspectorVisible: true, isEnabled: true, language: .portugueseBrazil)
        let hidden = InspectorToggleButtonPresentation(isInspectorVisible: false, isEnabled: true, language: .portugueseBrazil)

        XCTAssertEqual(visible.iconSystemName, "sidebar.right")
        XCTAssertEqual(visible.helpText, "Alternar inspetor - Command-Shift-B")
        XCTAssertEqual(visible.accessibilityLabel, "Ocultar inspetor")
        XCTAssertEqual(visible.accessibilityValue, "Inspetor visível")
        XCTAssertEqual(visible.accessibilityHint, "Alterna o painel do inspetor")
        XCTAssertFalse(visible.isHighlighted)

        XCTAssertEqual(hidden.iconSystemName, "sidebar.right")
        XCTAssertEqual(hidden.helpText, "Alternar inspetor - Command-Shift-B")
        XCTAssertEqual(hidden.accessibilityLabel, "Mostrar inspetor")
        XCTAssertEqual(hidden.accessibilityValue, "Inspetor oculto")
        XCTAssertEqual(hidden.accessibilityHint, "Alterna o painel do inspetor")
        XCTAssertTrue(hidden.isHighlighted)
    }

    @MainActor
    func testToggleInspectorAppActionFlipsRuntimeState() {
        let model = AppModel()

        XCTAssertTrue(model.isInspectorVisible)

        model.performAppAction(.toggleInspector)
        XCTAssertFalse(model.isInspectorVisible)

        model.performAppAction(.toggleInspector)
        XCTAssertTrue(model.isInspectorVisible)
    }

    @MainActor
    func testActiveModalBlocksInspectorToggleThroughCentralAvailability() {
        let model = AppModel()
        model.isInspectorVisible = false
        model.isShowingSettings = true

        XCTAssertFalse(model.canPerformAppAction(.toggleInspector))

        model.performAppAction(.toggleInspector)
        XCTAssertFalse(model.isInspectorVisible)
    }

    @MainActor
    func testInspectorTogglePreservesUnrelatedShellAndConversationState() {
        let fixedDate = Date(timeIntervalSince1970: 1_763_000_000)
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let session = StoredSession(
            id: "session-1",
            piSessionID: "pi-session-1",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: "Build UI",
            status: "Ready",
            sessionFile: "/tmp/session.json",
            updatedAt: fixedDate
        )
        let messages = [
            ChatMessage(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                role: .user,
                title: "You",
                text: "Keep this conversation",
                timestamp: fixedDate
            )
        ]
        let tools = [
            ToolActivity(
                id: "tool-1",
                name: "read",
                summary: "Read file",
                output: "Output",
                isRunning: true,
                isError: false
            )
        ]
        let eventLog = [EventLog(title: "status", detail: "unchanged", timestamp: fixedDate)]

        let model = AppModel()
        model.projects = [project]
        model.sessions = [session]
        model.selectedProjectID = project.id
        model.selectedSessionID = session.id
        model.workspacePath = project.path
        model.sessionTitle = session.title
        model.composerText = "Draft prompt"
        model.statusText = "Running"
        model.isConnected = true
        model.isStreaming = true
        model.pendingMessageCount = 2
        model.modelName = "provider/model"
        model.thinkingLevel = "high"
        model.isSidebarVisible = false
        model.messages = messages
        model.tools = tools
        model.eventLog = eventLog

        model.performAppAction(.toggleInspector)

        XCTAssertFalse(model.isInspectorVisible)
        XCTAssertEqual(model.projects, [project])
        XCTAssertEqual(model.sessions, [session])
        XCTAssertEqual(model.selectedProjectID, project.id)
        XCTAssertEqual(model.selectedSessionID, session.id)
        XCTAssertEqual(model.workspacePath, project.path)
        XCTAssertEqual(model.sessionTitle, session.title)
        XCTAssertEqual(model.composerText, "Draft prompt")
        XCTAssertEqual(model.statusText, "Running")
        XCTAssertTrue(model.isConnected)
        XCTAssertTrue(model.isStreaming)
        XCTAssertEqual(model.pendingMessageCount, 2)
        XCTAssertEqual(model.modelName, "provider/model")
        XCTAssertEqual(model.thinkingLevel, "high")
        XCTAssertFalse(model.isSidebarVisible)
        XCTAssertEqual(model.messages, messages)
        XCTAssertEqual(model.tools, tools)
        XCTAssertEqual(model.eventLog, eventLog)
    }

    @MainActor
    func testInspectorVisibilityIsIndependentOfProjectAndSessionSelectionState() {
        let projectA = ProjectItem(id: "project-a", name: "A", path: "/tmp/a")
        let projectB = ProjectItem(id: "project-b", name: "B", path: "/tmp/b")
        let sessionA = StoredSession(
            id: "session-a",
            piSessionID: "pi-session-a",
            projectID: projectA.id,
            projectPath: projectA.path,
            projectName: projectA.name,
            title: "A session",
            status: "Ready",
            sessionFile: "/tmp/a.json",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let sessionB = StoredSession(
            id: "session-b",
            piSessionID: "pi-session-b",
            projectID: projectB.id,
            projectPath: projectB.path,
            projectName: projectB.name,
            title: "B session",
            status: "Ready",
            sessionFile: "/tmp/b.json",
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let model = AppModel()
        model.projects = [projectA, projectB]
        model.sessions = [sessionA, sessionB]
        model.selectedProjectID = projectA.id
        model.selectedSessionID = sessionA.id
        model.workspacePath = projectA.path
        model.isInspectorVisible = false

        model.selectedProjectID = projectB.id
        model.workspacePath = projectB.path
        model.selectedSessionID = sessionB.id

        XCTAssertFalse(model.isInspectorVisible)
    }

    func testPersistedSessionStateDoesNotIncludeInspectorVisibility() throws {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let session = StoredSession(
            id: "session-1",
            piSessionID: "pi-session-1",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: "Build UI",
            status: "Ready",
            sessionFile: "/tmp/session.json",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_000)
        )
        let state = AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: session.id
        )

        let data = try JSONEncoder().encode(state)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(object.keys), Set(["projects", "sessions", "selectedProjectID", "selectedSessionID"]))
        XCTAssertNil(object["isInspectorVisible"])
    }
}
