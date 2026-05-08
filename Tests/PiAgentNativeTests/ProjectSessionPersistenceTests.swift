import Foundation
import XCTest
@testable import PiAgentNativeCore

final class ProjectSessionPersistenceTests: XCTestCase {
    private var temporaryURLs: [URL] = []
    private var originalCustomExecutablePath: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalCustomExecutablePath = UserDefaults.standard.string(forKey: "customExecutablePath")
    }

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil
        if let originalCustomExecutablePath {
            UserDefaults.standard.set(originalCustomExecutablePath, forKey: "customExecutablePath")
        } else {
            UserDefaults.standard.removeObject(forKey: "customExecutablePath")
        }
        originalCustomExecutablePath = nil

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

    func testProjectAvailabilityReportsExistingDirectoryAsAvailable() throws {
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)

        XCTAssertEqual(project.availability, .available)
        XCTAssertTrue(project.isAvailable)
    }

    func testProjectAvailabilityReportsMissingOrNonDirectoryPathAsStale() throws {
        let root = temporaryDirectoryURL()
        let missingProject = ProjectItem(id: "missing", name: "Missing", path: root.appendingPathComponent("Missing").path)
        let fileURL = root.appendingPathComponent("README.md")
        try Data("not a directory".utf8).write(to: fileURL)
        let fileProject = ProjectItem(id: "file", name: "File", path: fileURL.path)

        XCTAssertEqual(missingProject.availability, .stale)
        XCTAssertFalse(missingProject.isAvailable)
        XCTAssertEqual(fileProject.availability, .stale)
        XCTAssertFalse(fileProject.isAvailable)
    }

    @MainActor
    func testAppModelRestoresProjectSessionAndSelectedContextAcrossSaveLoadBoundary() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        let session = storedSession(id: "session-1", project: project)

        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: session.id
        ))

        let model = AppModel()

        XCTAssertEqual(model.projects, [project])
        XCTAssertEqual(model.sessions, [session])
        XCTAssertEqual(model.selectedProjectID, project.id)
        XCTAssertEqual(model.selectedSessionID, session.id)
        XCTAssertEqual(model.workspacePath, project.path)
        XCTAssertEqual(model.workspaceStore.selectedProject, project)
        XCTAssertEqual(model.sessionIndexStore.selectedSession, session)
    }

    @MainActor
    func testAppModelPersistsSelectedContextUsingProjectAndSessionIDs() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let project = ProjectItem(id: "project-id-not-path", name: "Repo", path: projectDirectory.path)
        let session = storedSession(id: "local-session-id", project: project)
        SessionStore.save(AppPersistedState(projects: [project], sessions: [session]))
        let model = AppModel()

        model.switchSession(session)

        let persistedState = SessionStore.load()
        XCTAssertEqual(persistedState.selectedProjectID, project.id)
        XCTAssertNotEqual(persistedState.selectedProjectID, project.path)
        XCTAssertEqual(persistedState.selectedSessionID, session.id)
        XCTAssertEqual(model.selectedProjectID, project.id)
        XCTAssertEqual(model.selectedSessionID, session.id)
    }

    @MainActor
    func testSwitchingSessionSelectsOwningProjectByIDBeforePathFallback() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let currentDirectory = temporaryDirectoryURL().appendingPathComponent("CurrentRepo", isDirectory: true)
        try FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        let stalePath = temporaryDirectoryURL().appendingPathComponent("OldRepo").path
        let project = ProjectItem(id: "project-id", name: "CurrentRepo", path: currentDirectory.path)
        var session = storedSession(id: "local-session-id", project: project)
        session.projectPath = stalePath
        session.sessionFile = URL(fileURLWithPath: stalePath).appendingPathComponent("session.json").path
        let model = AppModel()
        model.projects = [project]
        model.sessions = [session]

        model.switchSession(session)

        XCTAssertEqual(model.selectedProjectID, project.id)
        XCTAssertEqual(model.workspacePath, project.path)
        XCTAssertEqual(model.selectedSessionID, session.id)
    }

    @MainActor
    func testStaleProjectRemainsInNormalProjectListOnStartup() {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let staleProject = ProjectItem(id: "project-1", name: "Missing", path: temporaryDirectoryURL().appendingPathComponent("Missing").path)
        SessionStore.save(AppPersistedState(projects: [staleProject], selectedProjectID: staleProject.id))

        let model = AppModel()

        XCTAssertEqual(model.projects, [staleProject])
        XCTAssertEqual(model.projects.first?.availability, .stale)
        XCTAssertEqual(model.selectedProjectID, staleProject.id)
    }

    @MainActor
    func testStartupRestoresAvailableAndMissingProjectsWithComputedAvailability() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let availableDirectory = temporaryDirectoryURL().appendingPathComponent("Available", isDirectory: true)
        try FileManager.default.createDirectory(at: availableDirectory, withIntermediateDirectories: true)
        let availableProject = ProjectItem(id: "available", name: "Available", path: availableDirectory.path)
        let staleProject = ProjectItem(
            id: "missing",
            name: "Missing",
            path: temporaryDirectoryURL().appendingPathComponent("Missing").path
        )

        SessionStore.save(AppPersistedState(
            projects: [availableProject, staleProject],
            selectedProjectID: availableProject.id
        ))

        let model = AppModel()

        XCTAssertEqual(model.projects.map(\.id), ["available", "missing"])
        XCTAssertEqual(model.projects.first { $0.id == availableProject.id }?.availability, .available)
        XCTAssertEqual(model.projects.first { $0.id == staleProject.id }?.availability, .stale)
        XCTAssertEqual(model.selectedProjectID, availableProject.id)
        XCTAssertEqual(model.workspacePath, availableProject.path)
    }

    @MainActor
    func testAppModelInitializationWithTemporaryStoreUsesTemporaryDatabase() {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL

        _ = AppModel()

        XCTAssertEqual(SessionStore.storeURL, databaseURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    @MainActor
    func testSessionUpsertStoresPiRPCSessionIDSeparatelyFromNativeSelectedSessionID() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        let piSessionID = "pi-runtime-session"
        let sessionFile = projectDirectory.appendingPathComponent("pi-session.json").path

        try emitRPCResponse(
            on: model,
            command: "get_state",
            data: [
                "sessionId": piSessionID,
                "sessionFile": sessionFile,
                "sessionName": "Runtime Session"
            ]
        )

        let session = try XCTUnwrap(model.selectedSession)
        XCTAssertNotEqual(session.id, piSessionID)
        XCTAssertEqual(session.piSessionID, piSessionID)
        XCTAssertEqual(model.selectedSessionID, session.id)

        let persistedState = SessionStore.load()
        XCTAssertEqual(persistedState.sessions.map(\.id), [session.id])
        XCTAssertEqual(persistedState.sessions.map(\.piSessionID), [piSessionID])
        XCTAssertEqual(persistedState.selectedSessionID, session.id)
        XCTAssertNotEqual(persistedState.selectedSessionID, piSessionID)
    }

    @MainActor
    func testRemovingProjectRemovesItFromWorkspaceAndClearsSelectedProject() {
        let selectedProject = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let otherProject = ProjectItem(id: "project-2", name: "Other", path: "/tmp/other")
        let store = WorkspaceStore(projects: [selectedProject, otherProject], selectedProjectID: selectedProject.id)

        let removedProject = store.removeProject(id: selectedProject.id)

        XCTAssertEqual(removedProject, selectedProject)
        XCTAssertEqual(store.projects, [otherProject])
        XCTAssertNil(store.selectedProjectID)
        XCTAssertEqual(store.workspacePath, "")
        XCTAssertFalse(store.expandedProjectIDs.contains(selectedProject.id))
    }

    @MainActor
    func testRemovingProjectSessionsRemovesAssociatedSessionsAndClearsSelectedSession() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let otherProject = ProjectItem(id: "project-2", name: "Other", path: "/tmp/other")
        let selectedSession = storedSession(id: "session-1", project: project)
        let otherSession = storedSession(id: "session-2", project: otherProject)
        let store = NativeSessionIndexStore(sessions: [selectedSession, otherSession], selectedSessionID: selectedSession.id)

        let removedSessions = store.removeSessions(forProjectID: project.id)

        XCTAssertEqual(removedSessions, [selectedSession])
        XCTAssertEqual(store.sessions, [otherSession])
        XCTAssertNil(store.selectedSessionID)
    }

    @MainActor
    func testRemovingSelectedStaleProjectClearsSelectedProjectAndSession() {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let staleProject = ProjectItem(id: "project-1", name: "Missing", path: temporaryDirectoryURL().appendingPathComponent("Missing").path)
        let session = storedSession(id: "session-1", project: staleProject)
        SessionStore.save(AppPersistedState(
            projects: [staleProject],
            sessions: [session],
            selectedProjectID: staleProject.id,
            selectedSessionID: session.id
        ))
        let model = AppModel()

        model.removeStaleProject(staleProject)

        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertNil(model.selectedProjectID)
        XCTAssertNil(model.selectedSessionID)
        XCTAssertEqual(model.workspacePath, "")
        XCTAssertEqual(model.statusText, "Open a project")

        let persistedState = SessionStore.load()
        XCTAssertTrue(persistedState.projects.isEmpty)
        XCTAssertTrue(persistedState.sessions.isEmpty)
        XCTAssertNil(persistedState.selectedProjectID)
        XCTAssertNil(persistedState.selectedSessionID)
    }

    @MainActor
    func testRemovingSelectedStaleProjectStopsRunningRPCProcess() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let root = temporaryDirectoryURL()
        let projectDirectory = root.appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let executableURL = root.appendingPathComponent("fake-pi-rpc.sh")
        try Data("""
        #!/bin/sh
        trap 'exit 0' TERM
        while true; do
          sleep 1
        done
        """.utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [],
            selectedProjectID: project.id,
            selectedSessionID: nil
        ))
        let model = AppModel()
        model.customExecutablePath = executableURL.path

        model.start()
        let client = try rpcClient(from: model)
        XCTAssertTrue(model.isConnected)
        XCTAssertTrue(client.isRunning)

        try FileManager.default.removeItem(at: projectDirectory)
        XCTAssertEqual(project.availability, .stale)

        model.removeStaleProject(project)

        XCTAssertFalse(model.isConnected)
        XCTAssertFalse(model.isStreaming)
        XCTAssertFalse(client.isRunning)
        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertNil(model.selectedProjectID)
        XCTAssertEqual(model.workspacePath, "")
        XCTAssertEqual(model.statusText, "Open a project")
    }

    @MainActor
    func testRemovingLocalProjectRecordDoesNotDeleteProjectDirectoryOrFilesAndPersistsRemoval() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let fileURL = projectDirectory.appendingPathComponent("README.md")
        try Data("keep me".utf8).write(to: fileURL)
        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        let session = storedSession(id: "session-1", project: project)
        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: session.id
        ))
        let model = AppModel()

        model.removeLocalProjectRecord(project)

        XCTAssertTrue(FileManager.default.fileExists(atPath: projectDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertTrue(model.sessions.isEmpty)

        let persistedState = SessionStore.load()
        XCTAssertTrue(persistedState.projects.isEmpty)
        XCTAssertTrue(persistedState.sessions.isEmpty)
        XCTAssertNil(persistedState.selectedProjectID)
        XCTAssertNil(persistedState.selectedSessionID)
    }

    @MainActor
    func testRemovingStaleProjectRemovesLocalRecordsAndDoesNotDeleteExistingTemporaryFiles() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let root = temporaryDirectoryURL()
        let projectDirectory = root.appendingPathComponent("Repo", isDirectory: true)
        let siblingDirectory = root.appendingPathComponent("Sibling", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingDirectory, withIntermediateDirectories: true)
        let siblingFileURL = siblingDirectory.appendingPathComponent("keep.txt")
        try Data("keep sibling".utf8).write(to: siblingFileURL)
        let project = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        let session = storedSession(id: "session-1", project: project)
        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: session.id
        ))
        try FileManager.default.removeItem(at: projectDirectory)
        XCTAssertEqual(project.availability, .stale)
        let model = AppModel()

        model.removeStaleProject(project)

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: siblingDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: siblingFileURL.path))
        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertTrue(model.sessions.isEmpty)

        let persistedState = SessionStore.load()
        XCTAssertTrue(persistedState.projects.isEmpty)
        XCTAssertTrue(persistedState.sessions.isEmpty)
        XCTAssertNil(persistedState.selectedProjectID)
        XCTAssertNil(persistedState.selectedSessionID)
    }

    private func temporaryDatabaseURL() -> URL {
        temporaryDirectoryURL().appendingPathComponent("sessions.sqlite")
    }

    private func temporaryDirectoryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectSessionPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    private func storedSession(id: String, project: ProjectItem) -> StoredSession {
        StoredSession(
            id: id,
            piSessionID: "pi-\(id)",
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: id,
            status: "Ready",
            sessionFile: URL(fileURLWithPath: project.path).appendingPathComponent("\(id).json").path,
            updatedAt: Date(timeIntervalSince1970: 1_763_000_000)
        )
    }

    @MainActor
    private func emitRPCResponse(on model: AppModel, command: String, data: [String: Any]) throws {
        let client = try rpcClient(from: model)
        let response = PiRPCResponse(payload: [
            "type": "response",
            "id": UUID().uuidString,
            "command": command,
            "success": true,
            "data": data
        ])

        try XCTUnwrap(client.onEvent)(.response(response))
    }

    @MainActor
    private func rpcClient(from model: AppModel) throws -> PiRPCClient {
        for child in Mirror(reflecting: model).children where child.label == "client" {
            return try XCTUnwrap(child.value as? PiRPCClient)
        }

        XCTFail("Expected AppModel to own a PiRPCClient")
        throw NSError(domain: "ProjectSessionPersistenceTests", code: 1)
    }
}
