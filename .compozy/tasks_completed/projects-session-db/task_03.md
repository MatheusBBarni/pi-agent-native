---
status: completed
title: Persist Projects, Sessions, and Selection in SQLite
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 3: Persist Projects, Sessions, and Selection in SQLite

## Overview
This task completes the SQLite persistence behavior for projects, sessions, and selected context. It makes the state required by the PRD durable without migrating legacy JSON state.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: `SessionStore.save(_:)` MUST persist projects, sessions, selected project id, and selected session id.
- REQ-002: `SessionStore.load()` MUST return persisted projects, sessions, selected project id, and selected session id.
- REQ-003: Project path uniqueness MUST prevent duplicate local project records for the same canonical path.
- REQ-004: Session persistence MUST preserve local session id separately from Pi RPC session id.
- REQ-005: The implementation MUST NOT import legacy `sessions.json` data.
- REQ-006: SQL statements MUST be parameterized.
</requirements>

## Subtasks
- [x] 3.1 Persist and load project records.
- [x] 3.2 Persist and load session records.
- [x] 3.3 Persist and load selected project/session identity.
- [x] 3.4 Enforce project path uniqueness in persistence behavior.
- [x] 3.5 Add store round-trip tests for project/session/selection state.

## Implementation Details
Modify `Sources/PiAgentNative/SessionStore.swift`. Extend `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift`. Use the schema from TechSpec "Data Models" and keep the public store boundary simple.

### Relevant Files
- `Sources/PiAgentNative/SessionStore.swift` — SQLite persistence implementation.
- `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift` — temporary database round-trip tests.
- `Sources/PiAgentNative/Models.swift` — model shape persisted by the store.

### Dependent Files
- `Sources/PiAgentNative/AppModel.swift` — consumes loaded selected identity and sessions in task 04.
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — displays store path in task 07.

### Related ADRs
- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Requires durable SQLite project/session continuity.
- [ADR-003: Use System SQLite With Local Store Wrapper](adrs/adr-003.md) — Defines wrapper and dependency constraints.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Rejects JSON migration.

## Deliverables
- Full SQLite round-trip persistence for V1 project/session state.
- Selection persistence based on ids, not selected project path.
- No legacy JSON import behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for repeated save/load cycles **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Save one project and load it back with the same id, name, and path.
  - [ ] Save two sessions for one project and load both with local id and Pi RPC id preserved.
  - [ ] Save selected project id and selected session id and load both back.
  - [ ] Saving duplicate project paths results in one canonical project record.
  - [ ] Absent legacy `sessions.json` has no effect on fresh SQLite state.
- Integration tests:
  - [ ] Two sequential save/load cycles preserve the final state and do not duplicate projects or sessions.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `rtk swift test --filter SessionStoreTests` passes for persistence scenarios.
- The new store starts fresh and ignores old JSON state.
