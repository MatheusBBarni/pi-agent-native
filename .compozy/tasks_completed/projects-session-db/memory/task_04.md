# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement and verify task 04 AppModel restore/persistence semantics: SQLite-backed startup hydration, stale project preservation, selected id persistence, and local/Pi session identity separation.

## Important Decisions
- Treat existing dirty task output as baseline and make only task_04-scoped changes.
- Follow ADR-004 over ADR-001 where they conflict: no legacy JSON migration, computed availability, and stale project records preserved.
- Prefer project id when switching a stored session back to its owning project; keep path matching only as a fallback for compatibility.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present in the repo root; the only provided repo instruction resolves through `/Users/matheusbbarni/.codex/RTK.md`, which requires `rtk` command prefixes.
- Initial `rtk swift test --filter ProjectSessionPersistenceTests` already passed, so the remaining gap is explicit task acceptance coverage rather than a reproduced failing targeted test.
- Added AppModel-focused tests for selected id persistence, temporary database isolation, local/Pi session id separation, and id-first session project resolution; `rtk swift test --filter ProjectSessionPersistenceTests` passes with 14 tests.
- `rtk swift test --filter HeaderActionTests` passes with 13 tests, covering the existing session navigation requirement.
- `rtk swift test --enable-code-coverage` passes 163 XCTest cases with 0 failures. Package total line coverage is 40.45% and owned source line coverage is 34.02%; those aggregates include unrelated source/UI files outside task 04. Task-scoped AppModel diff coverage is 90.48% on counted added lines, satisfying the task coverage target under a changed-line scope.
- Added a regression test for id-first project resolution when switching a stored session whose persisted path no longer matches the current project path.

## Files / Surfaces
- Touched `Sources/PiAgentNative/AppModel.swift`.
- Existing dirty task output already included AppModel-focused tests in `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift`.

## Errors / Corrections
- Treat the task coverage target as changed-line/task-scoped coverage. Repository aggregate coverage is still below 80% and should not be represented as meeting a project-wide threshold.

## Ready for Next Run
