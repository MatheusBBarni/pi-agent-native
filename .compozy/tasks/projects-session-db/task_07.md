---
status: completed
title: Update Settings Diagnostics for SQLite State Path
type: frontend
complexity: low
dependencies:
  - task_01
---

# Task 7: Update Settings Diagnostics for SQLite State Path

## Overview
This task updates settings diagnostics so the app reports the new SQLite state file instead of the old JSON sessions path. It keeps troubleshooting aligned with the new persistence location.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: Settings diagnostics MUST display the SQLite project/session store path.
- REQ-002: Diagnostic labeling MUST avoid referring to `sessions.json`.
- REQ-003: The displayed path MUST come from `SessionStore.storeURL` or equivalent single source of truth.
- REQ-004: Existing auth and launch diagnostics MUST remain unchanged.
</requirements>

## Subtasks
- [x] 7.1 Update settings store diagnostic naming for the project/session DB.
- [x] 7.2 Update settings sheet display label.
- [x] 7.3 Add or update tests for diagnostic path value.
- [x] 7.4 Confirm existing settings diagnostics still render expected values.

## Implementation Details
Modify `Sources/PiAgentNative/Settings/SettingsStore.swift` and `Sources/PiAgentNative/SettingsSheetView.swift`. This task depends only on the DB URL from task 01 and should not alter persistence behavior.

### Relevant Files
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — exposes current `sessionStorePath`.
- `Sources/PiAgentNative/SettingsSheetView.swift` — displays the state directory diagnostics.
- `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift` — example app-state persistence expectations.

### Dependent Files
- `Sources/PiAgentNative/SessionStore.swift` — source of the SQLite store path.

### Related ADRs
- [ADR-003: Use System SQLite With Local Store Wrapper](adrs/adr-003.md) — Requires database path diagnostics.

## Deliverables
- Settings diagnostic label/value for SQLite project/session DB.
- Tests or assertions covering the diagnostic value.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for settings diagnostics **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Settings store exposes a path ending in the SQLite database filename.
  - [x] Settings store no longer exposes a JSON-specific sessions path label or property name where tests assert it.
  - [x] Auth directory path remains unchanged.
- Integration tests:
  - [x] Settings sheet renders the project/session state path without changing launch diagnostics.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Settings diagnostics point users to the SQLite state location.
- Existing auth and launch diagnostics are unaffected.
