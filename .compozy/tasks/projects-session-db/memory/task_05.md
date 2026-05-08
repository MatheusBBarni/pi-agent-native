# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 05: computed project availability and safe stale-project removal through `ProjectItem`/store/AppModel boundaries, with tests proving local records are removed without deleting project files.

## Important Decisions
- Proceeding despite `_tasks.md` and `task_04.md` still marking task 04 pending because the code already has the SQLite-backed state shape and local/Pi session identity split needed for task 05. The remaining inherited conflict is `AppModel.sanitizePersistedProjects` dropping missing paths, which task 05 must correct to preserve stale records.

## Learnings
- Pre-change stale-removal gap: `WorkspaceStore` has no project removal API, `NativeSessionIndexStore` has no project-session removal API, and `AppModel.sanitizePersistedProjects` filters persisted projects through existing-directory checks.
- `swift test --enable-code-coverage` initially failed two `CommandPaletteTests` because they used the real app SQLite store; isolating that test class with a temporary `SessionStore.databaseURLForTesting` made the coverage run deterministic.
- SwiftPM project-wide line coverage after this task is 38.18% (8592/22506), below the generic PRD 80% target because much existing UI/AppModel code remains uncovered. The new AppModel stale/local removal lines are covered by the task tests.

## Files / Surfaces
- Planned surfaces: `Sources/PiAgentNative/Models.swift`, `Sources/PiAgentNative/Workspace/WorkspaceStore.swift`, `Sources/PiAgentNative/Sessions/NativeSessionIndexStore.swift`, `Sources/PiAgentNative/AppModel.swift`, and project/session persistence tests.
- Touched implementation: `Models.swift` computed `ProjectAvailability`; `WorkspaceStore.swift` project record removal; `NativeSessionIndexStore.swift` project-session removal; `AppModel.swift` stale/local project removal orchestration and stale-preserving persisted-project normalization.
- Touched tests/tracking: `Tests/PiAgentNativeTests/ProjectSessionPersistenceTests.swift`, `Tests/PiAgentNativeTests/CommandPaletteTests.swift`, task 05 tracking files, and workflow memory.

## Errors / Corrections
- Corrected test isolation after coverage exposed state leakage through the real `SessionStore`.

## Ready for Next Run
- Task 05 implementation and tracking are updated. Automatic commits are disabled; leave the diff for manual review.
