import Foundation

/// User-facing credential relationship with the native app and the pi credential store.
enum AuthenticationState: Equatable {
    case unknown
    case unauthenticated
    case authenticating(providerID: String)
    case authenticated(providerID: String?)
    case failed(message: String)
}

/// Ability to run model-backed interactions from any supported credential source.
enum ModelAccessState: Equatable {
    case unknown
    case refreshing
    case unavailable(reason: String?)
    case available(providerID: String?)
    case failed(message: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var unavailableMessage: String {
        unavailableMessage(l10n: L10n(language: .english))
    }

    func unavailableMessage(l10n: L10n) -> String {
        switch self {
        case .unknown:
            return l10n.string("auth.model_access.unavailable.unknown")
        case .refreshing:
            return l10n.string("auth.model_access.unavailable.refreshing")
        case .unavailable(let reason):
            return reason ?? l10n.string("auth.model_access.unavailable.no_access")
        case .available:
            return l10n.string("auth.model_access.available")
        case .failed(let message):
            return l10n.string("auth.model_access.unavailable.failed", message)
        }
    }
}

/// Access level for actions that require a subscription-backed credential.
enum SubscriptionAccessState: Equatable {
    case unknown
    case refreshing
    case inactive(reason: String?)
    case active(providerID: String?)
    case failed(message: String)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var unavailableMessage: String {
        unavailableMessage(l10n: L10n(language: .english))
    }

    func unavailableMessage(l10n: L10n) -> String {
        switch self {
        case .unknown:
            return l10n.string("auth.subscription_access.unavailable.unknown")
        case .refreshing:
            return l10n.string("auth.subscription_access.unavailable.refreshing")
        case .inactive(let reason):
            return reason ?? l10n.string("auth.subscription_access.unavailable.no_active")
        case .active:
            return l10n.string("auth.subscription_access.active")
        case .failed(let message):
            return l10n.string("auth.subscription_access.unavailable.failed", message)
        }
    }
}

struct AuthAccessState: Equatable {
    var authentication: AuthenticationState = .unknown
    var modelAccess: ModelAccessState = .unknown
    var subscriptionAccess: SubscriptionAccessState = .unknown
    var refreshEpoch: Int = 0
    var lastRefreshStartedAt: Date?
    var lastRefreshCompletedAt: Date?

    var hasAvailableModelAccess: Bool {
        modelAccess.isAvailable
    }

    var hasActiveSubscriptionAccess: Bool {
        subscriptionAccess.isActive
    }

    var modelPickerEmptyTitle: String {
        modelPickerEmptyTitle(l10n: L10n(language: .english))
    }

    func modelPickerEmptyTitle(l10n: L10n) -> String {
        switch modelAccess {
        case .unknown:
            switch authentication {
            case .unauthenticated:
                return l10n.string("auth.model_picker.empty.title.not_logged_in")
            default:
                return l10n.string("auth.model_picker.empty.title.not_checked")
            }
        case .refreshing:
            return l10n.string("auth.model_picker.empty.title.refreshing")
        case .unavailable:
            return l10n.string("auth.model_picker.empty.title.no_access")
        case .available:
            return l10n.string("auth.model_picker.empty.title.no_models")
        case .failed:
            return l10n.string("auth.model_picker.empty.title.refresh_failed")
        }
    }

    var modelPickerEmptyDetail: String {
        modelPickerEmptyDetail(l10n: L10n(language: .english))
    }

    func modelPickerEmptyDetail(l10n: L10n) -> String {
        switch modelAccess {
        case .unknown:
            return l10n.string("auth.model_picker.empty.detail.unknown")
        case .refreshing:
            return l10n.string("auth.model_picker.empty.detail.refreshing")
        case .unavailable(let reason):
            return reason ?? l10n.string("auth.model_picker.empty.detail.no_authenticated_models")
        case .available:
            switch subscriptionAccess {
            case .active:
                return l10n.string("auth.model_picker.empty.detail.active_no_models")
            case .inactive(let reason):
                return reason ?? l10n.string("auth.model_picker.empty.detail.no_active_subscription")
            case .unknown, .refreshing:
                return l10n.string("auth.model_picker.empty.detail.subscription_checking")
            case .failed(let message):
                return l10n.string("auth.model_picker.empty.detail.subscription_failed", message)
            }
        case .failed(let message):
            return message
        }
    }

