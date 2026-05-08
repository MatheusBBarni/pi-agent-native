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
    @Published var mentionPickerState: MentionPickerState?
    @Published var pendingMentionTextReplacement: MentionTextReplacement?

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
    private var pendingPromptAfterNewSession: String?
    private var mentionIndexCache: [String: [MentionIndexEntry]] = [:]
    private var mentionIndexTask: Task<Void, Never>?
    private var mentionIndexLoadingProjectPath: String?
    private var handledSubscriptionLoginAttemptIDs: Set<UUID> = []

    var workspacePath: String {
        get { workspaceStore.workspacePath }
        set { workspaceStore.workspacePath = newValue }
    }

    var customExecutablePath: String {
        get { settingsStore.customExecutablePath }
        set { settingsStore.customExecutablePath = newValue }
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
        let persistedProjects = Self.sanitizePersistedProjects(persistedState.projects)
        let persistedSessionProjectPaths = Set(persistedProjects.map(\.path))
        let persistedSessions = persistedState.sessions.filter { persistedSessionProjectPaths.contains($0.projectPath) }
        let persistedSelectedSessionID = persistedSessions.first(where: { $0.id == persistedState.selectedSessionID })?.id

        settingsStore = SettingsStore(customExecutablePath: storedExecutable ?? "")
        workspaceStore = WorkspaceStore(
            projects: persistedProjects,
            selectedProjectPath: persistedState.selectedProjectPath,
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

        if let selectedProjectPath = persistedState.selectedProjectPath,
           selectedProjectID != nil {
            let selectedSession = selectedSessionID.flatMap { id in
                persistedSessions.first { $0.id == id }
            }
            if selectedSession?.projectPath != selectedProjectPath {
                selectedSessionID = NativeSessionIndexStore.lastOpenedSession(
                    in: persistedSessions,
                    projectPath: selectedProjectPath
                )?.id
            }
        }
        persistState()
        bindStoreChanges()
        refreshGitDetails()

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
            self.availableSkills = []
            self.skillAvailability = .unavailable("Skills unavailable")
            self.pendingSelectedSkills.removeAll()
            self.highlightedSkillID = nil
            self.dismissedSkillQuery = nil
            self.clearAuthDerivedState(authentication: self.authenticationStateFromCredentialStore())
            self.statusText = status == 0 ? "Stopped" : "Exited with status \(status)"
            self.appendLog(title: "process exited", detail: "status \(status)")
        }
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

    private static func sanitizePersistedProjects(_ persistedProjects: [ProjectItem]) -> [ProjectItem] {
        var seenPaths = Set<String>()
        return persistedProjects.compactMap { item in
            let normalizedPath = URL(fileURLWithPath: item.path).standardized.path
            guard !normalizedPath.isEmpty,
                  isExistingDirectory(normalizedPath),
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

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
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
                status: .unavailable("Skills loading")
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
        guard let selectedProject else {
            statusText = "Open a project"
            launchDetail = "Choose a project folder before starting pi"
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
            statusText = "Connected"
            launchDetail = "\(launch.displayName): \(launch.diagnostic)"
            appendLog(title: "started pi rpc", detail: "\(launch.diagnostic) --mode rpc")
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
            statusText = "Launch failed"
            skillAvailability = .unavailable("Skills unavailable")
            clearAuthDerivedState(
                authentication: authenticationStateFromCredentialStore(),
                modelAccess: .failed(message: error.localizedDescription),
                subscriptionAccess: .failed(message: error.localizedDescription)
            )
            appendLog(title: "launch failed", detail: error.localizedDescription)
        }
    }

    public func stop() {
        client.stop()
        isConnected = false
        isStreaming = false
        statusText = "Stopped"
        clearSkillSelectionState(clearAvailableSkills: true)
        clearAuthDerivedState(authentication: authenticationStateFromCredentialStore())
    }

    func sendPrompt() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard !isStreaming else { return }
        guard selectedProject != nil else {
            statusText = "Open a project"
            return
        }
        guard !isCreatingNewSession else { return }

        let submission = SkillSelectionLogic.parseSubmission(prompt)

        if !isConnected {
            start()
        }

        switch submission {
        case .normalPrompt:
            if let message = authAccess.sendPromptUnavailableMessage {
                statusText = "Model access unavailable"
                appendLog(title: "prompt blocked", detail: message)
                return
            }
        case .invalid(let message):
            statusText = "Invalid skill command"
            appendLog(title: "skill selection failed", detail: message)
            return
        case .selection(let skillIDs):
            submitSkillSelection(skillIDs)
            return
        }

        let rpcPrompt: String
        do {
            rpcPrompt = try SkillPromptDecorator.decoratedPrompt(userPrompt: prompt, skills: pendingSelectedSkills)
        } catch {
            statusText = "Skill expansion failed"
            appendLog(title: "skill expansion failed", detail: error.localizedDescription)
            return
        }

        messages.append(ChatMessage(role: .user, title: "You", text: prompt))
        closeMentionPicker()
        if shouldReplaceGeneratedTitle(sessionTitle) {
            sessionTitle = prompt.truncatedSessionTitle()
            persistCurrentSessionSnapshot()
        }
        composerText = ""
        pendingSelectedSkills.removeAll()

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
            statusText = "Open a project"
            return
        }
        persistCurrentSessionSnapshot()
        selectedSessionID = nil
        conversationStore.clear()
        toolActivityStore.clear()
        sessionTitle = "New chat"
        statusText = isConnected ? "Ready" : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        clearSkillSelectionState(clearAvailableSkills: false)
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
        guard submissionRequiresModelAccess(prompt), let message = authAccess.sendPromptUnavailableMessage else { return }
        statusText = "Model access unavailable"
        appendLog(title: "prompt blocked", detail: message)
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

    public func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder"

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
              !prompt.isEmpty,
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
        guard let message = authAccess.subscriptionGateUnavailableMessage else { return true }
        statusText = "Subscription access unavailable"
        appendLog(title: "subscription action blocked", detail: "action=\(actionName) \(message)")
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
        } else if extensionUIRouter.activeRequest != nil {
            cancelExtensionUIRequest()
        }
    }

    func showCommandPalette() {
        guard !hasActiveModalExcludingCommandPalette else {
            statusText = "Close active modal first"
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
                title: "Switch project: \(project.name)",
                subtitle: project.path,
                keywords: ["project", "workspace", "switch", project.name, project.path],
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
                    title: "Switch session: \(session.title)",
                    subtitle: session.status,
                    keywords: ["session", "chat", selectedProject.name, session.title, session.status],
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
                title: "Select model: \(model.displayName)",
                subtitle: model.id,
                keywords: ["model", "provider", model.provider, model.modelId, model.name],
                iconSystemName: "cpu",
                keybindingLabel: nil,
                availability: .enabled,
                invocation: .selectModel(provider: model.provider, modelID: model.modelId)
            )
        })

        items.append(contentsOf: CommandPaletteCatalog.thinkingLevels.map { level in
            CommandPaletteItem(
                id: "thinking:\(level)",
                title: "Set thinking: \(level.capitalized)",
                subtitle: level == thinkingLevel ? "Current thinking level" : nil,
                keywords: ["thinking", "reasoning", level],
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
                    title: "Open externally: \(target.displayName)",
                    subtitle: selectedProject?.path,
                    keywords: ["open", "external", "editor", target.displayName, target.id.rawValue],
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
            statusText = availability.disabledReason ?? "Command unavailable"
            return
        }

        guard let resolvedInvocation = resolveCommandPaletteInvocation(item.invocation) else {
            statusText = "Command unavailable"
            return
        }

        closeCommandPalette()
        performCommandPaletteInvocation(resolvedInvocation)
    }

    private func staticCommandPaletteItems() -> [CommandPaletteItem] {
        let staticActions: [(AppActionID, String, String?, [String], String)] = [
            (.newChat, "New chat", "Start a new chat in the selected project", ["new", "chat", "session"], "square.and.pencil"),
            (.openProject, "Open project", "Choose a project folder", ["open", "project", "folder", "workspace"], "folder.badge.plus"),
            (.focusComposer, "Focus composer", "Move keyboard focus to the prompt composer", ["focus", "composer", "prompt"], "text.cursor"),
            (.refreshState, "Refresh state", "Refresh Pi state, commands, and project details", ["refresh", "reload", "state"], "arrow.clockwise"),
            (.openSettings, "Open settings", nil, ["settings", "preferences"], "gearshape"),
            (.openProcessLog, "Open process log", nil, ["process", "log", "debug"], "list.bullet.rectangle"),
            (.openKeybindingHelp, "Open Keyboard Shortcuts", nil, ["keyboard", "shortcuts", "help"], "keyboard"),
            (.toggleSidebar, "Toggle sidebar", nil, ["sidebar", "left", "projects"], "sidebar.left"),
            (.toggleInspector, "Toggle inspector", nil, ["inspector", "right", "details"], "sidebar.right"),
            (.sendPrompt, "Send prompt", nil, ["send", "submit", "prompt"], "paperplane"),
            (.stopGeneration, "Stop generation", nil, ["stop", "abort", "cancel", "generation"], "stop.fill"),
            (.cycleThinkingLevel, "Cycle thinking level", nil, ["thinking", "reasoning", "cycle"], "brain.head.profile")
        ]

        var items = staticActions.map { actionID, title, subtitle, keywords, icon in
            CommandPaletteItem(
                id: "action:\(actionID.rawValue)",
                title: title,
                subtitle: subtitle,
                keywords: keywords,
                iconSystemName: icon,
                keybindingLabel: DefaultKeymap.displayLabel(for: actionID),
                availability: commandPaletteAvailability(for: .appAction(actionID)),
                invocation: .appAction(actionID)
            )
        }

        items.append(CommandPaletteItem(
            id: "login",
            title: "Login",
            subtitle: "Manage authentication",
            keywords: ["login", "auth", "authentication", "account"],
            iconSystemName: "key",
            keybindingLabel: nil,
            availability: commandPaletteAvailability(for: .showLogin),
            invocation: .showLogin
        ))

        items.append(CommandPaletteItem(
            id: "model-picker",
            title: "Select model",
            subtitle: modelName,
            keywords: ["select", "model", "provider", modelName],
            iconSystemName: "cpu",
            keybindingLabel: nil,
            availability: commandPaletteAvailability(for: .showModelPicker),
            invocation: .showModelPicker
        ))

        return items
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
                : .disabled(reason: "Project is no longer available")

        case .switchSession(let sessionID):
            guard let selectedProject else {
                return .disabled(reason: "Open a project first")
            }
            return sessionsForProject(selectedProject).contains(where: { $0.id == sessionID })
                ? .enabled
                : .disabled(reason: "Session is no longer available")

        case .selectModel(let provider, let modelID):
            return availableModels.contains { $0.provider == provider && $0.modelId == modelID }
                ? .enabled
                : .disabled(reason: "Model is no longer available")

        case .setThinkingLevel(let level):
            return CommandPaletteCatalog.thinkingLevels.contains(level)
                ? .enabled
                : .disabled(reason: "Thinking level is not supported")

        case .openExternalTarget(let targetID):
            guard selectedProject != nil else {
                return .disabled(reason: "Open a project first")
            }
            return availableExternalTargets.contains(where: { $0.id == targetID })
                ? .enabled
                : .disabled(reason: "External target is no longer available")

        case .showLogin, .showModelPicker:
            return hasActiveModalExcludingCommandPalette ? .disabled(reason: "Close active modal first") : .enabled
        }
    }

    private func unavailableReason(for actionID: AppActionID) -> String {
        if hasActiveModalExcludingCommandPalette {
            return "Close active modal first"
        }

        switch actionID {
        case .newChat, .refreshState:
            return "Open a project first"
        case .sendPrompt:
            if selectedProject == nil {
                return "Open a project first"
            }
            if isStreaming {
                return "Generation is already running"
            }
            if isCreatingNewSession {
                return "Wait for the new chat to be created"
            }
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Enter a prompt first"
            }
            if let message = authAccess.sendPromptUnavailableMessage {
                return message
            }
            return "Prompt cannot be sent"
        case .stopGeneration:
            return "Nothing is running"
        case .closeActiveModal:
            return "No active modal"
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
            return "Command unavailable"
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
        sessionNavigationUnavailableReason(for: .previous) ?? SessionNavigationDirection.previous.title
    }

    func nextSessionHelpText() -> String {
        sessionNavigationUnavailableReason(for: .next) ?? SessionNavigationDirection.next.title
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
            return "Close active modal first"
        }

        guard let selectedProject else {
            return "Open a project first"
        }

        guard let selectedSessionID else {
            return "Select a session first"
        }

        let projectSessions = sessionsForProject(selectedProject)
        guard projectSessions.count > 1 else {
            return "No other sessions"
        }

        guard let currentIndex = projectSessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return "Select a session in this project first"
        }

        let adjacentIndex = currentIndex + direction.offset
        guard projectSessions.indices.contains(adjacentIndex) else {
            return direction.boundaryReason
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

    func mentionTextReplacementWasApplied(_ id: UUID) {
        guard pendingMentionTextReplacement?.id == id else { return }
        pendingMentionTextReplacement = nil
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
        appendLog(title: "saved api key", detail: "Credentials saved to \(NativeAuthStore.authFileURL.path)")
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
            appendLog(title: "logged out", detail: "Removed credentials for \(provider.name)")
            restartRPC()
        } catch {
            authAccess.authentication = .failed(message: error.localizedDescription)
            authAccess.modelAccess = .failed(message: error.localizedDescription)
            authAccess.subscriptionAccess = .failed(message: error.localizedDescription)
            statusText = "Logout failed"
            appendLog(title: "logout failed", detail: error.localizedDescription)
        }
    }

    func startSubscriptionLogin(provider: LoginProvider) {
        clearAuthDerivedState(
            authentication: .authenticating(providerID: provider.id),
            modelAccess: .refreshing,
            subscriptionAccess: .refreshing
        )
        statusText = "Login in progress"
        appendLog(title: "subscription login", detail: "Starting login for \(provider.name)")
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
        statusText = "Stopping login"
        appendLog(title: "subscription login", detail: "Stopping login for \(provider.name)")
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
            appendLog(title: "subscription login", detail: "Login for \(provider.name) finished; restarting pi RPC")
            restartRPC()
        } else {
            completeFailedSubscriptionLogin(provider: provider, message: "Login exited with status \(exitStatus).")
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
        modelName = "No model"
        statusText = "Login failed"
        appendLog(title: "subscription login failed", detail: "provider=\(provider.name) \(message)")
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
        sessionTitle = "New chat"
        statusText = isConnected ? "Ready" : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        clearSkillSelectionState(clearAvailableSkills: shouldRestart)
        persistState()
        refreshGitDetails()
        if shouldRestart {
            restartRPC()
        }
    }

    func toggleProject(_ project: ProjectItem) {
        workspaceStore.toggle(project)
    }

    func addProject(path: String) {
        let project = workspaceStore.addProject(path: path)
        selectProject(project)
    }

    func openExternally(_ target: AvailableExternalTarget) {
        guard let selectedProject else {
            statusText = "Open a project"
            return
        }

        let projectPath = selectedProject.path
        externalTargetLauncher(target, projectPath) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case .failure(let error) = result {
                    self.statusText = "Could not open in \(target.displayName)"
                    self.appendLog(
                        title: "open externally failed",
                        detail: "target=\(target.displayName) projectPath=\(projectPath) error=\(error.localizedDescription)"
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
        invalidateMentionIndex(for: projectPath)
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
        selectedSessionID = session.id
        sessionTitle = session.title
        statusText = session.status
        sessionIndexStore.touch(session)
        conversationStore.clear()
        isSwitchingSession = true
        isCreatingNewSession = false
        if let project = projects.first(where: { $0.path == session.projectPath }) {
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
        sendCommand(.switchSession(sessionPath: session.sessionFile))
    }

    private func ensureConnected() {
        if !isConnected {
            start()
        }
    }

    private func submitSkillSelection(_ skillIDs: [String]) {
        guard skillAvailability.isLoaded else {
            statusText = "Skills unavailable"
            appendLog(title: "skill selection failed", detail: "Skills are not available from the running pi process.")
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
            statusText = pendingSelectedSkills.isEmpty ? "Ready" : "Skills selected"
        } catch {
            statusText = "Skill selection failed"
            appendLog(title: "skill selection failed", detail: error.localizedDescription)
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
        modelName = "No model"
        statusText = "Refreshing access"
        let commandIDs = accessRefreshTracker.begin(
            state: &authAccess,
            credentialSnapshot: NativeAuthStore.credentialSnapshot()
        )
        appendLog(title: "access refresh", detail: "reason=\(reason) epoch=\(commandIDs.epoch)")

        let sentState = sendCommand(.getState(id: commandIDs.stateCommandID))
        let sentModels = sendCommand(.getAvailableModels(id: commandIDs.modelsCommandID))
        if !sentState || !sentModels {
            let failedCommands = [
                sentState ? nil : "get_state",
                sentModels ? nil : "get_available_models"
            ].compactMap { $0 }.joined(separator: ", ")
            _ = accessRefreshTracker.failCurrentRefresh(
                state: &authAccess,
                message: "Could not send \(failedCommands)."
            )
            statusText = "Access refresh failed"
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
        modelName = "No model"
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
            appendLog(title: "send failed", detail: error.localizedDescription)
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
            statusText = value ? "Running" : "Ready"
        case .setCompacting(let value):
            isCompacting = value
        case .setPendingMessageCount(let count):
            pendingMessageCount = count
        case .appendLog(let title, let detail):
            appendLog(title: title, detail: detail)
        case .refreshState:
            refreshState()
        case .extensionUIRequest(let request):
            handleExtensionUIRequest(request)
        }
    }

    private func handleExtensionUIRequest(_ request: PiExtensionUIRequest) {
        appendLog(title: "extension ui", detail: request.methodName)
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
        let accessEffect = accessRefreshTracker.handle(response: response, state: &authAccess)

        switch accessEffect {
        case .ignoredStale:
            appendLog(title: "ignored stale access refresh", detail: "command=\(command) id=\(response.id ?? "unknown")")
            return
        case .failed(let message):
            availableModels.removeAll()
            modelName = "No model"
            statusText = "Access refresh failed"
            appendLog(title: "access refresh failed", detail: message)
            return
        case .notAccessRefresh, .waiting, .completed:
            break
        }

        if !response.success {
            if command == "get_commands" {
                availableSkills = []
                skillAvailability = .unavailable("Skills unavailable")
            }
            appendLog(title: "\(command) failed", detail: response.error ?? "unknown error")
            return
        }

        if command == "get_state", let data = response.data {
            if let model = data["model"] as? [String: Any] {
                let provider = PiRPCValue.string(model["provider"]) ?? ""
                let name = PiRPCValue.string(model["name"]) ?? PiRPCValue.string(model["id"]) ?? "Model"
                modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            } else {
                modelName = "No model"
            }
            thinkingLevel = PiRPCValue.string(data["thinkingLevel"]) ?? thinkingLevel
            isStreaming = data["isStreaming"] as? Bool ?? isStreaming
            isCompacting = data["isCompacting"] as? Bool ?? isCompacting
            pendingMessageCount = data["pendingMessageCount"] as? Int ?? pendingMessageCount
            if isCreatingNewSession {
                sessionTitle = firstPromptTitle ?? "New chat"
            } else if let name = PiRPCValue.string(data["sessionName"]), !name.isEmpty, !shouldReplaceGeneratedTitle(name) {
                sessionTitle = name
            } else if let selectedSession, !shouldReplaceGeneratedTitle(selectedSession.title) {
                sessionTitle = selectedSession.title
            } else if let firstPromptTitle {
                sessionTitle = firstPromptTitle
            } else {
                sessionTitle = "New chat"
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
            sessionTitle = "New chat"
            statusText = "Ready"
            conversationStore.currentAssistantID = nil
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
            let name = PiRPCValue.string(data["name"]) ?? PiRPCValue.string(data["id"]) ?? "Model"
            modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            appendLog(title: "selected model", detail: modelName)
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
                skillAvailability = .unavailable("Skills unavailable")
                return
            }
            availableSkills = SkillSelectionLogic.availableSkills(from: commands)
            skillAvailability = .loaded
        } else if command == "get_session_stats", let data = response.data {
            if let cost = data["cost"] as? Double {
                appendLog(title: "session stats", detail: "cost $\(String(format: "%.4f", cost))")
            }
        } else if command == "get_messages", let data = response.data {
            let rpcMessages = data["messages"] as? [[String: Any]] ?? []
            messages = rpcMessages.compactMap(chatMessage(from:))
            if let firstPromptTitle {
                sessionTitle = firstPromptTitle
                persistCurrentSessionSnapshot()
            }
        } else if command != "prompt" {
            appendLog(title: command, detail: "ok")
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
            statusText = "Ready"
        case .unavailable:
            statusText = "No model access"
        case .failed:
            statusText = "Access refresh failed"
        case .unknown:
            statusText = "Model access unknown"
        case .refreshing:
            statusText = "Refreshing access"
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
        let title = shouldReplaceGeneratedTitle(sessionTitle) ? (firstPromptTitle ?? "New chat") : sessionTitle
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
            return sessionID == selectedSessionID
        }
        if let selectedSessionID {
            return sessionID == selectedSessionID
        }
        return selectedProject != nil
    }

    private func persistState() {
        SessionStore.save(AppPersistedState(
            projects: projects,
            sessions: sessions,
            selectedProjectPath: selectedProject?.path,
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
                title: "You",
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

        var title: String {
            switch self {
            case .previous: return "Previous session"
            case .next: return "Next session"
            }
        }

        var boundaryReason: String {
            switch self {
            case .previous: return "No previous session"
            case .next: return "No next session"
            }
        }
    }

    private var firstPromptTitle: String? {
        conversationStore.firstPromptTitle
    }

    private func shouldReplaceGeneratedTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "New chat" || trimmed == "New pi session" || trimmed.hasPrefix("Session ")
    }

    private func refreshGitDetails() {
        guard selectedProject != nil, !workspacePath.isEmpty else {
            gitDetails = GitBranchDetails(
                branch: "No project selected",
                hasChanges: false,
                changeSummary: "Open a project"
            )
            return
        }

        let workspace = workspacePath
        DispatchQueue.global(qos: .utility).async {
            let details = GitService.branchDetails(for: workspace)

            DispatchQueue.main.async {
                if self.workspacePath == workspace {
                    self.gitDetails = details
                }
            }
        }
    }

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
