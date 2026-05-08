# TechSpec: Project Session Continuity

## Executive Summary

Project/session continuity will replace JSON-backed sidebar persistence with a local SQLite store built on Apple system SQLite through a small Swift wrapper. The implementation keeps the current `SessionStore`/`AppModel` boundary, starts with empty new persistence state, and adds only the V1 continuity behavior required by the PRD.

Primary trade-off: this avoids a new package dependency and keeps scope small, but it requires careful manual SQLite statement handling, schema setup, and temporary-database tests.

## System Architecture

### Component Overview

- `SessionStore`
  - Owns SQLite file location, schema setup, load/save behavior, and project/session persistence.
  - Replaces `sessions.json` persistence while preserving high-level state hydration for `AppModel`.

- `AppPersistedState`
  - Remains the high-level transfer shape between persistence and app state.
  - Expands only as needed to represent local session identity and Pi RPC session identity.

- `ProjectItem`
  - Stores durable project identity, name, and path.
  - Availability is computed from the filesystem, not persisted.

- `StoredSession`
  - Stores local session identity, project relationship, Pi RPC session id, title, status, session file, and `updatedAt`.

- `WorkspaceStore`
  - Continues to own in-memory projects and selected project state.
  - Adds stale-project removal operation.

- `NativeSessionIndexStore`
  - Continues to own in-memory session list and selected session state.
  - Uses local session id for UI selection and ordering.

- `AppShellView`
  - Displays stale project state, remove action for stale projects, and minimal session metadata.

## Implementation Design

### Core Interfaces

Swift implementation contract:

```swift
struct AppPersistedState: Equatable {
    var projects: [ProjectItem]
    var sessions: [StoredSession]
    var selectedProjectID: String?
    var selectedSessionID: String?
}
```

Required store shape, shown as a Go-style contract sketch for task compatibility:

```go
type ProjectSessionStore interface {
    Load() (AppPersistedState, error)
    Save(state AppPersistedState) error
    RemoveProject(projectID string) error
}
```

Swift-facing methods should remain simple:

```swift
enum SessionStore {
    static var storeURL: URL { get }
    static func load() -> AppPersistedState
    static func save(_ state: AppPersistedState)
}
```

### Data Models

`ProjectItem`:
- `id: String`
- `name: String`
- `path: String`

Computed project availability:
- `available` when `path` exists and is a directory.
- `stale` when `path` no longer exists or is not a directory.

`StoredSession`:
- `id: String` local app session id
- `piSessionID: String?`
- `projectID: String`
- `projectPath: String`
- `projectName: String`
- `title: String`
- `status: String`
- `sessionFile: String`
- `updatedAt: Date`

SQLite schema:
- `projects(id primary key, name, path unique, created_at, updated_at)`
- `sessions(id primary key, project_id, pi_session_id, title, status, session_file, updated_at)`
- `app_selection(key primary key, value)`

No automatic `sessions.json` migration is required.

### API Endpoints

No network or HTTP API endpoints are introduced.

## Integration Points

- Pi RPC
  - Pi remains the authority for session runtime behavior.
  - Native stores `piSessionID` as metadata and uses existing switch-session behavior.

- Filesystem
  - Used to compute project availability.
  - Stale project removal must never delete project files.

- macOS Application Support
  - Stores the SQLite database under the Pi Agent Native app support directory.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `Package.swift` | Modified | Needs system SQLite linkage/import support. Medium risk. | Add the minimal linker/import setup for `SQLite3`. |
| `SessionStore.swift` | Modified | Replaces JSON implementation with SQLite wrapper. High risk. | Add schema setup, load/save, parameterized SQL, temp DB support. |
| `Models.swift` | Modified | Session identity separates local id from Pi RPC id. Medium risk. | Extend `StoredSession` while preserving UI needs. |
| `AppModel.swift` | Modified | Startup restore and persistence calls must use new semantics. High risk. | Stop dropping stale projects; preserve selected context when valid. |
| `WorkspaceStore.swift` | Modified | Needs local project removal. Low risk. | Add `removeProject(id:)` or equivalent. |
| `NativeSessionIndexStore.swift` | Modified | Must filter/remove sessions by project id. Medium risk. | Add project-id-based operations. |
| `AppShellView.swift` | Modified | Shows stale project state, remove button, and session metadata. Medium risk. | Update project/session rows. |
| `SettingsStore.swift` | Modified | Diagnostic path should point to SQLite DB. Low risk. | Replace `sessionStorePath` label/value. |
| Tests | New/Modified | Existing tests assume JSON shape in places. Medium risk. | Add temp DB unit tests and AppModel/store tests. |

