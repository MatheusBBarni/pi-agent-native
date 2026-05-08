import Foundation
import XCTest
@testable import PiAgentNativeCore

final class ContextAttachmentResolverTests: XCTestCase {
    func testResolvesValidFileAndFolderAttachments() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Sources/App.swift")
        let folder = root.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: Data())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)

        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("Sources/App.swift", kind: .file, project: project), selectedProject: project),
            .valid(resolvedURL: file.standardizedFileURL.resolvingSymlinksInPath())
        )
        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("Sources/Feature/", kind: .folder, project: project), selectedProject: project),
            .valid(resolvedURL: folder.standardizedFileURL.resolvingSymlinksInPath())
        )
    }

    func testReportsMissingAndWrongKindAttachments() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("README.md")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: Data())
        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)

        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("Missing.md", kind: .file, project: project), selectedProject: project),
            .missing
        )
        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("README.md", kind: .folder, project: project), selectedProject: project),
            .wrongKind(actualKind: .file)
        )
    }

    func testRejectsSymlinkAndRelativePathEscapes() throws {
        let container = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: container) }
        let root = container.appendingPathComponent("project", isDirectory: true)
        let sibling = container.appendingPathComponent("project-other", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let outsideFile = sibling.appendingPathComponent("Secret.md")
        FileManager.default.createFile(atPath: outsideFile.path, contents: Data())
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Secret.md"),
            withDestinationURL: outsideFile
        )
        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)

        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("Secret.md", kind: .file, project: project), selectedProject: project),
            .outOfProject
        )
        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("../project-other/Secret.md", kind: .file, project: project), selectedProject: project),
            .outOfProject
        )
    }

    func testProjectMismatchInvalidatesAttachment() throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = ProjectItem(id: "project-a", name: "A", path: root.path)
        let selected = ProjectItem(id: "project-b", name: "B", path: root.path)

        XCTAssertEqual(
            ContextAttachmentResolver.resolve(attachment("README.md", kind: .file, project: original), selectedProject: selected),
            .projectChanged
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func attachment(
        _ relativePath: String,
        kind: ContextAttachmentKind,
        project: ProjectItem
    ) -> ContextAttachment {
        ContextAttachment(
            id: "\(project.id):\(relativePath)",
            projectID: project.id,
            projectPath: project.path,
            relativePath: relativePath,
            displayName: URL(fileURLWithPath: relativePath).lastPathComponent,
            kind: kind,
            createdResolvedURL: URL(fileURLWithPath: project.path).appendingPathComponent(relativePath),
            status: .missing
        )
    }
}
