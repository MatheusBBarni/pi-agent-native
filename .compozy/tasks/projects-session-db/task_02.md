---
status: completed
title: Update Project and Session Domain Models
type: refactor
complexity: medium
dependencies:
  - task_01
---

# Task 2: Update Project and Session Domain Models

## Overview
This task updates the app's domain model so local session identity is separate from Pi RPC session identity. It keeps existing UI-facing model names stable where possible while adding the fields needed by the SQLite store and future restore behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: `StoredSession.id` MUST represent the local app session identity.
- REQ-002: `StoredSession` MUST store the Pi RPC session id separately as optional metadata.
- REQ-003: Sessions MUST retain enough project relationship data for existing UI and restore flows until downstream tasks complete.
- REQ-004: All existing previews and tests that construct `StoredSession` MUST compile against the new model shape.
- REQ-005: Model updates MUST avoid introducing archive/delete state because those workflows are out of V1 scope.
</requirements>

## Subtasks
- [x] 2.1 Add Pi RPC session id metadata to `StoredSession`.
- [x] 2.2 Add project relationship fields needed by the TechSpec.
- [x] 2.3 Update session construction sites in tests and previews.
- [x] 2.4 Update session index helpers to remain source-compatible where possible.
- [x] 2.5 Add model tests for local id and Pi RPC id separation.

## Implementation Details
Modify `Sources/PiAgentNative/Models.swift` and `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift`. Update construction sites in existing tests and previews. See TechSpec "Data Models" for required fields and ADR-004 for the selected identity semantics.

### Relevant Files
- `Sources/PiAgentNative/Models.swift` — defines `ProjectItem` and `StoredSession`.
- `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift` — indexes and sorts sessions.
- `Tests/PiAgentNativeTests/HeaderActionTests.swift` — constructs sessions for navigation tests.
- `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift` — constructs persisted state with sessions.
- `Tests/PiAgentNativeCoreTests/ExternalTargetsTests.swift` — uses preview/test session state.
- `Sources/PiAgentNative/AppShellView.swift` — preview session construction.

### Dependent Files
- `Sources/PiAgentNative/AppModel.swift` — later updates upsert and selection semantics.
- `Sources/PiAgentNative/SessionStore.swift` — later persists the new model shape.

### Related ADRs
- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Requires local session identity separate from Pi RPC identity.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Defines resumability around Pi RPC session id presence.

## Deliverables
- Updated `StoredSession` domain model.
- Updated compile-time construction sites.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for existing session navigation compatibility **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Session created with local id and Pi RPC id preserves both values.
  - [x] Session without Pi RPC id is represented as non-resumable by helper logic added in this task or a documented placeholder for task 05.
  - [x] Session index ordering still sorts by running state and `updatedAt`.
- Integration tests:
  - [x] `HeaderActionTests` continue to pass with the updated model.
  - [x] Existing previews/test fixtures compile with the new initializer shape.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `rtk swift test --filter HeaderActionTests` passes.
- Local session id and Pi RPC session id are no longer conflated in model construction.
