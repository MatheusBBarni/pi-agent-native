import XCTest
@testable import PiAgentNativeCore

@MainActor
final class HeaderActionTests: XCTestCase {
    func testSidebarToggleUsesCentralAppActionAndModalBlocking() {
        let model = AppModel()

        XCTAssertTrue(model.isSidebarVisible)
        XCTAssertTrue(model.canPerformAppAction(.toggleSidebar))

        model.performAppAction(.toggleSidebar)
        XCTAssertFalse(model.isSidebarVisible)

        model.isShowingSettings = true
        XCTAssertFalse(model.canPerformAppAction(.toggleSidebar))

        model.performAppAction(.toggleSidebar)
        XCTAssertFalse(model.isSidebarVisible)
    }

    func testPreviousAndNextSessionUseRenderedProjectSessionOrder() {
        let fixture = makeSessionNavigationFixture(selectedSessionID: "middle")
        let model = fixture.model

        XCTAssertEqual(model.sessionsForProject(fixture.project).map(\.id), ["newest", "middle", "oldest"])
        XCTAssertTrue(model.canNavigateToPreviousSession())
        XCTAssertTrue(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Previous session")
        XCTAssertEqual(model.nextSessionHelpText(), "Next session")

        model.navigateToPreviousSession()
        XCTAssertEqual(model.selectedSessionID, "newest")
        XCTAssertEqual(model.sessionTitle, "Newest")
        XCTAssertEqual(model.selectedProjectID, fixture.project.id)

        model.sessions = fixture.sessions
        model.selectedSessionID = "middle"
        model.sessionTitle = "Middle"

        model.navigateToNextSession()
        XCTAssertEqual(model.selectedSessionID, "oldest")
        XCTAssertEqual(model.sessionTitle, "Oldest")
        XCTAssertEqual(model.selectedProjectID, fixture.project.id)
    }

    func testPreviousAndNextSessionDisableAtBoundariesAndUnavailableStates() {
        let fixture = makeSessionNavigationFixture(selectedSessionID: "newest")
        let model = fixture.model

        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertTrue(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "No previous session")
        model.navigateToPreviousSession()
        XCTAssertEqual(model.selectedSessionID, "newest")

        model.selectedSessionID = "oldest"
        XCTAssertTrue(model.canNavigateToPreviousSession())
        XCTAssertFalse(model.canNavigateToNextSession())
        XCTAssertEqual(model.nextSessionHelpText(), "No next session")
        model.navigateToNextSession()
        XCTAssertEqual(model.selectedSessionID, "oldest")

        model.selectedSessionID = nil
        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertFalse(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Select a session first")
        XCTAssertEqual(model.nextSessionHelpText(), "Select a session first")

        model.selectedSessionID = "middle"
        model.sessions = [fixture.sessions[1]]
        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertFalse(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "No other sessions")
        XCTAssertEqual(model.nextSessionHelpText(), "No other sessions")

        model.sessions = fixture.sessions
        model.isShowingSettings = true
        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertFalse(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Close active modal first")
        XCTAssertEqual(model.nextSessionHelpText(), "Close active modal first")

        model.navigateToPreviousSession()
        XCTAssertEqual(model.selectedSessionID, "middle")
    }

    func testPreviousAndNextSessionDoNotIntroduceDefaultKeymapActions() {
        let actionIDs = Set(AppActionID.allCases.map(\.rawValue))

        XCTAssertFalse(actionIDs.contains("previousSession"))
        XCTAssertFalse(actionIDs.contains("nextSession"))
    }

    private func makeSessionNavigationFixture(
        selectedSessionID: StoredSession.ID
    ) -> (model: AppModel, project: ProjectItem, sessions: [StoredSession]) {
        let project = ProjectItem(id: "project", name: "Repo", path: "/tmp/repo")
        let otherProject = ProjectItem(id: "other-project", name: "Other", path: "/tmp/other")
        let sessions = [
            StoredSession(
                id: "oldest",
                projectPath: project.path,
                projectName: project.name,
                title: "Oldest",
                status: "Ready",
                sessionFile: "/tmp/repo/oldest.json",
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            StoredSession(
                id: "middle",
                projectPath: project.path,
                projectName: project.name,
                title: "Middle",
                status: "Ready",
                sessionFile: "/tmp/repo/middle.json",
                updatedAt: Date(timeIntervalSince1970: 2)
            ),
            StoredSession(
                id: "newest",
                projectPath: project.path,
                projectName: project.name,
                title: "Newest",
                status: "Ready",
                sessionFile: "/tmp/repo/newest.json",
                updatedAt: Date(timeIntervalSince1970: 3)
            ),
            StoredSession(
                id: "other-project-newest",
                projectPath: otherProject.path,
                projectName: otherProject.name,
                title: "Other Project Newest",
                status: "Ready",
                sessionFile: "/tmp/other/newest.json",
                updatedAt: Date(timeIntervalSince1970: 4)
            )
        ]
        let model = AppModel()
        model.projects = [project, otherProject]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.sessions = sessions
        model.selectedSessionID = selectedSessionID
        model.sessionTitle = sessions.first { $0.id == selectedSessionID }?.title ?? "New chat"
        model.statusText = "Ready"
        model.isConnected = true

        return (model, project, sessions)
    }
}
