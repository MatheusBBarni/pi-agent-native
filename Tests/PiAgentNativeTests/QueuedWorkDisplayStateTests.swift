import Foundation
import XCTest
@testable import PiAgentNativeCore

@MainActor
final class QueuedWorkDisplayStateTests: XCTestCase {
    func testCountOnlyStateIsReplacedByQueueEntries() {
        let model = AppModel()

        model.applyPendingMessageCount(2)
        XCTAssertEqual(model.pendingMessageCount, 2)
        XCTAssertEqual(model.queuedWorkDisplayState, .countOnly(2))

        let update = PiRPCQueueUpdate(payload: [
            "steering": ["Focus on the failing test first"],
            "followUp": ["Run swift test"]
        ])
        model.applyQueuedWorkUpdate(update)

        XCTAssertEqual(model.pendingMessageCount, 2)
        XCTAssertEqual(model.queuedWorkDisplayState, .entries(update.entries))
    }

    func testMatchingCountOnlyRefreshPreservesVisibleQueueDetails() {
        let model = AppModel()
        let update = PiRPCQueueUpdate(payload: [
            "steering": ["Keep the focused slice"],
            "followUp": ["Verify with XCTest"]
        ])

        model.applyQueuedWorkUpdate(update)
        model.applyPendingMessageCount(2)

        XCTAssertEqual(model.pendingMessageCount, 2)
        XCTAssertEqual(model.queuedWorkDisplayState, .entries(update.entries))
    }

    func testMismatchedCountOnlyRefreshClearsStaleQueueDetails() {
        let model = AppModel()
        let update = PiRPCQueueUpdate(payload: [
            "steering": ["Keep the focused slice"],
            "followUp": ["Verify with XCTest"]
        ])

        model.applyQueuedWorkUpdate(update)
        model.applyPendingMessageCount(1)

        XCTAssertEqual(model.pendingMessageCount, 1)
        XCTAssertEqual(model.queuedWorkDisplayState, .countOnly(1))
    }

    func testZeroCountClearsVisibleQueueDetails() {
        let model = AppModel()
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Do not show this later"],
            "followUp": []
        ]))

        model.applyPendingMessageCount(0)

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testEmptyQueueUpdateClearsVisibleQueueDetails() {
        let model = AppModel()
        model.applyPendingMessageCount(2)

        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": [],
            "followUp": []
        ]))

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testNewSessionClearsQueueState() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Do not leak into a new chat"],
            "followUp": []
        ]))

        model.newSession()

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testNewSessionIgnoresLateQueueUpdateUntilStateRefresh() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Old session detail"],
            "followUp": []
        ]))

        model.newSession()
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Should not reappear"],
            "followUp": []
        ]))

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testSwitchSessionIgnoresLateQueueUpdateUntilStateRefresh() {
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let session = StoredSession(
            id: "session-2",
            projectPath: project.path,
            projectName: project.name,
            title: "Target",
            status: "Ready",
            sessionFile: "/tmp/repo/session-2.json",
            updatedAt: Date()
        )
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Old session detail"],
            "followUp": []
        ]))

        model.switchSession(session)
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": ["Should not reappear"],
            "followUp": []
        ]))

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testStopClearsQueueState() {
        let model = AppModel()
        model.applyQueuedWorkUpdate(PiRPCQueueUpdate(payload: [
            "steering": [],
            "followUp": ["Do not leak after stop"]
        ]))

        model.stop()

        XCTAssertEqual(model.pendingMessageCount, 0)
        XCTAssertEqual(model.queuedWorkDisplayState, .empty)
    }

    func testLocalizedQueuedWorkEntryCopyDoesNotChangeRawQueuedText() {
        let entry = QueuedWorkEntry(kind: .steering, text: "  Preserve   /tmp/Projeto Bruto %@  ", position: 0)
        let empty = QueuedWorkEntry(kind: .followUp, text: "   ", position: 0)
        let portuguese = L10n(language: .portugueseBrazil)

        XCTAssertEqual(entry.title(l10n: portuguese), "Direcionamento")
        XCTAssertEqual(entry.text, "  Preserve   /tmp/Projeto Bruto %@  ")
        XCTAssertEqual(entry.summary(l10n: portuguese), "Preserve /tmp/Projeto Bruto %@")
        XCTAssertEqual(empty.title(l10n: portuguese), "Seguimento")
        XCTAssertEqual(empty.summary(l10n: portuguese), "Mensagem vazia na fila")
    }
}
