---
status: completed
title: "Add runner-owned subscription login state model"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Add runner-owned subscription login state model

## Overview

Add the structured subscription login attempt model that the rest of the implementation will depend on. This task gives `OAuthLoginRunner` a testable user-facing state source while preserving the existing raw runner properties during migration.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- The implementation MUST add a `SubscriptionLoginPhase` value model matching the TechSpec phase set.
- The implementation MUST add a `SubscriptionLoginAttemptState` value model that can represent provider, attempt ID, phase, latest Provider Login URL, and exit status.
- `OAuthLoginRunner` MUST expose runner-owned structured attempt state for Login modal rendering.
- The new state model MUST remain `Equatable` for deterministic unit tests.
- Existing runner fields used by current code SHOULD remain available during migration unless all references are safely updated in this task.
</requirements>

## Subtasks

- [ ] 1.1 Add the subscription login phase model to the auth/login domain.
- [ ] 1.2 Add the subscription login attempt state model to the auth/login domain.
- [ ] 1.3 Add runner-owned published attempt state to `OAuthLoginRunner`.
- [ ] 1.4 Add focused transition helpers for starting, waiting, refreshing, confirmed, failed, stopped, and reset states.
- [ ] 1.5 Add unit coverage for state defaults and transition helper behavior.

## Implementation Details

Create or modify the smallest auth-domain surface needed for the TechSpec "Core Interfaces" section. Prefer a new file under `Sources/PiAgentNative/Auth/` if it keeps `AuthStore.swift` from growing further; otherwise keep the value models adjacent to `OAuthLoginRunner`.

### Relevant Files

- `Sources/PiAgentNative/AuthStore.swift` — contains `OAuthLoginRunner`, current raw login process state, URL detection, and duplicate open tracker.
- `Sources/PiAgentNative/AuthAccessState.swift` — existing Equatable auth/access state patterns that the new value models should match stylistically.
- `Sources/PiAgentNative/Auth/LoginProviderCatalog.swift` — defines the supported subscription providers represented by the new attempt state.
- `Tests/PiAgentNativeCoreTests/AuthAccessStateTests.swift` — existing pure auth/login tests and URL detector coverage patterns.

### Dependent Files

- `Sources/PiAgentNative/AppModel.swift` — later tasks will drive runner transition helpers from AppModel lifecycle and PiRPC refresh outcomes.
- `Sources/PiAgentNative/LoginSheetView.swift` — later tasks will render the new runner-owned attempt state.
- `Tests/PiAgentNativeCoreTests/OAuthLoginRunnerTests.swift` — new or extended test file for runner state behavior.

### Related ADRs

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — keeps provider login process ownership outside Pi Agent Native billing/account management.
- [ADR-002: Prioritize Provider Login State Clarity](adrs/adr-002.md) — requires explicit user-facing login states.
- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — requires the structured attempt state to live in `OAuthLoginRunner`.

## Deliverables

- Runner-owned subscription login attempt state model.
- Transition helpers for all TechSpec phases.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for downstream AppModel bridge are not required in this task, but the state model must be usable by later AppModel tests **(REQUIRED)**.

## Tests

- Unit tests:
  - [ ] New attempt state defaults to no provider, no attempt ID, no URL, no exit status, and `notStarted`.
  - [ ] Starting transition records provider and attempt ID and clears stale URL and exit status.
  - [ ] Waiting transition records latest Provider Login URL without confirming login.
  - [ ] Refreshing transition preserves provider and attempt identity.
  - [ ] Failed and stopped transitions retain enough provider context for user-facing explanation.
- Integration tests:
  - [ ] Not required for this isolated model task; verify the public model is accessible to AppModel and LoginSheetView compile targets.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- `OAuthLoginRunner` exposes a structured login attempt state without removing current behavior needed by existing call sites.
- The new model represents every phase required by the PRD and TechSpec.
