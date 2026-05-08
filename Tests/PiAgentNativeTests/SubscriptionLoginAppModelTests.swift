import XCTest
@testable import PiAgentNativeCore

@MainActor
final class SubscriptionLoginAppModelTests: XCTestCase {
    func testZeroProviderExitSetsRunnerPhaseToRefreshingAccess() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)

        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.phase, .refreshingAccess)
        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.exitStatus, 0)
        XCTAssertEqual(harness.commands().map(\.type), ["get_state", "get_available_models"])
        XCTAssertFalse(harness.model.eventLog.contains { $0.title == "subscription login confirmed" })
    }

    func testNonZeroProviderExitSetsRunnerPhaseToFailedAndDoesNotStartConfirmation() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.rpcRestartAction = {
            XCTFail("Non-zero provider exit must not restart PiRPC for confirmation")
        }
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)

        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 17)

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .failed(message: "Login exited with status 17.")
        )
        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.exitStatus, 17)
        XCTAssertTrue(harness.commands().isEmpty)
    }

    func testSuccessfulCurrentRefreshWithSubscriptionBackedModelAccessConfirmsRunner() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(response(id: commands["get_state"], command: "get_state", data: stateData()))

        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.phase, .refreshingAccess)

        harness.model.handleResponse(
            response(
                id: commands["get_available_models"],
                command: "get_available_models",
                data: modelsData(provider: provider.id)
            )
        )

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .confirmed(providerID: provider.id)
        )
        XCTAssertTrue(harness.model.authAccess.hasActiveSubscriptionAccess)
    }

    func testRefreshFailureSetsRunnerPhaseToFailedWithVisibleMessage() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(
            response(
                id: commands["get_state"],
                command: "get_state",
                success: false,
                error: "Credentials rejected."
            )
        )

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .failed(message: "Credentials rejected.")
        )
        XCTAssertEqual(harness.model.statusText, "Access refresh failed")
    }

    func testRefreshSuccessWithoutUsableSubscriptionBackedAccessDoesNotConfirmRunner() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(response(id: commands["get_state"], command: "get_state", data: stateData()))
        harness.model.handleResponse(
            response(
                id: commands["get_available_models"],
                command: "get_available_models",
                data: modelsData(provider: "anthropic")
            )
        )

        guard case .failed(let message) = harness.model.oauthLoginRunner.attemptState.phase else {
            return XCTFail("Expected failed runner phase")
        }
        XCTAssertTrue(message.contains("no subscription-backed credentials"))
        XCTAssertFalse(harness.model.authAccess.hasActiveSubscriptionAccess)
    }

    func testSupersededAttemptCompletionDoesNotUpdateRunnerPhase() {
        let provider = subscriptionProvider()
        let currentAttemptID = UUID()
        let oldAttemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: currentAttemptID)

        harness.model.completeSubscriptionLogin(provider: provider, attemptID: oldAttemptID, exitStatus: 0)

        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.phase, .starting)
        XCTAssertTrue(harness.commands().isEmpty)
    }

    func testSimulatedRefreshResponsesCompleteCurrentRefreshAndUpdateRunnerState() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(
            response(
                id: commands["get_available_models"],
                command: "get_available_models",
                data: modelsData(provider: provider.id)
            )
        )

        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.phase, .refreshingAccess)

        harness.model.handleResponse(response(id: commands["get_state"], command: "get_state", data: stateData()))

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .confirmed(providerID: provider.id)
        )
        XCTAssertEqual(harness.model.availableModels, [
            PiModel(provider: provider.id, modelId: "gpt-5", name: "GPT-5")
        ])
    }

    func testStaleRefreshResponsesCannotOverwriteNewerRunnerState() {
        let provider = subscriptionProvider()
        let oldAttemptID = UUID()
        let newAttemptID = UUID()
        let harness = makeHarness(provider: provider)
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: oldAttemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: oldAttemptID, exitStatus: 0)
        let oldCommands = commandsByType(harness.commands())

        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: newAttemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: newAttemptID, exitStatus: 0)
        let newCommands = commandsByType(Array(harness.commands().suffix(2)))

        harness.model.handleResponse(response(id: oldCommands["get_state"], command: "get_state", data: stateData()))
        harness.model.handleResponse(
            response(
                id: oldCommands["get_available_models"],
                command: "get_available_models",
                data: modelsData(provider: provider.id)
            )
        )

        XCTAssertEqual(harness.model.oauthLoginRunner.attemptState.phase, .refreshingAccess)

        harness.model.handleResponse(response(id: newCommands["get_state"], command: "get_state", data: stateData()))
        harness.model.handleResponse(
            response(
                id: newCommands["get_available_models"],
                command: "get_available_models",
                data: modelsData(provider: provider.id)
            )
        )

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .confirmed(providerID: provider.id)
        )

        harness.model.handleResponse(
            response(
                id: oldCommands["get_state"],
                command: "get_state",
                success: false,
                error: "Old refresh failed."
            )
        )

        XCTAssertEqual(
            harness.model.oauthLoginRunner.attemptState.phase,
            .confirmed(providerID: provider.id)
        )
    }

    func testCurrentSessionRemainsSelectedAfterSuccessfulProviderLoginRefresh() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let session = StoredSession(
            id: "session-1",
            projectPath: project.path,
            projectName: project.name,
            title: "Keep this session",
            status: "Ready",
            sessionFile: "/tmp/repo/session-1.json",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        harness.model.projects = [project]
        harness.model.sessions = [session]
        harness.model.selectedProjectID = project.id
        harness.model.workspacePath = project.path
        harness.model.selectedSessionID = session.id
        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)

        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)

        XCTAssertEqual(harness.model.selectedSessionID, session.id)
        XCTAssertEqual(harness.commands().map(\.type), ["get_state", "get_available_models", "switch_session"])
    }

    func testMatchingRefreshPreservesSelectedModelAndThinkingLevel() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        primeSelectedModel(
            harness.model,
            provider: provider.id,
            modelID: "gpt-5",
            name: "GPT-5",
            thinkingLevel: "high"
        )

        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)
        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(
            response(
                id: commands["get_state"],
                command: "get_state",
                data: stateData(provider: provider.id, modelID: "gpt-6", name: "GPT-6", thinkingLevel: "low")
            )
        )
        harness.model.handleResponse(
            response(
                id: commands["get_available_models"],
                command: "get_available_models",
                data: modelsData(
                    [
                        modelData(provider: provider.id, modelID: "gpt-6", name: "GPT-6"),
                        modelData(provider: provider.id, modelID: "gpt-5", name: "GPT-5")
                    ]
                )
            )
        )

        XCTAssertEqual(harness.model.modelName, "\(provider.id)/GPT-5")
        XCTAssertEqual(harness.model.thinkingLevel, "high")
        XCTAssertEqual(harness.model.authAccess.modelAccess, .available(providerID: provider.id))
        XCTAssertTrue(harness.model.canSendPrompt)
    }

    func testMissingRefreshModelRequiresExplicitSelectionWithoutFirstModelFallback() {
        let provider = subscriptionProvider()
        let attemptID = UUID()
        let harness = makeHarness(provider: provider)
        primeSelectedModel(
            harness.model,
            provider: provider.id,
            modelID: "gpt-5",
            name: "GPT-5",
            thinkingLevel: "high"
        )

        harness.model.oauthLoginRunner.markStarting(provider: provider, attemptID: attemptID)
        harness.model.completeSubscriptionLogin(provider: provider, attemptID: attemptID, exitStatus: 0)
        let commands = commandsByType(harness.commands())
        harness.model.handleResponse(
            response(
                id: commands["get_state"],
                command: "get_state",
                data: stateData(provider: provider.id, modelID: "gpt-6", name: "GPT-6", thinkingLevel: "low")
            )
        )
        harness.model.handleResponse(
            response(
                id: commands["get_available_models"],
                command: "get_available_models",
                data: modelsData([modelData(provider: provider.id, modelID: "gpt-6", name: "GPT-6")])
            )
        )

        XCTAssertEqual(harness.model.modelName, "No model")
        XCTAssertEqual(harness.model.thinkingLevel, "high")
        XCTAssertEqual(harness.model.availableModels, [
            PiModel(provider: provider.id, modelId: "gpt-6", name: "GPT-6")
        ])
        XCTAssertEqual(
            harness.model.authAccess.modelAccess,
            .unavailable(reason: "Selected model is no longer available. Choose a model to continue.")
        )
        XCTAssertFalse(harness.model.canSendPrompt)
        XCTAssertFalse(harness.commands().contains { $0.type == "set_model" })
    }

    private func makeHarness(provider: LoginProvider) -> (model: AppModel, commands: () -> [PiRPCCommand]) {
        let model = AppModel()
        var commands: [PiRPCCommand] = []
        model.isConnected = true
        model.credentialSnapshotProvider = {
            AuthCredentialSnapshot(credentialsByProvider: [provider.id: .oauth])
        }
        model.rpcCommandSender = { command in
            commands.append(command)
        }
        model.rpcRestartAction = { [weak model] in
            guard let model else { return }
            model.isConnected = true
            model.beginAccessRefresh(reason: "pi rpc start")
        }
        return (model, { commands })
    }

    private func commandsByType(_ commands: [PiRPCCommand]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: commands.map { ($0.type, $0.id) })
    }

    private func subscriptionProvider() -> LoginProvider {
        LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
    }

    private func primeSelectedModel(
        _ model: AppModel,
        provider: String,
        modelID: String,
        name: String,
        thinkingLevel: String
    ) {
        model.projects = [ProjectItem(name: "Repo", path: "/tmp/repo")]
        model.selectedProjectID = model.projects[0].id
        model.workspacePath = model.projects[0].path
        model.composerText = "Keep working"
        model.handleResponse(
            response(
                id: nil,
                command: "get_state",
                data: stateData(provider: provider, modelID: modelID, name: name, thinkingLevel: thinkingLevel)
            )
        )
        model.authAccess.modelAccess = .available(providerID: provider)
    }

    private func response(
        id: String?,
        command: String,
        success: Bool = true,
        data: [String: Any]? = nil,
        error: String? = nil
    ) -> PiRPCResponse {
        var payload: [String: Any] = [
            "type": "response",
            "command": command,
            "success": success
        ]
        if let id {
            payload["id"] = id
        }
        if let data {
            payload["data"] = data
        }
        if let error {
            payload["error"] = error
        }
        return PiRPCResponse(payload: payload)
    }

    private func stateData(
        provider: String = "openai-codex",
        modelID: String = "gpt-5",
        name: String = "GPT-5",
        thinkingLevel: String = "medium"
    ) -> [String: Any] {
        [
            "model": [
                "provider": provider,
                "id": modelID,
                "name": name
            ],
            "thinkingLevel": thinkingLevel,
            "isStreaming": false,
            "isCompacting": false,
            "pendingMessageCount": 0,
            "sessionName": "New chat"
        ]
    }

    private func modelsData(provider: String, modelID: String = "gpt-5", name: String = "GPT-5") -> [String: Any] {
        modelsData([modelData(provider: provider, modelID: modelID, name: name)])
    }

    private func modelsData(_ models: [[String: Any]]) -> [String: Any] {
        ["models": models]
    }

    private func modelData(provider: String, modelID: String, name: String) -> [String: Any] {
        [
            "provider": provider,
            "id": modelID,
            "name": name
        ]
    }
}
