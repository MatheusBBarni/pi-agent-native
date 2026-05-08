---
status: pending
title: Cover Restore, Stale State, and Removal Integration
type: test
complexity: medium
dependencies:
  - task_05
  - task_06
  - task_07
---

# Task 8: Cover Restore, Stale State, and Removal Integration

## Overview
This task adds cross-component verification for the finished continuity slice. Earlier tasks include focused tests; this task proves the store, AppModel, sidebar-facing state, stale removal, and diagnostics work together.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: Integration coverage MUST verify project/session restore across a save/load boundary.
- REQ-002: Integration coverage MUST verify stale project visibility after restore.
- REQ-003: Integration coverage MUST verify stale project removal updates project and session state without deleting files.
- REQ-004: Integration coverage MUST verify sidebar-facing metadata state for sessions.
- REQ-005: Integration coverage MUST include focused commands and document any unrelated full-suite failures.
</requirements>

## Subtasks
- [ ] 8.1 Add cross-component restore tests using a temporary database.
- [ ] 8.2 Add stale project restore tests using missing and existing temporary paths.
- [ ] 8.3 Add stale removal tests that verify local records and filesystem safety.
- [ ] 8.4 Add sidebar-facing metadata tests for session display state.
- [ ] 8.5 Run focused test filters and full validation command.

## Implementation Details
Create or extend `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift` and related test files. Use temporary database support from task 01. Do not duplicate low-level SQL tests already covered by `SessionStoreTests`.

### Relevant Files
- `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift` — likely new integration test file.
- `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift` — low-level persistence tests to avoid duplicating.
- `Sources/PiAgentNative/AppModel.swift` — integrated restore/removal behavior.
- `Sources/PiAgentNative/AppShellView.swift` — sidebar-facing presentation helpers.
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — diagnostics path behavior.

### Dependent Files
- `Sources/PiAgentNative/SessionStore.swift` — must support temporary DB tests.
- `Sources/PiAgentNative/Workspace/WorkspaceStore.swift` — project removal behavior.
- `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift` — session removal and metadata behavior.

### Related ADRs
- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — End-to-end continuity goal.
- [ADR-002: Scope PRD to Continuity MVP](adrs/adr-002.md) — Defines V1 behavior covered by integration tests.
- [ADR-003: Use System SQLite With Local Store Wrapper](adrs/adr-003.md) — Requires temporary DB verification.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Defines stale and resumability rules under test.

## Deliverables
- Integration tests for restore, stale state, stale removal, and diagnostics.
- Focused verification command results documented in implementation notes or PR output.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for project/session continuity **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Presentation helper for session metadata returns expected values for resumable and non-resumable sessions.
  - [ ] Diagnostic path helper returns the SQLite database path.
- Integration tests:
  - [ ] Save projects/sessions, recreate AppModel or equivalent state, and restore the same selected context.
  - [ ] Restore a missing project path and keep it visible as stale.
  - [ ] Remove a stale project and verify associated sessions are removed from local state.
  - [ ] Remove a stale project and verify an existing temporary directory is not deleted.
  - [ ] Focused filters for `SessionStoreTests`, `ProjectSessionPersistenceTests`, `HeaderActionTests`, and `InspectorPaneToggleTests` pass or unrelated pre-existing failures are documented.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `rtk compozy tasks validate --name projects-session-db` passes after task generation.
- Focused project/session continuity tests demonstrate the PRD success criteria at implementation level.
