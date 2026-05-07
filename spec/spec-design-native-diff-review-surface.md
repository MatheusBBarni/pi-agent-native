---
title: Native Diff Review Surface Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, diff, git, review, macos]
---

# Introduction

This specification defines the first native diff and patch review surface for Pi Agent Native. The goal is to let users inspect current repository changes for the Selected Project, review changed files and diff hunks, and jump to external tools for deeper review without leaving the native workflow.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's Selected Project Git integration, Inspector or review UI, tool-activity refresh behavior, manual Refresh State behavior, and Open Externally integration.

The intended audience is implementation agents and maintainers adding GitHub issue 24: "Add native diff and patch review surface".

In scope:

- Building a Repository Change Snapshot for the Selected Project.
- Listing changed files with added, modified, deleted, renamed, and untracked states when Git reports them.
- Mapping untracked files to an added-style Changed File state for first-version UI.
- Showing diff hunks for a selected Changed File in a native scrollable view.
- Showing empty, loading, unavailable, and error states.
- Refreshing review data after completed agent tool activity.
- Refreshing review data when the user invokes Refresh State.
- Opening the selected file or Selected Project externally for deeper review.
- Tests for Git output mapping, diff hunk parsing, empty repository state, dirty worktree state, and refresh behavior.

Out of scope:

- Staging, unstaging, discarding, applying, or editing patches.
- Commit creation.
- Pull request review.
- Exact attribution of changes to a specific Pi turn or tool call.
- Live filesystem watching.
- Showing non-Git directory diffs.
- Syntax highlighting beyond basic added/removed/context line styling.
- Merge conflict resolution.
- Binary diff rendering beyond a concise binary-file message.

## 2. Definitions

**Selected Project**: The project currently active in Pi Agent Native.

**Selected Session**: The conversation session currently active inside the Selected Project.

**Change Review Surface**: A native surface for inspecting current repository changes in the Selected Project.

**Repository Change Snapshot**: The latest native model of changed files and diff hunks for the Selected Project.

**Changed File**: A file path in a Repository Change Snapshot with a change state such as added, modified, deleted, renamed, or untracked.

**Diff Hunk**: A parsed section of a file diff shown inside the Change Review Surface.

**Open Externally**: An App Action that launches the Selected Project in another app or destination.

**Tool Activity**: First-class UI state representing tool calls and tool execution reported by Pi RPC.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall provide a Change Review Surface for the Selected Project.
- **REQ-002**: The Change Review Surface shall show repository changes for the current Selected Project.
- **REQ-003**: The first implementation shall use Git as the source of Repository Change Snapshot data.
- **REQ-004**: If no Selected Project exists, the Change Review Surface shall show an unavailable state.
- **REQ-005**: If the Selected Project is not a Git repository, the Change Review Surface shall show a not-a-repository state.
- **REQ-006**: If the Selected Project is a Git repository with no changes, the Change Review Surface shall show an empty state.
- **REQ-007**: The Changed File list shall include files reported as added.
- **REQ-008**: The Changed File list shall include files reported as modified.
- **REQ-009**: The Changed File list shall include files reported as deleted.
- **REQ-010**: The Changed File list shall include files reported as renamed when Git reports rename metadata.
- **REQ-011**: The Changed File list shall include untracked files and display them as added-style changes.
- **REQ-012**: A Changed File shall use workspace-relative POSIX paths.
- **REQ-013**: A renamed Changed File shall store both current path and original path.
- **REQ-014**: The Changed File list shall show a compact status marker for each file.
- **REQ-015**: The Changed File list shall preserve a deterministic order from Git status output or a documented stable sort.
- **REQ-016**: Selecting a Changed File shall show its diff hunks in a native scrollable view.
- **REQ-017**: The Diff Hunk view shall preserve hunk headers.
- **REQ-018**: The Diff Hunk view shall distinguish added, removed, context, and metadata lines.
- **REQ-019**: The Diff Hunk view shall support text selection.
- **REQ-020**: Binary files shall show a concise binary-file message instead of raw binary content.
- **REQ-021**: Deleted files shall show removed lines when Git provides them.
- **REQ-022**: Added tracked files shall show added lines when Git provides them.
- **REQ-023**: Untracked text files may show a synthesized added-file diff when bounded and readable, or a clear "not yet tracked" message when not rendered.
- **REQ-024**: The first implementation shall not read arbitrarily large untracked files into memory for diff display.
- **REQ-025**: The app shall refresh the Repository Change Snapshot when the user invokes Refresh State.
- **REQ-026**: The app shall refresh the Repository Change Snapshot after completed agent tool activity.
- **REQ-027**: Tool-activity refresh shall be debounced or coalesced so a burst of tool events does not launch excessive Git processes.
- **REQ-028**: The app shall refresh the Repository Change Snapshot after agent end, preserving the existing refresh behavior.
- **REQ-029**: The app shall refresh the Repository Change Snapshot when the Selected Project changes.
- **REQ-030**: Repository Change Snapshot loads shall run off the main actor.
- **REQ-031**: A completed snapshot load shall apply only if the Selected Project path still matches the request that started the load.
- **REQ-032**: Git command failures shall be surfaced as lightweight unavailable/error state and process log detail, not as blocking modals.
- **REQ-033**: The Change Review Surface shall offer a clear path to open the selected file externally when the file exists.
- **REQ-034**: The Change Review Surface shall offer a clear path to open the Selected Project externally.
- **REQ-035**: External open behavior shall use the existing Open Externally / External Target infrastructure where possible.
- **REQ-036**: Opening a file or project externally shall not change Selected Project, Selected Session, conversation messages, composer text, streaming state, or the Repository Change Snapshot.
- **REQ-037**: The first implementation shall not allow staging, unstaging, discarding, applying, or editing changes.
- **REQ-038**: The Change Review Surface shall not parse process-log text or tool stdout to determine repository changes.
- **REQ-039**: The Change Review Surface shall not claim exact Pi-turn attribution for changes in the first slice.
- **REQ-040**: The existing Inspector branch summary may continue to show the compact dirty count, but it shall be backed by or kept consistent with the Repository Change Snapshot refresh path.
- **CON-001**: Git is the only repository backend in the first implementation.
- **CON-002**: The first implementation is inspect-only.
- **CON-003**: Live filesystem watching is out of scope.
- **CON-004**: Exact attribution to a Pi session or tool call is out of scope.
- **CON-005**: The UI must remain usable when no repository changes exist.
- **GUD-001**: Prefer extending `GitService` rather than adding ad hoc Git commands in SwiftUI views.
- **GUD-002**: Prefer a split layout: changed-file list on one side and diff hunks on the other.
- **GUD-003**: Keep the review surface visually denser than a marketing page; this is an inspection workflow.
- **PAT-001**: Separate Git command execution, status parsing, diff parsing, snapshot state, and SwiftUI rendering.

