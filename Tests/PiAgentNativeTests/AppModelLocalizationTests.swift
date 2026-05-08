import Foundation
import XCTest
@testable import PiAgentNativeCore

@MainActor
final class AppModelLocalizationTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        SessionStore.databaseURLForTesting = temporaryDirectory().appendingPathComponent("sessions.sqlite")
    }

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil
        resetLanguagePreference()

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

    func testChatComposerLabelsResolveInEnglishAndPortuguese() {
        XCTAssertEqual(
            L10n(language: .english).string("chat.composer.placeholder"),
            "Ask pi to work in this workspace"
        )
        XCTAssertEqual(
            L10n(language: .portugueseBrazil).string("chat.composer.placeholder"),
            "Peça ao pi para trabalhar neste workspace"
        )
        XCTAssertEqual(
            L10n(language: .portugueseBrazil).string("chat.tool_result.output"),
            "Saída da ferramenta"
        )
    }

    func testSuggestedPromptDisplayLocalizesWithoutChangingInsertedPromptText() {
        let prompts = SuggestedPromptContent.defaults(l10n: L10n(language: .portugueseBrazil))
        let inspect = prompts[0]

        XCTAssertEqual(
            inspect.displayText,
            "Inspecionar este repositório e sugerir a arquitetura do shell nativo do pi."
        )
        XCTAssertEqual(inspect.promptText, SuggestedPromptContent.inspectRepositoryPrompt)
        XCTAssertEqual(
            inspect.promptText,
            "Inspect this repository and suggest the native pi shell architecture."
        )
    }

    func testLocalizedSkillPickerCompletionPreservesSkillCommandPayload() {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let model = AppModel()
        model.appLanguage = .portugueseBrazil
        let skill = AvailableSkill(
            id: "diagnose",
            displayName: "Diagnose",
            description: "Debug carefully",
            skillFilePath: "/tmp/diagnose/SKILL.md",
            skillBaseDir: "/tmp/diagnose"
        )
        model.skillAvailability = .loaded
        model.availableSkills = [skill]
        model.composerText = "/skill:dia"
        model.composerSelectionRange = NSRange(location: (model.composerText as NSString).length, length: 0)

        XCTAssertEqual(model.skillPickerState?.status, .results)

        model.completeSkillQuery(with: skill)

        XCTAssertEqual(model.composerText, "/skill:diagnose ")
        XCTAssertEqual(
            model.composerSelectionRange,
            NSRange(location: ("/skill:diagnose " as NSString).length, length: 0)
        )
    }

    func testStartWithoutProjectLocalizesStatusAndLaunchDetail() {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let englishModel = AppModel()
        englishModel.appLanguage = .english

        englishModel.start()

        XCTAssertEqual(englishModel.statusText, "Open a project")
        XCTAssertEqual(englishModel.launchDetail, "Choose a project folder before starting pi")

        let portugueseModel = AppModel()
        portugueseModel.appLanguage = .portugueseBrazil

        portugueseModel.start()

        XCTAssertEqual(portugueseModel.statusText, "Abra um projeto")
        XCTAssertEqual(portugueseModel.launchDetail, "Escolha uma pasta de projeto antes de iniciar o pi")
    }

    func testCommandPaletteDisabledReasonLocalizesWithoutRunningInvocation() {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let model = AppModel()
        model.appLanguage = .portugueseBrazil
        model.showCommandPalette()
        let sendItem = model.commandPaletteItems().first { $0.invocation == .appAction(.sendPrompt) }!

        model.runCommandPaletteItem(sendItem)

        XCTAssertTrue(model.isShowingCommandPalette)
        XCTAssertEqual(model.statusText, "Abra um projeto primeiro")
        XCTAssertNil(model.selectedSessionID)
    }

    func testEventLogTitleLocalizesWhileAttachmentPathStaysRaw() throws {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let project = ProjectItem(id: "project-a", name: "Project", path: root.path)
        let model = AppModel()
        model.appLanguage = .portugueseBrazil
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.authAccess.modelAccess = .available(providerID: "openai-codex")
        model.composerText = "Review this"
        model.pendingContextAttachments = [
            attachment(
                "Sources/Raw Missing.md",
                kind: .file,
                project: project,
                status: .valid(resolvedURL: root.appendingPathComponent("Sources/Raw Missing.md"))
            )
        ]

        model.sendPrompt()

        XCTAssertEqual(model.statusText, "Anexo indisponível")
        XCTAssertEqual(model.eventLog.first?.title, "prompt bloqueado")
        XCTAssertTrue(model.eventLog.first?.detail.contains("Sources/Raw Missing.md") == true)
    }

    func testExternalOpenFailureLocalizesAppCopyAndPreservesRawTechnicalValues() async {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        struct LaunchFailure: LocalizedError {
            var errorDescription: String? { "Raw launch error /tmp/Projeto Teste" }
        }

        let model = AppModel()
        model.appLanguage = .portugueseBrazil
        let project = ProjectItem(id: "project-a", name: "Projeto", path: "/tmp/Projeto Teste")
        let target = AvailableExternalTarget(
            definition: ExternalTargetCatalog.definitions.first { $0.id == .vscode }!,
            launchReference: .commandPath("/custom/bin/code")
        )
        model.projects = [project]
        model.selectedProjectID = project.id
        model.workspacePath = project.path
        model.externalTargetLauncher = { _, projectPath, completion in
            XCTAssertEqual(projectPath, project.path)
            completion(.failure(LaunchFailure()))
        }

        model.openExternally(target)
        await Task.yield()

        XCTAssertEqual(model.statusText, "Não foi possível abrir em VS Code")
        XCTAssertEqual(model.eventLog.first?.title, "abertura externa falhou")
        XCTAssertTrue(model.eventLog.first?.detail.contains("target=VS Code") == true)
        XCTAssertTrue(model.eventLog.first?.detail.contains("projectPath=/tmp/Projeto Teste") == true)
        XCTAssertTrue(model.eventLog.first?.detail.contains("Raw launch error /tmp/Projeto Teste") == true)
    }

    func testProviderAndModelIdentifiersStayVerbatimInLocalizedInterpolation() {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let provider = "openai-codex"
        let modelID = "model=gpt-5.4-mini/pi"

        let detail = L10n(language: .portugueseBrazil)
            .string("app_model.log.detail.provider_message", provider, modelID)

        XCTAssertEqual(detail, "provider=openai-codex model=gpt-5.4-mini/pi")
    }

    func testInspectorAndChangeReviewPresentationLocalizesChromeAroundRawGitData() {
        let l10n = L10n(language: .portugueseBrazil)
        let rawBranch = "feature/i18n-%@-raw"
        let rawPath = "Sources/Área Bruta/App.swift"
        let rawOriginalPath = "Sources/Old Área/App.swift"
        let rawDiff = """
        diff --git a/\(rawOriginalPath) b/\(rawPath)
        rename from \(rawOriginalPath)
        rename to \(rawPath)
        @@ -10,2 +10,3 @@ func exemplo()
         let keep = "/tmp/Projeto Bruto"
        -let label = "old %@"
        +let label = "novo %@"
        """
        let hunks = GitDiffParser.parseUnifiedDiff(rawDiff)
        let file = ChangedFile(
            path: rawPath,
            originalPath: rawOriginalPath,
            state: .renamed,
            isBinary: false,
            hunks: hunks,
            diffStatus: .loaded
        )
        let snapshot = RepositoryChangeSnapshot(
            projectPath: "/tmp/Projeto Bruto",
            branch: rawBranch,
            files: [file],
            loadedAt: Date(timeIntervalSince1970: 1),
            status: .dirty
        )

        XCTAssertEqual(InspectorPresentation.changesSummary(for: snapshot, l10n: l10n), "1 arquivo alterado")
        XCTAssertEqual(
            ChangeReviewPresentation.headerDetail(for: snapshot, l10n: l10n),
            "1 arquivo alterado em feature/i18n-%@-raw"
        )
        XCTAssertEqual(ChangeReviewPresentation.diffStatusText(for: file, l10n: l10n), "Diff de texto")
        XCTAssertEqual(file.path, rawPath)
        XCTAssertEqual(file.originalPath, rawOriginalPath)
        XCTAssertEqual(hunks.first?.header, "@@ -10,2 +10,3 @@ func exemplo()")
        XCTAssertTrue(hunks.flatMap(\.lines).contains { $0.kind == .deletion && $0.text == #"let label = "old %@""# })
        XCTAssertTrue(hunks.flatMap(\.lines).contains { $0.kind == .addition && $0.text == #"let label = "novo %@""# })
    }

    func testChangeReviewLocalizesKnownGitMessagesAndPreservesPathInterpolation() {
        let l10n = L10n(language: .portugueseBrazil)
        let rawPath = "Sources/Área Bruta/App.swift"
        let file = ChangedFile(
            path: rawPath,
            state: .modified,
            diffStatus: .failed(message: "Could not load diff for \(rawPath).")
        )
        let snapshot = RepositoryChangeSnapshot(
            projectPath: "/tmp/Projeto Bruto",
            branch: "feature/raw",
            files: [],
            loadedAt: Date(timeIntervalSince1970: 1),
            status: .failed(message: "Could not read Git status.")
        )

        XCTAssertEqual(
            ChangeReviewPresentation.diffStatusText(for: file, l10n: l10n),
            "Não foi possível carregar o diff de Sources/Área Bruta/App.swift."
        )
        XCTAssertEqual(
            ChangeReviewPresentation.emptyDetail(for: snapshot, l10n: l10n),
            "Não foi possível ler o status do Git."
        )
        XCTAssertEqual(file.path, rawPath)
    }

    func testProcessLogAndToolOutputStayVerbatimBesideLocalizedChrome() {
        let l10n = L10n(language: .portugueseBrazil)
        let rawProcessOutput = "stderr: /tmp/Projeto Bruto status=%@ código=42"
        let rawToolOutput = "stdout: caminho=/tmp/raw path\njson={\"key\":\"%@\"}"
        let event = EventLog(title: "stderr", detail: rawProcessOutput)
        let tool = ToolActivity(
            id: "tool-raw",
            name: "bash/raw-tool",
            summary: "printf '%@'",
            output: rawToolOutput,
            isRunning: false,
            isError: false
        )

        XCTAssertEqual(l10n.string("process_log.title"), "Registro de Processo")
        XCTAssertEqual(l10n.string("process_log.close"), "Fechar")
        XCTAssertEqual(l10n.string("inspector.tool_activity.output"), "Saída")
        XCTAssertEqual(event.title, "stderr")
        XCTAssertEqual(event.detail, rawProcessOutput)
        XCTAssertEqual(tool.name, "bash/raw-tool")
        XCTAssertEqual(tool.summary, "printf '%@'")
        XCTAssertEqual(tool.output, rawToolOutput)
    }

    func testLoginSheetLanguageLocalizesControlsButPreservesProviderAndOAuthOutput() {
        resetLanguagePreference()
        defer { resetLanguagePreference() }

        let provider = LoginProviderCatalog.subscriptionProviders.first { $0.id == "openai-codex" }!
        let rawOutput = "Open https://auth.example/callback?code=RAW&provider=openai-codex\nprovider=ChatGPT / OpenAI Codex"
        let model = AppModel()
        model.appLanguage = .portugueseBrazil
        model.oauthLoginRunner.output = rawOutput

        XCTAssertEqual(model.l10n.string("auth.login_sheet.title"), "Login")
        XCTAssertEqual(model.l10n.string("auth.login_sheet.start_login"), "Iniciar login")
        XCTAssertEqual(model.l10n.string("auth.login_sheet.open_link"), "Abrir link")
        XCTAssertEqual(provider.name, "ChatGPT / OpenAI Codex")
        XCTAssertEqual(model.oauthLoginRunner.output, rawOutput)
        XCTAssertTrue(model.oauthLoginRunner.output.contains("https://auth.example/callback?code=RAW&provider=openai-codex"))
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryURLs.append(url)
        return url
    }

    private func resetLanguagePreference() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
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
