import Foundation

/// User-facing phase for a provider-owned subscription login attempt.
enum SubscriptionLoginPhase: Equatable {
    case notStarted
    case starting
    case waitingForProvider(url: URL?)
    case refreshingAccess
    case confirmed(providerID: String?)
    case failed(message: String)
    case stopped
}

struct SubscriptionLoginAttemptState: Equatable {
    var provider: LoginProvider?
    var attemptID: UUID?
    var phase: SubscriptionLoginPhase = .notStarted
    var lastURL: URL?
    var exitStatus: Int32?
}

extension OAuthLoginRunner {
    func markStarting(provider: LoginProvider, attemptID: UUID) {
        currentProvider = provider
        currentAttemptID = attemptID
        exitStatus = nil
        lastURL = nil
        attemptState = SubscriptionLoginAttemptState(
            provider: provider,
            attemptID: attemptID,
            phase: .starting,
            lastURL: nil,
            exitStatus: nil
        )
    }

    func markWaitingForProvider(url: URL?) {
        let providerURL = url ?? attemptState.lastURL
        if let providerURL {
            lastURL = providerURL
        }
        attemptState.provider = currentProvider ?? attemptState.provider
        attemptState.attemptID = currentAttemptID ?? attemptState.attemptID
        attemptState.lastURL = providerURL
        attemptState.phase = .waitingForProvider(url: providerURL)
    }

    func markRefreshingAccess() {
        attemptState.provider = currentProvider ?? attemptState.provider
        attemptState.attemptID = currentAttemptID ?? attemptState.attemptID
        attemptState.lastURL = lastURL ?? attemptState.lastURL
        attemptState.exitStatus = exitStatus ?? attemptState.exitStatus
        attemptState.phase = .refreshingAccess
    }

    func markConfirmed(providerID: String?) {
        attemptState.provider = currentProvider ?? attemptState.provider
        attemptState.attemptID = currentAttemptID ?? attemptState.attemptID
        attemptState.lastURL = lastURL ?? attemptState.lastURL
        attemptState.exitStatus = exitStatus ?? attemptState.exitStatus
        attemptState.phase = .confirmed(providerID: providerID)
    }

    func markFailed(_ message: String, exitStatus: Int32? = nil) {
        if let exitStatus {
            self.exitStatus = exitStatus
        }
        attemptState.provider = currentProvider ?? attemptState.provider
        attemptState.attemptID = currentAttemptID ?? attemptState.attemptID
        attemptState.lastURL = lastURL ?? attemptState.lastURL
        attemptState.exitStatus = exitStatus ?? self.exitStatus ?? attemptState.exitStatus
        attemptState.phase = .failed(message: message)
    }

    func markStopped() {
        attemptState.provider = currentProvider ?? attemptState.provider
        attemptState.attemptID = currentAttemptID ?? attemptState.attemptID
        attemptState.lastURL = lastURL ?? attemptState.lastURL
        attemptState.exitStatus = exitStatus ?? attemptState.exitStatus
        attemptState.phase = .stopped
    }

    func resetAttemptState() {
        currentProvider = nil
        currentAttemptID = nil
        exitStatus = nil
        lastURL = nil
        attemptState = SubscriptionLoginAttemptState()
    }
}
