import XCTest
@testable import PiAgentNativeCore

final class SubscriptionLoginStatusSummaryTests: XCTestCase {
    func testNotStartedStateProducesSelectedProviderCopyWithoutActiveAccess() {
        let provider = provider(id: "anthropic", name: "Anthropic")

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: provider,
            attemptState: SubscriptionLoginAttemptState()
        )

        XCTAssertEqual(status.title, "Ready to sign in with Anthropic")
        XCTAssertTrue(status.detail.contains("Start provider login"))
        XCTAssertTrue(status.detail.contains("Accounts and billing stay with Anthropic"))
        XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("confirmed"))
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertNil(status.providerLoginURL)
        XCTAssertEqual(status.emphasis, .neutral)
    }

    func testWaitingStateWithURLTellsUserToContinueAndKeepsOpenLinkAvailable() throws {
        let selectedProvider = provider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let url = try XCTUnwrap(URL(string: "https://auth.openai.com/login"))
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .waitingForProvider(url: url),
            lastURL: nil,
            exitStatus: nil
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "Continue with ChatGPT / OpenAI Codex")
        XCTAssertTrue(status.detail.contains("Complete the provider page"))
        XCTAssertTrue(status.detail.contains("Provider Login URL can be reopened"))
        XCTAssertEqual(status.providerLoginURL, url)
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertEqual(status.emphasis, .progress)
    }

    func testWaitingStateFallsBackToLatestProviderLoginURL() throws {
        let selectedProvider = provider(id: "github-copilot", name: "GitHub Copilot")
        let url = try XCTUnwrap(URL(string: "https://github.com/login/device"))
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .waitingForProvider(url: nil),
            lastURL: url,
            exitStatus: nil
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.providerLoginURL, url)
        XCTAssertTrue(status.detail.contains("provider page"))
    }

    func testRefreshingStateProducesAccessCheckingCopy() {
        let selectedProvider = provider(id: "anthropic", name: "Anthropic")
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .refreshingAccess,
            lastURL: nil,
            exitStatus: 0
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "Checking Anthropic access")
        XCTAssertTrue(status.detail.contains("refreshing model access"))
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertEqual(status.emphasis, .progress)
    }

    func testConfirmedStateProducesCopyOnlyWhenAttemptProviderMatchesSelectedProvider() {
        let selectedProvider = provider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .confirmed(providerID: selectedProvider.id),
            lastURL: nil,
            exitStatus: 0
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "ChatGPT / OpenAI Codex access confirmed")
        XCTAssertTrue(status.detail.contains("usable provider-backed model access"))
        XCTAssertTrue(status.isConfirmedForSelectedProvider)
        XCTAssertEqual(status.emphasis, .success)
    }

    func testConfirmedStateWithDifferentConfirmedProviderIDSuppressesConfirmation() {
        let selectedProvider = provider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .confirmed(providerID: "anthropic"),
            lastURL: nil,
            exitStatus: 0
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "Ready to sign in with ChatGPT / OpenAI Codex")
        XCTAssertTrue(status.detail.contains("not for ChatGPT / OpenAI Codex"))
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertEqual(status.emphasis, .neutral)
    }

    func testFailedAndStoppedStatesProduceDistinctUserFacingCopy() {
        let selectedProvider = provider(id: "anthropic", name: "Anthropic")
        let failedState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .failed(message: "Credentials rejected."),
            lastURL: nil,
            exitStatus: 1
        )
        let stoppedState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .stopped,
            lastURL: nil,
            exitStatus: nil
        )

        let failedStatus = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: failedState
        )
        let stoppedStatus = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: stoppedState
        )

        XCTAssertEqual(failedStatus.title, "Anthropic login failed")
        XCTAssertEqual(failedStatus.detail, "Credentials rejected.")
        XCTAssertEqual(failedStatus.emphasis, .failure)
        XCTAssertEqual(stoppedStatus.title, "Anthropic login stopped")
        XCTAssertTrue(stoppedStatus.detail.contains("stopped before access was confirmed"))
        XCTAssertEqual(stoppedStatus.emphasis, .neutral)
    }

    func testSelectedProviderMismatchSuppressesStaleConfirmedCopy() throws {
        let selectedProvider = provider(id: "github-copilot", name: "GitHub Copilot")
        let previousProvider = provider(id: "anthropic", name: "Anthropic")
        let url = try XCTUnwrap(URL(string: "https://console.anthropic.com/login"))
        let attemptState = SubscriptionLoginAttemptState(
            provider: previousProvider,
            attemptID: UUID(),
            phase: .confirmed(providerID: previousProvider.id),
            lastURL: url,
            exitStatus: 0
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "Ready to sign in with GitHub Copilot")
        XCTAssertTrue(status.detail.contains("last login attempt was for Anthropic"))
        XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("confirmed"))
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertEqual(status.providerLoginURL, url)
    }

    func testStartingStateNeverConfirmsBrowserOpenSuccess() throws {
        let selectedProvider = provider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let url = try XCTUnwrap(URL(string: "https://auth.openai.com/login"))
        let attemptState = SubscriptionLoginAttemptState(
            provider: selectedProvider,
            attemptID: UUID(),
            phase: .starting,
            lastURL: url,
            exitStatus: nil
        )

        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedProvider,
            attemptState: attemptState
        )

        XCTAssertEqual(status.title, "Starting ChatGPT / OpenAI Codex login")
        XCTAssertEqual(status.providerLoginURL, url)
        XCTAssertFalse(status.isConfirmedForSelectedProvider)
        XCTAssertNotEqual(status.emphasis, .success)
    }

    private func provider(id: String, name: String) -> LoginProvider {
        LoginProvider(id: id, name: name)
    }
}
