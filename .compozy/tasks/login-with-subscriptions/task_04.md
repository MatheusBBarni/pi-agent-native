---
status: pending
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

- [ ] 4.1 Identify the current selected model identity before login-triggered refresh.
- [ ] 4.2 Preserve the selected session through provider login, PiRPC restart, and Access Refresh.
- [ ] 4.3 Preserve model and reasoning display when refreshed availability still contains the selected model.
- [ ] 4.4 Clear or block invalid stale model selection when refreshed availability no longer supports it.
- [ ] 4.5 Avoid silent first-model fallback after provider switch.
- [ ] 4.6 Add AppModel tests for model/reasoning preservation and invalidation.

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
  - [ ] Current session remains selected after successful provider login and Access Refresh.
  - [ ] Current model remains selected when refreshed models include the same provider and model ID.
  - [ ] Current reasoning level remains unchanged when model selection remains valid.
  - [ ] Current model is not silently replaced with the first available model when refreshed models do not include it.
  - [ ] Invalid stale model state requires explicit user selection before model-backed actions continue.
- Integration tests:
  - [ ] Simulated refresh with matching model preserves model/reasoning display.
  - [ ] Simulated refresh without matching model clears or blocks stale selection according to existing AppModel conventions.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- Provider login behaves like terminal `pi` by preserving the current session.
- The app never silently changes model choice after provider login or provider switch.
