import XCTest
@testable import PiAgentNativeCore

final class CommandPaletteTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        SessionStore.databaseURLForTesting = temporaryDirectoryURL().appendingPathComponent("sessions.sqlite")
    }

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

    @MainActor
    func testOpenCommandPaletteUsesModalRulesAndPreservesComposerText() {
        let model = AppModel()
        model.composerText = "/skill:diagnose "

        model.performAppAction(.openCommandPalette)

        XCTAssertTrue(model.isShowingCommandPalette)
        XCTAssertEqual(model.composerText, "/skill:diagnose ")
        XCTAssertEqual(model.commandPaletteHighlightedItemID, model.filteredCommandPaletteItems(query: "").first?.id)

        model.closeCommandPalette()
        model.isShowingSettings = true
        model.performAppAction(.openCommandPalette)

        XCTAssertFalse(model.isShowingCommandPalette)
        XCTAssertTrue(model.isShowingSettings)
    }

    @MainActor
    func testStaticItemsExposeKeybindingsAndFilterDeterministically() {
        let model = AppModel()

        let emptyQueryItems = model.filteredCommandPaletteItems(query: "")
        XCTAssertFalse(emptyQueryItems.contains { $0.invocation == .appAction(.openCommandPalette) })
        XCTAssertEqual(
            emptyQueryItems.first { $0.invocation == .appAction(.newChat) }?.keybindingLabel,
            "Command-N"
        )

        let logItems = model.filteredCommandPaletteItems(query: "log")
        XCTAssertEqual(logItems.first?.invocation, .appAction(.openProcessLog))
    }

    @MainActor
    func testDisabledStaticItemDoesNotRunOrClosePalette() {
        let model = AppModel()
        model.showCommandPalette()
        let sendItem = model.commandPaletteItems().first { $0.invocation == .appAction(.sendPrompt) }!

        model.runCommandPaletteItem(sendItem)

        XCTAssertTrue(model.isShowingCommandPalette)
        XCTAssertEqual(model.statusText, "Open a project first")
        XCTAssertNil(model.selectedSessionID)
    }

    @MainActor
    func testStaticAppActionClosesPaletteBeforeDispatch() {
        let model = AppModel()
        model.showCommandPalette()
        let settingsItem = model.commandPaletteItems().first { $0.invocation == .appAction(.openSettings) }!

        model.runCommandPaletteItem(settingsItem)

        XCTAssertFalse(model.isShowingCommandPalette)
        XCTAssertTrue(model.isShowingSettings)
    }

    @MainActor
    func testProjectAndSessionItemsDispatchThroughAppModelStatePaths() {
        let model = AppModel()
        let project = ProjectItem(id: "project-a", name: "Repo", path: "/tmp/repo")
        let session = StoredSession(
            id: "session-a",
            piSessionID: "pi-session-a",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: "Fix auth",
            status: "Ready",
            sessionFile: "/tmp/session-a.json",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        model.projects = [project]
        model.sessions = [session]

        model.showCommandPalette()
        let projectItem = model.commandPaletteItems().first { $0.invocation == .selectProject(project.id) }!
        model.runCommandPaletteItem(projectItem)
        XCTAssertEqual(model.selectedProjectID, project.id)

        model.showCommandPalette()
        let sessionItem = model.commandPaletteItems().first { $0.invocation == .switchSession(session.id) }!
        model.runCommandPaletteItem(sessionItem)
        XCTAssertEqual(model.selectedSessionID, session.id)
        XCTAssertFalse(model.isShowingCommandPalette)
    }

    @MainActor
    func testSessionItemsUseSidebarOrdering() {
        let model = AppModel()
        let project = ProjectItem(id: "project-a", name: "Repo", path: "/tmp/repo")
        let older = StoredSession(
            id: "older",
            piSessionID: "pi-older",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: "Older",
            status: "Ready",
            sessionFile: "/tmp/older.json",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = StoredSession(
            id: "newer",
            piSessionID: "pi-newer",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: "Newer",
            status: "Ready",
            sessionFile: "/tmp/newer.json",
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.sessions = [older, newer]

        let sessionInvocations = model.commandPaletteItems().compactMap { item -> CommandPaletteInvocation? in
            guard case .switchSession = item.invocation else { return nil }
            return item.invocation
        }

        XCTAssertEqual(sessionInvocations, [.switchSession(newer.id), .switchSession(older.id)])
    }

    @MainActor
    func testParameterizedItemsResolveCurrentStateAtDispatchTime() {
        let model = AppModel()
        let project = ProjectItem(id: "project-a", name: "Repo", path: "/tmp/repo")
        model.projects = [project]
        let projectItem = model.commandPaletteItems().first { $0.invocation == .selectProject(project.id) }!

        model.showCommandPalette()
        model.projects = []
        model.runCommandPaletteItem(projectItem)

        XCTAssertTrue(model.isShowingCommandPalette)
        XCTAssertNil(model.selectedProjectID)
        XCTAssertEqual(model.statusText, "Project is no longer available")
    }

    @MainActor
    func testModelThinkingAndExternalItemsUseSharedDispatchPaths() {
        let model = AppModel()
        let project = ProjectItem(id: "project-a", name: "Repo", path: "/tmp/repo")
        let target = AvailableExternalTarget(
            definition: ExternalTargetCatalog.definitions.first { $0.id == .finder }!,
            launchReference: .baselineMacTarget
        )
        var openedTargetID: ExternalTargetID?
        var openedProjectPath: String?
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.availableModels = [
            PiModel(provider: "openai", modelId: "gpt-test", name: "GPT Test")
        ]
        model.availableExternalTargets = [target]
        model.externalTargetLauncher = { target, projectPath, completion in
            openedTargetID = target.id
            openedProjectPath = projectPath
            completion(.success(()))
        }

        XCTAssertTrue(model.commandPaletteItems().contains {
            $0.invocation == .selectModel(provider: "openai", modelID: "gpt-test")
        })

        model.showCommandPalette()
        let thinkingItem = model.commandPaletteItems().first { $0.invocation == .setThinkingLevel("high") }!
        model.runCommandPaletteItem(thinkingItem)
        XCTAssertFalse(model.isShowingCommandPalette)
        XCTAssertTrue(model.eventLog.contains { $0.title == "send failed" })

        model.showCommandPalette()
        let externalItem = model.commandPaletteItems().first { $0.invocation == .openExternalTarget(.finder) }!
        model.runCommandPaletteItem(externalItem)

        XCTAssertEqual(openedTargetID, .finder)
        XCTAssertEqual(openedProjectPath, project.path)
    }

    private func temporaryDirectoryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommandPaletteTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }
}
