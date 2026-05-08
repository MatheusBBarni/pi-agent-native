---
status: pending
title: Add Computed Project Availability and Stale Removal
type: backend
complexity: medium
dependencies:
  - task_04
---

# Task 5: Add Computed Project Availability and Stale Removal

## Overview
This task adds the core stale-project behavior required by the PRD. It computes project availability from the filesystem and adds safe local removal for stale projects without mutating project files on disk.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: Project availability MUST be computed from whether the stored path exists and is a directory.
- REQ-002: Stale projects MUST remain in the normal project list.
- REQ-003: Removing a stale project MUST remove only local app records.
- REQ-004: Removing a project MUST also remove local sessions associated with that project.
- REQ-005: Removing a project MUST clear selected project/session state when those selections point at the removed project.
- REQ-006: Removing a stale project MUST never delete the project directory or files from disk.
</requirements>

## Subtasks
- [ ] 5.1 Add project availability helper logic.
- [ ] 5.2 Add project removal to `WorkspaceStore`.
- [ ] 5.3 Add associated session removal to `NativeSessionIndexStore`.
- [ ] 5.4 Add `AppModel` stale project removal orchestration.
- [ ] 5.5 Add tests proving local removal does not touch filesystem content.

## Implementation Details
Modify `Sources/PiAgentNative/Workspace/WorkspaceStore.swift`, `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift`, and `Sources/PiAgentNative/AppModel.swift`. Keep removal action ownership in AppModel/store layers, not direct persistence mutation.

### Relevant Files
- `Sources/PiAgentNative/Workspace/WorkspaceStore.swift` — owns in-memory project list and selected project.
- `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift` — owns in-memory sessions and selected session.
- `Sources/PiAgentNative/AppModel.swift` — coordinates user-facing app actions and persistence.
- `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift` — likely location for AppModel/store behavior tests.

### Dependent Files
- `Sources/PiAgentNative/AppShellView.swift` — later invokes stale removal from UI.
- `Sources/PiAgentNative/SessionStore.swift` — persists resulting state after removal.

### Related ADRs
- [ADR-002: Scope PRD to Continuity MVP](adrs/adr-002.md) — Requires stale remove action and defers archive/delete.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Selects computed availability and AppModel/store-owned removal.

## Deliverables
- Computed project availability helper or equivalent model surface.
- Safe stale project removal through AppModel/store boundaries.
- Tests proving filesystem content is not deleted.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for stale project removal flow **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Existing directory path is reported available.
  - [ ] Missing directory path is reported stale.
  - [ ] Removing a stale project removes that project from `WorkspaceStore`.
  - [ ] Removing a stale project removes associated local sessions.
  - [ ] Removing selected stale project clears selected project and selected session.
- Integration tests:
  - [ ] A temporary project directory still exists after its app project record is removed.
  - [ ] Persisted state after stale removal no longer contains the removed project or sessions.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Stale project removal cannot delete filesystem content.
- Stale projects are preserved until the user removes them.