## Testing Approach

### Unit Tests

- `SessionStore` with temporary SQLite database files:
  - creates schema on first load
  - saves and loads projects
  - saves and loads sessions
  - preserves selected project/session ids
  - deduplicates project paths
  - separates local session id from Pi RPC session id
  - handles empty fresh-start DB

- Store-level removal:
  - removing a stale project removes local project record
  - associated local sessions are removed
  - no filesystem content is touched

### Integration Tests

- `AppModel` startup restore:
  - available projects remain visible
  - unavailable projects remain visible as stale
  - selected project/session restores when available
  - stale selected project does not start Pi automatically

- Sidebar behavior:
  - stale project row shows stale state
  - stale project remove action calls AppModel/WorkspaceStore path
  - session row displays title, status, updated time, and resumability

## Development Sequencing

### Build Order

1. Add SQLite-backed `SessionStore` test harness with temporary DB URL support - no dependencies.
2. Add SQLite schema setup and empty load/save behavior - depends on step 1.
3. Update models for local session id and Pi RPC session id separation - depends on step 2.
4. Implement project/session persistence round trips - depends on steps 2 and 3.
5. Update `AppModel` hydration/persistence to use new state semantics - depends on step 4.
6. Replace silent stale-project dropping with computed availability - depends on step 5.
7. Add `WorkspaceStore`/`AppModel` stale project removal - depends on steps 5 and 6.
8. Add sidebar project/session UI metadata and remove action - depends on steps 6 and 7.
9. Update settings diagnostics to show the SQLite store path - depends on step 2.
10. Add AppModel and UI-facing tests for restore, stale state, and remove behavior - depends on steps 5 through 8.

### Technical Dependencies

- macOS system SQLite availability.
- SwiftPM configuration for importing/linking SQLite.
- Temporary database injection for tests.

## Monitoring and Observability

- Log SQLite open/schema failures with store path and operation name.
- Log stale project removal with project id and path, never full session contents.
- Log failed session restore attempts with local session id and Pi RPC session id.
- No alerts are required for the local desktop MVP.

## Technical Considerations

### Key Decisions

- Decision: use system SQLite with a small local wrapper.
  - Rationale: avoids third-party dependency for a narrow persistence feature.
  - Trade-off: more manual SQL and error handling.
  - Alternatives rejected: GRDB, library-agnostic TechSpec, JSON persistence.

- Decision: no legacy JSON migration.
  - Rationale: product has not launched and no real users have existing JSON data.
  - Trade-off: local developer state may start fresh.
  - Alternatives rejected: best-effort JSON import.

- Decision: compute project availability.
  - Rationale: filesystem availability changes outside the app.
  - Trade-off: repeated filesystem checks must remain bounded.
  - Alternatives rejected: persisted availability status.

- Decision: resumability is based on Pi RPC session id presence.
  - Rationale: matches user-selected V1 behavior and avoids preflight file checks.
  - Trade-off: restore can still fail at switch time.

### Known Risks

- Manual SQLite wrapper errors.
  - Mitigation: parameterized statements and focused temp-DB tests.

- Identity regression during local/Pi session id split.
  - Mitigation: add tests for selection, switching, and upsert behavior.

- Stale project UI accidentally mutates filesystem.
  - Mitigation: removal operates only on local stores and tests assert project directory remains.

- PRD/ADR conflict around JSON migration.
  - Mitigation: ADR-004 resolves the TechSpec direction to no migration.

## Architecture Decision Records

- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Establishes local project/session continuity as a durable persistence boundary.
- [ADR-002: Scope PRD to Continuity MVP](adrs/adr-002.md) — Selects focused V1 scope and defers archive/delete workflows.
- [ADR-003: Use System SQLite With Local Store Wrapper](adrs/adr-003.md) — Chooses system SQLite and a small local Swift wrapper.
- [ADR-004: Keep Continuity State Fresh and Computed](adrs/adr-004.md) — Resolves no migration, computed availability, resumability, and removal boundaries.
