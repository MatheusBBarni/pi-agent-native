import XCTest
@testable import PiAgentNativeCore

final class SubscriptionLoginStatusSummaryTests: XCTestCase {
    func testNotStartedSummaryLocalizesInEnglishAndPortuguese() {
        let state = AuthAccessState()

        XCTAssertEqual(
            SubscriptionLoginStatusSummary(authAccess: state, l10n: L10n(language: .english)),
            SubscriptionLoginStatusSummary(
                title: "Authentication not checked",
                detail: "Model access has not been checked yet. Refresh state or log in. Subscription access has not been checked yet."
            )
        )
        XCTAssertEqual(
            SubscriptionLoginStatusSummary(authAccess: state, l10n: L10n(language: .portugueseBrazil)),
            SubscriptionLoginStatusSummary(
                title: "Autenticação não verificada",
                detail: "O acesso ao modelo ainda não foi verificado. Atualize o estado ou faça login. O acesso por assinatura ainda não foi verificado."
            )
        )
    }

    func testProviderNameRemainsVerbatimInsideLocalizedTitle() {
        let state = AuthAccessState(authentication: .authenticating(providerID: "openai-codex"))
        let summary = SubscriptionLoginStatusSummary(authAccess: state, l10n: L10n(language: .portugueseBrazil))

        XCTAssertEqual(summary.title, "Fazendo login em ChatGPT / OpenAI Codex")
        XCTAssertTrue(summary.title.contains("ChatGPT / OpenAI Codex"))
    }

    func testFailurePayloadRemainsVerbatimInsideLocalizedDetail() {
        let payload = #"oauth_failed {"provider":"openai-codex","url":"https://auth.example/callback?code=RAW"}"#
        let state = AuthAccessState(
            authentication: .failed(message: payload),
            modelAccess: .failed(message: payload),
            subscriptionAccess: .failed(message: payload)
        )
        let summary = SubscriptionLoginStatusSummary(authAccess: state, l10n: L10n(language: .portugueseBrazil))

        XCTAssertEqual(summary.title, "Erro de autenticação")
        XCTAssertTrue(summary.detail.contains(payload))
        XCTAssertTrue(summary.detail.contains("https://auth.example/callback?code=RAW"))
    }
}