## 4. Interfaces & Data Contracts

### Git Commands

The first implementation should use these Git commands or equivalents:

```text
git status --porcelain=v1 -z
git diff --find-renames --no-ext-diff --no-color --unified=3 HEAD -- <path>
```

Rules:

- Run Git commands with the Selected Project as current directory.
- Do not invoke shell interpolation; pass arguments as an array to `Process`.
- Use `--porcelain=v1 -z` or an equivalently parseable status format.
- Use `HEAD` as the first-version baseline for tracked changes so staged and unstaged tracked changes are visible together.
- Treat `??` entries as untracked and display them as added-style Changed Files.
- If `HEAD` is unavailable, fall back to status-only Changed File listing and show a clear diff unavailable message.

### Conceptual Models

The implementation should expose data structures equivalent to:

```swift
struct RepositoryChangeSnapshot: Equatable {
    let projectPath: String
    let branch: String
    let files: [ChangedFile]
    let loadedAt: Date
    let status: RepositoryChangeSnapshotStatus
}

enum RepositoryChangeSnapshotStatus: Equatable {
    case unavailable(reason: String)
    case notRepository
    case clean
    case dirty
    case loading
    case failed(message: String)
}

struct ChangedFile: Identifiable, Equatable {
    let id: String
    let path: String
    let originalPath: String?
    let state: ChangedFileState
    let indexStatus: GitFileStatus?
    let worktreeStatus: GitFileStatus?
    let isBinary: Bool
    var hunks: [DiffHunk]
    var diffStatus: DiffLoadStatus
}

enum ChangedFileState: Equatable {
    case added
    case modified
    case deleted
    case renamed
    case untracked
}

enum GitFileStatus: String, Equatable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case unmerged
    case untracked
}

enum DiffLoadStatus: Equatable {
    case notLoaded
    case loading
    case loaded
    case unavailable(message: String)
    case failed(message: String)
}

struct DiffHunk: Identifiable, Equatable {
    let id: String
    let header: String
    let oldStart: Int?
    let oldCount: Int?
    let newStart: Int?
    let newCount: Int?
    let lines: [DiffLine]
}

struct DiffLine: Identifiable, Equatable {
    let id: String
    let kind: DiffLineKind
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let text: String
}

enum DiffLineKind: Equatable {
    case metadata
    case hunkHeader
    case context
    case addition
    case deletion
}
```

