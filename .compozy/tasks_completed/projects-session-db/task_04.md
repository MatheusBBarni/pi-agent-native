---
status: completed
title: Wire AppModel Restore and Persistence Semantics
type: refactor
complexity: high
dependencies:
    - task_03
---

# Task 4: Wire AppModel Restore and Persistence Semantics

## Overview
This task updates app startup and save behavior to use the SQLite-backed model semantics. It keeps project/session restore inside the existing `AppModel`, `WorkspaceStore`, and `NativeSessionIndexStore` boundaries while stopping the current behavior that silently drops unavailable projects.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: App startup MUST hydrate projects, sessions, selected project id, and selected session id from the SQLite-backed store.
- REQ-002: App startup MUST NOT silently drop projects only because their paths are unavailable.
- REQ-003: App persistence MUST save selected project id rather than selected project path.
- REQ-004: Session upsert logic MUST use Pi RPC session id as metadata and local session id for native selection.
- REQ-005: Existing session switching and navigation behavior MUST continue to work for available projects.
</requirements>

## Subtasks
- [x] 4.1 Update `AppModel` hydration to use selected project id.
- [x] 4.2 Replace silent persisted-project dropping with normalization that preserves stale records.
- [x] 4.3 Update persistence saves to write the new state shape.
- [x] 4.4 Update session upsert and selection comparisons for local/Pi id separation.
- [x] 4.5 Add app-model tests for restore and save semantics.

## Implementation Details
Modify `Sources/PiAgentNative/AppModel.swift`. Add or extend tests in `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift` or the closest existing AppModel test file. The current `sanitizePersistedProjects` behavior is a key conflict with the PRD and TechSpec.

### Relevant Files
- `Sources/PiAgentNative/AppModel.swift` — startup hydration, session upsert, persistence writes.
- `Sources/PiAgentNative/SessionStore.swift` — persistence boundary consumed by AppModel.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — example AppModel-style test structure.
- `Tests/PiAgentNativeTests/HeaderActionTests.swift` — existing session navigation expectations.

### Dependent Files
- `Sources/PiAgentNative/Workspace/WorkspaceStore.swift` — selected project behavior used by AppModel.
- `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift` — selected session and session list behavior.

### Related ADRs
- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Requires reliable restore semantics.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Requires no migration and computed availability.

## Deliverables
- AppModel restore behavior using SQLite-backed state.
- Persistence writes using selected ids and separated session identity.
- AppModel tests for available and stale project restore.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for AppModel restore behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Startup with stored available project restores project and selected session.
  - [x] Startup with stored unavailable project keeps the project record in memory.
  - [x] Persisting selected context writes selected project id and selected session id.
  - [x] Session upsert stores Pi RPC session id separately from native selected session id.
- Integration tests:
  - [x] Existing session navigation tests pass after identity split.
  - [x] AppModel initialization with temporary store does not touch the real application support database.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `rtk swift test --filter ProjectSessionPersistenceTests` passes if a new test file is added.
- Available project/session restore still behaves like the current user workflow.
