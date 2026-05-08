import Foundation
import XCTest
@testable import PiAgentNativeCore

final class ContextAttachmentPromptDecoratorTests: XCTestCase {
    func testDecoratesValidAttachmentsOnlyInPendingOrder() {
        let project = ProjectItem(id: "project-a", name: "Project", path: "/tmp/project")
        let prompt = ContextAttachmentPromptDecorator.decoratedPrompt(
            userPrompt: "Review these.",
            attachments: [
                attachment("Sources/App.swift", kind: .file, project: project, status: .valid(resolvedURL: URL(fileURLWithPath: "/tmp/project/Sources/App.swift"))),
                attachment("Sources/RPC/", kind: .folder, project: project, status: .valid(resolvedURL: URL(fileURLWithPath: "/tmp/project/Sources/RPC", isDirectory: true))),
                attachment("Missing.md", kind: .file, project: project, status: .missing)
            ]
        )

        XCTAssertEqual(prompt, """
        <context-attachments>
        - file: Sources/App.swift
        - folder: Sources/RPC/
        </context-attachments>

        Review these.
        """)
    }

    func testOmitsDecorationForEmptyOrInvalidAttachments() {
        let project = ProjectItem(id: "project-a", name: "Project", path: "/tmp/project")

        XCTAssertEqual(
            ContextAttachmentPromptDecorator.decoratedPrompt(userPrompt: "Plain prompt", attachments: []),
            "Plain prompt"
        )
        XCTAssertEqual(
            ContextAttachmentPromptDecorator.decoratedPrompt(
                userPrompt: "Plain prompt",
                attachments: [attachment("Missing.md", kind: .file, project: project, status: .missing)]
            ),
            "Plain prompt"
        )
    }

    func testEscapesControlCharactersIntoSingleAttachmentLine() {
        let project = ProjectItem(id: "project-a", name: "Project", path: "/tmp/project")
        let prompt = ContextAttachmentPromptDecorator.decoratedPrompt(
            userPrompt: "Inspect",
            attachments: [
                attachment("Sources/Line\nTab\tSlash\\File.swift", kind: .file, project: project, status: .valid(resolvedURL: URL(fileURLWithPath: "/tmp/project/file")))
            ]
        )

        XCTAssertTrue(prompt.contains("- file: Sources/Line\\nTab\\tSlash\\\\File.swift"))
        XCTAssertEqual(prompt.components(separatedBy: "\n").filter { $0.hasPrefix("- file:") }.count, 1)
    }

    func testVisiblePromptStripsNativeContextAttachmentsAfterSkills() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let skillPath = directory.appendingPathComponent("SKILL.md")
        try "# Diagnose\nRun carefully.".write(to: skillPath, atomically: true, encoding: .utf8)
        let project = ProjectItem(id: "project-a", name: "Project", path: "/tmp/project")
        let attachmentPrompt = ContextAttachmentPromptDecorator.decoratedPrompt(
            userPrompt: "Fix it.",
            attachments: [attachment("Sources/App.swift", kind: .file, project: project, status: .valid(resolvedURL: URL(fileURLWithPath: "/tmp/project/Sources/App.swift")))]
        )
        let rpcPrompt = try SkillPromptDecorator.decoratedPrompt(
            userPrompt: attachmentPrompt,
            skills: [
                AvailableSkill(
                    id: "diagnose",
                    displayName: nil,
                    description: nil,
                    skillFilePath: skillPath.path,
                    skillBaseDir: nil
                )
            ]
        )

        XCTAssertTrue(rpcPrompt.contains("</skill>\n\n<context-attachments>"))
        XCTAssertEqual(SkillPromptDecorator.visibleUserPrompt(from: rpcPrompt), "Fix it.")
        XCTAssertEqual(
            SkillPromptDecorator.visibleUserPrompt(from: "Explain <context-attachments> literally."),
            "Explain <context-attachments> literally."
        )
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