Exact names may differ, but the implementation must preserve these concepts.

### Status Mapping

| Git status | Changed File state |
|---|---|
| `A` in index or worktree | added |
| `M` in index or worktree | modified |
| `D` in index or worktree | deleted |
| `R` in index | renamed |
| `??` | untracked |
| unmerged states | modified with an unavailable/conflict note, unless a later implementation adds conflict-specific UI |

If both index and worktree statuses exist, choose the most user-visible state in this order for the first badge: renamed, deleted, added, modified, untracked. Preserve raw index and worktree status fields for detail text and tests.

### Diff Parsing

The diff parser shall:

- Treat lines beginning with `diff --git`, `index`, `new file mode`, `deleted file mode`, `rename from`, `rename to`, `---`, and `+++` as metadata lines outside hunks or metadata lines attached to the next hunk.
- Treat lines beginning with `@@` as hunk headers and parse old/new ranges when possible.
- Treat lines beginning with `+` but not `+++` as additions.
- Treat lines beginning with `-` but not `---` as deletions.
- Treat lines beginning with a single space as context.
- Treat `\ No newline at end of file` as metadata.
- Preserve original line text after the diff prefix for display.

### View Placement

The first implementation should place the Change Review Surface in the Inspector or as an Inspector-adjacent modal/sheet opened from the Inspector. It must remain discoverable from the normal shell when a Selected Project exists.

Recommended first slice:

- Add a "Changes" Inspector card with changed-file count and a Review button.
- Open a native review sheet or panel containing the file list and hunk viewer.
- Keep the compact existing Branch details metrics for branch and dirty count.

This placement can change if a broader shell navigation surface exists, but the first slice must not hide review behind process logs.

## 5. Acceptance Criteria

- **AC-001**: Given no Selected Project exists, When the Change Review Surface is opened or rendered, Then it shows an unavailable state asking the user to open a project.
- **AC-002**: Given the Selected Project is not a Git repository, When changes are refreshed, Then the surface shows a not-a-repository state.
- **AC-003**: Given the Selected Project is a clean Git repository, When changes are refreshed, Then the surface shows an empty state and no stale Changed Files.
- **AC-004**: Given a file is added, When changes are refreshed, Then the Changed File list shows that file with added state.
- **AC-005**: Given a file is modified, When changes are refreshed, Then the Changed File list shows that file with modified state.
- **AC-006**: Given a file is deleted, When changes are refreshed, Then the Changed File list shows that file with deleted state.
- **AC-007**: Given a file is renamed and Git reports rename metadata, When changes are refreshed, Then the Changed File list shows renamed state and both original and current paths.
- **AC-008**: Given an untracked file exists, When changes are refreshed, Then the Changed File list shows it as an added-style change.
- **AC-009**: Given a Changed File is selected, When its diff is loaded, Then the native hunk view shows hunk headers and added, removed, and context lines distinctly.
- **AC-010**: Given a binary changed file is selected, When its diff is loaded, Then the hunk area shows a concise binary-file message rather than raw binary content.
- **AC-011**: Given the user invokes Refresh State, When Git state changed since the previous snapshot, Then the Repository Change Snapshot updates.
- **AC-012**: Given an agent tool execution completes after modifying files, When the debounced refresh runs, Then the Repository Change Snapshot updates.
- **AC-013**: Given an agent run ends, When existing refresh behavior runs, Then branch details and Repository Change Snapshot are both refreshed.
- **AC-014**: Given the Selected Project changes while a snapshot load is in flight, When the old load completes, Then the old snapshot is ignored.
- **AC-015**: Given a Changed File exists on disk, When the user chooses to open it externally, Then the app opens the file or containing project through an existing external-open path.
- **AC-016**: Given the user opens the Selected Project externally from the review surface, Then the existing Open Externally behavior is used and app conversation state is unchanged.
- **AC-017**: Given the user inspects changes, Then no staging, unstaging, discard, apply, or commit controls are present in the first slice.
- **AC-018**: Given Git command execution fails, Then the surface shows a lightweight error and process log detail without a blocking modal.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for status parsing, diff parsing, service output mapping, snapshot state transitions, and refresh invalidation; AppModel tests for refresh trigger wiring where practical; manual UI smoke tests for hunk view layout.
- **Frameworks**: Swift XCTest in existing SwiftPM test targets.
- **Test Data Management**: Prefer parser tests with fixture strings for porcelain status and unified diff output. Add integration-style temporary Git repository tests only where process execution behavior matters and Git is available.
- **Coverage Requirements**: Tests must cover clean status output, added, modified, deleted, renamed, untracked, binary diff output, hunk range parsing, no-newline metadata, failed Git command mapping, Selected Project change during async refresh, manual refresh, and tool-completion refresh scheduling.
- **Performance Testing**: Add a bounded test or assertion for untracked file preview limits if the implementation synthesizes untracked-file diffs. No large-repo load test is required in the first slice.

