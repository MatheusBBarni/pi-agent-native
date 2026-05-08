import Foundation

struct SubscriptionLoginStatusSummary: Equatable {
    enum Emphasis: Equatable {
        case neutral
        case progress
        case success
        case failure
    }

    var title: String
    var detail: String
    var providerName: String
    var attemptProviderName: String?
    var providerLoginURL: URL?
    var emphasis: Emphasis
    var isConfirmedForSelectedProvider: Bool

    static func make(
        selectedProvider: LoginProvider,
        attemptState: SubscriptionLoginAttemptState
    ) -> SubscriptionLoginStatusSummary {
        let providerName = selectedProvider.name
        let attemptProviderName = attemptState.provider?.name
        let providerLoginURL = providerLoginURL(from: attemptState)

        guard attemptMatchesSelectedProvider(selectedProvider, attemptState: attemptState) else {
            return SubscriptionLoginStatusSummary(
                title: "Ready to sign in with \(providerName)",
                detail: providerMismatchDetail(
                    selectedProvider: selectedProvider,
                    attemptProviderName: attemptProviderName
                ),
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .neutral,
                isConfirmedForSelectedProvider: false
            )
        }

        switch attemptState.phase {
        case .notStarted:
            return SubscriptionLoginStatusSummary(
                title: "Ready to sign in with \(providerName)",
                detail: "Start provider login when you're ready. Accounts and billing stay with \(providerName).",
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .neutral,
                isConfirmedForSelectedProvider: false
            )
        case .starting:
            return SubscriptionLoginStatusSummary(
                title: "Starting \(providerName) login",
                detail: "Waiting for the provider command to produce the next step.",
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .progress,
                isConfirmedForSelectedProvider: false
            )
        case .waitingForProvider:
            return SubscriptionLoginStatusSummary(
                title: "Continue with \(providerName)",
                detail: waitingDetail(providerName: providerName, hasURL: providerLoginURL != nil),
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .progress,
                isConfirmedForSelectedProvider: false
            )
        case .refreshingAccess:
            return SubscriptionLoginStatusSummary(
                title: "Checking \(providerName) access",
                detail: "Provider login finished. Pi Agent Native is refreshing model access before confirming.",
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .progress,
                isConfirmedForSelectedProvider: false
            )
        case .confirmed(let providerID):
            guard providerID == nil || providerID == selectedProvider.id else {
                return SubscriptionLoginStatusSummary(
                    title: "Ready to sign in with \(providerName)",
                    detail: "The latest confirmed access is not for \(providerName). Start provider login to verify this provider.",
                    providerName: providerName,
                    attemptProviderName: attemptProviderName,
                    providerLoginURL: providerLoginURL,
                    emphasis: .neutral,
                    isConfirmedForSelectedProvider: false
                )
            }
            return SubscriptionLoginStatusSummary(
                title: "\(providerName) access confirmed",
                detail: "The latest access check found usable provider-backed model access.",
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .success,
                isConfirmedForSelectedProvider: true
            )
        case .failed(let message):
            return SubscriptionLoginStatusSummary(
                title: "\(providerName) login failed",
                detail: message.isEmpty ? "Provider login did not finish. Check the output below and try again." : message,
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .failure,
                isConfirmedForSelectedProvider: false
            )
        case .stopped:
            return SubscriptionLoginStatusSummary(
                title: "\(providerName) login stopped",
                detail: "Provider login was stopped before access was confirmed.",
                providerName: providerName,
                attemptProviderName: attemptProviderName,
                providerLoginURL: providerLoginURL,
                emphasis: .neutral,
                isConfirmedForSelectedProvider: false
            )
        }
    }

    private static func attemptMatchesSelectedProvider(
        _ selectedProvider: LoginProvider,
        attemptState: SubscriptionLoginAttemptState
    ) -> Bool {
        guard let attemptProvider = attemptState.provider else {
            return attemptState.phase == .notStarted
        }

        return attemptProvider.id == selectedProvider.id
    }

    private static func providerLoginURL(from attemptState: SubscriptionLoginAttemptState) -> URL? {
        switch attemptState.phase {
        case .waitingForProvider(let url):
            return url ?? attemptState.lastURL
        case .notStarted, .starting, .refreshingAccess, .confirmed, .failed, .stopped:
            return attemptState.lastURL
        }
    }

    private static func waitingDetail(providerName: String, hasURL: Bool) -> String {
        if hasURL {
            return "Complete the provider page, then return here while access is checked. The Provider Login URL can be reopened below."
        }

        return "Complete the provider prompts, then return here while access is checked."
    }

    private static func providerMismatchDetail(
        selectedProvider: LoginProvider,
        attemptProviderName: String?
    ) -> String {
        guard let attemptProviderName else {
            return "Start provider login when you're ready. Accounts and billing stay with \(selectedProvider.name)."
        }

        return "The last login attempt was for \(attemptProviderName). Start \(selectedProvider.name) login to verify this provider."
    }
}
