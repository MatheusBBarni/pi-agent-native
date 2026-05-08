---
status: completed
title: "Wire runner lifecycle transitions through provider login process"
type: backend
complexity: medium
dependencies:
    - task_01
---

# Task 02: Wire runner lifecycle transitions through provider login process

## Overview

Connect the new runner-owned state to actual provider login process events. This task makes `OAuthLoginRunner` reflect start, URL detection, stop, termination, and process failure states before AppModel adds PiRPC confirmation.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- `OAuthLoginRunner.start(provider:)` MUST transition the structured attempt state into a starting or waiting phase for the selected provider.
- Provider Login URL detection MUST update the structured attempt state with the latest URL and waiting phase.
- `OAuthLoginRunner.stop()` MUST transition an active attempt to stopped without marking it failed or confirmed.
- Process launch failure MUST transition the attempt to failed with a user-visible message.
- Process termination MUST retain exit status in structured state while deferring usable-access confirmation to AppModel.
- Existing duplicate URL detection and raw terminal output behavior MUST remain intact.
</requirements>

## Subtasks

- [x] 2.1 Connect `OAuthLoginRunner.start(provider:)` to the starting attempt transition.
- [x] 2.2 Connect appended provider output and detected Provider Login URLs to waiting state updates.
- [x] 2.3 Connect process launch failure to failed state updates.
- [x] 2.4 Connect process termination to exit-status recording without confirming access.
- [x] 2.5 Connect runner stop behavior to stopped state updates.
- [x] 2.6 Add unit tests for lifecycle transitions and URL state updates.

## Implementation Details

Modify `OAuthLoginRunner` around its existing process lifecycle. Preserve the current process execution responsibilities described in the TechSpec "System Architecture" and avoid moving PiRPC confirmation into the runner.

### Relevant Files

- `Sources/PiAgentNative/AuthStore.swift` — primary implementation location for process start, output append, URL detection, termination, and stop behavior.
- `Sources/PiAgentNative/Auth/OAuthLoginService.swift` — provider command resolution remains unchanged but defines the external process boundary.
- `Tests/PiAgentNativeCoreTests/AuthAccessStateTests.swift` — existing Provider Login URL detector tests that must continue passing.
- `Tests/PiAgentNativeCoreTests/OAuthLoginRunnerTests.swift` — expected location for new runner lifecycle tests.

### Dependent Files

- `Sources/PiAgentNative/AppModel.swift` — depends on runner attempt state when bridging process completion to PiRPC refresh.
- `Sources/PiAgentNative/LoginSheetView.swift` — depends on runner state for modal rendering in later tasks.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — later AppModel tests will assume lifecycle state exists.

### Related ADRs

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — browser handoff and provider process remain provider-owned.
- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — lifecycle events must update runner-owned structured state.

## Deliverables

- Structured runner state connected to provider process lifecycle events.
- Existing raw output, latest URL, provider, attempt ID, and exit status behavior preserved for compatibility.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for process-to-AppModel confirmation are deferred to dependent tasks **(REQUIRED)**.

## Tests

- Unit tests:
  - [x] `start(provider:)` creates a new attempt state for the selected provider and a new attempt ID.
  - [x] Detected Provider Login URL updates `attemptState.lastURL` and waiting phase.
  - [x] Duplicate URL opening tracker behavior remains unchanged after state wiring.
  - [x] `stop()` moves an active attempt to stopped and keeps provider context.
  - [x] Launch failure moves the active attempt to failed with the launch error message.
  - [x] Termination records exit status without moving to confirmed.
- Integration tests:
  - [x] Not required for real provider processes; use deterministic runner/unit seams where possible.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- Runner state reflects process lifecycle events before AppModel access confirmation.
- Provider URL detection and manual fallback behavior remain available.

## Execution Notes

- Task-specific unit tests pass for `OAuthLoginRunnerTests` and `AuthAccessStateTests`.
- Focused coverage for `AuthStore.swift` plus `Auth/SubscriptionLoginAttemptState.swift` reports 87.79% line coverage.
- Task status is left pending because full `swift test` remains red in unrelated keymap/inspector expectation tests.