Suggested focused test files:

- `Tests/PiAgentNativeCoreTests/GitStatusParserTests.swift`
- `Tests/PiAgentNativeCoreTests/GitDiffParserTests.swift`
- `Tests/PiAgentNativeCoreTests/RepositoryChangeSnapshotTests.swift`
- `Tests/PiAgentNativeTests/ChangeReviewRefreshTests.swift`

## 7. Rationale & Context

Issues #6 and #7 introduced structured conversation and tool activity, which makes it possible for Pi Agent Native to show richer post-run context. Issue 24 should not depend on parsing tool output to discover files, though. The current app already has Git branch and dirty-count display through `GitService`, and the reducer refreshes state when an agent run ends. Extending this into a Repository Change Snapshot keeps the review surface grounded in the repository state users actually need to review.

The first slice is inspect-only because staging, discarding, applying patches, and commit flows are higher-risk actions. They require separate user-confirmation and safety design. Opening external tools gives users an escape hatch for deeper review without expanding this issue into a full Git client.

The first slice also avoids exact attribution to a Pi session or tool call. The issue asks for changes produced during Pi sessions, but the reliable first behavior is to show the current Selected Project repository changes after agent tools and refreshes. Attribution can be layered later once session/tool-to-file provenance exists.

No ADR is required because the design extends the existing GitService and Inspector/tool-activity architecture without a hard-to-reverse architectural commitment.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Git command-line interface - Required to read status and diff data for the Selected Project.
- **EXT-002**: Local filesystem - Required to determine file existence and optionally synthesize bounded untracked-file previews.
- **EXT-003**: macOS external opening - Required to open files or projects for deeper review.

### Infrastructure Dependencies

- **INF-001**: Existing `GitService` - Should be extended to provide Repository Change Snapshot data.
- **INF-002**: Existing `AppModel.refreshState()` flow - Required for manual and agent-end refresh.
- **INF-003**: Existing `ToolActivityStore` and Pi RPC reducer - Required to trigger refresh after completed tool activity.
- **INF-004**: Existing Open Externally infrastructure - Required for external review paths.

### Technology Platform Dependencies

- **PLT-001**: SwiftUI - Required for native list, split, and scrollable hunk views.
- **PLT-002**: AppKit/Process - Required for safe Git process execution.

## 9. Examples & Edge Cases

### Porcelain Status Mapping

```text
 M Sources/App.swift
A  Sources/NewView.swift
D  Sources/OldView.swift
R  Sources/Before.swift -> Sources/After.swift
?? Notes.txt
```

Expected Changed Files:

```text
modified Sources/App.swift
added Sources/NewView.swift
deleted Sources/OldView.swift
renamed Sources/After.swift original=Sources/Before.swift
untracked Notes.txt shown as added-style
```

### Diff Hunk

```diff
@@ -10,2 +10,3 @@ struct Example
 let oldValue = 1
-let name = "old"
+let name = "new"
+let enabled = true
```

Expected line kinds:

```text
hunkHeader @@ -10,2 +10,3 @@ struct Example
context    let oldValue = 1
deletion   let name = "old"
addition   let name = "new"
addition   let enabled = true
```

### Non-Repository

```text
Selected Project: /tmp/not-a-git-folder
Snapshot status: notRepository
Changed Files: []
Review surface: "No Git repository found for this project."
```

## 10. Validation Criteria

- `swift test` passes.
- `git diff --check` reports no whitespace errors.
- Status parsing tests cover added, modified, deleted, renamed, and untracked states.
- Diff parsing tests cover hunk headers, additions, deletions, context, metadata, and binary/unavailable output.
- Refresh behavior tests prove manual refresh and completed tool activity request a snapshot update.
- Selected Project change protection prevents stale snapshots from applying.
- Manual UI smoke testing confirms a dirty repository displays file list and hunk content in a scrollable native view.

## 11. Related Specifications / Further Reading

- [Inspector Pane Toggle Design](./spec-design-inspector-pane-toggle.md)
- [Header Control App Action Design](./spec-design-header-actions.md)
- [Open Externally Design](./spec-design-open-externally.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 6: Architecture: Conversation domain](https://github.com/MatheusBBarni/pi-agent-native/issues/6)
- [GitHub issue 7: Architecture: Tool activity as first-class UI](https://github.com/MatheusBBarni/pi-agent-native/issues/7)
