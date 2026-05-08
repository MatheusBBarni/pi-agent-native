# PRD: Project Session Continuity

## Overview

Pi Agent Native should reliably restore the user's known projects and per-project sessions after app restart. The feature is for end users who open local project folders, create Pi sessions inside those projects, and expect the native app to remember where they were.

V1 focuses on continuity, not full project/session management. Users should reopen the app and see the same project list, the sessions under each project, minimal session metadata, and clear stale-project states when a previously opened project path is no longer available.

## Goals

- Restore known projects and sessions after app restart with >= 99% project-list continuity in normal use.
- Restore the selected project and selected session when both remain available.
- Show unavailable project paths as stale rather than silently hiding them.
- Let users remove stale projects from the app's local project list.
- Show minimal session metadata so users can choose the right session without inspecting logs.

## User Stories

- As a user returning to Pi Agent Native, I want my opened projects to reappear after restart so I can continue work without reopening folders manually.
- As a user with multiple sessions in one project, I want to see each session's title, status, last updated time, and resumability so I can select the right session.
- As a user whose project folder was moved or deleted, I want the app to show that the project is unavailable so I understand why it cannot be resumed.
- As a user with stale projects, I want to remove unavailable projects from the app list so my sidebar stays useful.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Project Restore | Critical | On app launch, show known projects from local app state with their name, path, and current availability status. |
| F2 | Session Restore | Critical | Show known sessions under each restored project, preserving title, status, last updated time, and resumability state. |
| F3 | Selected Context Restore | High | Restore the last selected project and session when they are still available and resumable. |
| F4 | Stale Project State | High | If a project path is unavailable, keep it visible with a stale/unavailable status instead of silently removing it. |
| F5 | Remove Stale Project | High | Let users remove stale projects from the app's local list. This must not delete files from disk. |
| F6 | Fresh Persistence Start | Medium | The new persistence model starts fresh; old JSON state is not required to migrate into V1. |

## User Experience

1. User opens Pi Agent Native.
2. The sidebar shows the known projects from local app state.
3. Available projects behave normally and can show their sessions.
4. The last selected project and session are selected when still available.
5. Each session row shows title, status, last updated time, and whether it can be resumed.
6. If a project path is unavailable, the project remains visible with a stale state.
7. A stale project exposes a remove action.
8. Removing a stale project removes only the app's local record, never the folder or files on disk.

UX requirements:
- Stale status must be visually clear and accessible.
- Remove actions must use explicit wording that avoids implying filesystem deletion.
- Session metadata must fit existing sidebar density.
- Empty states should explain whether there are no projects, no sessions, or only unavailable projects.

## High-Level Technical Constraints

- Project/session continuity must remain local to the user's machine.
- Project names, paths, session titles, and session metadata may reveal sensitive work context and should not be exposed outside local app state.
- The app must distinguish local app session identity from Pi runtime session identity at the product-contract level.
- Startup restore should feel fast enough that users do not perceive project/session continuity as a loading step.

## Non-Goals (Out of Scope)

- Migrating existing `sessions.json` data into the new persistence model.
- Archiving projects.
- Archiving sessions.
- Deleting valid project records through configuration.
- Deleting valid session records through configuration.
- Search, filtering, tags, favorites, or grouped recent-project management.
- Cloud sync or cross-device session continuity.
- Session summaries, cost, message count, model, branch, or rich history metadata.

## Phased Rollout Plan

### MVP (Phase 1)

- Restore known projects after restart.
- Restore known sessions under projects.
- Restore selected project/session when available.
- Show stale project state.
- Allow stale project removal.
- Show minimal session metadata.

Success criteria:
- >= 99% project-list restore success across restart in normal use.
- >= 95% selected context restore success when project and session are still available.
- 0 cases where stale project removal deletes files from disk.

### Phase 2

- Add archive project and archive session workflows.
- Add configuration-level delete project and delete session actions.
- Add clearer management affordances for valid but unwanted records.

Success criteria:
- Users can clean up active records without confusing archive, delete, and filesystem deletion.

### Phase 3

- Add richer session discovery such as search, summaries, filters, or project grouping.
- Evaluate launchpad-style recent project/session entry points.

Success criteria:
- Users with many projects can find the right project/session quickly without cluttering the core sidebar.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Project restore success | >= 99% | Projects shown after restart match local app state for available paths. |
| Selected context restore success | >= 95% | Last selected available project/session is restored after restart. |
| Stale project clarity | >= 90% | User testing participants correctly identify unavailable projects. |
| Stale removal safety | 100% | Removing stale projects never deletes filesystem content. |
| Time to visible continuity | < 5 seconds | App launch to visible project/session list on typical local data. |

## Risks and Mitigations

- Users may expect old JSON state to appear after the change.
  - Mitigation: clearly communicate that V1 starts fresh if existing state is not carried forward.

- Stale projects may clutter the sidebar.
  - Mitigation: stale projects include a remove action in V1.

- Users may confuse removing a stale project with deleting project files.
  - Mitigation: use explicit copy: remove from Pi Agent Native, not delete from disk.

- Minimal session metadata may be insufficient for users with many sessions.
  - Mitigation: defer richer session discovery to Phase 3 after continuity is validated.

- Competitors already support recent projects and session restore.
  - Mitigation: focus V1 on trust and correctness, then build richer project/session management in later phases.

## Architecture Decision Records

- [ADR-001: Use SQLite for Project and Session Continuity](adrs/adr-001.md) — Establishes local project/session continuity as a durable persistence boundary.
- [ADR-002: Scope PRD to Continuity MVP](adrs/adr-002.md) — Selects the focused V1 product scope and defers archive/delete management.

## Open Questions

- Should V1 include a user-facing note that previous JSON-backed project/session state starts fresh.
- Should stale projects appear in normal sort order, at the bottom, or in a separate unavailable group.
- What exact session statuses should be user-facing in V1.
