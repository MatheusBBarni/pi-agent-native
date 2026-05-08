import XCTest
@testable import PiAgentNativeCore

@MainActor
final class HeaderActionTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        SessionStore.databaseURLForTesting = temporaryDatabaseURL()
    }

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

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
        model.appLanguage = .english

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
        model.appLanguage = .english

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

    func testPreviousAndNextSessionHelpTextLocalizesWithoutChangingNavigationBehavior() {
        let fixture = makeSessionNavigationFixture(selectedSessionID: "middle")
        let model = fixture.model
        model.appLanguage = .portugueseBrazil

        XCTAssertTrue(model.canNavigateToPreviousSession())
        XCTAssertTrue(model.canNavigateToNextSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Sessão anterior")
        XCTAssertEqual(model.nextSessionHelpText(), "Próxima sessão")

        model.selectedSessionID = "newest"
        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Não há sessão anterior")

        model.selectedSessionID = nil
        XCTAssertFalse(model.canNavigateToNextSession())
        XCTAssertEqual(model.nextSessionHelpText(), "Selecione uma sessão primeiro")

        model.selectedSessionID = "middle"
        model.isShowingSettings = true
        XCTAssertFalse(model.canNavigateToPreviousSession())
        XCTAssertEqual(model.previousSessionHelpText(), "Feche o modal ativo primeiro")
    }

    func testPreviousAndNextSessionDoNotIntroduceDefaultKeymapActions() {
        let actionIDs = Set(AppActionID.allCases.map(\.rawValue))

        XCTAssertFalse(actionIDs.contains("previousSession"))
        XCTAssertFalse(actionIDs.contains("nextSession"))
    }

    func testAvailableProjectSidebarPresentationDoesNotShowStaleOrRemoveState() throws {
        let project = try availableProject(id: "project", name: "Repo")

        let presentation = SidebarProjectRowPresentation(project: project)

        XCTAssertFalse(presentation.isStale)
        XCTAssertNil(presentation.metadataText)
        XCTAssertFalse(presentation.showsRemoveAction)
        XCTAssertEqual(presentation.iconSystemName, "folder")
        XCTAssertEqual(presentation.helpText, project.path)
    }

    func testStaleProjectSidebarPresentationShowsUnavailableStateAndSafeRemoveCopy() {
        let project = staleProject(id: "missing", name: "Missing")

        let presentation = SidebarProjectRowPresentation(project: project)

        XCTAssertTrue(presentation.isStale)
        XCTAssertEqual(presentation.metadataText, "Unavailable")
        XCTAssertTrue(presentation.showsRemoveAction)
        XCTAssertEqual(presentation.iconSystemName, "folder.badge.questionmark")
        XCTAssertEqual(presentation.removeActionTitle, "Remove from app")
        XCTAssertTrue(presentation.removeActionHelp.contains("Files on disk are not deleted"))
    }

    func testSessionSidebarPresentationIncludesMetadataAndResumability() throws {
        let project = try availableProject(id: "project", name: "Repo")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = storedSession(
            id: "session",
            project: project,
            title: "Continue feature",
            status: "Ready",
            updatedAt: now.addingTimeInterval(-300)
        )

        let presentation = SidebarSessionRowPresentation(session: session, project: project, now: now)

        XCTAssertEqual(presentation.title, "Continue feature")
        XCTAssertEqual(presentation.statusText, "Ready")
        XCTAssertEqual(presentation.updatedAtText, "Updated 5m ago")
        XCTAssertEqual(presentation.resumabilityText, "Resumable")
        XCTAssertEqual(presentation.resumabilitySystemImage, "arrow.clockwise.circle")
        XCTAssertTrue(presentation.isEnabled)
    }

    func testNonResumableSessionPresentationIsDistinguishable() throws {
        let project = try availableProject(id: "project", name: "Repo")
        var session = storedSession(id: "session", project: project)
        session.piSessionID = nil

        let presentation = SidebarSessionRowPresentation(
            session: session,
            project: project,
            now: session.updatedAt.addingTimeInterval(30)
        )

        XCTAssertEqual(presentation.resumabilityText, "Not resumable")
        XCTAssertEqual(presentation.resumabilitySystemImage, "exclamationmark.circle")
        XCTAssertTrue(presentation.accessibilityLabel.contains("Not resumable"))
    }

    func testSessionSidebarPresentationFallsBackForBlankTitleAndStatus() throws {
        let project = try availableProject(id: "project", name: "Repo")
        let session = storedSession(
            id: "session",
            project: project,
            title: "   ",
            status: "   "
        )

        let presentation = SidebarSessionRowPresentation(
            session: session,
            project: project,
            now: session.updatedAt.addingTimeInterval(30)
        )

        XCTAssertEqual(presentation.title, "Untitled session")
        XCTAssertEqual(presentation.statusText, "Unknown")
    }

    func testSessionUpdatedAtPresentationUsesDenseRelativeBucketsAndShortDate() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(
            SidebarSessionRowPresentation.updatedAtText(for: now.addingTimeInterval(15), now: now),
            "Updated just now"
        )
        XCTAssertEqual(
            SidebarSessionRowPresentation.updatedAtText(for: now.addingTimeInterval(-7_200), now: now),
            "Updated 2h ago"
        )
        XCTAssertEqual(
            SidebarSessionRowPresentation.updatedAtText(for: now.addingTimeInterval(-172_800), now: now),
            "Updated 2d ago"
        )
        XCTAssertEqual(
            SidebarSessionRowPresentation.updatedAtText(for: Date(timeIntervalSince1970: 0), now: now),
            "Updated 1/1/70"
        )
    }

    func testStaleProjectSessionPresentationIsDisabledForSidebarSwitching() {
        let project = staleProject(id: "missing", name: "Missing")
        let session = storedSession(id: "session", project: project)

        let presentation = SidebarSessionRowPresentation(
            session: session,
            project: project,
            now: session.updatedAt.addingTimeInterval(30)
        )

        XCTAssertFalse(presentation.isEnabled)
        XCTAssertTrue(presentation.helpText.contains("Project unavailable"))
    }

    func testSidebarStaleRemoveActionCallsAppModelRemovalBehavior() {
        let project = staleProject(id: "missing", name: "Missing")
        let session = storedSession(id: "session", project: project)
        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: session.id
        ))
        let model = AppModel()

        model.removeSidebarStaleProject(project)

        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertNil(model.selectedProjectID)
        XCTAssertNil(model.selectedSessionID)
    }

    func testSidebarSessionSwitchForStaleProjectDoesNotRestoreOrStartSession() {
        let project = staleProject(id: "missing", name: "Missing")
        let session = storedSession(id: "session", project: project)
        let model = AppModel()
        model.projects = [project]
        model.sessions = [session]
        model.statusText = "Ready"

        model.switchSidebarSession(session, in: project)

        XCTAssertNil(model.selectedProjectID)
        XCTAssertNil(model.selectedSessionID)
        XCTAssertFalse(model.isConnected)
        XCTAssertEqual(model.sessionTitle, "New chat")
        XCTAssertEqual(model.statusText, "Project unavailable")
    }

    private func makeSessionNavigationFixture(
        selectedSessionID: StoredSession.ID
    ) -> (model: AppModel, project: ProjectItem, sessions: [StoredSession]) {
        let project = ProjectItem(id: "project", name: "Repo", path: "/tmp/repo")
        let otherProject = ProjectItem(id: "other-project", name: "Other", path: "/tmp/other")
        let sessions = [
            StoredSession(
                id: "oldest",
                piSessionID: "pi-oldest",
                projectID: project.id,
                projectPath: project.path,
                projectName: project.name,
                title: "Oldest",
                status: "Ready",
                sessionFile: "/tmp/repo/oldest.json",
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            StoredSession(
                id: "middle",
                piSessionID: "pi-middle",
                projectID: project.id,
                projectPath: project.path,
                projectName: project.name,
                title: "Middle",
                status: "Ready",
                sessionFile: "/tmp/repo/middle.json",
                updatedAt: Date(timeIntervalSince1970: 2)
            ),
            StoredSession(
                id: "newest",
                piSessionID: "pi-newest",
                projectID: project.id,
                projectPath: project.path,
                projectName: project.name,
                title: "Newest",
                status: "Ready",
                sessionFile: "/tmp/repo/newest.json",
                updatedAt: Date(timeIntervalSince1970: 3)
            ),
            StoredSession(
                id: "other-project-newest",
                piSessionID: "pi-other-project-newest",
                projectID: otherProject.id,
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

    private func availableProject(id: ProjectItem.ID, name: String) throws -> ProjectItem {
        let directory = temporaryDirectoryURL().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProjectItem(id: id, name: name, path: directory.path)
    }

    private func staleProject(id: ProjectItem.ID, name: String) -> ProjectItem {
        ProjectItem(id: id, name: name, path: temporaryDirectoryURL().appendingPathComponent(name).path)
    }

    private func storedSession(
        id: StoredSession.ID,
        project: ProjectItem,
        title: String? = nil,
        status: String = "Ready",
        updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> StoredSession {
        StoredSession(
            id: id,
            piSessionID: "pi-\(id)",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: title ?? id,
            status: status,
            sessionFile: URL(fileURLWithPath: project.path).appendingPathComponent("\(id).json").path,
            updatedAt: updatedAt
        )
    }

    private func temporaryDatabaseURL() -> URL {
        temporaryDirectoryURL().appendingPathComponent("sessions.sqlite")
    }

    private func temporaryDirectoryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HeaderActionTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }
}
