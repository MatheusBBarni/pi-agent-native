# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Render runner-owned subscription login attempt state as the primary signal in `LoginSheetView`, with terminal output and Provider Login URL fallback still available.

## Important Decisions
- Keep status interpretation in a small value helper so copy and provider-mismatch behavior can be unit tested without SwiftUI automation.
- `LoginSheetView` now treats `OAuthLoginRunner.attemptState.lastURL` as the browser auto-open signal and keeps the visible Open Link action tied to the helper's latest Provider Login URL.
- Provider mismatch and mismatched confirmed provider IDs intentionally render ready-to-start copy, not confirmed copy.

## Learnings
- `AGENTS.md` and `CLAUDE.md` were requested but are not present in the repository root; active project instruction is the user-provided RTK include, which requires `rtk` command prefixes.
- Pre-change signal: focused runner attempt-state test passes, but no `SubscriptionLoginStatus` helper/status surface exists and the subscription pane still relies on terminal copy as the main login signal.
- `SubscriptionLoginStatusSummaryTests` covers not-started, starting, waiting with URL, waiting URL fallback, refreshing, confirmed, mismatched confirmed provider ID, failed, stopped, and selected-provider mismatch.
- Coverage evidence for `Sources/PiAgentNative/Auth/SubscriptionLoginStatusSummary.swift`: 90.32% region coverage, 97.78% line coverage, 100% function coverage from `swift test --enable-code-coverage --filter SubscriptionLoginStatusSummaryTests`.
- Focused login verification passed: `swift test --filter OAuthLoginRunnerTests --filter SubscriptionLoginAppModelTests --filter SubscriptionLoginStatusSummaryTests` executed 35 tests with 0 failures.
- Full `swift test` remains red in pre-existing keymap/inspector expectations unrelated to this task: 117 tests executed, 5 failures in `DefaultKeymapTests` and `InspectorPaneToggleTests`.

## Files / Surfaces
- Touched: `Sources/PiAgentNative/LoginSheetView.swift`
- Added: `Sources/PiAgentNative/Auth/SubscriptionLoginStatusSummary.swift`
- Added: `Tests/PiAgentNativeCoreTests/SubscriptionLoginStatusSummaryTests.swift`

## Errors / Corrections
- Fixed a Swift opaque return compile error in `subscriptionPane` by making the `VStack` return explicit after adding a local status value.
- Tightened the status panel layout so long provider names render in a separate selected-provider line instead of competing with the status title.

## Ready for Next Run
- Manual modal checklist to execute in a GUI session: verify not started, starting, waiting with Provider Login URL and Open Link, refreshing, confirmed, failed, stopped, provider switching after confirmation, secondary terminal output, and duplicate browser-open behavior.
- Do not mark task tracking complete until the repository-wide test gate is either green or the workflow explicitly accepts the known unrelated keymap/inspector failures.