    var sendPromptUnavailableMessage: String? {
        sendPromptUnavailableMessage(l10n: L10n(language: .english))
    }

    func sendPromptUnavailableMessage(l10n: L10n) -> String? {
        modelAccess.isAvailable ? nil : modelAccess.unavailableMessage(l10n: l10n)
    }

    var subscriptionGateUnavailableMessage: String? {
        subscriptionGateUnavailableMessage(l10n: L10n(language: .english))
    }

    func subscriptionGateUnavailableMessage(l10n: L10n) -> String? {
        subscriptionAccess.isActive ? nil : subscriptionAccess.unavailableMessage(l10n: l10n)
    }
}

enum AuthCredentialKind: Equatable {
    case apiKey
    case oauth
    case other(String?)
}

struct AuthCredentialSnapshot: Equatable {
    var credentialsByProvider: [String: AuthCredentialKind]

    init(credentialsByProvider: [String: AuthCredentialKind] = [:]) {
        self.credentialsByProvider = credentialsByProvider
    }

    var isEmpty: Bool {
        credentialsByProvider.isEmpty
    }

    var singleProviderID: String? {
        credentialsByProvider.count == 1 ? credentialsByProvider.keys.first : nil
    }

    func kind(for providerID: String) -> AuthCredentialKind? {
        credentialsByProvider[providerID]
    }

    func isSubscriptionBackedModelProvider(_ modelProviderID: String) -> Bool {
        credentialsByProvider.contains { credentialProviderID, kind in
            guard kind == .oauth else { return false }
            return AuthProviderMapping.modelProviderIDs(forSubscriptionCredentialProvider: credentialProviderID)
                .contains(modelProviderID)
        }
    }
}

enum AuthProviderMapping {
    private static let subscriptionModelProviderIDsByCredentialProvider: [String: Set<String>] = [
        "anthropic": ["anthropic"],
        "openai-codex": ["openai-codex"],
        "github-copilot": ["github-copilot"]
    ]

    static func modelProviderIDs(forSubscriptionCredentialProvider providerID: String) -> Set<String> {
        subscriptionModelProviderIDsByCredentialProvider[providerID] ?? [providerID]
    }
}

struct AccessRefreshCommandIDs: Equatable {
    var epoch: Int
    var stateCommandID: String
    var modelsCommandID: String
}

enum AccessRefreshResponseEffect: Equatable {
    case notAccessRefresh
    case ignoredStale
    case waiting
    case completed(models: [PiModel])
    case failed(message: String)
}

struct AuthAccessRefreshTracker: Equatable {
    private struct PendingAccessRefresh: Equatable {
        var epoch: Int
        var stateCommandID: String
        var modelsCommandID: String
        var credentialSnapshot: AuthCredentialSnapshot
        var receivedState = false
        var receivedModels: [PiModel]?
    }

    private var pending: PendingAccessRefresh?
    private var commandEpochs: [String: Int] = [:]

    var trackedCommandCount: Int {
        commandEpochs.count
    }

    mutating func begin(
        state: inout AuthAccessState,
        credentialSnapshot: AuthCredentialSnapshot,
        now: Date = Date(),
        stateCommandID: String = UUID().uuidString,
        modelsCommandID: String = UUID().uuidString
    ) -> AccessRefreshCommandIDs {
        pruneTrackedCommands()
        let epoch = state.refreshEpoch + 1
        state.authentication = credentialSnapshot.isEmpty ? .unknown : .authenticated(providerID: credentialSnapshot.singleProviderID)
        state.modelAccess = .refreshing
        state.subscriptionAccess = .refreshing
        state.refreshEpoch = epoch
        state.lastRefreshStartedAt = now
        state.lastRefreshCompletedAt = nil

        pending = PendingAccessRefresh(
            epoch: epoch,
            stateCommandID: stateCommandID,
            modelsCommandID: modelsCommandID,
            credentialSnapshot: credentialSnapshot
        )
        commandEpochs[stateCommandID] = epoch
        commandEpochs[modelsCommandID] = epoch

        return AccessRefreshCommandIDs(
            epoch: epoch,
            stateCommandID: stateCommandID,
            modelsCommandID: modelsCommandID
        )
    }

