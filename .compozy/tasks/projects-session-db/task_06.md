---
status: pending
title: Render Stale Projects and Session Metadata in Sidebar
type: frontend
complexity: medium
dependencies:
  - task_05
---

# Task 6: Render Stale Projects and Session Metadata in Sidebar

## Overview
This task exposes the continuity state in the sidebar. It adds stale project presentation, stale project removal affordance, and minimal session metadata so users can understand what can be resumed.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: Sidebar project rows MUST visually distinguish stale projects from available projects.
- REQ-002: Stale project rows MUST expose a remove action with copy that does not imply filesystem deletion.
- REQ-003: Session rows MUST show title, status, last updated time, and resumability state.
- REQ-004: Stale project rows MUST not start or switch Pi sessions.
- REQ-005: Sidebar metadata MUST remain dense enough for the existing sidebar layout.
</requirements>

## Subtasks
- [ ] 6.1 Update project row presentation for stale state.
- [ ] 6.2 Add stale project remove action in the sidebar.
- [ ] 6.3 Update session row presentation for required metadata.
- [ ] 6.4 Disable or guard interactions that cannot work for stale projects.
- [ ] 6.5 Add presentation-focused tests or helper tests for stale and resumable display states.

## Implementation Details
Modify `Sources/PiAgentNative/AppShellView.swift`. Extract small presentation helpers if needed to make stale/resumable display testable without snapshot tests. Keep archive/delete actions out of V1.

### Relevant Files
- `Sources/PiAgentNative/AppShellView.swift` — project and session sidebar row rendering.
- `Sources/PiAgentNative/Theme.swift` — existing design tokens for sidebar styling.
- `Tests/PiAgentNativeTests/HeaderActionTests.swift` — existing sidebar/session-adjacent behavior tests.

### Dependent Files
- `Sources/PiAgentNative/AppModel.swift` — provides availability/removal/session metadata APIs to UI.
- `Sources/PiAgentNative/Models.swift` — session metadata fields used in rows.

### Related ADRs
- [ADR-002: Scope PRD to Continuity MVP](adrs/adr-002.md) — Defines V1 UI scope.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Defines computed availability and resumability semantics.

## Deliverables
- Sidebar stale project state.
- Sidebar remove action for stale projects.
- Session rows showing minimal metadata and resumability.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for sidebar action wiring **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Available project row presentation does not show stale/remove state.
  - [ ] Stale project row presentation shows stale state and remove action.
  - [ ] Session row presentation includes title, status, updated time, and resumability copy or icon metadata.
  - [ ] Non-resumable session presentation is distinguishable from resumable state.
- Integration tests:
  - [ ] Activating stale remove in the sidebar calls AppModel removal behavior.
  - [ ] Stale project row does not trigger session restore/start behavior.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can identify stale projects from the sidebar.
- Users can see minimal session metadata without opening logs.
