# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Bridge AppModel subscription login completion and PiRPC Access Refresh results into the runner-owned `SubscriptionLoginAttemptState` for the current attempt only.
- Acceptance focus: zero provider exit enters `refreshingAccess`; current refresh success with subscription-backed access enters `confirmed`; refresh failure or unusable subscription access enters `failed`; stale attempts/responses remain ignored.

## Important Decisions
- Added narrow AppModel test seams for deterministic auth snapshots, RPC command sending, restart simulation, and direct response ingestion. These do not change default production behavior.
- AppModel now records a pending login refresh after a zero provider exit, links it to the next `AuthAccessRefreshTracker` epoch, and only maps completion/failure when the linked epoch still belongs to the current runner attempt.
- Refresh success confirms the runner only when `authAccess.subscriptionAccess` is `.active`; inactive/failed/unknown subscription access fails the runner attempt instead of confirming it.

## Learnings
- Repo root does not contain `AGENTS.md` or `CLAUDE.md`; the prompt-provided AGENTS content points to `/Users/matheusbbarni/.codex/RTK.md`, so shell commands are prefixed with `rtk`.
- Pre-change static signal: `AppModel.swift` had no calls to `OAuthLoginRunner.markRefreshingAccess`, `markConfirmed`, or `markFailed`.
- Focused AppModel bridge tests pass, including out-of-order simulated refresh responses and stale response protection.
- Coverage run for `SubscriptionLoginAppModelTests` passed; whole-file `AppModel.swift` coverage remains low because AppModel is a large existing class, so the requested 80% target is not honestly met at whole-file scope.

## Files / Surfaces
- Expected implementation surface: `Sources/PiAgentNative/AppModel.swift`.
- Expected test surface: add focused AppModel bridge tests under `Tests/PiAgentNativeTests`.
- Touched implementation: `Sources/PiAgentNative/AppModel.swift`.
- Added tests: `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift`.
- Tracking/memory touched: current task memory and task tracking file.

## Errors / Corrections
- Full `swift test` still exits non-zero due unrelated existing expectation mismatches in `DefaultKeymapTests` and `InspectorPaneToggleTests`; task-specific tests pass.

## Ready for Next Run
- Verification evidence captured this run: `swift test --filter SubscriptionLoginAppModelTests` passed 8 tests; `swift test --filter OAuthLoginRunnerTests` passed 15 tests; `swift test --filter AuthAccessStateTests` passed 14 tests; `swift test --enable-code-coverage --filter SubscriptionLoginAppModelTests` passed 8 tests; `git diff --check` passed.
- Full-suite evidence: `swift test` built and ran 105 tests, with 5 unrelated failures in keymap/inspector presentation expectations.