    mutating func invalidate(
        state: inout AuthAccessState,
        authentication: AuthenticationState,
        modelAccess: ModelAccessState = .unknown,
        subscriptionAccess: SubscriptionAccessState = .unknown,
        now: Date = Date()
    ) {
        pending = nil
        pruneTrackedCommands()
        state.authentication = authentication
        state.modelAccess = modelAccess
        state.subscriptionAccess = subscriptionAccess
        state.refreshEpoch += 1
        state.lastRefreshStartedAt = now
        state.lastRefreshCompletedAt = nil
    }

    mutating func failCurrentRefresh(
        state: inout AuthAccessState,
        message: String,
        now: Date = Date()
    ) -> AccessRefreshResponseEffect {
        guard pending != nil else { return .notAccessRefresh }
        pruneTrackedCommands()
        pending = nil
        state.authentication = .failed(message: message)
        state.modelAccess = .failed(message: message)
        state.subscriptionAccess = .failed(message: message)
        state.lastRefreshCompletedAt = now
        return .failed(message: message)
    }

    mutating func handle(
        response: PiRPCResponse,
        state: inout AuthAccessState,
        l10n: L10n = L10n(language: .english),
        now: Date = Date()
    ) -> AccessRefreshResponseEffect {
        guard let responseID = response.id,
              let epoch = commandEpochs[responseID]
        else {
            return .notAccessRefresh
        }

        guard var current = pending,
              current.epoch == epoch
        else {
            commandEpochs.removeValue(forKey: responseID)
            return .ignoredStale
        }

        guard responseID == current.stateCommandID || responseID == current.modelsCommandID else {
            commandEpochs.removeValue(forKey: responseID)
            return .ignoredStale
        }

        guard response.success else {
            let message = response.error ?? "\(response.command) failed"
            pruneTrackedCommands(for: current)
            pending = nil
            state.authentication = .failed(message: message)
            state.modelAccess = .failed(message: message)
            state.subscriptionAccess = .failed(message: message)
            state.lastRefreshCompletedAt = now
            return .failed(message: message)
        }

        if responseID == current.stateCommandID {
            current.receivedState = true
            commandEpochs.removeValue(forKey: responseID)
        }

        if responseID == current.modelsCommandID {
            current.receivedModels = Self.models(from: response.data)
            commandEpochs.removeValue(forKey: responseID)
        }

        guard current.receivedState, let models = current.receivedModels else {
            pending = current
            return .waiting
        }

        pruneTrackedCommands(for: current)
        pending = nil
        applySuccessfulRefresh(
            models: models,
            credentialSnapshot: current.credentialSnapshot,
            state: &state,
            l10n: l10n,
            now: now
        )
        return .completed(models: models)
    }

    private mutating func pruneTrackedCommands() {
        commandEpochs.removeAll(keepingCapacity: true)
    }

    private mutating func pruneTrackedCommands(for refresh: PendingAccessRefresh) {
        commandEpochs.removeValue(forKey: refresh.stateCommandID)
        commandEpochs.removeValue(forKey: refresh.modelsCommandID)
    }

    private static func models(from data: [String: Any]?) -> [PiModel] {
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

    private func applySuccessfulRefresh(
        models: [PiModel],
        credentialSnapshot: AuthCredentialSnapshot,
        state: inout AuthAccessState,
        l10n: L10n,
        now: Date
    ) {
        let distinctModelProviders = Set(models.map(\.provider))
        let singleModelProvider = distinctModelProviders.count == 1 ? distinctModelProviders.first : nil

        if credentialSnapshot.isEmpty {
            state.authentication = models.isEmpty ? .unauthenticated : .authenticated(providerID: singleModelProvider)
        } else {
            state.authentication = .authenticated(providerID: credentialSnapshot.singleProviderID)
        }

        if models.isEmpty {
            state.modelAccess = .unavailable(reason: l10n.string("auth.model_access.reason.no_authenticated_models"))
            state.subscriptionAccess = .inactive(reason: l10n.string("auth.subscription_access.reason.no_active"))
        } else {
            state.modelAccess = .available(providerID: singleModelProvider)
            let subscriptionProviders = distinctModelProviders
                .filter { credentialSnapshot.isSubscriptionBackedModelProvider($0) }

            if subscriptionProviders.isEmpty {
                state.subscriptionAccess = .inactive(
                    reason: l10n.string("auth.subscription_access.reason.no_subscription_credentials")
                )
            } else {
                state.subscriptionAccess = .active(
                    providerID: subscriptionProviders.count == 1 ? subscriptionProviders.first : nil
                )
            }
        }

        state.lastRefreshCompletedAt = now
    }
}
