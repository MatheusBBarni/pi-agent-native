import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published var workspacePath: String
    @Published var customExecutablePath: String
    @Published var sessionTitle = "New chat"
    @Published var composerText = ""
    @Published var statusText = "Disconnected"
    @Published var launchDetail = "pi has not been started"
    @Published public var isConnected = false
    @Published var isStreaming = false
    @Published var isCompacting = false
    @Published var modelName = "No model"
    @Published var thinkingLevel = "medium"
    @Published var pendingMessageCount = 0
    @Published var messages: [ChatMessage] = []
    @Published var eventLog: [EventLog] = []
    @Published var tools: [ToolActivity] = []
    @Published var availableModels: [PiModel] = []
    @Published var isShowingModelPicker = false
    @Published var isShowingLogin = false
    @Published var isShowingProcessLog = false
    @Published var isShowingSettings = false
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
    @Published var projects: [ProjectItem]
    @Published var selectedProjectID: ProjectItem.ID?
    @Published var expandedProjectIDs: Set<ProjectItem.ID> = []
    @Published var sessions: [StoredSession]
    @Published var selectedSessionID: StoredSession.ID?
    @Published var mentionPickerState: MentionPickerState?
    @Published var pendingMentionTextReplacement: MentionTextReplacement?

    private let client = PiRPCClient()
    private var currentAssistantID: UUID?
    private var shouldSwitchToStoredSessionAfterStart = true
    private var isCreatingNewSession = false
    private var isSwitchingSession = false
    private var pendingPromptAfterNewSession: String?
    private var composerSelectionRange = NSRange(location: 0, length: 0)
    private var mentionIndexCache: [String: [MentionIndexEntry]] = [:]
    private var mentionIndexTask: Task<Void, Never>?
    private var mentionIndexLoadingProjectPath: String?

    public init() {
        let storedExecutable = UserDefaults.standard.string(forKey: "customExecutablePath")
        let storedFontSize = UserDefaults.standard.object(forKey: "uiFontSize") as? Double
        let storedThemeFamily = UserDefaults.standard.string(forKey: "themeFamily").flatMap(AppThemeFamily.init(rawValue:))
        let storedThemeVariant = UserDefaults.standard.string(forKey: "themeVariant").flatMap(AppThemeVariant.init(rawValue:))
        let legacyThemeMode = UserDefaults.standard.string(forKey: "themeMode").flatMap(AppThemeVariant.init(rawValue:))
        let persistedState = SessionStore.load()
        let persistedProjects = persistedState.projects
        let persistedSessions = persistedState.sessions

        customExecutablePath = storedExecutable ?? ""
        uiFontSize = min(max(storedFontSize ?? 15, 12), 20)
        themeFamily = storedThemeFamily ?? .nord
        themeVariant = storedThemeVariant ?? legacyThemeMode ?? .dark
        projects = persistedProjects
        sessions = persistedSessions
        if let selectedProjectPath = persistedState.selectedProjectPath,
           let selectedProject = persistedProjects.first(where: { $0.path == selectedProjectPath }) {
            selectedProjectID = selectedProject.id
            workspacePath = selectedProject.path
        } else {
            selectedProjectID = nil
            workspacePath = ""
        }
        if let selectedProjectID {
            expandedProjectIDs.insert(selectedProjectID)
        }
        selectedSessionID = persistedState.selectedSessionID
        if let selectedProjectPath = persistedState.selectedProjectPath,
           selectedProjectID != nil {
            let selectedSession = selectedSessionID.flatMap { id in
                persistedSessions.first { $0.id == id }
            }
            if selectedSession?.projectPath != selectedProjectPath {
                selectedSessionID = Self.lastOpenedSession(in: persistedSessions, projectPath: selectedProjectPath)?.id
            }
        }
        refreshGitDetails()

        client.onEvent = { [weak self] event in
            self?.handleRPCEvent(event)
        }
        client.onStderr = { [weak self] text in
            self?.appendLog(title: "stderr", detail: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        client.onExit = { [weak self] status in
            self?.isConnected = false
            self?.isStreaming = false
            self?.statusText = status == 0 ? "Stopped" : "Exited with status \(status)"
            self?.appendLog(title: "process exited", detail: "status \(status)")
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
            let launch = try client.start(workspacePath: selectedProject.path, customExecutable: customExecutablePath)
            isConnected = true
            statusText = "Connected"
            launchDetail = "\(launch.displayName): \(launch.diagnostic)"
            appendLog(title: "started pi rpc", detail: "\(launch.diagnostic) --mode rpc")
            sendCommand(["id": requestID(), "type": "get_state"])
            sendCommand(["id": requestID(), "type": "get_available_models"])
            if shouldSwitchToStoredSessionAfterStart,
               let selectedSession,
               !selectedSession.sessionFile.isEmpty {
                shouldSwitchToStoredSessionAfterStart = false
                sendCommand(["id": requestID(), "type": "switch_session", "sessionPath": selectedSession.sessionFile])
            }
        } catch {
            isConnected = false
            statusText = "Launch failed"
            appendLog(title: "launch failed", detail: error.localizedDescription)
        }
    }

    public func stop() {
        client.stop()
        isConnected = false
        isStreaming = false
        statusText = "Stopped"
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

        if !isConnected {
            start()
        }

        messages.append(ChatMessage(role: .user, title: "You", text: prompt))
        closeMentionPicker()
        if shouldReplaceGeneratedTitle(sessionTitle) {
            sessionTitle = prompt.truncatedSessionTitle()
            persistCurrentSessionSnapshot()
        }
        composerText = ""

        if selectedSessionID == nil {
            pendingPromptAfterNewSession = prompt
            isCreatingNewSession = true
            isSwitchingSession = false
            sendCommand(["id": requestID(), "type": "new_session"])
        } else {
            sendPromptCommand(prompt)
        }
    }

    public func newSession() {
        guard selectedProject != nil else {
            statusText = "Open a project"
            return
        }
        persistCurrentSessionSnapshot()
        selectedSessionID = nil
        messages.removeAll()
        tools.removeAll()
        currentAssistantID = nil
        sessionTitle = "New chat"
        statusText = isConnected ? "Ready" : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        persistState()
    }

    func abort() {
        sendCommand(["id": requestID(), "type": "abort"])
    }

    func refreshState() {
        sendCommand(["id": requestID(), "type": "get_state"])
        sendCommand(["id": requestID(), "type": "get_session_stats"])
        sendCommand(["id": requestID(), "type": "get_available_models"])
        refreshGitDetails()
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
        sendCommand(["id": requestID(), "type": "get_available_models"])
    }

    func selectModel(_ model: PiModel) {
        sendCommand([
            "id": requestID(),
            "type": "set_model",
            "provider": model.provider,
            "modelId": model.modelId
        ])
    }

    func setThinkingLevel(_ level: String) {
        sendCommand([
            "id": requestID(),
            "type": "set_thinking_level",
            "level": level.lowercased()
        ])
    }

    func cycleThinkingLevel() {
        sendCommand(["id": requestID(), "type": "cycle_thinking_level"])
    }

    func saveAPIKey(provider: LoginProvider, apiKey: String) throws {
        try NativeAuthStore.saveAPIKey(provider: provider.id, apiKey: apiKey)
        appendLog(title: "saved api key", detail: "Credentials saved to \(NativeAuthStore.authFileURL.path)")
        restartRPC()
    }

    func finishSubscriptionLogin() {
        appendLog(title: "subscription login", detail: "Login finished; restarting pi RPC")
        restartRPC()
    }

    func selectProject(_ project: ProjectItem) {
        if let lastSession = lastOpenedSession(for: project) {
            switchSession(lastSession, expandProject: true)
            return
        }

        selectProjectForNewChat(project)
    }

    func selectProjectForNewChat(_ project: ProjectItem) {
        persistCurrentSessionSnapshot()
        let shouldRestart = isConnected && workspacePath != project.path
        resetMentionContext(invalidateProjectAt: project.path)
        selectedProjectID = project.id
        workspacePath = project.path
        expandedProjectIDs.insert(project.id)
        selectedSessionID = nil
        messages.removeAll()
        tools.removeAll()
        currentAssistantID = nil
        sessionTitle = "New chat"
        statusText = isConnected ? "Ready" : statusText
        isCreatingNewSession = false
        isSwitchingSession = false
        pendingPromptAfterNewSession = nil
        persistState()
        refreshGitDetails()
        if shouldRestart {
            restartRPC()
        }
    }

    func toggleProject(_ project: ProjectItem) {
        if expandedProjectIDs.contains(project.id) {
            expandedProjectIDs.remove(project.id)
        } else {
            expandedProjectIDs.insert(project.id)
        }
    }

    func addProject(path: String) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let path = url.path
        let existing = projects.first { $0.path == path }
        if let existing {
            selectProject(existing)
            return
        }

        let project = ProjectItem(name: url.lastPathComponent, path: path)
        projects.append(project)
        selectProject(project)
    }

    var selectedProject: ProjectItem? {
        projects.first { $0.id == selectedProjectID }
    }

    var selectedSession: StoredSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    func sessionsForProject(_ project: ProjectItem) -> [StoredSession] {
        sessions
            .filter { $0.projectPath == project.path }
            .sorted { lhs, rhs in
                let lhsIsRunning = isRunningSession(lhs)
                let rhsIsRunning = isRunningSession(rhs)
                if lhsIsRunning != rhsIsRunning {
                    return lhsIsRunning
                }
                return lhs.updatedAt > rhs.updatedAt
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

    func switchSession(_ session: StoredSession) {
        switchSession(session, expandProject: true)
    }

    private func switchSession(_ session: StoredSession, expandProject: Bool) {
        let oldWorkspace = workspacePath
        persistCurrentSessionSnapshot()
        selectedSessionID = session.id
        sessionTitle = session.title
        statusText = session.status
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].updatedAt = Date()
        }
        messages.removeAll()
        currentAssistantID = nil
        isSwitchingSession = true
        isCreatingNewSession = false
        if let project = projects.first(where: { $0.path == session.projectPath }) {
            if workspacePath != project.path {
                resetMentionContext(invalidateProjectAt: project.path)
            }
            selectedProjectID = project.id
            if expandProject {
                expandedProjectIDs.insert(project.id)
            } else {
                expandedProjectIDs.remove(project.id)
            }
            workspacePath = project.path
        }
        persistState()
        if isConnected && oldWorkspace != workspacePath {
            restartRPC()
        } else {
            ensureConnected()
        }
        sendCommand(["id": requestID(), "type": "switch_session", "sessionPath": session.sessionFile])
    }

    private func lastOpenedSession(for project: ProjectItem) -> StoredSession? {
        Self.lastOpenedSession(in: sessions, projectPath: project.path)
    }

    private static func lastOpenedSession(in sessions: [StoredSession], projectPath: String) -> StoredSession? {
        sessions
            .filter { $0.projectPath == projectPath && !$0.sessionFile.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private func ensureConnected() {
        if !isConnected {
            start()
        }
    }

    private func restartRPC() {
        stop()
        start()
    }

    private func sendCommand(_ command: [String: Any]) {
        do {
            try client.send(command)
        } catch {
            appendLog(title: "send failed", detail: error.localizedDescription)
        }
    }

    private func sendPromptCommand(_ prompt: String) {
        sendCommand([
            "id": requestID(),
            "type": "prompt",
            "message": prompt
        ])
    }

    private func handleRPCEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "response":
            handleResponse(event)
        case "agent_start":
            isStreaming = true
            statusText = "Running"
            beginAssistantIfNeeded()
        case "agent_end":
            isStreaming = false
            finishCurrentAssistant()
            statusText = "Ready"
            refreshState()
        case "message_start":
            handleMessageStart(event)
        case "message_update":
            handleMessageUpdate(event)
        case "message_end":
            handleMessageEnd(event)
        case "tool_execution_start":
            handleToolStart(event)
        case "tool_execution_update":
            handleToolUpdate(event)
        case "tool_execution_end":
            handleToolEnd(event)
        case "queue_update":
            handleQueueUpdate(event)
        case "compaction_start":
            isCompacting = true
            appendLog(title: "compaction", detail: "started")
        case "compaction_end":
            isCompacting = false
            appendLog(title: "compaction", detail: stringValue(event["errorMessage"]) ?? "completed")
        case "extension_ui_request":
            appendLog(title: "extension ui", detail: stringValue(event["method"]) ?? "request")
        case "extension_error":
            appendLog(title: "extension error", detail: stringValue(event["error"]) ?? "unknown error")
        default:
            appendLog(title: type, detail: compactJSON(event))
        }
    }

    private func handleResponse(_ event: [String: Any]) {
        let command = stringValue(event["command"]) ?? "response"
        let success = event["success"] as? Bool ?? false
        if !success {
            appendLog(title: "\(command) failed", detail: stringValue(event["error"]) ?? "unknown error")
            return
        }

        if command == "get_state", let data = event["data"] as? [String: Any] {
            if let model = data["model"] as? [String: Any] {
                let provider = stringValue(model["provider"]) ?? ""
                let name = stringValue(model["name"]) ?? stringValue(model["id"]) ?? "Model"
                modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            } else {
                modelName = "No model"
            }
            thinkingLevel = stringValue(data["thinkingLevel"]) ?? thinkingLevel
            isStreaming = data["isStreaming"] as? Bool ?? isStreaming
            isCompacting = data["isCompacting"] as? Bool ?? isCompacting
            pendingMessageCount = data["pendingMessageCount"] as? Int ?? pendingMessageCount
            if isCreatingNewSession {
                sessionTitle = firstPromptTitle ?? "New chat"
            } else if let name = stringValue(data["sessionName"]), !name.isEmpty, !shouldReplaceGeneratedTitle(name) {
                sessionTitle = name
            } else if let selectedSession, !shouldReplaceGeneratedTitle(selectedSession.title) {
                sessionTitle = selectedSession.title
            } else if let firstPromptTitle {
                sessionTitle = firstPromptTitle
            } else {
                sessionTitle = "New chat"
            }
            var didPersistSession = false
            if let sessionID = stringValue(data["sessionId"]),
               let sessionFile = stringValue(data["sessionFile"]),
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
            currentAssistantID = nil
            if let pendingPromptAfterNewSession {
                self.pendingPromptAfterNewSession = nil
                sendPromptCommand(pendingPromptAfterNewSession)
            } else {
                messages.removeAll()
            }
            refreshState()
        } else if command == "switch_session" {
            isSwitchingSession = false
            refreshState()
            sendCommand(["id": requestID(), "type": "get_messages"])
        } else if command == "set_model", let data = event["data"] as? [String: Any] {
            let provider = stringValue(data["provider"]) ?? ""
            let name = stringValue(data["name"]) ?? stringValue(data["id"]) ?? "Model"
            modelName = provider.isEmpty ? name : "\(provider)/\(name)"
            appendLog(title: "selected model", detail: modelName)
            refreshState()
        } else if command == "set_thinking_level" {
            refreshState()
        } else if command == "cycle_thinking_level", let data = event["data"] as? [String: Any] {
            if let level = stringValue(data["level"]) {
                thinkingLevel = level
            }
        } else if command == "get_available_models", let data = event["data"] as? [String: Any] {
            let models = data["models"] as? [[String: Any]] ?? []
            availableModels = models.compactMap { model in
                guard
                    let provider = stringValue(model["provider"]),
                    let modelId = stringValue(model["id"])
                else { return nil }
                return PiModel(
                    provider: provider,
                    modelId: modelId,
                    name: stringValue(model["name"]) ?? modelId
                )
            }
        } else if command == "get_session_stats", let data = event["data"] as? [String: Any] {
            if let cost = data["cost"] as? Double {
                appendLog(title: "session stats", detail: "cost $\(String(format: "%.4f", cost))")
            }
        } else if command == "get_messages", let data = event["data"] as? [String: Any] {
            let rpcMessages = data["messages"] as? [[String: Any]] ?? []
            messages = rpcMessages.compactMap(chatMessage(from:))
            if let firstPromptTitle {
                sessionTitle = firstPromptTitle
                persistCurrentSessionSnapshot()
            }
        } else if command != "prompt" {
            appendLog(title: command, detail: "ok")
        }
    }

    private func handleMessageStart(_ event: [String: Any]) {
        guard
            let message = event["message"] as? [String: Any],
            stringValue(message["role"]) == "assistant"
        else { return }
        beginAssistantIfNeeded()
    }

    private func handleMessageUpdate(_ event: [String: Any]) {
        guard let delta = event["assistantMessageEvent"] as? [String: Any] else { return }
        let deltaType = stringValue(delta["type"]) ?? "update"

        switch deltaType {
        case "text_delta":
            appendAssistantText(stringValue(delta["delta"]) ?? "")
        case "thinking_delta":
            appendAssistantThinking(stringValue(delta["delta"]) ?? "")
        case "toolcall_start":
            appendLog(title: "tool call", detail: stringValue(delta["name"]) ?? "started")
        case "toolcall_end":
            if let toolCall = delta["toolCall"] as? [String: Any] {
                appendLog(title: "tool call", detail: stringValue(toolCall["name"]) ?? "completed")
            }
        case "error":
            appendAssistantText("\n\nError: \(stringValue(delta["error"]) ?? "unknown error")")
        default:
            break
        }
    }

    private func handleMessageEnd(_ event: [String: Any]) {
        guard
            let message = event["message"] as? [String: Any],
            stringValue(message["role"]) == "assistant"
        else { return }

        if let content = message["content"] {
            let finalText = extractText(from: content)
            if !finalText.isEmpty {
                replaceCurrentAssistantText(finalText)
            }
        }
        finishCurrentAssistant()
    }

    private func handleToolStart(_ event: [String: Any]) {
        let id = stringValue(event["toolCallId"]) ?? requestID()
        let name = stringValue(event["toolName"]) ?? "tool"
        let args = event["args"] as? [String: Any]
        let summary = stringValue(args?["command"]) ?? compactJSON(args ?? [:])
        upsertTool(ToolActivity(id: id, name: name, summary: summary, output: "", isRunning: true, isError: false))
    }

    private func handleToolUpdate(_ event: [String: Any]) {
        let id = stringValue(event["toolCallId"]) ?? ""
        guard let index = tools.firstIndex(where: { $0.id == id }) else { return }
        if let partial = event["partialResult"] as? [String: Any] {
            tools[index].output = extractResultText(partial)
        }
    }

    private func handleToolEnd(_ event: [String: Any]) {
        let id = stringValue(event["toolCallId"]) ?? ""
        guard let index = tools.firstIndex(where: { $0.id == id }) else { return }
        tools[index].isRunning = false
        tools[index].isError = event["isError"] as? Bool ?? false
        if let result = event["result"] as? [String: Any] {
            tools[index].output = extractResultText(result)
        }
    }

    private func handleQueueUpdate(_ event: [String: Any]) {
        let steering = event["steering"] as? [Any] ?? []
        let followUp = event["followUp"] as? [Any] ?? []
        pendingMessageCount = steering.count + followUp.count
    }

    private func beginAssistantIfNeeded() {
        if let currentAssistantID, messages.contains(where: { $0.id == currentAssistantID }) {
            return
        }

        let message = ChatMessage(role: .assistant, title: "π", text: "", isStreaming: true)
        currentAssistantID = message.id
        messages.append(message)
    }

    private func appendAssistantText(_ text: String) {
        beginAssistantIfNeeded()
        guard let currentAssistantID, let index = messages.firstIndex(where: { $0.id == currentAssistantID }) else { return }
        messages[index].text += text
        messages[index].isStreaming = true
    }

    private func appendAssistantThinking(_ text: String) {
        beginAssistantIfNeeded()
        guard let currentAssistantID, let index = messages.firstIndex(where: { $0.id == currentAssistantID }) else { return }
        messages[index].thinking += text
    }

    private func replaceCurrentAssistantText(_ text: String) {
        beginAssistantIfNeeded()
        guard let currentAssistantID, let index = messages.firstIndex(where: { $0.id == currentAssistantID }) else { return }
        messages[index].text = text
    }

    private func finishCurrentAssistant() {
        guard let currentAssistantID, let index = messages.firstIndex(where: { $0.id == currentAssistantID }) else { return }
        messages[index].isStreaming = false
        if messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages[index].text = "Finished without text output."
        }
        self.currentAssistantID = nil
    }

    private func upsertTool(_ activity: ToolActivity) {
        if let index = tools.firstIndex(where: { $0.id == activity.id }) {
            tools[index] = activity
        } else {
            tools.insert(activity, at: 0)
        }
    }

    private func appendLog(title: String, detail: String) {
        guard !detail.isEmpty else { return }
        eventLog.insert(EventLog(title: title, detail: detail), at: 0)
        if eventLog.count > 80 {
            eventLog.removeLast(eventLog.count - 80)
        }
    }

    private func requestID() -> String {
        UUID().uuidString
    }

    private func persistCurrentSessionSnapshot() {
        guard let selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == selectedSessionID })
        else { return }
        sessions[index].title = sessionTitle
        sessions[index].status = statusText
        sessions[index].updatedAt = Date()
        persistState()
    }

    private func upsertSession(sessionID: String, sessionFile: String) {
        guard let project = selectedProject else { return }
        let title = shouldReplaceGeneratedTitle(sessionTitle) ? (firstPromptTitle ?? "New chat") : sessionTitle
        let session = StoredSession(
            id: sessionID,
            projectPath: project.path,
            projectName: project.name,
            title: title,
            status: statusText,
            sessionFile: sessionFile,
            updatedAt: Date()
        )
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        selectedSessionID = sessionID
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
        guard let role = stringValue(rpcMessage["role"]) else { return nil }
        switch role {
        case "user":
            return ChatMessage(role: .user, title: "You", text: extractText(from: rpcMessage["content"] ?? ""))
        case "assistant":
            return ChatMessage(role: .assistant, title: "π", text: extractText(from: rpcMessage["content"] ?? ""))
        default:
            return nil
        }
    }

    private var firstPromptTitle: String? {
        messages
            .first { $0.role == .user && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .text
            .truncatedSessionTitle()
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
            let branch = Self.runGit(["branch", "--show-current"], cwd: workspace)
            let fallbackHead = Self.runGit(["rev-parse", "--short", "HEAD"], cwd: workspace)
            let status = Self.runGit(["status", "--porcelain"], cwd: workspace)

            let resolvedBranch: String
            if let branch, !branch.isEmpty {
                resolvedBranch = branch
            } else if let fallbackHead, !fallbackHead.isEmpty {
                resolvedBranch = "detached \(fallbackHead)"
            } else {
                resolvedBranch = "Not a git repository"
            }

            let changedLines = status?.split(separator: "\n").count ?? 0
            let details = GitBranchDetails(
                branch: resolvedBranch,
                hasChanges: changedLines > 0,
                changeSummary: changedLines > 0 ? "\(changedLines) changed file\(changedLines == 1 ? "" : "s")" : "No changes"
            )

            DispatchQueue.main.async {
                if self.workspacePath == workspace {
                    self.gitDetails = details
                }
            }
        }
    }

    nonisolated private static func runGit(_ arguments: [String], cwd: String) -> String? {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value { return "\(value)" }
        return nil
    }

    private func extractText(from content: Any) -> String {
        if let text = content as? String {
            return text
        }
        guard let blocks = content as? [[String: Any]] else {
            return ""
        }
        return blocks.compactMap { block in
            if let text = block["text"] as? String { return text }
            if let text = block["thinking"] as? String { return text }
            if stringValue(block["type"]) == "toolCall" {
                return "Tool: \(stringValue(block["name"]) ?? "unknown")"
            }
            return nil
        }
        .joined(separator: "\n\n")
    }

    private func extractResultText(_ result: [String: Any]) -> String {
        guard let content = result["content"] as? [[String: Any]] else {
            return compactJSON(result)
        }
        return content.compactMap { stringValue($0["text"]) }.joined(separator: "\n")
    }

    private func compactJSON(_ object: Any) -> String {
        guard
            JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "\(object)"
        }
        return text
    }
}

private extension String {
    func truncatedSessionTitle(limit: Int = 48) -> String {
        let collapsed = trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > limit else {
            return collapsed.isEmpty ? "New chat" : collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
