# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- After task 02, sidebar/session selection is local-session-id based; code that reconciles Pi RPC state must compare incoming RPC `sessionId` to `StoredSession.piSessionID`, not `StoredSession.id`.
- After task 03, `AppPersistedState` persists `selectedProjectID` and `selectedSessionID`; the old `selectedProjectPath` persistence boundary is gone.
- AppModel tests that can trigger persistence should set `SessionStore.databaseURLForTesting` to a temporary SQLite file; otherwise test order or coverage runs can read/write the real Application Support database and become state-dependent.

## Open Risks
- `rtk swift test --enable-code-coverage` currently reports 34.02% total line coverage across the repository because many UI files have no direct coverage. PRD task coverage targets may need a scoped interpretation or a separate coverage campaign; task-local persistence surfaces are much higher.

## Handoffs
- Task 01 leaves `SessionStore.save(_:)` as bootstrap-only: it opens the SQLite database and ensures schema exists, but intentionally does not write `AppPersistedState` rows until task 03 implements project/session/selection persistence.
