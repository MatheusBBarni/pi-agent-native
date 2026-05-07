import XCTest
@testable import PiAgentNativeCore

final class SkillSelectionTests: XCTestCase {
    func testParseSubmissionRecognizesRepeatedSkillCommands() {
        XCTAssertEqual(
            SkillSelectionLogic.parseSubmission("/skill:diagnose /skill:build-ios-apps:ios-app-intents"),
            .selection(skillIDs: ["diagnose", "build-ios-apps:ios-app-intents"])
        )
    }

    func testParseSubmissionRejectsMixedPromptTextAndCommaLists() {
        XCTAssertEqual(
            SkillSelectionLogic.parseSubmission("/skill:diagnose fix this crash"),
            .invalid("Skill selections cannot be mixed with prompt text.")
        )
        XCTAssertEqual(
            SkillSelectionLogic.parseSubmission("Use /skill:diagnose"),
            .invalid("Skill selections cannot be mixed with prompt text.")
        )
        XCTAssertEqual(
            SkillSelectionLogic.parseSubmission("/skill:diagnose,zoom-out"),
            .invalid("Use repeated /skill:<skill-id> tokens instead of comma-separated skills.")
        )
    }

    func testDetectQueryOnlyActivatesForCompletedSkillPrefix() {
        XCTAssertNil(SkillSelectionLogic.detectQuery(in: "/help", selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertNil(SkillSelectionLogic.detectQuery(in: "/skill:dia", selectedRange: NSRange(location: 3, length: 0)))

        XCTAssertEqual(
            SkillSelectionLogic.detectQuery(in: "Use /skill:dia now", selectedRange: NSRange(location: 14, length: 0)),
            SkillQuery(tokenRange: NSRange(location: 4, length: 10), searchText: "dia")
        )
    }

    func testSearchRanksAndCapsResults() {
        let skills = [
            AvailableSkill(id: "zoom-out", displayName: "Broader context", description: nil, skillFilePath: nil, skillBaseDir: nil),
            AvailableSkill(id: "diagnose", displayName: "Debug problems", description: nil, skillFilePath: nil, skillBaseDir: nil),
            AvailableSkill(id: "ios-diagnose", displayName: "Apple debugging", description: nil, skillFilePath: nil, skillBaseDir: nil)
        ] + (0..<20).map {
            AvailableSkill(id: "skill-\($0)", displayName: nil, description: nil, skillFilePath: nil, skillBaseDir: nil)
        }

        XCTAssertEqual(SkillSelectionLogic.search("dia", in: skills).map(\.id), ["diagnose", "ios-diagnose"])
        XCTAssertEqual(SkillSelectionLogic.search("", in: skills).count, 12)
    }

    func testResolveSelectionValidatesAllOrNothingAndDedupes() throws {
        let diagnose = AvailableSkill(id: "diagnose", displayName: nil, description: nil, skillFilePath: nil, skillBaseDir: nil)
        let zoomOut = AvailableSkill(id: "zoom-out", displayName: nil, description: nil, skillFilePath: nil, skillBaseDir: nil)

        let resolved = try SkillSelectionLogic.resolveSelection(
            skillIDs: ["diagnose", "diagnose", "zoom-out"],
            availableSkills: [diagnose, zoomOut],
            existingSkills: [diagnose]
        )
        XCTAssertEqual(resolved, [zoomOut])

        XCTAssertThrowsError(
            try SkillSelectionLogic.resolveSelection(
                skillIDs: ["diagnose", "unknown"],
                availableSkills: [diagnose],
                existingSkills: []
            )
        ) { error in
            XCTAssertEqual(error as? SkillSelectionValidationError, .unknownSkill("unknown"))
        }
    }

    func testAvailableSkillsParseOnlySkillCommands() {
        let skills = SkillSelectionLogic.availableSkills(from: [
            [
                "name": "skill:diagnose",
                "displayName": "Diagnose",
                "description": "Debug carefully",
                "source": "skill",
                "sourceInfo": [
                    "path": "/tmp/diagnose/SKILL.md",
                    "baseDir": "/tmp/diagnose"
                ]
            ],
            ["name": "skill:diagnose", "source": "skill"],
            ["name": "help", "source": "builtin"],
            ["name": "skill:", "source": "skill"]
        ])

        XCTAssertEqual(skills, [
            AvailableSkill(
                id: "diagnose",
                displayName: "Diagnose",
                description: "Debug carefully",
                skillFilePath: "/tmp/diagnose/SKILL.md",
                skillBaseDir: "/tmp/diagnose"
            )
        ])
    }

    func testDecoratorExpandsSkillFilesAndStripsFrontmatter() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let skillPath = directory.appendingPathComponent("SKILL.md")
        try """
        ---
        name: diagnose
        ---

        # Diagnose
        Run the loop.
        """.write(to: skillPath, atomically: true, encoding: .utf8)

        let prompt = try SkillPromptDecorator.decoratedPrompt(
            userPrompt: "Fix the crash.",
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

        XCTAssertTrue(prompt.hasPrefix("""
        <skill name="diagnose" location="\(skillPath.path)">
        References are relative to \(directory.path).

        # Diagnose
        """))
        XCTAssertFalse(prompt.contains("name: diagnose"))
        XCTAssertTrue(prompt.hasSuffix("</skill>\n\nFix the crash."))
    }

    func testVisibleUserPromptStripsLeadingNativeSkillBlocks() {
        let rpcPrompt = """
        <skill name="diagnose" location="/tmp/diagnose/SKILL.md">
        References are relative to /tmp/diagnose.

        # Diagnose
        </skill>

        <skill name="zoom-out" location="/tmp/zoom-out/SKILL.md">
        References are relative to /tmp/zoom-out.

        # Zoom Out
        </skill>

        Fix the crash.
        """

        XCTAssertEqual(SkillPromptDecorator.visibleUserPrompt(from: rpcPrompt), "Fix the crash.")
        XCTAssertEqual(SkillPromptDecorator.visibleUserPrompt(from: "Use <skill> literally."), "Use <skill> literally.")
    }

    func testDecoratorFailsForMissingOrUnreadablePath() {
        XCTAssertThrowsError(
            try SkillPromptDecorator.decoratedPrompt(
                userPrompt: "Hello",
                skills: [AvailableSkill(id: "diagnose", displayName: nil, description: nil, skillFilePath: nil, skillBaseDir: nil)]
            )
        ) { error in
            XCTAssertEqual(error as? SkillPromptDecorationError, .missingPath("diagnose"))
        }

        XCTAssertThrowsError(
            try SkillPromptDecorator.decoratedPrompt(
                userPrompt: "Hello",
                skills: [
                    AvailableSkill(
                        id: "diagnose",
                        displayName: nil,
                        description: nil,
                        skillFilePath: "/definitely/not/readable/SKILL.md",
                        skillBaseDir: nil
                    )
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? SkillPromptDecorationError,
                .unreadablePath(skillID: "diagnose", path: "/definitely/not/readable/SKILL.md")
            )
        }
    }
}
