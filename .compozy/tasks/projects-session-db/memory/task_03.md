# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03 SQLite round-trip persistence for projects, sessions, and selected project/session ids. Baseline `rtk swift test --filter SessionStoreTests` passes existing schema-bootstrap tests but does not verify persistence behavior yet.

## Important Decisions
- Align `AppPersistedState` with the TechSpec by using `selectedProjectID` for persistence instead of the older `selectedProjectPath` boundary.
- Save uses a replace-all transaction for the V1 snapshot: delete previous selection/sessions/projects, canonicalize and dedupe projects, then insert the final state with prepared statements.
- Duplicate project paths are canonicalized with `URL(fileURLWithPath:).standardizedFileURL.path`; duplicate project ids are remapped to the first retained project for session/project selection consistency.

## Learnings
- Current `SessionStore` has the SQLite file path, schema bootstrap, and test database injection from prior tasks, but `load()` returns an empty state and `save(_:)` ignores the state beyond schema creation.
- `SessionStore.load()` rebuilds `StoredSession.projectPath` and `projectName` by joining `sessions` to `projects`; these fields are not duplicated in the `sessions` table.
- Legacy `sessions.json` is ignored entirely; fresh SQLite load/save never decodes JSON.

## Files / Surfaces
- Touched surfaces: `Sources/PiAgentNative/SessionStore.swift`, `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift`, `Sources/PiAgentNative/AppModel.swift`, `Sources/PiAgentNative/Workspace/WorkspaceStore.swift`, `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift`, shared memory, and task tracking files.

## Errors / Corrections
- Initial focused compile failed because prepared-statement helpers returned optional `Bool` and `SQLITE_TRANSIENT` is not exported by Swift SQLite; fixed by defaulting helper results to `false` and defining a local `sqliteTransient` destructor.

## Ready for Next Run
- Verification evidence after implementation: `rtk swift test --filter SessionStoreTests` passed 10 tests; `rtk swift test` passed 136 tests; `rtk swift test --enable-code-coverage --filter SessionStoreTests` passed 10 tests; `xcrun llvm-cov report` showed `Sources/PiAgentNative/SessionStore.swift` at 89.22% line coverage.
