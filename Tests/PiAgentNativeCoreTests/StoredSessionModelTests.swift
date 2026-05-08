import XCTest
@testable import PiAgentNativeCore

final class StoredSessionModelTests: XCTestCase {
    func testChatMessageModelUpdatesMergeAndReplaceContentBlocks() {
        var thinkingMessage = ChatMessage(role: .assistant, text: "", thinking: "Plan")
        thinkingMessage.appendThinking(" more")

        XCTAssertEqual(thinkingMessage.thinking, "Plan more")
        XCTAssertEqual(thinkingMessage.contentBlocks, [.thinking("Plan more")])

        var textMessage = ChatMessage(role: .assistant, text: "Hello")
        textMessage.appendText(" world")
        textMessage.replaceText("Done")

        XCTAssertEqual(textMessage.text, "Done")
        XCTAssertEqual(textMessage.contentBlocks, [.text("Done")])
    }

    func testStoredSessionPreservesLocalIDAndPiSessionIDSeparately() {
        let session = StoredSession(
            id: "local-session-1",
            piSessionID: "pi-session-1",
            projectID: "project-1",
            projectPath: "/tmp/repo",
            projectName: "Repo",
            title: "Build UI",
            status: "Ready",
            sessionFile: "/tmp/repo/session.json",
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(session.id, "local-session-1")
        XCTAssertEqual(session.piSessionID, "pi-session-1")
        XCTAssertNotEqual(session.id, session.piSessionID)
        XCTAssertEqual(session.projectID, "project-1")
        XCTAssertTrue(session.isResumable)
    }

    func testStoredSessionWithoutPiSessionIDIsNotResumable() {
        let missingPiSessionID = StoredSession(
            id: "local-session-1",
            piSessionID: nil,
            projectID: "project-1",
            projectPath: "/tmp/repo",
            projectName: "Repo",
            title: "Imported shell",
            status: "Ready",
            sessionFile: "/tmp/repo/session.json",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let blankPiSessionID = StoredSession(
            id: "local-session-2",
            piSessionID: "  ",
            projectID: "project-1",
            projectPath: "/tmp/repo",
            projectName: "Repo",
            title: "Imported shell",
            status: "Ready",
            sessionFile: "/tmp/repo/session-2.json",
            updatedAt: Date(timeIntervalSince1970: 101)
        )

        XCTAssertFalse(missingPiSessionID.isResumable)
        XCTAssertFalse(blankPiSessionID.isResumable)
    }
}

@MainActor
final class NativeSessionIndexStoreModelTests: XCTestCase {
    func testSessionsForProjectSortsRunningSessionBeforeUpdatedAtOrder() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let otherProject = ProjectItem(id: "project-2", name: "Other", path: "/tmp/repo")
        let olderRunning = makeSession(
            id: "older-running",
            piSessionID: "pi-older-running",
            project: project,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newerIdle = makeSession(
            id: "newer-idle",
            piSessionID: "pi-newer-idle",
            project: project,
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let newestIdle = makeSession(
            id: "newest-idle",
            piSessionID: "pi-newest-idle",
            project: project,
            updatedAt: Date(timeIntervalSince1970: 30)
        )
        let samePathDifferentProject = makeSession(
            id: "same-path-different-project",
            piSessionID: "pi-other",
            project: otherProject,
            updatedAt: Date(timeIntervalSince1970: 40)
        )
        let store = NativeSessionIndexStore(
            sessions: [newerIdle, samePathDifferentProject, olderRunning, newestIdle],
            selectedSessionID: olderRunning.id
        )

        let ordered = store.sessionsForProject(project, runningSessionID: olderRunning.id) { session in
            session.id == olderRunning.id
        }

        XCTAssertEqual(ordered.map(\.id), ["older-running", "newest-idle", "newer-idle"])
    }

    func testUpsertUsesLocalIDForSelectionAndPiSessionIDForUpdates() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let store = NativeSessionIndexStore()

        let localID = store.upsert(
            sessionID: "pi-session-1",
            project: project,
            title: "Build UI",
            status: "Ready",
            sessionFile: "/tmp/repo/session.json"
        )

        XCTAssertNotEqual(localID, "pi-session-1")
        XCTAssertEqual(store.selectedSessionID, localID)
        XCTAssertEqual(store.sessions.first?.id, localID)
        XCTAssertEqual(store.sessions.first?.piSessionID, "pi-session-1")
        XCTAssertEqual(store.sessions.first?.projectID, project.id)

        let updatedLocalID = store.upsert(
            sessionID: "pi-session-1",
            project: project,
            title: "Build UI updated",
            status: "Running",
            sessionFile: "/tmp/repo/session.json"
        )

        XCTAssertEqual(updatedLocalID, localID)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.title, "Build UI updated")
        XCTAssertEqual(store.sessions.first?.status, "Running")
    }

    private func makeSession(
        id: String,
        piSessionID: String?,
        project: ProjectItem,
        updatedAt: Date
    ) -> StoredSession {
        StoredSession(
            id: id,
            piSessionID: piSessionID,
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: id,
            status: "Ready",
            sessionFile: "/tmp/repo/\(id).json",
            updatedAt: updatedAt
        )
    }
}
