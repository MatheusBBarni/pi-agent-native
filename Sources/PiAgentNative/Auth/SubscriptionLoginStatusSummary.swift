import Foundation

struct SubscriptionLoginStatusSummary: Equatable {
    var title: String
    var detail: String

    init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    init(
        authAccess: AuthAccessState,
        l10n: L10n,
        providerDisplayName: (String) -> String = LoginProviderCatalog.displayName(forID:)
    ) {
        title = Self.title(
            for: authAccess.authentication,
            l10n: l10n,
            providerDisplayName: providerDisplayName
        )
        detail = Self.detail(for: authAccess, l10n: l10n)
    }

    private static func title(
        for authentication: AuthenticationState,
        l10n: L10n,
        providerDisplayName: (String) -> String
    ) -> String {
        switch authentication {
        case .unknown:
            return l10n.string("auth.login_status.title.not_checked")
        case .unauthenticated:
            return l10n.string("auth.login_status.title.not_logged_in")
        case .authenticating(let providerID):
            return l10n.string("auth.login_status.title.logging_in", providerDisplayName(providerID))
        case .authenticated(let providerID):
            if let providerID {
                return l10n.string("auth.login_status.title.authenticated_with_provider", providerDisplayName(providerID))
            }
            return l10n.string("auth.login_status.title.authenticated")
        case .failed:
            return l10n.string("auth.login_status.title.error")
        }
    }

    private static func detail(for authAccess: AuthAccessState, l10n: L10n) -> String {
        let modelMessage = authAccess.modelAccess.unavailableMessage(l10n: l10n)
        let subscriptionMessage = authAccess.subscriptionAccess.unavailableMessage(l10n: l10n)

        if authAccess.hasAvailableModelAccess {
            return authAccess.hasActiveSubscriptionAccess
                ? l10n.string("auth.login_status.detail.model_and_subscription_active")
                : l10n.string("auth.login_status.detail.model_active_subscription_message", subscriptionMessage)
        }

        return l10n.string("auth.login_status.detail.model_and_subscription_messages", modelMessage, subscriptionMessage)
    }
}
