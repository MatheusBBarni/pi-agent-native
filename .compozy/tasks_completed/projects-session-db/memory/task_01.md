# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Task 01 establishes the SQLite persistence foundation only: system SQLite linkage, app-support database URL, temp DB injection for tests, schema bootstrap, empty `load()` result, and fail-closed initialization behavior. Full project/session round-trip persistence remains deferred to task 03.

## Important Decisions
- Treat ADR-004 as resolving the older ADR-001 migration note: no `sessions.json` migration for this task.

## Learnings
- Pre-change signal on 2026-05-08: `rtk swift test --filter SessionStoreTests` built successfully but ran 0 tests because no `SessionStoreTests` existed yet.
- The current store implementation is JSON-backed (`sessions.json`) and `AppPersistedState` still carries `selectedProjectPath`; task 01 should preserve that high-level shape for compatibility.
- Verification after implementation: focused `SessionStoreTests` pass with 5 tests, `PiAgentNativeCore` builds with `.linkedLibrary("sqlite3")`, `SessionStore.swift` file coverage is 106/124 lines (85.48%), and the full `rtk swift test` suite passes with 126 tests.

## Files / Surfaces
- Touched surfaces: `Package.swift`, `Sources/PiAgentNative/SessionStore.swift`, new `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift`, and `Tests/PiAgentNativeCoreTests/RPCTests.swift` for the unrelated truncation expectation correction.

## Errors / Corrections
- Repository root does not contain `AGENTS.md` or `CLAUDE.md`; only the prompt-provided AGENTS instruction requiring `RTK.md` was available for this repo.
- First focused test run after implementation failed because the invalid-parent test tried to write inside a temp directory before creating it; fixed the test helper to create temp directories eagerly.
- Full `rtk swift test` exposed an unrelated stale expectation in `RPCTests.swift`: `QueuedWorkEntry.summary(maxLength:)` includes the ellipsis inside the requested maximum length, so `maxLength: 12` returns `This queu...`. The expectation was corrected to match existing implementation behavior.

## Ready for Next Run
- Task 01 completed with SQLite schema bootstrap only. Task 03 still needs real project/session/selection row persistence; `SessionStore.save(_:)` currently opens/bootstraps the database but intentionally does not persist the provided state yet.
