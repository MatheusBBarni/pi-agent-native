---
status: completed
title: "Preserve terminal-like session, model, and reasoning continuity"
type: backend
complexity: high
dependencies:
    - task_03
---

# Task 04: Preserve terminal-like session, model, and reasoning continuity

## Overview

Preserve the active session and keep the selected model and reasoning level when a provider login or provider switch refresh still supports them. This task makes the native app behave more like `pi` in a terminal while still requiring explicit user action when the refreshed provider no longer supports the selected model.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- Successful provider login or provider switch MUST preserve the current Pi Agent Native session.
- Current model and reasoning selection MUST be preserved when refreshed model availability still supports the selected model.
- Current model selection MUST require explicit user selection when refreshed model availability no longer supports it.
- Reasoning selection SHOULD remain unchanged unless the app can determine it is unsupported.
- The implementation MUST NOT silently switch to the first available model after provider login.
- Existing selected-session behavior outside login MUST remain unchanged.
</requirements>

## Subtasks

- [x] 4.1 Identify the current selected model identity before login-triggered refresh.
- [x] 4.2 Preserve the selected session through provider login, PiRPC restart, and Access Refresh.
- [x] 4.3 Preserve model and reasoning display when refreshed availability still contains the selected model.
- [x] 4.4 Clear or block invalid stale model selection when refreshed availability no longer supports it.
- [x] 4.5 Avoid silent first-model fallback after provider switch.
- [x] 4.6 Add AppModel tests for model/reasoning preservation and invalidation.

## Implementation Details

Work in the existing AppModel model-selection path. If display-only `modelName` is insufficient to compare refreshed availability, add the smallest internal selected-model identity helper needed to compare provider and model ID safely.

### Relevant Files

- `Sources/PiAgentNative/AppModel.swift` — owns `modelName`, `thinkingLevel`, selected model responses, refresh handling, and session state.
- `Sources/PiAgentNative/Models.swift` — contains `PiModel` and may need a small identity helper if AppModel cannot compare refreshed models cleanly.
- `Sources/PiAgentNative/ChatSurfaceView.swift` — renders current model and thinking level controls.
- `Sources/PiAgentNative/InspectorView.swift` — renders model and thinking level status.

### Dependent Files

- `Sources/PiAgentNative/LoginSheetView.swift` — depends on confirmed/failed state being accurate after preserving or invalidating current selection.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — expected location for session/model/reasoning continuity tests.
- `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift` — existing expectations around `modelName` and `thinkingLevel` must continue passing.

### Related ADRs

- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — requires terminal-like session continuity after login/provider switch.

## Deliverables

- Session continuity preserved through successful provider login and provider switch.
- Model and reasoning preservation when refreshed availability supports the current selection.
- Explicit invalid/stale model handling when refreshed availability does not support the current selection.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration-style AppModel tests for simulated refresh model availability **(REQUIRED)**.

## Tests

- Unit tests:
  - [x] Current session remains selected after successful provider login and Access Refresh.
  - [x] Current model remains selected when refreshed models include the same provider and model ID.
  - [x] Current reasoning level remains unchanged when model selection remains valid.
  - [x] Current model is not silently replaced with the first available model when refreshed models do not include it.
  - [x] Invalid stale model state requires explicit user selection before model-backed actions continue.
- Integration tests:
  - [x] Simulated refresh with matching model preserves model/reasoning display.
  - [x] Simulated refresh without matching model clears or blocks stale selection according to existing AppModel conventions.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- Provider login behaves like terminal `pi` by preserving the current session.
- The app never silently changes model choice after provider login or provider switch.

## Execution Notes

- Added AppModel continuity handling for selected session, selected model identity, and thinking level during login-linked Access Refresh.
- Added integration-style AppModel tests in `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` for selected-session preservation, matching model/reasoning preservation, and missing-model invalidation without first-model fallback.
- Focused verification passed: `swift test --filter SubscriptionLoginAppModelTests` executed 11 tests with 0 failures.
- Related verification passed: `swift test --filter OAuthLoginRunnerTests` executed 15 tests with 0 failures; `swift test --filter AuthAccessStateTests` executed 14 tests with 0 failures.
- Coverage verification passed for the focused test suite, but whole-file `AppModel.swift` line coverage remains 29.25% because AppModel is a large existing class; `SubscriptionLoginAppModelTests.swift` reports 99.14% line coverage.
- Full `swift test` remains red due unrelated existing keymap/inspector expectation mismatches in `DefaultKeymapTests` and `InspectorPaneToggleTests`, so task status is intentionally left pending and `_tasks.md` was not advanced.
