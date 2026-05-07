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
        switch self {
        case .unknown:
            return "Model access has not been checked yet. Refresh state or log in."
        case .refreshing:
            return "Model access is refreshing. Try again when refresh completes."
        case .unavailable(let reason):
            return reason ?? "No model access is available."
        case .available:
            return "Model access is available."
        case .failed(let message):
            return "Could not refresh model access: \(message)"
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
        switch self {
        case .unknown:
            return "Subscription access has not been checked yet."
        case .refreshing:
            return "Subscription access is refreshing."
        case .inactive(let reason):
            return reason ?? "No active subscription found."
        case .active:
            return "Subscription access is active."
        case .failed(let message):
            return "Could not refresh subscription access: \(message)"
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
        switch modelAccess {
        case .unknown:
            switch authentication {
            case .unauthenticated:
                return "Not logged in"
            default:
                return "Model access not checked"
            }
        case .refreshing:
            return "Refreshing model access"
        case .unavailable:
            return "No model access"
        case .available:
            return "No models loaded"
        case .failed:
            return "Could not refresh model access"
        }
    }

    var modelPickerEmptyDetail: String {
        switch modelAccess {
        case .unknown:
            return "Use Login to add an API key or subscription, then refresh."
        case .refreshing:
            return "The app is checking the current credentials with pi."
        case .unavailable(let reason):
            return reason ?? "No authenticated models were returned for the current credentials."
        case .available:
            switch subscriptionAccess {
            case .active:
                return "Model access and subscription access are active, but no models were returned to display."
            case .inactive(let reason):
                return reason ?? "Model access is available without an active subscription."
            case .unknown, .refreshing:
                return "Model access is available while subscription access is still being checked."
            case .failed(let message):
                return "Model access is available, but subscription refresh failed: \(message)"
            }
        case .failed(let message):
            return message
        }
    }

    var sendPromptUnavailableMessage: String? {
        modelAccess.isAvailable ? nil : modelAccess.unavailableMessage
    }

    var subscriptionGateUnavailableMessage: String? {
        subscriptionAccess.isActive ? nil : subscriptionAccess.unavailableMessage
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

    mutating func begin(
        state: inout AuthAccessState,
        credentialSnapshot: AuthCredentialSnapshot,
        now: Date = Date(),
        stateCommandID: String = UUID().uuidString,
        modelsCommandID: String = UUID().uuidString
    ) -> AccessRefreshCommandIDs {
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
            return .ignoredStale
        }

        guard responseID == current.stateCommandID || responseID == current.modelsCommandID else {
            return .ignoredStale
        }

        guard response.success else {
            let message = response.error ?? "\(response.command) failed"
            pending = nil
            state.authentication = .failed(message: message)
            state.modelAccess = .failed(message: message)
            state.subscriptionAccess = .failed(message: message)
            state.lastRefreshCompletedAt = now
            return .failed(message: message)
        }

        if responseID == current.stateCommandID {
            current.receivedState = true
        }

        if responseID == current.modelsCommandID {
            current.receivedModels = Self.models(from: response.data)
        }

        guard current.receivedState, let models = current.receivedModels else {
            pending = current
            return .waiting
        }

        pending = nil
        applySuccessfulRefresh(
            models: models,
            credentialSnapshot: current.credentialSnapshot,
            state: &state,
            now: now
        )
        return .completed(models: models)
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
            state.modelAccess = .unavailable(reason: "No authenticated models found.")
            state.subscriptionAccess = .inactive(reason: "No active subscription found.")
        } else {
            state.modelAccess = .available(providerID: singleModelProvider)
            let subscriptionProviders = distinctModelProviders
                .filter { credentialSnapshot.isSubscriptionBackedModelProvider($0) }

            if subscriptionProviders.isEmpty {
                state.subscriptionAccess = .inactive(
                    reason: "Model access is available, but no subscription-backed credentials were found."
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
