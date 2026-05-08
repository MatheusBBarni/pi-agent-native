import XCTest
@testable import PiAgentNativeCore

final class AuthAccessStateTests: XCTestCase {
    func testModelAndSubscriptionAccessMessagesLocalizeFailurePayloadVerbatim() {
        let payload = #"RPC error {"provider":"anthropic","code":"raw/42"}"#

        XCTAssertEqual(
            ModelAccessState.failed(message: payload).unavailableMessage(l10n: L10n(language: .english)),
            #"Could not refresh model access: RPC error {"provider":"anthropic","code":"raw/42"}"#
        )
        XCTAssertEqual(
            ModelAccessState.failed(message: payload).unavailableMessage(l10n: L10n(language: .portugueseBrazil)),
            #"Não foi possível atualizar o acesso ao modelo: RPC error {"provider":"anthropic","code":"raw/42"}"#
        )
        XCTAssertEqual(
            SubscriptionAccessState.failed(message: payload).unavailableMessage(l10n: L10n(language: .portugueseBrazil)),
            #"Não foi possível atualizar o acesso por assinatura: RPC error {"provider":"anthropic","code":"raw/42"}"#
        )
    }

    func testModelPickerEmptyStatesLocalizeAppOwnedCopy() {
        var state = AuthAccessState(authentication: .unauthenticated)

        XCTAssertEqual(state.modelPickerEmptyTitle(l10n: L10n(language: .english)), "Not logged in")
        XCTAssertEqual(state.modelPickerEmptyTitle(l10n: L10n(language: .portugueseBrazil)), "Não conectado")
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: L10n(language: .portugueseBrazil)),
            "Use Login para adicionar uma chave de API ou assinatura e depois atualize."
        )

        state.modelAccess = .failed(message: "raw failure /tmp/auth.json")

        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: L10n(language: .portugueseBrazil)),
            "raw failure /tmp/auth.json"
        )
    }

    func testModelPickerAvailableBranchDetailsLocalizeAppOwnedCopy() {
        let l10n = L10n(language: .portugueseBrazil)
        var state = AuthAccessState(modelAccess: .refreshing)

        XCTAssertEqual(state.modelPickerEmptyTitle(l10n: l10n), "Atualizando acesso ao modelo")

        state.modelAccess = .unavailable(reason: nil)
        XCTAssertEqual(state.modelPickerEmptyTitle(l10n: l10n), "Sem acesso ao modelo")
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: l10n),
            "Nenhum modelo autenticado foi retornado para as credenciais atuais."
        )

        state.modelAccess = .available(providerID: "openai")
        state.subscriptionAccess = .active(providerID: "openai")
        XCTAssertEqual(state.modelPickerEmptyTitle(l10n: l10n), "Nenhum modelo carregado")
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: l10n),
            "O acesso ao modelo e o acesso por assinatura estão ativos, mas nenhum modelo foi retornado para exibição."
        )

        state.subscriptionAccess = .inactive(reason: nil)
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: l10n),
            "O acesso ao modelo está disponível sem uma assinatura ativa."
        )

        state.subscriptionAccess = .refreshing
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: l10n),
            "O acesso ao modelo está disponível enquanto o acesso por assinatura ainda está sendo verificado."
        )

        state.subscriptionAccess = .failed(message: "raw subscription payload")
        XCTAssertEqual(
            state.modelPickerEmptyDetail(l10n: l10n),
            "O acesso ao modelo está disponível, mas a atualização da assinatura falhou: raw subscription payload"
        )
    }

    func testAPIKeyModelsEnableModelAccessWithoutSubscriptionAccess() {
        var state = AuthAccessState(
            authentication: .authenticated(providerID: "anthropic"),
            modelAccess: .available(providerID: "anthropic"),
            subscriptionAccess: .active(providerID: "anthropic"),
            refreshEpoch: 0,
            lastRefreshStartedAt: nil,
            lastRefreshCompletedAt: nil
        )
        var tracker = AuthAccessRefreshTracker()

        let ids = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["openai": .apiKey]),
            stateCommandID: "state-a",
            modelsCommandID: "models-a"
        )

        XCTAssertEqual(ids.epoch, 1)
        XCTAssertEqual(state.modelAccess, .refreshing)
        XCTAssertEqual(state.subscriptionAccess, .refreshing)
        XCTAssertEqual(tracker.trackedCommandCount, 2)

        XCTAssertEqual(
            tracker.handle(response: response(id: "models-a", command: "get_available_models", data: modelsData(provider: "openai")), state: &state),
            .waiting
        )
        XCTAssertEqual(state.modelAccess, .refreshing)
        XCTAssertEqual(tracker.trackedCommandCount, 1)

        XCTAssertEqual(
            tracker.handle(response: response(id: "state-a", command: "get_state"), state: &state),
            .completed(models: [PiModel(provider: "openai", modelId: "gpt-5", name: "GPT-5")])
        )
        XCTAssertEqual(tracker.trackedCommandCount, 0)
        XCTAssertEqual(state.authentication, .authenticated(providerID: "openai"))
        XCTAssertEqual(state.modelAccess, .available(providerID: "openai"))
        XCTAssertEqual(
            state.subscriptionAccess,
            .inactive(reason: "Model access is available, but no subscription-backed credentials were found.")
        )
    }

    func testOAuthModelsEnableSubscriptionAccess() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["openai-codex": .oauth]),
            stateCommandID: "state-b",
            modelsCommandID: "models-b"
        )

        _ = tracker.handle(response: response(id: "state-b", command: "get_state"), state: &state)
        let effect = tracker.handle(
            response: response(id: "models-b", command: "get_available_models", data: modelsData(provider: "openai-codex")),
            state: &state
        )

        XCTAssertEqual(effect, .completed(models: [PiModel(provider: "openai-codex", modelId: "gpt-5", name: "GPT-5")]))
        XCTAssertEqual(state.modelAccess, .available(providerID: "openai-codex"))
        XCTAssertEqual(state.subscriptionAccess, .active(providerID: "openai-codex"))
    }

    func testSuccessfulRefreshReasonsLocalizeWithSelectedLanguage() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["openai": .apiKey]),
            stateCommandID: "state-localized",
            modelsCommandID: "models-localized"
        )

        _ = tracker.handle(
            response: response(id: "state-localized", command: "get_state"),
            state: &state,
            l10n: L10n(language: .portugueseBrazil)
        )
        _ = tracker.handle(
            response: response(id: "models-localized", command: "get_available_models", data: modelsData(provider: "openai")),
            state: &state,
            l10n: L10n(language: .portugueseBrazil)
        )

        XCTAssertEqual(
            state.subscriptionAccess,
            .inactive(reason: "O acesso ao modelo está disponível, mas nenhuma credencial baseada em assinatura foi encontrada.")
        )
    }

    func testEnvironmentBackedModelsDoNotBecomeSubscriptionAccessWhenCredentialSourceIsUnknown() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(),
            stateCommandID: "state-c",
            modelsCommandID: "models-c"
        )

        _ = tracker.handle(response: response(id: "state-c", command: "get_state"), state: &state)
        _ = tracker.handle(
            response: response(id: "models-c", command: "get_available_models", data: modelsData(provider: "anthropic")),
            state: &state
        )

        XCTAssertEqual(state.authentication, .authenticated(providerID: "anthropic"))
        XCTAssertEqual(state.modelAccess, .available(providerID: "anthropic"))
        XCTAssertFalse(state.hasActiveSubscriptionAccess)
    }

    func testStaleRefreshResponsesCannotOverwriteNewerAccessState() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["anthropic": .oauth]),
            stateCommandID: "state-old",
            modelsCommandID: "models-old"
        )

        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["openai": .apiKey]),
            stateCommandID: "state-new",
            modelsCommandID: "models-new"
        )
        _ = tracker.handle(response: response(id: "state-new", command: "get_state"), state: &state)
        _ = tracker.handle(
            response: response(id: "models-new", command: "get_available_models", data: modelsData(provider: "openai")),
            state: &state
        )
        let expected = state

        XCTAssertEqual(
            tracker.handle(response: response(id: "state-old", command: "get_state"), state: &state),
            .notAccessRefresh
        )
        XCTAssertEqual(
            tracker.handle(response: response(id: "models-old", command: "get_available_models", data: modelsData(provider: "anthropic")), state: &state),
            .notAccessRefresh
        )
        XCTAssertEqual(state, expected)
        XCTAssertEqual(tracker.trackedCommandCount, 0)
    }

    func testVeryLateTrackedRefreshResponsesStayIgnoredAfterManyNewerRefreshes() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["anthropic": .oauth]),
            stateCommandID: "state-very-old",
            modelsCommandID: "models-very-old"
        )

        for index in 0..<12 {
            _ = tracker.begin(
                state: &state,
                credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["openai": .apiKey]),
                stateCommandID: "state-\(index)",
                modelsCommandID: "models-\(index)"
            )
        }
        _ = tracker.handle(response: response(id: "state-11", command: "get_state"), state: &state)
        _ = tracker.handle(
            response: response(id: "models-11", command: "get_available_models", data: modelsData(provider: "openai")),
            state: &state
        )
        let expected = state

        XCTAssertEqual(
            tracker.handle(response: response(id: "models-very-old", command: "get_available_models", data: modelsData(provider: "anthropic")), state: &state),
            .notAccessRefresh
        )
        XCTAssertEqual(state, expected)
        XCTAssertEqual(tracker.trackedCommandCount, 0)
    }

    func testRefreshFailureClearsPreviousActiveAccess() {
        var state = AuthAccessState(
            authentication: .authenticated(providerID: "anthropic"),
            modelAccess: .available(providerID: "anthropic"),
            subscriptionAccess: .active(providerID: "anthropic"),
            refreshEpoch: 0,
            lastRefreshStartedAt: nil,
            lastRefreshCompletedAt: nil
        )
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["anthropic": .oauth]),
            stateCommandID: "state-d",
            modelsCommandID: "models-d"
        )

        XCTAssertEqual(
            tracker.handle(response: response(id: "models-d", command: "get_available_models", success: false, error: "network down"), state: &state),
            .failed(message: "network down")
        )
        XCTAssertEqual(state.authentication, .failed(message: "network down"))
        XCTAssertEqual(state.modelAccess, .failed(message: "network down"))
        XCTAssertEqual(state.subscriptionAccess, .failed(message: "network down"))
        XCTAssertEqual(tracker.trackedCommandCount, 0)
        XCTAssertEqual(
            tracker.handle(response: response(id: "state-d", command: "get_state"), state: &state),
            .notAccessRefresh
        )
    }

    func testInvalidationPrunesAccessRefreshCommandIDs() {
        var state = AuthAccessState()
        var tracker = AuthAccessRefreshTracker()
        _ = tracker.begin(
            state: &state,
            credentialSnapshot: AuthCredentialSnapshot(credentialsByProvider: ["anthropic": .oauth]),
            stateCommandID: "state-invalidated",
            modelsCommandID: "models-invalidated"
        )
        XCTAssertEqual(tracker.trackedCommandCount, 2)

        tracker.invalidate(state: &state, authentication: .unauthenticated)

        XCTAssertEqual(tracker.trackedCommandCount, 0)
        XCTAssertEqual(
            tracker.handle(response: response(id: "state-invalidated", command: "get_state"), state: &state),
            .notAccessRefresh
        )
    }

    func testNativeAuthStoreSnapshotAndRemovalPreserveOtherProviders() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authFileURL = directory.appendingPathComponent("auth.json")
        try NativeAuthStore.saveAPIKey(provider: "openai", apiKey: "sk-test", authFileURL: authFileURL)
        try """
        {
          "anthropic" : { "type" : "oauth", "expires" : 9999999999999 },
          "openai" : { "type" : "api_key", "key" : "sk-test" }
        }
        """.data(using: .utf8)!.write(to: authFileURL, options: .atomic)

        var snapshot = try NativeAuthStore.credentialSnapshot(authFileURL: authFileURL)
        XCTAssertEqual(snapshot.kind(for: "openai"), .apiKey)
        XCTAssertEqual(snapshot.kind(for: "anthropic"), .oauth)

        try NativeAuthStore.removeCredential(provider: "openai", authFileURL: authFileURL)
        snapshot = try NativeAuthStore.credentialSnapshot(authFileURL: authFileURL)
        XCTAssertNil(snapshot.kind(for: "openai"))
        XCTAssertEqual(snapshot.kind(for: "anthropic"), .oauth)
    }

    func testProviderLoginURLDetectorWaitsForCompleteSplitURL() throws {
        var detector = ProviderLoginURLDetector()

        XCTAssertNil(detector.append("Open https://auth.example/"))
        XCTAssertEqual(
            detector.append("callback?code=abc\n"),
            URL(string: "https://auth.example/callback?code=abc")
        )
    }

    func testProviderLoginURLDetectorCanFinalizeURLWithoutTrailingBoundary() throws {
        var detector = ProviderLoginURLDetector()

        XCTAssertNil(detector.append("Open https://auth.example/callback?code=abc"))
        XCTAssertEqual(
            detector.detectFinalURL(),
            URL(string: "https://auth.example/callback?code=abc")
        )
    }

    func testProviderLoginURLDetectorUsesLatestCompleteWebURL() throws {
        var detector = ProviderLoginURLDetector()

        XCTAssertEqual(
            detector.append("First https://auth.example/one\nThen https://auth.example/two\n"),
            URL(string: "https://auth.example/two")
        )
    }

    func testProviderLoginURLDetectorAllowsSentencePunctuationAfterURL() throws {
        var detector = ProviderLoginURLDetector()

        XCTAssertEqual(
            detector.append("Open https://auth.example/callback?code=abc.\n"),
            URL(string: "https://auth.example/callback?code=abc")
        )
    }

    func testProviderLoginURLDetectorIgnoresNonWebLinks() {
        var detector = ProviderLoginURLDetector()

        XCTAssertNil(detector.append("Email support@example.com\n"))
        XCTAssertNil(detector.append("Use file:///tmp/token\n"))
    }

    func testProviderLoginURLOpeningTrackerSuppressesDuplicatesPerAttempt() throws {
        var tracker = ProviderLoginURLOpeningTracker()
        let url = try XCTUnwrap(URL(string: "https://auth.example/callback?code=abc"))

        XCTAssertTrue(tracker.shouldOpen(url))
        XCTAssertFalse(tracker.shouldOpen(url))

        tracker.reset()
        XCTAssertTrue(tracker.shouldOpen(url))
    }

    private func response(
        id: String,
        command: String,
        success: Bool = true,
        data: [String: Any]? = nil,
        error: String? = nil
    ) -> PiRPCResponse {
        var payload: [String: Any] = [
            "type": "response",
            "id": id,
            "command": command,
            "success": success
        ]
        if let data {
            payload["data"] = data
        }
        if let error {
            payload["error"] = error
        }
        return PiRPCResponse(payload: payload)
    }

    private func modelsData(provider: String, modelID: String = "gpt-5", name: String = "GPT-5") -> [String: Any] {
        [
            "models": [
                [
                    "provider": provider,
                    "id": modelID,
                    "name": name
                ]
            ]
        ]
    }
}
