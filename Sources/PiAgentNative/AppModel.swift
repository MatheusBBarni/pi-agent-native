import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class AppModel: ObservableObject {
    @Published var sessionTitle = "New chat"
    @Published var composerText = ""
    @Published var statusText = "Disconnected"
    @Published var launchDetail = "pi has not been started"
    @Published public var isConnected = false
    @Published var isStreaming = false
    @Published var isCompacting = false
    @Published var composerSelectionRange = NSRange(location: 0, length: 0)
    @Published var modelName = "No model"
    @Published var thinkingLevel = "medium"
    @Published var pendingMessageCount = 0
    @Published var queuedWorkDisplayState: QueuedWorkDisplayState = .empty
    @Published var availableModels: [PiModel] = []
    @Published var authAccess = AuthAccessState()
    @Published var availableSkills: [AvailableSkill] = []
    @Published var skillAvailability: SkillAvailability = .notLoaded
    @Published var pendingSelectedSkills: [AvailableSkill] = []
    @Published var highlightedSkillID: String?
    @Published private var dismissedSkillQuery: SkillQuery?
    @Published var isShowingModelPicker = false
    @Published var isShowingLogin = false
    @Published var isShowingProcessLog = false
    @Published var isShowingSettings = false
    @Published var isShowingKeybindingHelp = false
    @Published var isShowingChangeReview = false
    @Published var isShowingCommandPalette = false
    @Published var commandPaletteQuery = ""
    @Published var commandPaletteHighlightedItemID: CommandPaletteItem.ID?
    @Published var isSidebarVisible = true
    @Published var isInspectorVisible = true
    @Published var composerFocusRequest = 0
    @Published var uiFontSize: Double {
        didSet {
            UserDefaults.standard.set(uiFontSize, forKey: "uiFontSize")
        }
    }
    @Published var themeFamily: AppThemeFamily {
        didSet {
            UserDefaults.standard.set(themeFamily.rawValue, forKey: "themeFamily")
        }
    }
    @Published var themeVariant: AppThemeVariant {
        didSet {
            UserDefaults.standard.set(themeVariant.rawValue, forKey: "themeVariant")
        }
    }
    @Published var gitDetails = GitBranchDetails()
    @Published var repositoryChangeSnapshot = RepositoryChangeSnapshot.unavailable(reason: "Open a project to review changes.")
    @Published var mentionPickerState: MentionPickerState?
    @Published var pendingMentionTextReplacement: MentionTextReplacement?
    @Published var pendingContextAttachments: [ContextAttachment] = []

    let conversationStore: ConversationStore
    let toolActivityStore: ToolActivityStore
    let processLogStore: ProcessLogStore
    let workspaceStore: WorkspaceStore
    let sessionIndexStore: NativeSessionIndexStore
    let settingsStore: SettingsStore
    let extensionUIRouter = ExtensionUIRouter()
    let oauthLoginRunner = OAuthLoginRunner()

    var externalTargetLauncher: ExternalTargetLaunchAction = ExternalTargetLauncher.launch

    private let client = PiRPCClient()
    private let reducer = PiRPCEventReducer()
    private var accessRefreshTracker = AuthAccessRefreshTracker()
    private var storeCancellables: Set<AnyCancellable> = []
    private var shouldSwitchToStoredSessionAfterStart = true
    private var isCreatingNewSession = false
    private var isSwitchingSession = false
    private var isAwaitingQueuedWorkContextRefresh = false
    private var pendingPromptAfterNewSession: String?
    private var mentionIndexCache: [String: [MentionIndexEntry]] = [:]
    private var mentionIndexTask: Task<Void, Never>?
    private var repositoryChangeSnapshotTask: Task<Void, Never>?
    private var debouncedRepositoryChangeSnapshotTask: Task<Void, Never>?
    private var mentionIndexLoadingProjectPath: String?
    private var pendingContextAttachmentInsertion: (replacementID: UUID, attachment: ContextAttachment)?
    private var handledSubscriptionLoginAttemptIDs: Set<UUID> = []
    var repositoryChangeRefreshDelayNanoseconds: UInt64 = 500_000_000

    var workspacePath: String {
        get { workspaceStore.workspacePath }
        set { workspaceStore.workspacePath = newValue }
    }

    var customExecutablePath: String {
        get { settingsStore.customExecutablePath }
        set { settingsStore.customExecutablePath = newValue }
    }

    var appLanguage: AppLanguage {
        get { settingsStore.appLanguage }
        set { settingsStore.appLanguage = newValue }
    }

    var l10n: L10n {
        L10n(language: appLanguage)
    }

    private func appString(_ key: String, _ args: CVarArg...) -> String {
        l10n.string(key, arguments: args)
    }

    private func appPlural(_ key: String, count: Int) -> String {
        l10n.plural(key, count: count)
    }

    private func appStringList(_ key: String) -> [String] {
        appString(key)
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func localizedTitle(for actionID: AppActionID) -> String {
        DefaultKeymap.title(for: actionID, l10n: l10n) ?? DefaultKeymap.title(for: actionID) ?? actionID.rawValue
    }

    public var startPiRPCMenuTitle: String {
        appString("app_menu.start_pi_rpc")
    }

    public var stopPiRPCMenuTitle: String {
        appString("app_menu.stop_pi_rpc")
    }

    var messages: [ChatMessage] {
        get { conversationStore.messages }
        set { conversationStore.messages = newValue }
    }

    var eventLog: [EventLog] {
        get { processLogStore.eventLog }
        set { processLogStore.eventLog = newValue }
    }

    var tools: [ToolActivity] {
        get { toolActivityStore.tools }
        set { toolActivityStore.tools = newValue }
    }

    var projects: [ProjectItem] {
        get { workspaceStore.projects }
        set { workspaceStore.projects = newValue }
    }

    var selectedProjectID: ProjectItem.ID? {
        get { workspaceStore.selectedProjectID }
        set { workspaceStore.selectedProjectID = newValue }
    }

    var expandedProjectIDs: Set<ProjectItem.ID> {
        get { workspaceStore.expandedProjectIDs }
        set { workspaceStore.expandedProjectIDs = newValue }
    }

    var sessions: [StoredSession] {
        get { sessionIndexStore.sessions }
        set { sessionIndexStore.sessions = newValue }
    }

    var selectedSessionID: StoredSession.ID? {
        get { sessionIndexStore.selectedSessionID }
        set { sessionIndexStore.selectedSessionID = newValue }
    }

    var availableExternalTargets: [AvailableExternalTarget] {
        get { workspaceStore.availableExternalTargets }
        set { workspaceStore.availableExternalTargets = newValue }
    }

    public init() {
        let storedExecutable = UserDefaults.standard.string(forKey: "customExecutablePath")
        let storedFontSize = UserDefaults.standard.object(forKey: "uiFontSize") as? Double
        let storedThemeFamily = UserDefaults.standard.string(forKey: "themeFamily").flatMap(AppThemeFamily.init(rawValue:))
        let storedThemeVariant = UserDefaults.standard.string(forKey: "themeVariant").flatMap(AppThemeVariant.init(rawValue:))
        let legacyThemeMode = UserDefaults.standard.string(forKey: "themeMode").flatMap(AppThemeVariant.init(rawValue:))
        let persistedState = SessionStore.load()
        let persistedProjects = Self.normalizePersistedProjects(persistedState.projects)
        let persistedProjectIDs = Set(persistedProjects.map(\.id))
        let persistedSessions = persistedState.sessions.filter { persistedProjectIDs.contains($0.projectID) }
        let persistedSelectedProjectID = persistedProjects.first(where: { $0.id == persistedState.selectedProjectID })?.id
        let persistedSelectedSessionID = persistedSessions.first(where: { $0.id == persistedState.selectedSessionID })?.id

        settingsStore = SettingsStore(customExecutablePath: storedExecutable ?? "")
        workspaceStore = WorkspaceStore(
            projects: persistedProjects,
            selectedProjectID: persistedSelectedProjectID,
            availableExternalTargets: ExternalTargetScanner().scan()
        )
        sessionIndexStore = NativeSessionIndexStore(
            sessions: persistedSessions,
            selectedSessionID: persistedSelectedSessionID
        )
        conversationStore = ConversationStore()
        toolActivityStore = ToolActivityStore()
        processLogStore = ProcessLogStore()

        uiFontSize = min(max(storedFontSize ?? 15, 12), 20)
        themeFamily = storedThemeFamily ?? .nord
        themeVariant = storedThemeVariant ?? legacyThemeMode ?? .dark
        applyLocalizedInitialState()

        if let selectedProjectID = persistedSelectedProjectID,
           let selectedProject = workspaceStore.selectedProject {
            let selectedSession = selectedSessionID.flatMap { id in
                persistedSessions.first { $0.id == id }
            }
            if selectedSession?.projectID != selectedProjectID {
                selectedSessionID = NativeSessionIndexStore.lastOpenedSession(
                    in: persistedSessions,
                    projectID: selectedProjectID,
                    projectPath: selectedProject.path
                )?.id
            }
        }
        persistState()
        bindStoreChanges()
        refreshGitDetails()
        refreshRepositoryChangeSnapshot()

        oauthLoginRunner.onCompletion = { [weak self] provider, attemptID, exitStatus in
            Task { @MainActor in
                self?.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: exitStatus)
            }
        }

        client.onEvent = { [weak self] event in
            self?.handleRPCEvent(event)
        }
        client.onStderr = { [weak self] text in
            self?.appendLog(title: "stderr", detail: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        client.onExit = { [weak self] status in
            guard let self else { return }
            self.isConnected = false
            self.isStreaming = false
            self.clearQueuedWork()
            self.availableSkills = []
            self.skillAvailability = .unavailable(self.appString("app_model.status.skills_unavailable"))
            self.pendingSelectedSkills.removeAll()
            self.highlightedSkillID = nil
            self.dismissedSkillQuery = nil
            self.clearAuthDerivedState(authentication: self.authenticationStateFromCredentialStore())
            self.statusText = status == 0
                ? self.appString("app_model.status.stopped")
                : self.appString("app_model.status.exited_with_status", status)
            self.appendLog(
                title: self.appString("app_model.log.title.process_exited"),
                detail: self.appString("app_model.log.detail.exit_status", status)
            )
        }
    }

    private func applyLocalizedInitialState() {
        sessionTitle = appString("app_model.session.new_chat")
        statusText = appString("app_model.status.disconnected")
        launchDetail = appString("app_model.launch_detail.not_started")
        modelName = appString("app_model.model.no_model")
        gitDetails = GitBranchDetails(
            branch: appString("app_model.git.no_project_selected"),
            hasChanges: false,
            changeSummary: appString("app_model.git.open_project")
        )
        repositoryChangeSnapshot = .unavailable(reason: appString("app_model.change_review.open_project"))
    }

    private func bindStoreChanges() {
        relayStoreChanges(from: conversationStore)
        relayStoreChanges(from: toolActivityStore)
        relayStoreChanges(from: processLogStore)
        relayStoreChanges(from: workspaceStore)
        relayStoreChanges(from: sessionIndexStore)
        relayStoreChanges(from: settingsStore)
        relayStoreChanges(from: extensionUIRouter)
        relayStoreChanges(from: oauthLoginRunner)
    }

    private func relayStoreChanges<Store: ObservableObject>(from store: Store) {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)
    }

    private static func normalizePersistedProjects(_ persistedProjects: [ProjectItem]) -> [ProjectItem] {
        var seenPaths = Set<String>()
        return persistedProjects.compactMap { item in
            let normalizedPath = URL(fileURLWithPath: item.path).standardized.path
            guard !normalizedPath.isEmpty,
                  !seenPaths.contains(normalizedPath)
            else {
                return nil
            }
            seenPaths.insert(normalizedPath)

            var normalizedItem = item
            normalizedItem.path = normalizedPath
            if normalizedItem.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalizedItem.name = URL(fileURLWithPath: normalizedPath).lastPathComponent
            }
            return normalizedItem
        }
    }

    var skillPickerState: SkillPickerState? {
        guard let query = currentSkillQuery else { return nil }
        if dismissedSkillQuery == query {
            return nil
        }

        switch skillAvailability {
        case .notLoaded:
            return SkillPickerState(
                query: query,
                results: [],
                highlightedSkillID: nil,
                status: .unavailable(appString("app_model.status.skills_loading"))
            )
        case .unavailable(let message):
            return SkillPickerState(
                query: query,
                results: [],
                highlightedSkillID: nil,
                status: .unavailable(message)
            )
        case .loaded:
            let results = SkillSelectionLogic.search(query.searchText, in: availableSkills)
            let highlighted = highlightedSkillID.flatMap { id in
                results.contains { $0.id == id } ? id : nil
            } ?? results.first?.id
            return SkillPickerState(
                query: query,
                results: results,
                highlightedSkillID: highlighted,
                status: results.isEmpty ? .empty : .results
            )
        }
    }

    public func start() {
        clearQueuedWork()
        guard let selectedProject else {
            statusText = appString("app_model.status.open_project")
            launchDetail = appString("app_model.launch_detail.choose_project")
            return
        }

        workspacePath = selectedProject.path
        UserDefaults.standard.set(customExecutablePath, forKey: "customExecutablePath")

        do {
            clearSkillSelectionState(clearAvailableSkills: true)
            clearAuthDerivedState(
                authentication: authenticationStateFromCredentialStore(),
                modelAccess: .refreshing,
                subscriptionAccess: .refreshing
            )
            let launch = try client.start(workspacePath: selectedProject.path, customExecutable: customExecutablePath)
            isConnected = true
            statusText = appString("app_model.status.connected")
            launchDetail = "\(launch.displayName): \(launch.diagnostic)"
            appendLog(title: appString("app_model.log.title.started_pi_rpc"), detail: "\(launch.diagnostic) --mode rpc")
            beginAccessRefresh(reason: "pi rpc start")
            sendCommand(.getCommands())
            if shouldSwitchToStoredSessionAfterStart,
               let selectedSession,
               !selectedSession.sessionFile.isEmpty {
                shouldSwitchToStoredSessionAfterStart = false
                sendCommand(.switchSession(sessionPath: selectedSession.sessionFile))
            }
        } catch {
            isConnected = false
            statusText = appString("app_model.status.launch_failed")
            skillAvailability = .unavailable(appString("app_model.status.skills_unavailable"))
            clearAuthDerivedState(
                authentication: authenticationStateFromCredentialStore(),
                modelAccess: .failed(message: error.localizedDescription),
                subscriptionAccess: .failed(message: error.localizedDescription)
            )
            appendLog(title: appString("app_model.log.title.launch_failed"), detail: error.localizedDescription)
        }
    }

    public func stop() {
        client.stop()
        isConnected = false
        isStreaming = false
        clearQueuedWork()
        statusText = appString("app_model.status.stopped")
        clearSkillSelectionState(clearAvailableSkills: true)
        clearAuthDerivedState(authentication: authenticationStateFromCredentialStore())
    }

    func sendPrompt() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || !pendingContextAttachments.isEmpty else { return }
        guard !isStreaming else { return }
        guard selectedProject != nil else {
            statusText = appString("app_model.status.open_project")
            return
        }
        guard !isCreatingNewSession else { return }

        let submission = SkillSelectionLogic.parseSubmission(prompt)

        switch submission {
        case .normalPrompt:
            guard validatePendingContextAttachmentsForSubmission() else {
                return
            }
            if !isConnected {
                start()
            }
            if let message = authAccess.sendPromptUnavailableMessage(l10n: l10n) {
                statusText = appString("app_model.status.model_access_unavailable")
                appendLog(title: appString("app_model.log.title.prompt_blocked"), detail: message)
                return
            }
        case .invalid(let message):
            statusText = appString("app_model.status.invalid_skill_command")
            appendLog(title: appString("app_model.log.title.skill_selection_failed"), detail: message)
            return
        case .selection(let skillIDs):
            if !isConnected {
                start()
            }
            submitSkillSelection(skillIDs)
            return
        }

        let rpcPrompt: String
        do {
            let attachmentPrompt = ContextAttachmentPromptDecorator.decoratedPrompt(
                userPrompt: prompt,
                attachments: pendingContextAttachments
            )
            rpcPrompt = try SkillPromptDecorator.decoratedPrompt(userPrompt: attachmentPrompt, skills: pendingSelectedSkills)
        } catch {
            statusText = appString("app_model.status.skill_expansion_failed")
            appendLog(title: appString("app_model.log.title.skill_expansion_failed"), detail: error.localizedDescription)
            return
        }

        messages.append(ChatMessage(role: .user, title: appString("chat.message.title.you"), text: prompt))
        closeMentionPicker()
        if shouldReplaceGeneratedTitle(sessionTitle) {
            sessionTitle = prompt.truncatedSessionTitle()
            persistCurrentSessionSnapshot()
        }
        composerText = ""
        pendingSelectedSkills.removeAll()
        pendingContextAttachments.removeAll()

        if selectedSessionID == nil {
            pendingPromptAfterNewSession = rpcPrompt
            isCreatingNewSession = true
            isSwitchingSession = false
            sendCommand(.newSession())
        } else {
            sendPromptCommand(rpcPrompt)
        }
    }

    public func newSession() {
        guard selectedProject != nil else {
            statusText = appString("app_model.status.open_project")
            return
        }
        persistCurrentSessionSnapshot()
        selectedSessionID = nil
        conversationStore.clear()
        toolActivityStore.clear()
        clearQueuedWork(waitForContextRefresh: true)
        sessionTitle = appString("app_model.session.new_chat")
        statusText = isConnected ? appString("app_model.status.ready") : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        clearSkillSelectionState(clearAvailableSkills: false)
        clearPendingContextAttachments()
        persistState()
    }

    public func performAppAction(_ actionID: AppActionID) {
        guard canPerformAppAction(actionID) else {
            explainUnavailableAppAction(actionID)
            return
        }

        switch actionID {
        case .newChat:
            newSession()
        case .openProject:
            openProject()
        case .openCommandPalette:
            showCommandPalette()
        case .focusComposer:
            focusComposer()
        case .refreshState:
            refreshState()
        case .openSettings:
            isShowingSettings = true
        case .openProcessLog:
            isShowingProcessLog = true
        case .openKeybindingHelp:
            isShowingKeybindingHelp = true
        case .toggleSidebar:
            withAnimation(.easeInOut(duration: 0.16)) {
                isSidebarVisible.toggle()
            }
        case .toggleInspector:
            withAnimation(.easeInOut(duration: 0.16)) {
                isInspectorVisible.toggle()
            }
        case .sendPrompt:
            sendPrompt()
        case .stopGeneration:
            stopGeneration()
        case .insertComposerNewline:
            break
        case .cycleThinkingLevel:
            cycleThinkingLevel()
        case .closeActiveModal:
            closeActiveModal()
        }
    }

    public func canPerformAppAction(_ actionID: AppActionID) -> Bool {
        canPerformAppAction(actionID, ignoringCommandPalette: false)
    }

    private func canPerformAppAction(_ actionID: AppActionID, ignoringCommandPalette: Bool) -> Bool {
        let activeModalBlocksAction = ignoringCommandPalette ? hasActiveModalExcludingCommandPalette : hasActiveModal
        if activeModalBlocksAction, actionID != .closeActiveModal {
            return false
        }

        switch actionID {
        case .newChat:
            return selectedProject != nil
        case .openProject, .focusComposer, .openSettings, .openProcessLog, .openKeybindingHelp, .toggleSidebar, .toggleInspector:
            return true
        case .openCommandPalette:
            return !hasActiveModalExcludingCommandPalette
        case .refreshState:
            return selectedProject != nil
        case .sendPrompt:
            return canSendPrompt
        case .stopGeneration:
            return isStreaming
        case .insertComposerNewline, .cycleThinkingLevel:
            return true
        case .closeActiveModal:
            return hasActiveModal
        }
    }

    private func explainUnavailableAppAction(_ actionID: AppActionID) {
        guard actionID == .sendPrompt else { return }
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard submissionRequiresModelAccess(prompt), let message = authAccess.sendPromptUnavailableMessage(l10n: l10n) else { return }
        statusText = appString("app_model.status.model_access_unavailable")
        appendLog(title: appString("app_model.log.title.prompt_blocked"), detail: message)
    }

    private func submissionRequiresModelAccess(_ prompt: String) -> Bool {
        if case .normalPrompt = SkillSelectionLogic.parseSubmission(prompt) {
            return true
        }
        return false
    }

    public func handleEscapeKey() -> Bool {
        if isShowingCommandPalette {
            closeCommandPalette()
            return true
        }

        if hasActiveModal {
            closeActiveModal()
            return true
        }

        if isStreaming {
            stopGeneration()
            return true
        }

        return false
    }

    public func handleWindowKeyDown(_ event: NSEvent) -> Bool {
        if let escapeDefinition = DefaultKeymap.firstDefinition(for: .closeActiveModal),
           escapeDefinition.matches(event) {
            return handleEscapeKey()
        }

        guard let definition = DefaultKeymap.appWideDefinition(matching: event),
              canPerformAppAction(definition.actionID)
        else {
            return false
        }

        performAppAction(definition.actionID)
        return true
    }

    public func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = appString("app_model.open_panel.prompt")
        panel.message = appString("app_model.open_panel.message")

        if panel.runModal() == .OK, let url = panel.url {
            addProject(path: url.path)
        }
    }

    public func focusComposer() {
        composerFocusRequest += 1
    }

    var canSendPrompt: Bool {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming,
              !prompt.isEmpty || !pendingContextAttachments.isEmpty,
              selectedProject != nil,
              !isCreatingNewSession
        else { return false }

        return !submissionRequiresModelAccess(prompt) || authAccess.hasAvailableModelAccess
    }

    func canPerformSubscriptionGatedAction() -> Bool {
        authAccess.hasActiveSubscriptionAccess
    }

    @discardableResult
    func requireSubscriptionAccess(actionName: String) -> Bool {
        guard let message = authAccess.subscriptionGateUnavailableMessage(l10n: l10n) else { return true }
        statusText = appString("app_model.status.subscription_access_unavailable")
        appendLog(
            title: appString("app_model.log.title.subscription_action_blocked"),
            detail: appString("app_model.log.detail.subscription_action_blocked", actionName, message)
        )
        return false
    }

    var hasActiveModal: Bool {
        isShowingCommandPalette ||
            hasActiveModalExcludingCommandPalette
    }

    var hasActiveModalExcludingCommandPalette: Bool {
        isShowingKeybindingHelp ||
            isShowingSettings ||
            isShowingLogin ||
            isShowingModelPicker ||
            isShowingProcessLog ||
            isShowingChangeReview ||
            extensionUIRouter.activeRequest != nil
    }

    func closeActiveModal() {
        if isShowingCommandPalette {
            closeCommandPalette()
        } else if isShowingKeybindingHelp {
            isShowingKeybindingHelp = false
        } else if isShowingSettings {
            isShowingSettings = false
        } else if isShowingLogin {
            dismissLoginSheet()
        } else if isShowingModelPicker {
            isShowingModelPicker = false
        } else if isShowingProcessLog {
            isShowingProcessLog = false
        } else if isShowingChangeReview {
            isShowingChangeReview = false
        } else if extensionUIRouter.activeRequest != nil {
            cancelExtensionUIRequest()
        }
    }

    func showCommandPalette() {
        guard !hasActiveModalExcludingCommandPalette else {
            statusText = appString("app_model.status.close_active_modal_first")
            return
        }

        commandPaletteQuery = ""
        isShowingCommandPalette = true
        refreshCommandPaletteHighlight()
    }

    func closeCommandPalette() {
        isShowingCommandPalette = false
        commandPaletteQuery = ""
        commandPaletteHighlightedItemID = nil
    }

    func commandPaletteItems() -> [CommandPaletteItem] {
        var items = staticCommandPaletteItems()

        items.append(contentsOf: projects.map { project in
            CommandPaletteItem(
                id: "project:\(project.id)",
                title: appString("command_palette.project.title", project.name),
                subtitle: project.path,
                keywords: appStringList("command_palette.project.keywords") + [project.name, project.path],
                iconSystemName: "folder",
                keybindingLabel: nil,
                availability: .enabled,
                invocation: .selectProject(project.id)
            )
        })

        if let selectedProject {
            items.append(contentsOf: sessionsForProject(selectedProject).map { session in
                CommandPaletteItem(
                    id: "session:\(session.id)",
                    title: appString("command_palette.session.title", session.title),
                    subtitle: session.status,
                    keywords: appStringList("command_palette.session.keywords") + [selectedProject.name, session.title, session.status],
                    iconSystemName: "bubble.left.and.text.bubble.right",
                    keybindingLabel: nil,
                    availability: .enabled,
                    invocation: .switchSession(session.id)
                )
            })
        }

        items.append(contentsOf: availableModels.map { model in
            CommandPaletteItem(
                id: "model:\(model.provider):\(model.modelId)",
                title: appString("command_palette.model.title", model.displayName),
                subtitle: model.id,
                keywords: appStringList("command_palette.model.keywords") + [model.provider, model.modelId, model.name],
                iconSystemName: "cpu",
                keybindingLabel: nil,
                availability: .enabled,
                invocation: .selectModel(provider: model.provider, modelID: model.modelId)
            )
        })

        items.append(contentsOf: CommandPaletteCatalog.thinkingLevels.map { level in
            CommandPaletteItem(
                id: "thinking:\(level)",
                title: appString("command_palette.thinking.title", localizedThinkingLevelDisplay(level)),
                subtitle: level == thinkingLevel ? appString("command_palette.thinking.current") : nil,
                keywords: appStringList("command_palette.thinking.keywords") + [level, localizedThinkingLevelDisplay(level)],
                iconSystemName: "brain.head.profile",
                keybindingLabel: nil,
                availability: .enabled,
                invocation: .setThinkingLevel(level)
            )
        })

        if selectedProject != nil {
            items.append(contentsOf: availableExternalTargets.map { target in
                CommandPaletteItem(
                    id: "external:\(target.id.rawValue)",
                    title: appString("command_palette.external.title", target.displayName),
                    subtitle: selectedProject?.path,
                    keywords: appStringList("command_palette.external.keywords") + [target.displayName, target.id.rawValue],
                    iconSystemName: target.fallbackSystemImage,
                    keybindingLabel: nil,
                    availability: .enabled,
                    invocation: .openExternalTarget(target.id)
                )
            })
        }

        return items
    }

    func filteredCommandPaletteItems(query: String) -> [CommandPaletteItem] {
        CommandPaletteFilter.filteredItems(commandPaletteItems(), query: query)
    }

    func refreshCommandPaletteHighlight() {
        let items = filteredCommandPaletteItems(query: commandPaletteQuery)
        if let highlightedID = commandPaletteHighlightedItemID,
           items.contains(where: { $0.id == highlightedID }) {
            return
        }
        commandPaletteHighlightedItemID = items.first?.id
    }

    func moveCommandPaletteHighlight(by delta: Int) {
        let items = filteredCommandPaletteItems(query: commandPaletteQuery)
        guard !items.isEmpty else {
            commandPaletteHighlightedItemID = nil
            return
        }

        let currentIndex = commandPaletteHighlightedItemID.flatMap { id in
            items.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = (currentIndex + delta + items.count) % items.count
        commandPaletteHighlightedItemID = items[nextIndex].id
    }

    func runHighlightedCommandPaletteItem() {
        let items = filteredCommandPaletteItems(query: commandPaletteQuery)
        guard let item = commandPaletteHighlightedItemID.flatMap({ highlightedID in
            items.first { $0.id == highlightedID }
        }) ?? items.first else { return }

        runCommandPaletteItem(item)
    }

    func runCommandPaletteItem(_ item: CommandPaletteItem) {
        let availability = commandPaletteAvailability(for: item.invocation)
        guard availability.isEnabled else {
            statusText = availability.disabledReason ?? appString("app_model.status.command_unavailable")
            return
        }

        guard let resolvedInvocation = resolveCommandPaletteInvocation(item.invocation) else {
            statusText = appString("app_model.status.command_unavailable")
            return
        }

        closeCommandPalette()
        performCommandPaletteInvocation(resolvedInvocation)
    }

    private func staticCommandPaletteItems() -> [CommandPaletteItem] {
        let staticActions: [StaticCommandPaletteAction] = [
            StaticCommandPaletteAction(
                actionID: .newChat,
                subtitleKey: "command_palette.action.new_chat.subtitle",
                keywordsKey: "command_palette.action.new_chat.keywords",
                iconSystemName: "square.and.pencil"
            ),
            StaticCommandPaletteAction(
                actionID: .openProject,
                subtitleKey: "command_palette.action.open_project.subtitle",
                keywordsKey: "command_palette.action.open_project.keywords",
                iconSystemName: "folder.badge.plus"
            ),
            StaticCommandPaletteAction(
                actionID: .focusComposer,
                subtitleKey: "command_palette.action.focus_composer.subtitle",
                keywordsKey: "command_palette.action.focus_composer.keywords",
                iconSystemName: "text.cursor"
            ),
            StaticCommandPaletteAction(
                actionID: .refreshState,
                subtitleKey: "command_palette.action.refresh_state.subtitle",
                keywordsKey: "command_palette.action.refresh_state.keywords",
                iconSystemName: "arrow.clockwise"
            ),
            StaticCommandPaletteAction(
                actionID: .openSettings,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.open_settings.keywords",
                iconSystemName: "gearshape"
            ),
            StaticCommandPaletteAction(
                actionID: .openProcessLog,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.open_process_log.keywords",
                iconSystemName: "list.bullet.rectangle"
            ),
            StaticCommandPaletteAction(
                actionID: .openKeybindingHelp,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.open_keybinding_help.keywords",
                iconSystemName: "keyboard"
            ),
            StaticCommandPaletteAction(
                actionID: .toggleSidebar,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.toggle_sidebar.keywords",
                iconSystemName: "sidebar.left"
            ),
            StaticCommandPaletteAction(
                actionID: .toggleInspector,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.toggle_inspector.keywords",
                iconSystemName: "sidebar.right"
            ),
            StaticCommandPaletteAction(
                actionID: .sendPrompt,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.send_prompt.keywords",
                iconSystemName: "paperplane"
            ),
            StaticCommandPaletteAction(
                actionID: .stopGeneration,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.stop_generation.keywords",
                iconSystemName: "stop.fill"
            ),
            StaticCommandPaletteAction(
                actionID: .cycleThinkingLevel,
                subtitleKey: nil,
                keywordsKey: "command_palette.action.cycle_thinking_level.keywords",
                iconSystemName: "brain.head.profile"
            )
        ]

        var items = staticActions.map { action in
            CommandPaletteItem(
                id: "action:\(action.actionID.rawValue)",
                title: localizedTitle(for: action.actionID),
                subtitle: action.subtitleKey.map { appString($0) },
                keywords: appStringList(action.keywordsKey),
                iconSystemName: action.iconSystemName,
                keybindingLabel: DefaultKeymap.displayLabel(for: action.actionID),
                availability: commandPaletteAvailability(for: .appAction(action.actionID)),
                invocation: .appAction(action.actionID)
            )
        }

        items.append(CommandPaletteItem(
            id: "login",
            title: appString("command_palette.login.title"),
            subtitle: appString("command_palette.login.subtitle"),
            keywords: appStringList("command_palette.login.keywords"),
            iconSystemName: "key",
            keybindingLabel: nil,
            availability: commandPaletteAvailability(for: .showLogin),
            invocation: .showLogin
        ))

        items.append(CommandPaletteItem(
            id: "model-picker",
            title: appString("command_palette.model_picker.title"),
            subtitle: modelName,
            keywords: appStringList("command_palette.model_picker.keywords") + [modelName],
            iconSystemName: "cpu",
            keybindingLabel: nil,
            availability: commandPaletteAvailability(for: .showModelPicker),
            invocation: .showModelPicker
        ))

        return items
    }

    private func localizedThinkingLevelDisplay(_ level: String) -> String {
        switch level {
        case "off":
            return appString("command_palette.thinking.level.off")
        case "minimal":
            return appString("command_palette.thinking.level.minimal")
        case "low":
            return appString("command_palette.thinking.level.low")
        case "medium":
            return appString("command_palette.thinking.level.medium")
        case "high":
            return appString("command_palette.thinking.level.high")
        case "xhigh":
            return appString("command_palette.thinking.level.xhigh")
        default:
            return level
        }
    }

    private func commandPaletteAvailability(for invocation: CommandPaletteInvocation) -> CommandPaletteAvailability {
        switch invocation {
        case .appAction(let actionID):
            guard canPerformAppAction(actionID, ignoringCommandPalette: true) else {
                return .disabled(reason: unavailableReason(for: actionID))
            }
            return .enabled

        case .selectProject(let projectID):
            return projects.contains(where: { $0.id == projectID })
                ? .enabled
                : .disabled(reason: appString("app_model.availability.project_no_longer_available"))

        case .switchSession(let sessionID):
            guard let selectedProject else {
                return .disabled(reason: appString("app_model.availability.open_project_first"))
            }
            return sessionsForProject(selectedProject).contains(where: { $0.id == sessionID })
                ? .enabled
                : .disabled(reason: appString("app_model.availability.session_no_longer_available"))

        case .selectModel(let provider, let modelID):
            return availableModels.contains { $0.provider == provider && $0.modelId == modelID }
                ? .enabled
                : .disabled(reason: appString("app_model.availability.model_no_longer_available"))

        case .setThinkingLevel(let level):
            return CommandPaletteCatalog.thinkingLevels.contains(level)
                ? .enabled
                : .disabled(reason: appString("app_model.availability.thinking_level_not_supported"))

        case .openExternalTarget(let targetID):
            guard selectedProject != nil else {
                return .disabled(reason: appString("app_model.availability.open_project_first"))
            }
            return availableExternalTargets.contains(where: { $0.id == targetID })
                ? .enabled
                : .disabled(reason: appString("app_model.availability.external_target_no_longer_available"))

        case .showLogin, .showModelPicker:
            return hasActiveModalExcludingCommandPalette
                ? .disabled(reason: appString("app_model.status.close_active_modal_first"))
                : .enabled
        }
    }

    private func unavailableReason(for actionID: AppActionID) -> String {
        if hasActiveModalExcludingCommandPalette {
            return appString("app_model.status.close_active_modal_first")
        }

        switch actionID {
        case .newChat, .refreshState:
            return appString("app_model.availability.open_project_first")
        case .sendPrompt:
            if selectedProject == nil {
                return appString("app_model.availability.open_project_first")
            }
            if isStreaming {
                return appString("app_model.availability.generation_already_running")
            }
            if isCreatingNewSession {
                return appString("app_model.availability.wait_new_chat")
            }
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return appString("app_model.availability.enter_prompt_first")
            }
            if let message = authAccess.sendPromptUnavailableMessage(l10n: l10n) {
                return message
            }
            return appString("app_model.availability.prompt_cannot_be_sent")
        case .stopGeneration:
            return appString("app_model.availability.nothing_running")
        case .closeActiveModal:
            return appString("app_model.availability.no_active_modal")
        case .openProject,
             .openCommandPalette,
             .focusComposer,
             .openSettings,
             .openProcessLog,
             .openKeybindingHelp,
             .toggleSidebar,
             .toggleInspector,
             .insertComposerNewline,
             .cycleThinkingLevel:
            return appString("app_model.status.command_unavailable")
        }
    }

    private func resolveCommandPaletteInvocation(_ invocation: CommandPaletteInvocation) -> ResolvedCommandPaletteInvocation? {
        switch invocation {
        case .appAction(let actionID):
            return .appAction(actionID)
        case .selectProject(let projectID):
            guard let project = projects.first(where: { $0.id == projectID }) else { return nil }
            return .selectProject(project)
        case .switchSession(let sessionID):
            guard let selectedProject,
                  let session = sessionsForProject(selectedProject).first(where: { $0.id == sessionID })
            else { return nil }
            return .switchSession(session)
        case .selectModel(let provider, let modelID):
            guard let model = availableModels.first(where: { $0.provider == provider && $0.modelId == modelID }) else { return nil }
            return .selectModel(model)
        case .setThinkingLevel(let level):
            guard CommandPaletteCatalog.thinkingLevels.contains(level) else { return nil }
            return .setThinkingLevel(level)
        case .openExternalTarget(let targetID):
            guard selectedProject != nil,
                  let target = availableExternalTargets.first(where: { $0.id == targetID })
            else { return nil }
            return .openExternalTarget(target)
        case .showLogin:
            return .showLogin
        case .showModelPicker:
            return .showModelPicker
        }
    }

    private func performCommandPaletteInvocation(_ invocation: ResolvedCommandPaletteInvocation) {
        switch invocation {
        case .appAction(let actionID):
            performAppAction(actionID)
        case .selectProject(let project):
            selectProject(project)
        case .switchSession(let session):
            switchSession(session)
        case .selectModel(let model):
            selectModel(model)
        case .setThinkingLevel(let level):
            setThinkingLevel(level)
        case .openExternalTarget(let target):
            openExternally(target)
        case .showLogin:
            isShowingLogin = true
        case .showModelPicker:
            showModelPicker()
        }
    }

    func stopGeneration() {
        guard isStreaming else { return }
        abort()
    }

    func abort() {
        sendCommand(.abort())
    }

    func refreshState() {
        if !isConnected {
            start()
        } else {
            beginAccessRefresh(reason: "manual refresh")
            sendCommand(.getSessionStats())
            sendCommand(.getCommands())
        }
        refreshGitDetails()
        refreshRepositoryChangeSnapshot()
        refreshPendingContextAttachmentResolution()
    }

    func openChangeReview() {
        guard selectedProject != nil else {
            repositoryChangeSnapshot = .unavailable(reason: appString("app_model.change_review.open_project"))
            return
        }
        isShowingChangeReview = true
        refreshRepositoryChangeSnapshot()
    }

    func canNavigateToPreviousSession() -> Bool {
        sessionNavigationTarget(for: .previous) != nil
    }

    func canNavigateToNextSession() -> Bool {
        sessionNavigationTarget(for: .next) != nil
    }

    func navigateToPreviousSession() {
        navigateSession(.previous)
    }

    func navigateToNextSession() {
        navigateSession(.next)
    }

    func previousSessionHelpText() -> String {
        sessionNavigationUnavailableReason(for: .previous) ?? appString("app_model.session.previous")
    }

    func nextSessionHelpText() -> String {
        sessionNavigationUnavailableReason(for: .next) ?? appString("app_model.session.next")
    }

    private func navigateSession(_ direction: SessionNavigationDirection) {
        guard let target = sessionNavigationTarget(for: direction) else { return }
        switchSession(target)
    }

    private func sessionNavigationTarget(for direction: SessionNavigationDirection) -> StoredSession? {
        guard !hasActiveModal,
              let selectedProject,
              let selectedSessionID
        else { return nil }

        let projectSessions = sessionsForProject(selectedProject)
        guard projectSessions.count > 1,
              let currentIndex = projectSessions.firstIndex(where: { $0.id == selectedSessionID })
        else { return nil }

        let adjacentIndex = currentIndex + direction.offset
        guard projectSessions.indices.contains(adjacentIndex) else { return nil }
        return projectSessions[adjacentIndex]
    }

    private func sessionNavigationUnavailableReason(for direction: SessionNavigationDirection) -> String? {
        if hasActiveModal {
            return appString("app_model.status.close_active_modal_first")
        }

        guard let selectedProject else {
            return appString("app_model.availability.open_project_first")
        }

        guard let selectedSessionID else {
            return appString("app_model.availability.select_session_first")
        }

        let projectSessions = sessionsForProject(selectedProject)
        guard projectSessions.count > 1 else {
            return appString("app_model.availability.no_other_sessions")
        }

        guard let currentIndex = projectSessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return appString("app_model.availability.select_session_in_project_first")
        }

        let adjacentIndex = currentIndex + direction.offset
        guard projectSessions.indices.contains(adjacentIndex) else {
            return sessionNavigationBoundaryReason(for: direction)
        }

        return nil
    }

    func updateComposerSelection(_ selectedRange: NSRange) {
        composerSelectionRange = selectedRange
        refreshMentionPicker()
    }

    func handleMentionCommand(_ command: MentionPickerCommand) -> Bool {
        guard mentionPickerState != nil else { return false }

        switch command {
        case .moveUp:
            moveMentionHighlight(by: -1)
        case .moveDown:
            moveMentionHighlight(by: 1)
        case .insertHighlighted:
            insertHighlightedMention()
        case .dismiss:
            closeMentionPicker()
        }
        return true
    }

    func highlightMentionResult(_ resultID: MentionSearchResult.ID) {
        guard var state = mentionPickerState,
              state.results.contains(where: { $0.id == resultID })
        else { return }

        state = MentionPickerState(
            query: state.query,
            results: state.results,
            highlightedResultID: resultID,
            status: state.status
        )
        mentionPickerState = state
    }

    func insertMentionResult(_ resultID: MentionSearchResult.ID) {
        guard let state = mentionPickerState,
              let result = state.results.first(where: { $0.id == resultID })
        else { return }

        insertMention(result)
    }

    func mentionTextReplacementWasApplied(_ id: UUID, wasApplied: Bool) {
        guard pendingMentionTextReplacement?.id == id else { return }
        pendingMentionTextReplacement = nil
        guard wasApplied else {
            if pendingContextAttachmentInsertion?.replacementID == id {
                pendingContextAttachmentInsertion = nil
            }
            refreshMentionPicker()
            return
        }
        if pendingContextAttachmentInsertion?.replacementID == id,
           let attachment = pendingContextAttachmentInsertion?.attachment {
            upsertPendingContextAttachment(attachment)
            pendingContextAttachmentInsertion = nil
        }
        refreshMentionPicker()
    }

    func showModelPicker() {
        ensureConnected()
        isShowingModelPicker = true
        if isConnected {
            beginAccessRefresh(reason: "model picker")
        }
    }

    func selectModel(_ model: PiModel) {
        sendCommand(.setModel(provider: model.provider, modelId: model.modelId))
    }

    func setThinkingLevel(_ level: String) {
        sendCommand(.setThinkingLevel(level))
    }

    func cycleThinkingLevel() {
        sendCommand(.cycleThinkingLevel())
    }

    func saveAPIKey(provider: LoginProvider, apiKey: String) throws {
        try NativeAuthStore.saveAPIKey(provider: provider.id, apiKey: apiKey)
        clearAuthDerivedState(
            authentication: .authenticated(providerID: provider.id),
            modelAccess: .refreshing,
            subscriptionAccess: .refreshing
        )
        appendLog(
            title: appString("app_model.log.title.saved_api_key"),
            detail: appString("app_model.log.detail.credentials_saved", NativeAuthStore.authFileURL.path)
        )
        restartRPC()
    }

    func logout(provider: LoginProvider) {
        do {
            if oauthLoginRunner.currentProvider?.id == provider.id, oauthLoginRunner.isRunning {
                if let attemptID = oauthLoginRunner.currentAttemptID {
                    handledSubscriptionLoginAttemptIDs.insert(attemptID)
                }
                oauthLoginRunner.stop()
            }
            try NativeAuthStore.removeCredential(provider: provider.id)
            clearAuthDerivedState(authentication: authenticationStateFromCredentialStore())
            appendLog(
                title: appString("app_model.log.title.logged_out"),
                detail: appString("app_model.log.detail.removed_credentials", provider.name)
            )
            restartRPC()
        } catch {
            authAccess.authentication = .failed(message: error.localizedDescription)
            authAccess.modelAccess = .failed(message: error.localizedDescription)
            authAccess.subscriptionAccess = .failed(message: error.localizedDescription)
            statusText = appString("app_model.status.logout_failed")
            appendLog(title: appString("app_model.log.title.logout_failed"), detail: error.localizedDescription)
        }
    }

    func startSubscriptionLogin(provider: LoginProvider) {
        clearAuthDerivedState(
            authentication: .authenticating(providerID: provider.id),
            modelAccess: .refreshing,
            subscriptionAccess: .refreshing
        )
        statusText = appString("app_model.status.login_in_progress")
        appendLog(
            title: appString("app_model.log.title.subscription_login"),
            detail: appString("app_model.log.detail.starting_login", provider.name)
        )
        switch oauthLoginRunner.start(provider: provider) {
        case .success:
            break
        case .failure(let error):
            completeFailedSubscriptionLogin(provider: provider, message: error.localizedDescription)
        }
    }

    func stopSubscriptionLogin() {
        guard let provider = oauthLoginRunner.currentProvider else {
            oauthLoginRunner.stop()
            return
        }
        oauthLoginRunner.stop()
        statusText = appString("app_model.status.stopping_login")
        appendLog(
            title: appString("app_model.log.title.subscription_login"),
            detail: appString("app_model.log.detail.stopping_login", provider.name)
        )
    }

    func dismissLoginSheet() {
        if oauthLoginRunner.isRunning {
            stopSubscriptionLogin()
        } else if let provider = oauthLoginRunner.currentProvider,
                  let attemptID = oauthLoginRunner.currentAttemptID,
                  let exitStatus = oauthLoginRunner.exitStatus {
            completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: exitStatus)
        }
        isShowingLogin = false
    }

    func completeSubscriptionLogin(provider: LoginProvider, attemptID: UUID, exitStatus: Int32) {
        guard oauthLoginRunner.currentAttemptID == attemptID else { return }
        guard handledSubscriptionLoginAttemptIDs.insert(attemptID).inserted else { return }
        if exitStatus == 0 {
            clearAuthDerivedState(
                authentication: .authenticated(providerID: provider.id),
                modelAccess: .refreshing,
                subscriptionAccess: .refreshing
            )
            appendLog(
                title: appString("app_model.log.title.subscription_login"),
                detail: appString("app_model.log.detail.login_finished_restart", provider.name)
            )
            restartRPC()
        } else {
            completeFailedSubscriptionLogin(
                provider: provider,
                message: appString("app_model.error.login_exited_status", exitStatus)
            )
        }
    }

    private func completeFailedSubscriptionLogin(provider: LoginProvider, message: String) {
        accessRefreshTracker.invalidate(
            state: &authAccess,
            authentication: .failed(message: message),
            modelAccess: .unavailable(reason: message),
            subscriptionAccess: .failed(message: message)
        )
        availableModels.removeAll()
        modelName = appString("app_model.model.no_model")
        statusText = appString("app_model.status.login_failed")
        appendLog(
            title: appString("app_model.log.title.subscription_login_failed"),
            detail: appString("app_model.log.detail.provider_message", provider.name, message)
        )
    }

    func selectProject(_ project: ProjectItem) {
        if let lastSession = sessionIndexStore.lastOpenedSession(for: project) {
            switchSession(lastSession, expandProject: true)
            return
        }

        selectProjectForNewChat(project)
    }

    func selectProjectForNewChat(_ project: ProjectItem) {
        persistCurrentSessionSnapshot()
        let shouldRestart = isConnected && workspacePath != project.path
        resetMentionContext(invalidateProjectAt: project.path)
        workspaceStore.select(project)
        selectedSessionID = nil
        conversationStore.clear()
        toolActivityStore.clear()
        sessionTitle = appString("app_model.session.new_chat")
        statusText = isConnected ? appString("app_model.status.ready") : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        clearSkillSelectionState(clearAvailableSkills: shouldRestart)
        persistState()
        refreshGitDetails()
        refreshRepositoryChangeSnapshot()
        if shouldRestart {
            restartRPC()
        }
    }

    func toggleProject(_ project: ProjectItem) {
        workspaceStore.toggle(project)
    }

    func switchSidebarSession(_ session: StoredSession, in project: ProjectItem) {
        guard project.isAvailable else {
            statusText = "Project unavailable"
            return
        }

        switchSession(session)
    }

    func addProject(path: String) {
        let project = workspaceStore.addProject(path: path)
        selectProject(project)
    }

    func removeSidebarStaleProject(_ project: ProjectItem) {
        removeStaleProject(project)
    }

    func removeStaleProject(_ project: ProjectItem) {
        guard project.availability == .stale else { return }
        removeLocalProjectRecord(project)
    }

    func removeLocalProjectRecord(_ project: ProjectItem) {
        let wasSelectedProject = selectedProjectID == project.id
        let wasConnectedToRemovedProject = wasSelectedProject && isConnected
        guard let removedProject = workspaceStore.removeProject(id: project.id) else { return }

        sessionIndexStore.removeSessions(forProjectID: removedProject.id)

        if wasSelectedProject {
            if wasConnectedToRemovedProject {
                stop()
            }
            resetMentionContext(invalidateProjectAt: removedProject.path)
            conversationStore.clear()
            toolActivityStore.clear()
            clearQueuedWork()
            sessionTitle = "New chat"
            statusText = "Open a project"
            isCreatingNewSession = false
            isSwitchingSession = false
            pendingPromptAfterNewSession = nil
            clearSkillSelectionState(clearAvailableSkills: wasConnectedToRemovedProject)
        }

        appendLog(title: "removed project record", detail: "projectID=\(removedProject.id) path=\(removedProject.path)")
        persistState()
        refreshGitDetails()
        refreshRepositoryChangeSnapshot()
    }

    func openExternally(_ target: AvailableExternalTarget) {
        guard let selectedProject else {
            statusText = appString("app_model.status.open_project")
            return
        }

        let projectPath = selectedProject.path
        externalTargetLauncher(target, projectPath) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case .failure(let error) = result {
                    self.statusText = self.appString("app_model.status.could_not_open_in", target.displayName)
                    self.appendLog(
                        title: self.appString("app_model.log.title.open_externally_failed"),
                        detail: self.appString(
                            "app_model.log.detail.open_externally_failed",
                            target.displayName,
                            projectPath,
                            error.localizedDescription
                        )
                    )
                }
            }
        }
    }

    func openChangedFileExternally(_ file: ChangedFile, target: AvailableExternalTarget) {
        guard let selectedProject else {
            statusText = appString("app_model.status.open_project")
            return
        }

        let fileURL = URL(fileURLWithPath: selectedProject.path).appendingPathComponent(file.path)
        let launchPath = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL.path : selectedProject.path
        externalTargetLauncher(target, launchPath) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case .failure(let error) = result {
                    self.statusText = self.appString("app_model.status.could_not_open_file_in", file.path, target.displayName)
                    self.appendLog(
                        title: self.appString("app_model.log.title.open_changed_file_failed"),
                        detail: self.appString(
                            "app_model.log.detail.open_changed_file_failed",
                            target.displayName,
                            launchPath,
                            error.localizedDescription
                        )
                    )
                }
            }
        }
    }

    var selectedProject: ProjectItem? {
        workspaceStore.selectedProject
    }

    var selectedSession: StoredSession? {
        sessionIndexStore.selectedSession
    }

    func removePendingSkill(_ skill: AvailableSkill) {
        pendingSelectedSkills.removeAll { $0.id == skill.id }
    }

    func clearPendingSkills() {
        pendingSelectedSkills.removeAll()
    }

    func removePendingContextAttachment(_ attachment: ContextAttachment) {
        pendingContextAttachments.removeAll { $0.id == attachment.id }
    }

    func clearPendingContextAttachments() {
        pendingContextAttachments.removeAll()
        pendingContextAttachmentInsertion = nil
    }

    func handleComposerControlKey(_ key: ComposerControlKey) -> Bool {
        guard let pickerState = skillPickerState else { return false }

        switch key {
        case .up:
            moveSkillHighlight(delta: -1, in: pickerState)
            return !pickerState.results.isEmpty
        case .down:
            moveSkillHighlight(delta: 1, in: pickerState)
            return !pickerState.results.isEmpty
        case .returnKey, .tab:
            guard let highlightedSkillID = pickerState.highlightedSkillID,
                  let skill = pickerState.results.first(where: { $0.id == highlightedSkillID })
            else { return false }
            completeSkillQuery(with: skill)
            return true
        case .escape:
            dismissedSkillQuery = pickerState.query
            highlightedSkillID = nil
            return true
        }
    }

    func highlightSkill(_ skill: AvailableSkill) {
        highlightedSkillID = skill.id
    }

    func completeSkillQuery(with skill: AvailableSkill) {
        guard let query = currentSkillQuery else { return }
        let replacement = SkillSelectionLogic.replacement(for: skill.id, in: composerText, query: query)
        composerText = replacement.text
        composerSelectionRange = replacement.selectedRange
        highlightedSkillID = nil
        dismissedSkillQuery = nil
    }

    func sessionsForProject(_ project: ProjectItem) -> [StoredSession] {
        sessionIndexStore.sessionsForProject(project, runningSessionID: selectedSessionID) { session in
            isRunningSession(session)
        }
    }

    private func refreshMentionPicker() {
        guard pendingMentionTextReplacement == nil,
              let selectedProject,
              !selectedProject.path.isEmpty,
              let query = MentionQueryDetector.activeQuery(in: composerText, selectedRange: composerSelectionRange)
        else {
            closeMentionPicker()
            return
        }

        let projectPath = selectedProject.path
        if let entries = mentionIndexCache[projectPath] {
            applyMentionSearch(entries: entries, query: query)
            return
        }

        mentionPickerState = MentionPickerState(
            query: query,
            results: [],
            highlightedResultID: nil,
            status: .indexing
        )
        loadMentionIndexIfNeeded(for: projectPath)
    }

    private func applyMentionSearch(entries: [MentionIndexEntry], query: MentionQuery) {
        let results = MentionSearcher.search(entries: entries, query: query)
        let previousHighlight = mentionPickerState?.highlightedResultID
        let highlightedID: MentionSearchResult.ID?
        if let previousHighlight, results.contains(where: { $0.id == previousHighlight }) {
            highlightedID = previousHighlight
        } else {
            highlightedID = results.first?.id
        }

        mentionPickerState = MentionPickerState(
            query: query,
            results: results,
            highlightedResultID: highlightedID,
            status: results.isEmpty ? .noMatches : .ready
        )
    }

    private func loadMentionIndexIfNeeded(for projectPath: String) {
        guard mentionIndexLoadingProjectPath != projectPath else { return }
        mentionIndexTask?.cancel()
        mentionIndexLoadingProjectPath = projectPath
        mentionIndexTask = Task.detached(priority: .utility) {
            let provider = MentionIndexProvider()
            let result: Result<[MentionIndexEntry], Error>
            do {
                result = .success(try provider.entries(forProjectAt: URL(fileURLWithPath: projectPath)))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                self.applyMentionIndexLoadResult(result, projectPath: projectPath)
            }
        }
    }

    private func applyMentionIndexLoadResult(
        _ result: Result<[MentionIndexEntry], Error>,
        projectPath: String
    ) {
        guard mentionIndexLoadingProjectPath == projectPath else { return }
        mentionIndexLoadingProjectPath = nil
        mentionIndexTask = nil

        guard selectedProject?.path == projectPath,
              let state = mentionPickerState
        else { return }

        switch result {
        case .success(let entries):
            mentionIndexCache[projectPath] = entries
            applyMentionSearch(entries: entries, query: state.query)
        case .failure:
            mentionPickerState = MentionPickerState(
                query: state.query,
                results: [],
                highlightedResultID: nil,
                status: .unavailable
            )
        }
    }

    private func moveMentionHighlight(by delta: Int) {
        guard let state = mentionPickerState, !state.results.isEmpty else { return }
        let currentIndex = state.highlightedResultID.flatMap { id in
            state.results.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = (currentIndex + delta + state.results.count) % state.results.count
        mentionPickerState = MentionPickerState(
            query: state.query,
            results: state.results,
            highlightedResultID: state.results[nextIndex].id,
            status: state.status
        )
    }

    private func insertHighlightedMention() {
        guard let result = mentionPickerState?.highlightedResult else { return }
        insertMention(result)
    }

    private func insertMention(_ result: MentionSearchResult) {
        guard let state = mentionPickerState,
              let selectedProject,
              let replacement = MentionInserter.replacement(
                for: result.entry,
                query: state.query,
                in: composerText,
                projectRoot: URL(fileURLWithPath: selectedProject.path)
              )
        else { return }

        pendingMentionTextReplacement = replacement
        let initialStatus = ContextAttachmentResolver.resolve(
            ContextAttachment.make(
                from: result.entry,
                selectedProject: selectedProject,
                status: .valid(resolvedURL: result.entry.resolvedURL)
            ),
            selectedProject: selectedProject
        )
        pendingContextAttachmentInsertion = (
            replacementID: replacement.id,
            attachment: ContextAttachment.make(
                from: result.entry,
                selectedProject: selectedProject,
                status: initialStatus
            )
        )
        closeMentionPicker()
    }

    private func closeMentionPicker() {
        mentionPickerState = nil
    }

    private func invalidateMentionIndex(for projectPath: String?) {
        if let projectPath {
            mentionIndexCache.removeValue(forKey: projectPath)
        } else {
            mentionIndexCache.removeAll()
        }
        if mentionIndexLoadingProjectPath == projectPath || projectPath == nil {
            mentionIndexTask?.cancel()
            mentionIndexTask = nil
            mentionIndexLoadingProjectPath = nil
        }
        closeMentionPicker()
    }

    private func resetMentionContext(invalidateProjectAt projectPath: String?) {
        pendingMentionTextReplacement = nil
        clearPendingContextAttachments()
        invalidateMentionIndex(for: projectPath)
    }

    private func upsertPendingContextAttachment(_ attachment: ContextAttachment) {
        var refreshedAttachment = attachment
        refreshedAttachment.status = ContextAttachmentResolver.resolve(
            attachment,
            selectedProject: selectedProject
        )

        if let index = pendingContextAttachments.firstIndex(where: { $0.id == refreshedAttachment.id }) {
            pendingContextAttachments[index] = refreshedAttachment
        } else {
            pendingContextAttachments.append(refreshedAttachment)
        }
    }

    private func refreshPendingContextAttachmentResolution() {
        guard !pendingContextAttachments.isEmpty else { return }
        pendingContextAttachments = ContextAttachmentResolver.refreshed(
            pendingContextAttachments,
            selectedProject: selectedProject
        )
    }

    private func validatePendingContextAttachmentsForSubmission() -> Bool {
        refreshPendingContextAttachmentResolution()
        let invalidAttachments = pendingContextAttachments.filter { !$0.status.isValid }
        guard !invalidAttachments.isEmpty else { return true }

        statusText = invalidAttachments.count == 1
            ? appString("app_model.status.attachment_unavailable")
            : appString("app_model.status.attachments_unavailable")
        appendLog(
            title: appString("app_model.log.title.prompt_blocked"),
            detail: invalidAttachments.map { "\($0.relativePath): \($0.status.displayText(l10n: l10n))" }.joined(separator: ", ")
        )
        return false
    }

    private func isRunningSession(_ session: StoredSession) -> Bool {
        session.id == selectedSessionID && (
            isStreaming ||
            isCompacting ||
            pendingMessageCount > 0 ||
            tools.contains { $0.isRunning }
        )
    }

    private var currentSkillQuery: SkillQuery? {
        SkillSelectionLogic.detectQuery(in: composerText, selectedRange: composerSelectionRange)
    }

    func switchSession(_ session: StoredSession) {
        switchSession(session, expandProject: true)
    }

    private func switchSession(_ session: StoredSession, expandProject: Bool) {
        let oldWorkspace = workspacePath
        persistCurrentSessionSnapshot()
        clearSkillSelectionState(clearAvailableSkills: oldWorkspace != session.projectPath)
        clearPendingContextAttachments()
        selectedSessionID = session.id
        sessionTitle = session.title
        statusText = session.status
        sessionIndexStore.touch(session)
        conversationStore.clear()
        clearQueuedWork(waitForContextRefresh: true)
        isSwitchingSession = true
        isCreatingNewSession = false
        let owningProject = projects.first { $0.id == session.projectID }
            ?? projects.first { $0.path == session.projectPath }
        if let project = owningProject {
            if workspacePath != project.path {
                resetMentionContext(invalidateProjectAt: project.path)
            }
            workspaceStore.select(project, expand: false)
            if expandProject {
                expandedProjectIDs.insert(project.id)
            } else {
                expandedProjectIDs.remove(project.id)
            }
        }
        persistState()
        if isConnected && oldWorkspace != workspacePath {
            restartRPC()
        } else {
            ensureConnected()
        }
        refreshGitDetails()
        refreshRepositoryChangeSnapshot()
        isAwaitingQueuedWorkContextRefresh = true
        sendCommand(.switchSession(sessionPath: session.sessionFile))
    }

    private func ensureConnected() {
        if !isConnected {
            start()
        }
    }

    private func submitSkillSelection(_ skillIDs: [String]) {
        guard skillAvailability.isLoaded else {
            statusText = appString("app_model.status.skills_unavailable")
            appendLog(
                title: appString("app_model.log.title.skill_selection_failed"),
                detail: appString("app_model.log.detail.skills_unavailable")
            )
            return
        }

        do {
            let resolved = try SkillSelectionLogic.resolveSelection(
                skillIDs: skillIDs,
                availableSkills: availableSkills,
                existingSkills: pendingSelectedSkills
            )
            pendingSelectedSkills.append(contentsOf: resolved)
            composerText = ""
            composerSelectionRange = NSRange(location: 0, length: 0)
            highlightedSkillID = nil
            dismissedSkillQuery = nil
            statusText = pendingSelectedSkills.isEmpty
                ? appString("app_model.status.ready")
                : appString("app_model.status.skills_selected")
        } catch {
            statusText = appString("app_model.status.skill_selection_failed")
            appendLog(title: appString("app_model.log.title.skill_selection_failed"), detail: error.localizedDescription)
        }
    }

    private func moveSkillHighlight(delta: Int, in pickerState: SkillPickerState) {
        let skillIDs = pickerState.results.map(\.id)
        guard !skillIDs.isEmpty else { return }

        let currentID = pickerState.highlightedSkillID ?? skillIDs[0]
        let currentIndex = skillIDs.firstIndex(of: currentID) ?? 0
        let nextIndex = (currentIndex + delta + skillIDs.count) % skillIDs.count
        highlightedSkillID = skillIDs[nextIndex]
    }

    private func clearSkillSelectionState(clearAvailableSkills: Bool) {
        pendingSelectedSkills.removeAll()
        highlightedSkillID = nil
        dismissedSkillQuery = nil
        if clearAvailableSkills {
            availableSkills.removeAll()
            skillAvailability = .notLoaded
        }
    }

    private func restartRPC() {
        stop()
        start()
    }

    private func beginAccessRefresh(reason: String) {
        guard isConnected else {
            clearAuthDerivedState(
                authentication: authenticationStateFromCredentialStore(),
                modelAccess: .unknown,
                subscriptionAccess: .unknown
            )
            return
        }

        availableModels.removeAll()
        modelName = appString("app_model.model.no_model")
        statusText = appString("app_model.status.refreshing_access")
        let commandIDs = accessRefreshTracker.begin(
            state: &authAccess,
            credentialSnapshot: NativeAuthStore.credentialSnapshot()
        )
        appendLog(
            title: appString("app_model.log.title.access_refresh"),
            detail: appString("app_model.log.detail.access_refresh", reason, commandIDs.epoch)
        )

        let sentState = sendCommand(.getState(id: commandIDs.stateCommandID))
        let sentModels = sendCommand(.getAvailableModels(id: commandIDs.modelsCommandID))
        if !sentState || !sentModels {
            let failedCommands = [
                sentState ? nil : "get_state",
                sentModels ? nil : "get_available_models"
            ].compactMap { $0 }.joined(separator: ", ")
            _ = accessRefreshTracker.failCurrentRefresh(
                state: &authAccess,
                message: appString("app_model.error.could_not_send_commands", failedCommands)
            )
            statusText = appString("app_model.status.access_refresh_failed")
        }
    }

    private func clearAuthDerivedState(
        authentication: AuthenticationState,
        modelAccess: ModelAccessState = .unknown,
        subscriptionAccess: SubscriptionAccessState = .unknown
    ) {
        accessRefreshTracker.invalidate(
            state: &authAccess,
            authentication: authentication,
            modelAccess: modelAccess,
            subscriptionAccess: subscriptionAccess
        )
        availableModels.removeAll()
        modelName = appString("app_model.model.no_model")
    }

    private func authenticationStateFromCredentialStore() -> AuthenticationState {
        let snapshot = NativeAuthStore.credentialSnapshot()
        return snapshot.isEmpty ? .unknown : .authenticated(providerID: snapshot.singleProviderID)
    }

    @discardableResult
    private func sendCommand(_ command: PiRPCCommand) -> Bool {
        do {
            try client.send(command)
            return true
        } catch {
            appendLog(title: appString("app_model.log.title.send_failed"), detail: error.localizedDescription)
            return false
        }
    }

    private func sendPromptCommand(_ prompt: String) {
        sendCommand(.prompt(prompt))
    }

    private func handleRPCEvent(_ event: PiRPCEvent) {
        if case .response(let response) = event {
            handleResponse(response)
            return
        }

        let effects = reducer.reduce(event, conversation: conversationStore, tools: toolActivityStore)
        effects.forEach(applyReducerEffect)
    }

    private func applyReducerEffect(_ effect: PiRPCEventReducerEffect) {
        switch effect {
        case .setStreaming(let value):
            isStreaming = value
            statusText = value ? appString("app_model.status.running") : appString("app_model.status.ready")
        case .setCompacting(let value):
            isCompacting = value
        case .setQueuedWork(let update):
            applyQueuedWorkUpdate(update)
        case .appendLog(let title, let detail):
            appendLog(title: title, detail: detail)
        case .refreshState:
            refreshState()
        case .refreshRepositoryChanges:
            scheduleRepositoryChangeSnapshotRefresh()
        case .extensionUIRequest(let request):
            handleExtensionUIRequest(request)
        }
    }

    func applyQueuedWorkUpdate(_ update: PiRPCQueueUpdate) {
        guard !isAwaitingQueuedWorkContextRefresh else {
            appendLog(
                title: appString("app_model.log.title.ignored_stale_queue_update"),
                detail: appString("app_model.log.detail.awaiting_active_session_state")
            )
            return
        }
        pendingMessageCount = update.pendingMessageCount
        queuedWorkDisplayState = update.entries.isEmpty ? .empty : .entries(update.entries)
    }

    func applyPendingMessageCount(_ count: Int) {
        let count = max(0, count)
        pendingMessageCount = count

        guard count > 0 else {
            queuedWorkDisplayState = .empty
            return
        }

        if case .entries(let entries) = queuedWorkDisplayState,
           entries.count == count {
            return
        }

        queuedWorkDisplayState = .countOnly(count)
    }

    func clearQueuedWork(waitForContextRefresh: Bool = false) {
        pendingMessageCount = 0
        queuedWorkDisplayState = .empty
        isAwaitingQueuedWorkContextRefresh = waitForContextRefresh
    }

    private func handleExtensionUIRequest(_ request: PiExtensionUIRequest) {
        appendLog(title: appString("app_model.log.title.extension_ui"), detail: request.methodName)
        switch extensionUIRouter.route(request) {
        case .command(let command):
            sendCommand(command)
        case .pendingDialog:
            break
        }
    }

    func submitExtensionUIRequest(result: Any?) {
        guard let command = extensionUIRouter.resolveActiveRequest(with: result) else { return }
        sendCommand(command)
    }

    func cancelExtensionUIRequest() {
        guard let command = extensionUIRouter.rejectActiveRequest() else { return }
        sendCommand(command)
    }

    private func piModels(from data: [String: Any]?) -> [PiModel] {
        let models = data?["models"] as? [[String: Any]] ?? []
        return models.compactMap { model in
            guard
                let provider = PiRPCValue.string(model["provider"]),
                let modelId = PiRPCValue.string(model["id"])
            else { return nil }
            return PiModel(
                provider: provider,
                modelId: modelId,
                name: PiRPCValue.string(model["name"]) ?? modelId
            )
        }
    }

    private func handleResponse(_ response: PiRPCResponse) {
        let command = response.command
        let accessEffect = accessRefreshTracker.handle(response: response, state: &authAccess, l10n: l10n)

        switch accessEffect {
        case .ignoredStale:
            appendLog(
                title: appString("app_model.log.title.ignored_stale_access_refresh"),
                detail: appString("app_model.log.detail.command_id", command, response.id ?? "unknown")
            )
            return
        case .failed(let message):
            availableModels.removeAll()
            modelName = appString("app_model.model.no_model")
            statusText = appString("app_model.status.access_refresh_failed")
            appendLog(title: appString("app_model.log.title.access_refresh_failed"), detail: message)
            return
        case .notAccessRefresh, .waiting, .completed:
            break
        }

        if !response.success {
            if command == "get_commands" {
                availableSkills = []
                skillAvailability = .unavailable(appString("app_model.status.skills_unavailable"))
            }
            appendLog(
                title: appString("app_model.log.title.command_failed", command),
                detail: response.error ?? appString("app_model.error.unknown_error")
            )
            return
        }

        if command == "get_state", let data = response.data {
            if let model = data["model"] as? [String: Any] {
                let provider = PiRPCValue.string(model["provider"]) ?? ""
                let name = PiRPCValue.string(model["name"]) ?? PiRPCValue.string(model["id"]) ?? appString("app_model.model.generic_model")
                modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            } else {
                modelName = appString("app_model.model.no_model")
            }
            thinkingLevel = PiRPCValue.string(data["thinkingLevel"]) ?? thinkingLevel
            isStreaming = data["isStreaming"] as? Bool ?? isStreaming
            isCompacting = data["isCompacting"] as? Bool ?? isCompacting
            let canApplyQueuedWorkState = canApplyQueuedWorkState(from: data)
            if canApplyQueuedWorkState {
                if let count = data["pendingMessageCount"] as? Int {
                    applyPendingMessageCount(count)
                }
                isAwaitingQueuedWorkContextRefresh = false
            } else if isAwaitingQueuedWorkContextRefresh && !canApplyQueuedWorkState {
                appendLog(
                    title: appString("app_model.log.title.ignored_stale_queue_state"),
                    detail: appString("app_model.log.detail.session_state_mismatch")
                )
            }
            if isCreatingNewSession {
                sessionTitle = firstPromptTitle ?? appString("app_model.session.new_chat")
            } else if let name = PiRPCValue.string(data["sessionName"]), !name.isEmpty, !shouldReplaceGeneratedTitle(name) {
                sessionTitle = name
            } else if let selectedSession, !shouldReplaceGeneratedTitle(selectedSession.title) {
                sessionTitle = selectedSession.title
            } else if let firstPromptTitle {
                sessionTitle = firstPromptTitle
            } else {
                sessionTitle = appString("app_model.session.new_chat")
            }
            var didPersistSession = false
            if let sessionID = PiRPCValue.string(data["sessionId"]),
               let sessionFile = PiRPCValue.string(data["sessionFile"]),
               shouldPersistStateSession(sessionID: sessionID) {
                upsertSession(sessionID: sessionID, sessionFile: sessionFile)
                didPersistSession = true
            }
            if isCreatingNewSession && didPersistSession {
                isCreatingNewSession = false
            }
        } else if command == "new_session" {
            selectedSessionID = nil
            sessionTitle = appString("app_model.session.new_chat")
            statusText = appString("app_model.status.ready")
            conversationStore.currentAssistantID = nil
            clearQueuedWork(waitForContextRefresh: true)
            if let pendingPromptAfterNewSession {
                self.pendingPromptAfterNewSession = nil
                sendPromptCommand(pendingPromptAfterNewSession)
            } else {
                conversationStore.clear()
            }
            refreshState()
        } else if command == "switch_session" {
            isSwitchingSession = false
            refreshState()
            sendCommand(.getMessages())
        } else if command == "set_model", let data = response.data {
            let provider = PiRPCValue.string(data["provider"]) ?? ""
            let name = PiRPCValue.string(data["name"]) ?? PiRPCValue.string(data["id"]) ?? appString("app_model.model.generic_model")
            modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            appendLog(title: appString("app_model.log.title.selected_model"), detail: modelName)
            refreshState()
        } else if command == "set_thinking_level" {
            refreshState()
        } else if command == "cycle_thinking_level", let data = response.data {
            if let level = PiRPCValue.string(data["level"]) {
                thinkingLevel = level
            }
        } else if command == "get_available_models" {
            switch accessEffect {
            case .waiting:
                return
            case .completed(let models):
                availableModels = models
                updateStatusAfterAccessRefresh()
                return
            case .notAccessRefresh:
                availableModels = piModels(from: response.data)
            case .ignoredStale, .failed:
                return
            }
        } else if command == "get_commands", let data = response.data {
            guard let commands = data["commands"] as? [[String: Any]] else {
                availableSkills = []
                skillAvailability = .unavailable(appString("app_model.status.skills_unavailable"))
                return
            }
            availableSkills = SkillSelectionLogic.availableSkills(from: commands)
            skillAvailability = .loaded
        } else if command == "get_session_stats", let data = response.data {
            if let cost = data["cost"] as? Double {
                appendLog(
                    title: appString("app_model.log.title.session_stats"),
                    detail: appString("app_model.log.detail.cost", String(format: "%.4f", cost))
                )
            }
        } else if command == "get_messages", let data = response.data {
            let rpcMessages = data["messages"] as? [[String: Any]] ?? []
            messages = rpcMessages.compactMap(chatMessage(from:))
            if let firstPromptTitle {
                sessionTitle = firstPromptTitle
                persistCurrentSessionSnapshot()
            }
        } else if command != "prompt" {
            appendLog(title: command, detail: appString("app_model.log.detail.ok"))
        }

        if case .completed(let models) = accessEffect {
            availableModels = models
            updateStatusAfterAccessRefresh()
        }
    }

    private func updateStatusAfterAccessRefresh() {
        guard !isStreaming else { return }
        switch authAccess.modelAccess {
        case .available:
            statusText = appString("app_model.status.ready")
        case .unavailable:
            statusText = appString("app_model.status.no_model_access")
        case .failed:
            statusText = appString("app_model.status.access_refresh_failed")
        case .unknown:
            statusText = appString("app_model.status.model_access_unknown")
        case .refreshing:
            statusText = appString("app_model.status.refreshing_access")
        }
    }

    private func appendLog(title: String, detail: String) {
        processLogStore.append(title: title, detail: detail)
    }

    private func persistCurrentSessionSnapshot() {
        sessionIndexStore.updateSelectedSnapshot(title: sessionTitle, status: statusText)
        persistState()
    }

    private func upsertSession(sessionID: String, sessionFile: String) {
        guard let project = selectedProject else { return }
        let title = shouldReplaceGeneratedTitle(sessionTitle)
            ? (firstPromptTitle ?? appString("app_model.session.new_chat"))
            : sessionTitle
        sessionIndexStore.upsert(
            sessionID: sessionID,
            project: project,
            title: title,
            status: statusText,
            sessionFile: sessionFile
        )
        persistState()
    }

    private func shouldPersistStateSession(sessionID: String) -> Bool {
        if isCreatingNewSession {
            return true
        }
        if isSwitchingSession {
            return selectedSessionMatchesPiSessionID(sessionID)
        }
        if selectedSessionID != nil {
            return selectedSessionMatchesPiSessionID(sessionID)
        }
        return selectedProject != nil
    }

    private func canApplyQueuedWorkState(from data: [String: Any]) -> Bool {
        guard isAwaitingQueuedWorkContextRefresh else { return true }

        guard let sessionID = PiRPCValue.string(data["sessionId"]) else {
            return false
        }

        if isCreatingNewSession {
            return true
        }

        guard selectedSessionID != nil else {
            return false
        }

        return selectedSessionMatchesPiSessionID(sessionID)
    }

    private func selectedSessionMatchesPiSessionID(_ piSessionID: String) -> Bool {
        selectedSession?.piSessionID == piSessionID
    }

    private func persistState() {
        SessionStore.save(AppPersistedState(
            projects: projects,
            sessions: sessions,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID
        ))
    }

    private func chatMessage(from rpcMessage: [String: Any]) -> ChatMessage? {
        guard let role = PiRPCValue.string(rpcMessage["role"]) else { return nil }
        switch role {
        case "user":
            let text = PiRPCValue.text(from: rpcMessage["content"] ?? "")
            return ChatMessage(
                role: .user,
                title: appString("chat.message.title.you"),
                text: SkillPromptDecorator.visibleUserPrompt(from: text)
            )
        case "assistant":
            let content = rpcMessage["content"] ?? ""
            return ChatMessage(
                role: .assistant,
                title: "π",
                text: PiRPCValue.text(from: content),
                contentBlocks: PiRPCValue.contentBlocks(from: content)
            )
        default:
            return nil
        }
    }

    private enum SessionNavigationDirection {
        case previous
        case next

        var offset: Int {
            switch self {
            case .previous: return -1
            case .next: return 1
            }
        }

    }

    private func sessionNavigationBoundaryReason(for direction: SessionNavigationDirection) -> String {
        switch direction {
        case .previous:
            return appString("app_model.availability.no_previous_session")
        case .next:
            return appString("app_model.availability.no_next_session")
        }
    }

    private var firstPromptTitle: String? {
        conversationStore.firstPromptTitle
    }

    private func shouldReplaceGeneratedTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ||
            trimmed == "New chat" ||
            trimmed == appString("app_model.session.new_chat") ||
            trimmed == "New pi session" ||
            trimmed.hasPrefix("Session ")
    }

    private func refreshGitDetails() {
        guard selectedProject != nil, !workspacePath.isEmpty else {
            gitDetails = GitBranchDetails(
                branch: appString("app_model.git.no_project_selected"),
                hasChanges: false,
                changeSummary: appString("app_model.git.open_project")
            )
            return
        }

        let workspace = workspacePath
        DispatchQueue.global(qos: .utility).async {
            let details = GitService.branchDetails(for: workspace)

            DispatchQueue.main.async {
                if self.workspacePath == workspace {
                    self.gitDetails = self.localizedGitDetails(details)
                }
            }
        }
    }

    func scheduleRepositoryChangeSnapshotRefresh() {
        debouncedRepositoryChangeSnapshotTask?.cancel()
        let delay = repositoryChangeRefreshDelayNanoseconds
        debouncedRepositoryChangeSnapshotTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            await MainActor.run {
                self?.refreshRepositoryChangeSnapshot()
            }
        }
    }

    func refreshRepositoryChangeSnapshot() {
        guard selectedProject != nil, !workspacePath.isEmpty else {
            repositoryChangeSnapshotTask?.cancel()
            repositoryChangeSnapshot = .unavailable(reason: appString("app_model.change_review.open_project"))
            return
        }

        let workspace = workspacePath
        repositoryChangeSnapshotTask?.cancel()
        repositoryChangeSnapshot = RepositoryChangeSnapshot(
            projectPath: workspace,
            branch: repositoryChangeSnapshot.projectPath == workspace ? repositoryChangeSnapshot.branch : gitDetails.branch,
            files: repositoryChangeSnapshot.projectPath == workspace ? repositoryChangeSnapshot.files : [],
            loadedAt: repositoryChangeSnapshot.loadedAt,
            status: .loading
        )

        repositoryChangeSnapshotTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                GitService.repositoryChangeSnapshot(for: workspace)
            }.value

            guard !Task.isCancelled, let self, self.workspacePath == workspace else { return }
            self.repositoryChangeSnapshot = snapshot
            if case .failed(let message) = snapshot.status {
                self.appendLog(
                    title: self.appString("app_model.log.title.change_review_failed"),
                    detail: ChangeReviewPresentation.localizedGitMessage(message, l10n: self.l10n)
                )
            }
            self.gitDetails = GitBranchDetails(
                branch: snapshot.branch.isEmpty ? self.gitDetails.branch : snapshot.branch,
                hasChanges: !snapshot.files.isEmpty,
                changeSummary: snapshot.files.isEmpty
                    ? self.appString("app_model.git.no_changes")
                    : self.appPlural("app_model.git.changed_files_count", count: snapshot.files.count),
                changedFileCount: snapshot.files.count
            )
        }
    }

    private func localizedGitDetails(_ details: GitBranchDetails) -> GitBranchDetails {
        var localizedDetails = details

        if details.branch == "Not a git repository" {
            localizedDetails.branch = appString("app_model.git.not_repository")
        } else if details.branch == "HEAD unavailable" {
            localizedDetails.branch = appString("app_model.git.head_unavailable")
        } else if details.branch.hasPrefix("detached ") {
            let hash = String(details.branch.dropFirst("detached ".count))
            localizedDetails.branch = appString("app_model.git.detached_head", hash)
        }

        if let count = details.changedFileCount {
            localizedDetails.changeSummary = count > 0
                ? appPlural("app_model.git.changed_files_count", count: count)
                : appString("app_model.git.no_changes")
        }

        return localizedDetails
    }

}

private struct StaticCommandPaletteAction {
    let actionID: AppActionID
    let subtitleKey: String?
    let keywordsKey: String
    let iconSystemName: String
}

private enum ResolvedCommandPaletteInvocation {
    case appAction(AppActionID)
    case selectProject(ProjectItem)
    case switchSession(StoredSession)
    case selectModel(PiModel)
    case setThinkingLevel(String)
    case openExternalTarget(AvailableExternalTarget)
    case showLogin
    case showModelPicker
}
