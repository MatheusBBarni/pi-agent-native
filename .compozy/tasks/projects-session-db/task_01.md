---
status: pending
title: Add SQLite Store Harness and Schema Bootstrap
type: backend
complexity: high
dependencies: []
---

# Task 1: Add SQLite Store Harness and Schema Bootstrap

## Overview
This task establishes the SQLite persistence foundation for project/session continuity. It replaces the JSON file foundation with a system SQLite-backed store harness that can create an empty database safely and run against temporary database files in tests.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-001: The core target MUST link/import Apple system SQLite without adding a third-party SQLite package.
- REQ-002: `SessionStore` MUST expose a SQLite database URL under the Pi Agent Native application support directory.
- REQ-003: `SessionStore` MUST support temporary database URL injection for tests without touching the real user app support store.
- REQ-004: First load against an absent database MUST create the required schema and return empty persisted state.
- REQ-005: Store initialization failures MUST fail closed to empty persisted state and produce diagnosable errors/log context where the existing architecture permits.
</requirements>

## Subtasks
- [ ] 1.1 Add system SQLite linkage/import support to the Swift package.
- [ ] 1.2 Replace the JSON store bootstrap with a SQLite database bootstrap path.
- [ ] 1.3 Add schema creation for the project/session continuity tables.
- [ ] 1.4 Add a temporary database harness for tests.
- [ ] 1.5 Add focused tests for empty database creation and schema bootstrap.

## Implementation Details
Modify `Package.swift` and `Sources/PiAgentNative/SessionStore.swift`. Create `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift` for low-level store behavior. Follow the TechSpec "Core Interfaces" and "Data Models" sections, but do not implement full project/session persistence until task 03.

### Relevant Files
- `Package.swift` — defines target dependencies and linker settings.
- `Sources/PiAgentNative/SessionStore.swift` — current JSON persistence boundary to replace.
- `Tests/PiAgentNativeCoreTests/SessionStoreTests.swift` — new focused store test file.

### Dependent Files
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — later consumes the new store URL.
- `Sources/PiAgentNative/AppModel.swift` — later consumes the SQLite-backed `load`/`save` behavior.

### Related ADRs
- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Establishes SQLite as the persistence boundary.
- [ADR-003: Use System SQLite With Local Store Wrapper](adrs/adr-003.md) — Requires system SQLite and a small local wrapper.

## Deliverables
- System SQLite linkage/import support for `PiAgentNativeCore`.
- SQLite-backed `SessionStore` bootstrap with schema creation.
- Test-only temporary database support.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for store bootstrap path **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Fresh temporary DB path: `SessionStore.load()` creates schema and returns empty state.
  - [ ] Existing empty DB path: repeated `load()` does not recreate or corrupt schema.
  - [ ] Invalid parent path or open failure returns empty state without crashing.
  - [ ] Store URL points to application support and ends with the SQLite database filename.
- Integration tests:
  - [ ] SwiftPM can build and link `PiAgentNativeCore` with system SQLite.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `rtk swift test --filter SessionStoreTests` passes for bootstrap scenarios.
- No third-party SQLite dependency is added.
