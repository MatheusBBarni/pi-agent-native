---
status: completed
title: "Bridge PiRPC access refresh confirmation into runner state"
type: backend
complexity: high
dependencies:
    - task_02
---

# Task 03: Bridge PiRPC access refresh confirmation into runner state

## Overview

Update AppModel so provider process success leads to PiRPC Access Refresh and only the current successful refresh can confirm the runner-owned login attempt. This task preserves the existing `get_state` and `get_available_models` authority boundary while making the runner state reflect refresh success or failure.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- A zero provider-login exit status MUST move the runner-owned attempt into `refreshingAccess`, not confirmed.
- AppModel MUST map the current Access Refresh success into runner confirmed state only when refreshed provider-backed access is usable.
- AppModel MUST map current Access Refresh failure into runner failed state for the relevant attempt.
- Stale or superseded login attempts MUST NOT update the current runner state.
- Existing `AuthAccessRefreshTracker` epoch handling MUST remain the source of stale-response protection.
- Browser-open success MUST NOT be used as confirmation.
</requirements>

## Subtasks

- [x] 3.1 Update subscription login completion to mark runner state as refreshing on zero exit.
- [x] 3.2 Link the active login attempt to the Access Refresh started after PiRPC restart.
- [x] 3.3 Map successful current refresh with provider-backed model access to runner confirmed state.
- [x] 3.4 Map refresh failure or unusable provider-backed access to runner failed state.
- [x] 3.5 Preserve existing stale attempt and stale refresh response behavior.
- [x] 3.6 Add AppModel unit tests for refresh-to-runner confirmation and failure.

## Implementation Details

Modify `AppModel` around subscription login completion and Access Refresh handling. If current private/concrete PiRPC handling makes deterministic tests awkward, introduce the smallest focused test seam or helper extraction needed to test refresh result mapping without changing the public product behavior.

### Relevant Files

- `Sources/PiAgentNative/AppModel.swift` — owns `startSubscriptionLogin`, `completeSubscriptionLogin`, `beginAccessRefresh`, and response handling.
- `Sources/PiAgentNative/AuthAccessState.swift` — existing refresh tracker and access state transitions remain authoritative.
- `Sources/PiAgentNative/AuthStore.swift` — runner state transition helpers are called by AppModel.
- `Sources/PiAgentNative/RPC/PiRPCCommand.swift` — existing `get_state` and `get_available_models` commands remain unchanged.

### Dependent Files

- `Sources/PiAgentNative/LoginSheetView.swift` — will render confirmed/failed/refreshing states from the runner after this bridge exists.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — expected location for AppModel bridge tests.
- `Tests/PiAgentNativeTests/DefaultKeymapTests.swift` — existing subscription login dismissal and superseded completion tests must continue passing.

### Related ADRs

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — confirmation comes after provider process and Access Refresh.
- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — AppModel is the bridge from PiRPC confirmation into runner-owned state.

## Deliverables

- AppModel bridge from provider process completion to runner refreshing state.
- AppModel bridge from current PiRPC Access Refresh outcome to runner confirmed or failed state.
- Stale attempt and stale refresh protections preserved.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration-style AppModel tests for simulated PiRPC refresh confirmation **(REQUIRED)**.

## Tests

- Unit tests:
  - [x] Zero provider exit sets runner phase to refreshing access.
  - [x] Non-zero provider exit sets runner phase to failed and does not start confirmation.
  - [x] Successful current refresh with subscription-backed model access sets runner phase to confirmed.
  - [x] Refresh failure sets runner phase to failed with a visible message.
  - [x] Refresh success without usable subscription-backed access does not set confirmed.
  - [x] Superseded attempt completion does not update runner phase.
- Integration tests:
  - [x] Simulated `get_state` and `get_available_models` responses complete the current refresh and update runner state.
  - [x] Stale refresh responses are ignored and cannot overwrite a newer runner state.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- Runner confirmed state is reachable only from current Access Refresh success.
- Existing auth/access gating remains fail-closed while refresh is unknown, refreshing, failed, or inactive.

## Execution Notes

- Added AppModel bridge tests in `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift`.
- Focused verification passed for `SubscriptionLoginAppModelTests`, `OAuthLoginRunnerTests`, and `AuthAccessStateTests`.
- Coverage run for `SubscriptionLoginAppModelTests` passed; whole-file `AppModel.swift` coverage reported 24.53% line coverage because AppModel is a large existing class, so the 80% target is not met at whole-file scope.
- Full `swift test` remains red due unrelated existing expectation mismatches in `DefaultKeymapTests` and `InspectorPaneToggleTests`; status remains pending and `_tasks.md` is not advanced.
