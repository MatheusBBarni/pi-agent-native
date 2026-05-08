import Foundation
import XCTest
@testable import PiAgentNativeCore

@MainActor
final class ContextAttachmentSubmissionTests: XCTestCase {
    func testInvalidAttachmentBlocksSubmissionAndPreservesComposerState() throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)
        let skill = AvailableSkill(id: "diagnose", displayName: nil, description: nil, skillFilePath: nil, skillBaseDir: nil)
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.authAccess.modelAccess = .available(providerID: "openai")
        model.composerText = "Review this"
        model.pendingSelectedSkills = [skill]
        model.pendingContextAttachments = [
            attachment("Missing.md", kind: .file, project: project, status: .valid(resolvedURL: root.appendingPathComponent("Missing.md")))
        ]

        model.sendPrompt()

        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertEqual(model.composerText, "Review this")
        XCTAssertEqual(model.pendingSelectedSkills, [skill])
        XCTAssertEqual(model.pendingContextAttachments.map(\.status), [.missing])
        XCTAssertEqual(model.statusText, "Attachment unavailable")
    }

    func testNewSessionAndProjectSwitchClearPendingAttachments() throws {
        let rootA = temporaryDirectory()
        let rootB = temporaryDirectory()
        try FileManager.default.createDirectory(at: rootA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootB, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootA)
            try? FileManager.default.removeItem(at: rootB)
        }
        let projectA = ProjectItem(id: "project-a", name: "A", path: rootA.path)
        let projectB = ProjectItem(id: "project-b", name: "B", path: rootB.path)
        let model = AppModel()
        model.projects = [projectA, projectB]
        model.selectedProjectID = projectA.id
        model.workspacePath = projectA.path
        model.pendingContextAttachments = [attachment("README.md", kind: .file, project: projectA, status: .missing)]

        model.newSession()

        XCTAssertTrue(model.pendingContextAttachments.isEmpty)

        model.pendingContextAttachments = [attachment("README.md", kind: .file, project: projectA, status: .missing)]
        model.selectProjectForNewChat(projectB)

        XCTAssertTrue(model.pendingContextAttachments.isEmpty)
    }

    func testAttachmentOnlyPromptCanBeSubmitted() throws {
        let root = temporaryDirectory()
        let file = root.appendingPathComponent("README.md")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: root) }
        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)
        let model = AppModel()
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.authAccess.modelAccess = .available(providerID: "openai")
        model.composerText = ""
        model.pendingContextAttachments = [
            attachment("README.md", kind: .file, project: project, status: .valid(resolvedURL: file))
        ]

        XCTAssertTrue(model.canPerformAppAction(.sendPrompt))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func attachment(
        _ relativePath: String,
        kind: ContextAttachmentKind,
        project: ProjectItem,
        status: ContextAttachmentStatus
    ) -> ContextAttachment {
        ContextAttachment(
            id: "\(project.id):\(relativePath)",
            projectID: project.id,
            projectPath: project.path,
            relativePath: relativePath,
            displayName: URL(fileURLWithPath: relativePath).lastPathComponent,
            kind: kind,
            createdResolvedURL: URL(fileURLWithPath: project.path).appendingPathComponent(relativePath),
            status: status
        )
    }
}
