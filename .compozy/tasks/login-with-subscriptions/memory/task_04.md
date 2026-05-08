# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Preserve the active selected session and selected model/reasoning through subscription login refresh when the refreshed model list still contains the selected provider/model ID.
- If refreshed availability does not contain the previous provider/model ID, leave available models visible but block model-backed actions until the user explicitly selects a valid model.

## Important Decisions
- Use an AppModel-local selected model identity because `modelName` is display text and cannot safely distinguish same display names across providers/model IDs.
- Resolve login-triggered model continuity only after the linked Access Refresh completes with `get_available_models`, so stale refresh responses keep using the existing epoch/attempt protections.
- Preserve the selected session by forcing the login-triggered PiRPC restart path to send `switch_session` for the existing selected session file when one is selected.
- When a previous model is missing after refresh, leave `availableModels` populated but set model access unavailable with an explicit "choose a model" reason so prompt submission remains blocked until user selection.

## Learnings
- Repo root has no `AGENTS.md` or `CLAUDE.md`; the prompt-provided AGENTS instruction points to `/Users/matheusbbarni/.codex/RTK.md`, so shell commands are run with `rtk`.
- Pre-change focused signal: `swift test --filter SubscriptionLoginAppModelTests` passed 8 tests, but `beginAccessRefresh` clears `modelName` and the response path does not compare the prior provider/model ID to refreshed availability.
- Task-specific tests now cover selected-session continuity, matching model/reasoning preservation, and missing-model invalidation without sending `set_model`.
- Coverage run for `SubscriptionLoginAppModelTests` passed 11 tests; `SubscriptionLoginAppModelTests.swift` reports 99.14% line coverage, while whole-file `AppModel.swift` remains 29.25% because it is a large existing class.

## Files / Surfaces
- Expected implementation surface: `Sources/PiAgentNative/AppModel.swift`.
- Expected test surface: `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift`.
- Touched implementation: `Sources/PiAgentNative/AppModel.swift`.
- Touched tests: `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift`.
- Touched tracking/memory: current task memory and task file.

## Errors / Corrections
- Full `swift test` still fails with 5 unrelated keymap/inspector expectation mismatches: `DefaultKeymapTests` expects `Command-Option-S/I` and "Toggle inspector", while current code reports `Command-B`, `Command-Shift-B`, and "Toggle right sidebar"; `InspectorPaneToggleTests` has the same help-text mismatch.
- Because full-suite validation remains red and whole-file `AppModel.swift` coverage is below 80%, task status was not advanced to completed.

## Ready for Next Run
- Focused verification passed: `swift test --filter SubscriptionLoginAppModelTests` executed 11 tests with 0 failures.
- Related auth verification passed: `swift test --filter OAuthLoginRunnerTests` executed 15 tests with 0 failures; `swift test --filter AuthAccessStateTests` executed 14 tests with 0 failures.
- Formatting check passed: `git diff --check`.
