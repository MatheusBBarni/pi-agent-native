---
status: pending
title: "Localize Inspector, Process Log, and Change Review"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 08: Localize Inspector, Process Log, and Change Review

## Overview
Localize app-owned labels, statuses, and pluralized counts in the inspector, process log, and change review surfaces. Preserve branches, paths, diffs, hunk metadata, tool output, and process output exactly.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize inspector and change review app-owned labels/statuses.
- MUST localize process log sheet chrome and empty states.
- MUST use `.stringsdict` for count-sensitive changed-file and queued-work copy.
- MUST preserve branch names, paths, diff lines, hunk metadata, tool output, and process output verbatim.
- MUST update tests without weakening parser/diff behavior coverage.
</requirements>

## Subtasks
- [ ] 8.1 Localize inspector section labels and status text.
- [ ] 8.2 Localize process log sheet title, close button, and empty state.
- [ ] 8.3 Localize change review sheet chrome and empty states.
- [ ] 8.4 Add pluralized changed-file and queued-work copy.
- [ ] 8.5 Preserve technical values as interpolation or raw display.
- [ ] 8.6 Add tests for pluralization and verbatim diff/path/tool output.

## Implementation Details
Prefer localizing display formatting close to the UI or assignment site when lower-risk than pulling localization into parser/service layers.

### Relevant Files
- `Sources/PiAgentNative/InspectorView.swift` — inspector labels/statuses.
- `Sources/PiAgentNative/ProcessLogSheetView.swift` — process log chrome.
- `Sources/PiAgentNative/ChangeReviewSheetView.swift` — change review UI and counts.
- `Sources/PiAgentNative/Models.swift` — queued work and git display models.
- `Sources/PiAgentNative/Workspace/GitService.swift` — app-owned git status summaries.
- `Sources/PiAgentNative/AppModel.swift` — repository snapshot and process log assignments.

### Dependent Files
- `Sources/PiAgentNative/RPC/PiRPCEventReducer.swift` — app-authored log titles mixed with raw details.
- `Tests/PiAgentNativeTests/QueuedWorkDisplayStateTests.swift` — queued work copy.
- `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift` — inspector help text.
- `Tests/PiAgentNativeCoreTests/RepositoryChangeSnapshotTests.swift` — change snapshot behavior.
- `Tests/PiAgentNativeCoreTests/GitDiffParserTests.swift` — diff content preservation.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Preserves paths, diffs, logs, and tool output.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Enables `.stringsdict` count handling.

## Deliverables
- Localized inspector, process log, and change review app-owned UI.
- Pluralized count resources for both locales.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for localized status/count display and verbatim technical output **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Changed-file count formats correctly for 0, 1, and many in English.
  - [ ] Changed-file count formats correctly for 0, 1, and many in pt-BR.
  - [ ] Branch name and path interpolation remain unchanged.
  - [ ] Diff line text and hunk metadata remain unchanged.
  - [ ] Tool/process output remains unchanged.
- Integration tests:
  - [ ] Change review displays localized chrome around unchanged diff data.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Inspector, process log, and change review app-owned UI localizes.
- Technical diff/log/tool data remains verbatim.
