# Project Session Continuity — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Add SQLite Store Harness and Schema Bootstrap | completed | high | — |
| 02 | Update Project and Session Domain Models | completed | medium | task_01 |
| 03 | Persist Projects, Sessions, and Selection in SQLite | completed | high | task_01, task_02 |
| 04 | Wire AppModel Restore and Persistence Semantics | completed | high | task_03 |
| 05 | Add Computed Project Availability and Stale Removal | completed | medium | task_04 |
| 06 | Render Stale Projects and Session Metadata in Sidebar | completed | medium | task_05 |
| 07 | Update Settings Diagnostics for SQLite State Path | completed | low | task_01 |
| 08 | Cover Restore, Stale State, and Removal Integration | completed | medium | task_05, task_06, task_07 |
