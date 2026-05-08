---
status: pending
title: "Localize Assignment-Time AppModel Strings"
type: backend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 04: Localize Assignment-Time AppModel Strings

## Overview
Localize app-owned status, log, availability, and model-owned display strings assigned by `AppModel`. This task applies the accepted assignment-time strategy while preserving technical values as interpolation.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize app-owned `AppModel` statuses and log titles/details where they are assigned.
- MUST preserve provider names, model IDs, paths, command names, UUIDs, exit statuses, and errors verbatim.
- SHOULD accept stale previously assigned app-owned strings after language switch per ADR-003.
- MUST update exact-English tests without weakening behavior coverage.
- MUST not localize user prompts, assistant output, RPC output, or tool content.
</requirements>

## Subtasks
- [ ] 4.1 Inventory app-owned `AppModel` assignment sites.
- [ ] 4.2 Localize status and launch detail defaults.
- [ ] 4.3 Localize start/stop/send/session/access-refresh statuses.
- [ ] 4.4 Localize app-authored process log titles and safe templates.
- [ ] 4.5 Preserve raw technical values as interpolation.
- [ ] 4.6 Add representative English and pt-BR assignment tests.
- [ ] 4.7 Update affected exact-English assertions.

## Implementation Details
Use the localization facade from task_02 and the selected language from task_03. Keep this task scoped to model-owned assignment-time strings; UI view chrome is covered by later tasks.

### Relevant Files
- `Sources/PiAgentNative/AppModel.swift` — primary assignment-time string surface.
- `Sources/PiAgentNative/App/ProcessLogStore.swift` — event log storage receives localized strings.
- `Sources/PiAgentNative/Models.swift` — `EventLog`, `StoredSession.status`, and technical value models.
- `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift` — persisted session status can remain stale by design.
- `Tests/PiAgentNativeTests/CommandPaletteTests.swift` — disabled status assertions.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — access refresh/status assertions.
- `Tests/PiAgentNativeTests/ContextAttachmentSubmissionTests.swift` — attachment status assertions.

### Dependent Files
- `Sources/PiAgentNative/ChatSurfaceView.swift` — displays `statusText`, model status, and picker states.
- `Sources/PiAgentNative/InspectorView.swift` — displays model-owned repository/status text.
- `Sources/PiAgentNative/ProcessLogSheetView.swift` — renders localized log titles and raw details.
- `Tests/PiAgentNativeCoreTests/ExternalTargetsTests.swift` — checks status/log detail preservation.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Defines verbatim technical boundary.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Defines assignment-time behavior and stale-state trade-off.

## Deliverables
- Localized app-owned `AppModel` assignment strings.
- Tests proving raw technical values are preserved.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for representative status/log flows **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `statusText` assignment resolves in English for a representative action.
  - [ ] `statusText` assignment resolves in pt-BR for the same action.
  - [ ] Event log title is localized while detail preserves a raw path or error string.
  - [ ] Provider/model IDs remain byte-for-byte unchanged when interpolated.
- Integration tests:
  - [ ] Command palette disabled action sets a localized app-owned reason without changing invocation behavior.
  - [ ] Existing send/session/login behavior remains unchanged except app-owned copy.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Representative model-owned statuses localize in both languages.
- Technical/user/generated values remain verbatim.
