---
status: completed
title: "Render structured subscription login state in the Login modal"
type: frontend
complexity: medium
dependencies:
    - task_02
    - task_03
---

# Task 05: Render structured subscription login state in the Login modal

## Overview

Update the Login modal so the structured runner-owned subscription login state is the primary user signal. The modal should make provider identity, waiting, refreshing, confirmed, failed, and stopped states clear while keeping terminal output and Open Link fallback available for recovery.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- `LoginSheetView` MUST render structured subscription login state from `OAuthLoginRunner.attemptState`.
- Terminal output MUST remain visible but secondary to structured status.
- The Open Link fallback MUST remain visible when a Provider Login URL is available.
- Browser-open success MUST NOT be rendered as login confirmation.
- The modal MUST avoid showing stale confirmation as current confirmation when the selected provider differs from the attempt provider.
- The UI copy MUST avoid implying that Pi Agent Native manages provider subscriptions.
</requirements>

## Subtasks

- [ ] 5.1 Add a focused subscription login status surface for the selected provider.
- [ ] 5.2 Render waiting, refreshing, confirmed, failed, stopped, and not-started states from runner attempt state.
- [ ] 5.3 Keep manual Open Link fallback tied to the latest Provider Login URL.
- [ ] 5.4 Keep terminal output available as secondary troubleshooting context.
- [ ] 5.5 Ensure provider switching does not show stale confirmed state for the newly selected provider.
- [ ] 5.6 Add unit-testable status helper coverage and a manual verification checklist.

## Implementation Details

Modify `LoginSheetView` to render a dedicated subscription status section driven by the runner state. Keep the view mostly rendering-only; any non-trivial status interpretation should live in a small helper that can be unit tested without SwiftUI view tests.

### Relevant Files

- `Sources/PiAgentNative/LoginSheetView.swift` — primary Login modal UI and subscription pane.
- `Sources/PiAgentNative/AuthStore.swift` — exposes runner-owned attempt state and Provider Login URL.
- `Sources/PiAgentNative/AppModel.swift` — owns the model environment object used by the sheet.
- `Sources/PiAgentNative/Theme.swift` — existing visual styling tokens for modal surfaces.

### Dependent Files

- `Tests/PiAgentNativeCoreTests/OAuthLoginRunnerTests.swift` — runner state coverage should support UI rendering assumptions.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — AppModel confirmation bridge coverage should support UI status assumptions.
- `README.md` — may need a small docs update only if visible login behavior copy changes materially.

### Related ADRs

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — UI must not promise native redirect ownership or subscription management.
- [ADR-002: Prioritize Provider Login State Clarity](adrs/adr-002.md) — UI must make provider login states clear.
- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — UI must consume runner-owned state.

## Deliverables

- Login modal subscription pane renders structured provider login states.
- Manual Open Link fallback and terminal output remain available.
- Provider switching does not show stale confirmation for the selected provider.
- Unit tests with 80%+ coverage for status helper behavior **(REQUIRED)**.
- Manual modal verification for all required states **(REQUIRED)**.

## Tests

- Unit tests:
  - [ ] Not-started state produces copy for the selected provider without implying active access.
  - [ ] Waiting state with URL produces copy that tells the user to continue with the provider and keeps Open Link available.
  - [ ] Refreshing state produces copy that access is being checked.
  - [ ] Confirmed state produces copy only when the attempt provider matches the selected provider.
  - [ ] Failed and stopped states produce distinct user-facing copy.
  - [ ] Selected provider mismatch suppresses stale confirmed copy.
- Integration tests:
  - [ ] No SwiftUI automation required; manually verify modal rendering for not started, waiting, refreshing, confirmed, failed, stopped, provider switching, terminal output, and Open Link fallback.
- Test coverage target: >=80%.
- All tests must pass.

## Success Criteria

- All tests passing.
- Test coverage >=80%.
- Login modal structured status is the primary subscription login signal.
- Terminal output remains available but no longer carries the main login state burden.
- Browser-open success is never presented as confirmed login.
