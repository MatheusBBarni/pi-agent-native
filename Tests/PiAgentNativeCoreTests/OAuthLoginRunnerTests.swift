import XCTest
@testable import PiAgentNativeCore

final class OAuthLoginRunnerTests: XCTestCase {
    func testStartCreatesNewAttemptStateForSelectedProviderAndAttemptID() throws {
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let staleAttemptID = UUID()
        let runner = makeRunner(command: command(executable: "/bin/cat"))
        runner.markStarting(provider: LoginProvider(id: "anthropic", name: "Anthropic"), attemptID: staleAttemptID)
        defer { runner.stop() }

        let attemptID = try XCTUnwrap(try runner.start(provider: provider).get())

        XCTAssertNotEqual(attemptID, staleAttemptID)
        XCTAssertEqual(runner.currentProvider, provider)
        XCTAssertEqual(runner.currentAttemptID, attemptID)
        XCTAssertTrue(runner.isRunning)
        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .starting,
                lastURL: nil,
                exitStatus: nil
            )
        )
    }

    func testProcessOutputProviderLoginURLUpdatesAttemptStateToWaiting() throws {
        let provider = LoginProvider(id: "anthropic", name: "Anthropic")
        let url = try XCTUnwrap(URL(string: "https://console.anthropic.com/login"))
        let runner = makeRunner(
            command: command(
                executable: "/bin/sh",
                arguments: ["-c", "printf 'Open https://console.anthropic.com/login\\n'; sleep 0.2"]
            )
        )
        defer { runner.stop() }

        _ = try runner.start(provider: provider).get()

        XCTAssertTrue(waitUntil { runner.attemptState.lastURL == url })
        XCTAssertEqual(runner.lastURL, url)
        XCTAssertEqual(runner.attemptState.phase, .waitingForProvider(url: url))
        XCTAssertEqual(runner.attemptState.provider, provider)
    }

    func testDuplicateProviderLoginURLOpeningTrackerBehaviorRemainsUnchanged() throws {
        var tracker = ProviderLoginURLOpeningTracker()
        let url = try XCTUnwrap(URL(string: "https://auth.example/callback?code=abc"))

        XCTAssertTrue(tracker.shouldOpen(url))
        XCTAssertFalse(tracker.shouldOpen(url))

        tracker.reset()
        XCTAssertTrue(tracker.shouldOpen(url))
    }

    func testStopMovesActiveAttemptToStoppedAndKeepsProviderContext() throws {
        let provider = LoginProvider(id: "github-copilot", name: "GitHub Copilot")
        let runner = makeRunner(command: command(executable: "/bin/cat"))
        let completion = expectation(description: "login process terminated")
        runner.onCompletion = { _, _, _ in
            completion.fulfill()
        }
        let attemptID = try XCTUnwrap(try runner.start(provider: provider).get())

        runner.stop()

        wait(for: [completion], timeout: 2)
        XCTAssertFalse(runner.isRunning)
        XCTAssertEqual(runner.currentProvider, provider)
        XCTAssertEqual(runner.currentAttemptID, attemptID)
        XCTAssertEqual(runner.attemptState.provider, provider)
        XCTAssertEqual(runner.attemptState.attemptID, attemptID)
        XCTAssertEqual(runner.attemptState.phase, .stopped)
    }

    func testLaunchFailureMovesAttemptStateToFailedWithLaunchErrorMessage() throws {
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let runner = makeRunner(command: command(executable: "/tmp/pi-agent-native-missing-login-command"))

        let result = runner.start(provider: provider)

        guard case .failure(let error) = result else {
            return XCTFail("Expected launch failure")
        }
        XCTAssertFalse(runner.isRunning)
        XCTAssertEqual(runner.attemptState.provider, provider)
        XCTAssertEqual(runner.attemptState.phase, .failed(message: error.localizedDescription))
        XCTAssertTrue(runner.output.contains("Failed to start login: \(error.localizedDescription)"))
    }

    func testNonZeroTerminationRecordsExitStatusAndFailsWithoutConfirming() throws {
        let provider = LoginProvider(id: "anthropic", name: "Anthropic")
        let url = try XCTUnwrap(URL(string: "https://console.anthropic.com/login"))
        let runner = makeRunner(
            command: command(
                executable: "/bin/sh",
                arguments: ["-c", "printf 'Open https://console.anthropic.com/login\\n'; exit 7"]
            )
        )
        let completion = expectation(description: "login process completed")
        runner.onCompletion = { completedProvider, _, exitStatus in
            XCTAssertEqual(completedProvider, provider)
            XCTAssertEqual(exitStatus, 7)
            completion.fulfill()
        }

        let attemptID = try XCTUnwrap(try runner.start(provider: provider).get())

        wait(for: [completion], timeout: 2)
        XCTAssertFalse(runner.isRunning)
        XCTAssertEqual(runner.exitStatus, 7)
        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .failed(message: "Login exited with status 7."),
                lastURL: url,
                exitStatus: 7
            )
        )
    }

    func testZeroTerminationRecordsExitStatusWithoutConfirmingAccess() throws {
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let runner = makeRunner(command: command(executable: "/bin/sh", arguments: ["-c", "exit 0"]))
        let completion = expectation(description: "login process completed")
        runner.onCompletion = { completedProvider, _, exitStatus in
            XCTAssertEqual(completedProvider, provider)
            XCTAssertEqual(exitStatus, 0)
            completion.fulfill()
        }

        let attemptID = try XCTUnwrap(try runner.start(provider: provider).get())

        wait(for: [completion], timeout: 2)
        XCTAssertFalse(runner.isRunning)
        XCTAssertEqual(runner.exitStatus, 0)
        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .starting,
                lastURL: nil,
                exitStatus: 0
            )
        )
    }

    func testAttemptStateDefaultsToNotStartedWithoutAttemptFacts() {
        let state = SubscriptionLoginAttemptState()

        XCTAssertNil(state.provider)
        XCTAssertNil(state.attemptID)
        XCTAssertEqual(state.phase, .notStarted)
        XCTAssertNil(state.lastURL)
        XCTAssertNil(state.exitStatus)
    }

    func testStartingTransitionRecordsProviderAndAttemptAndClearsStaleDetails() throws {
        let runner = OAuthLoginRunner()
        let staleURL = try XCTUnwrap(URL(string: "https://auth.example/stale"))
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let attemptID = UUID()
        runner.lastURL = staleURL
        runner.exitStatus = 17
        runner.attemptState = SubscriptionLoginAttemptState(
            provider: LoginProvider(id: "anthropic", name: "Anthropic"),
            attemptID: UUID(),
            phase: .failed(message: "old failure"),
            lastURL: staleURL,
            exitStatus: 17
        )

        runner.markStarting(provider: provider, attemptID: attemptID)

        XCTAssertEqual(runner.currentProvider, provider)
        XCTAssertEqual(runner.currentAttemptID, attemptID)
        XCTAssertNil(runner.lastURL)
        XCTAssertNil(runner.exitStatus)
        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .starting,
                lastURL: nil,
                exitStatus: nil
            )
        )
    }

    func testWaitingTransitionRecordsLatestProviderLoginURLWithoutConfirming() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "anthropic", name: "Anthropic")
        let attemptID = UUID()
        let url = try XCTUnwrap(URL(string: "https://console.anthropic.com/login"))
        runner.markStarting(provider: provider, attemptID: attemptID)

        runner.markWaitingForProvider(url: url)

        XCTAssertEqual(runner.lastURL, url)
        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .waitingForProvider(url: url),
                lastURL: url,
                exitStatus: nil
            )
        )
    }

    func testRefreshingTransitionPreservesProviderAndAttemptIdentity() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "github-copilot", name: "GitHub Copilot")
        let attemptID = UUID()
        let url = try XCTUnwrap(URL(string: "https://github.com/login/device"))
        runner.markStarting(provider: provider, attemptID: attemptID)
        runner.markWaitingForProvider(url: url)
        runner.exitStatus = 0

        runner.markRefreshingAccess()

        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .refreshingAccess,
                lastURL: url,
                exitStatus: 0
            )
        )
    }

    func testConfirmedTransitionPreservesContextAndRecordsProviderID() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let attemptID = UUID()
        runner.markStarting(provider: provider, attemptID: attemptID)
        runner.exitStatus = 0

        runner.markConfirmed(providerID: provider.id)

        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .confirmed(providerID: provider.id),
                lastURL: nil,
                exitStatus: 0
            )
        )
    }

    func testFailedAndStoppedTransitionsRetainProviderContext() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "anthropic", name: "Anthropic")
        let attemptID = UUID()
        let url = try XCTUnwrap(URL(string: "https://console.anthropic.com/login"))
        runner.markStarting(provider: provider, attemptID: attemptID)
        runner.markWaitingForProvider(url: url)

        runner.markFailed("Login exited with status 2.", exitStatus: 2)

        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .failed(message: "Login exited with status 2."),
                lastURL: url,
                exitStatus: 2
            )
        )

        runner.markStopped()

        XCTAssertEqual(
            runner.attemptState,
            SubscriptionLoginAttemptState(
                provider: provider,
                attemptID: attemptID,
                phase: .stopped,
                lastURL: url,
                exitStatus: 2
            )
        )
    }

    func testResetAttemptStateClearsProviderAttemptURLAndExitStatus() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex")
        let attemptID = UUID()
        let url = try XCTUnwrap(URL(string: "https://auth.openai.com/login"))
        runner.markStarting(provider: provider, attemptID: attemptID)
        runner.markWaitingForProvider(url: url)
        runner.markFailed("failed", exitStatus: 1)

        runner.resetAttemptState()

        XCTAssertNil(runner.currentProvider)
        XCTAssertNil(runner.currentAttemptID)
        XCTAssertNil(runner.lastURL)
        XCTAssertNil(runner.exitStatus)
        XCTAssertEqual(runner.attemptState, SubscriptionLoginAttemptState())
    }

    func testTransitionsPreserveExistingAttemptContextWhenRawFieldsAreUnavailable() throws {
        let runner = OAuthLoginRunner()
        let provider = LoginProvider(id: "github-copilot", name: "GitHub Copilot")
        let attemptID = UUID()
        let url = try XCTUnwrap(URL(string: "https://github.com/login/device"))
        runner.attemptState = SubscriptionLoginAttemptState(
            provider: provider,
            attemptID: attemptID,
            phase: .waitingForProvider(url: url),
            lastURL: url,
            exitStatus: 0
        )

        runner.markWaitingForProvider(url: nil)

        XCTAssertEqual(runner.attemptState.provider, provider)
        XCTAssertEqual(runner.attemptState.attemptID, attemptID)
        XCTAssertEqual(runner.attemptState.phase, .waitingForProvider(url: url))
        XCTAssertEqual(runner.lastURL, url)

        runner.lastURL = nil
        runner.exitStatus = nil
        runner.markRefreshingAccess()
        XCTAssertEqual(runner.attemptState.provider, provider)
        XCTAssertEqual(runner.attemptState.attemptID, attemptID)
        XCTAssertEqual(runner.attemptState.lastURL, url)
        XCTAssertEqual(runner.attemptState.exitStatus, 0)

        runner.markConfirmed(providerID: nil)
        XCTAssertEqual(runner.attemptState.phase, .confirmed(providerID: nil))

        runner.markFailed("Access refresh failed.")
        XCTAssertEqual(runner.attemptState.phase, .failed(message: "Access refresh failed."))
        XCTAssertEqual(runner.attemptState.exitStatus, 0)

        runner.markStopped()
        XCTAssertEqual(runner.attemptState.provider, provider)
        XCTAssertEqual(runner.attemptState.attemptID, attemptID)
        XCTAssertEqual(runner.attemptState.lastURL, url)
        XCTAssertEqual(runner.attemptState.exitStatus, 0)
        XCTAssertEqual(runner.attemptState.phase, .stopped)
    }

    private func makeRunner(command: OAuthLaunchCommand) -> OAuthLoginRunner {
        let authDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return OAuthLoginRunner(
            commandResolver: { _ in command },
            environmentResolver: { ProcessInfo.processInfo.environment },
            authDirectoryURL: { authDirectoryURL }
        )
    }

    private func command(
        executable: String,
        arguments: [String] = [],
        display: String = "test login command"
    ) -> OAuthLaunchCommand {
        OAuthLaunchCommand(
            executableURL: URL(fileURLWithPath: executable),
            arguments: arguments,
            display: display
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}
