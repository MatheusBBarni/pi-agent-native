# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire `OAuthLoginRunner` structured attempt state into real provider process lifecycle paths: start, Provider Login URL detection, stop, launch failure, and termination.
- Keep AppModel usable-access confirmation deferred to later tasks; process exit must not mark access confirmed.

## Important Decisions
- Treat task_01's uncommitted `SubscriptionLoginAttemptState` model and helper transitions as the dependency baseline for this task.
- Added injectable command/environment/auth-directory closures to `OAuthLoginRunner` so process lifecycle tests can run deterministic local commands without changing production command resolution.
- Non-zero provider process termination now marks runner state failed with `Login exited with status N.`; zero exit only records `exitStatus` and leaves usable-access confirmation to AppModel.
- Stopped attempts retain stopped phase during termination remainder handling, so late Provider Login URLs cannot move a stopped attempt back to waiting.

## Learnings
- No repository-local `AGENTS.md` or `CLAUDE.md` files were found; the prompt-provided AGENTS instruction points to `/Users/matheusbbarni/.codex/RTK.md`, so shell commands should use `rtk`.
- Pre-change focused runner tests passed but only covered direct transition helpers, not `start(provider:)`, process output, launch failure, stop, or termination paths.
- Focused `OAuthLoginRunnerTests` and `AuthAccessStateTests` pass after implementation; full `swift test` is still red for unrelated keymap/inspector expectation mismatches.
- Focused coverage for `AuthStore.swift` plus `Auth/SubscriptionLoginAttemptState.swift` reports 87.79% line coverage.

## Files / Surfaces
- `Sources/PiAgentNative/AuthStore.swift`
- `Sources/PiAgentNative/Auth/SubscriptionLoginAttemptState.swift`
- `Tests/PiAgentNativeCoreTests/OAuthLoginRunnerTests.swift`
- `.compozy/tasks/login-with-subscriptions/task_02.md`

## Errors / Corrections
- Added explicit cleanup to the process-output URL test after self-review so the test owns the short-lived shell process lifecycle.

## Ready for Next Run
- Task-specific implementation is ready for review. Do not mark task_02 completed until the team decides whether unrelated full-suite keymap/inspector failures can be waived or are fixed.
