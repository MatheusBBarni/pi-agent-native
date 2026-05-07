---
title: File Mention Picker Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, composer, mentions, macos]
---

# Introduction

This specification defines the first-version `@` file mention picker for Pi Agent Native. The goal is to let a user search project files and folders from the composer and insert an editable plain-text reference into the prompt.

## 1. Purpose & Scope

This specification applies to the Pi Agent Native macOS composer, selected-project file indexing, local picker interaction, and prompt text insertion.

The intended audience is implementation agents and maintainers adding GitHub issue 1: "Implement @ file add picker".

In scope:

- Detecting active `@` mention queries in the composer.
- Building and refreshing a searchable mention index for the selected project.
- Showing a compact suggestion surface above the composer.
- Searching files and folders by display name and workspace-relative path.
- Keyboard and pointer selection.
- Inserting editable plain-text file mentions into the composer.
- Sending mentions as ordinary prompt text through the existing RPC command.

Out of scope:

- Structured attachments.
- Rich inline mention rendering.
- RPC payload changes.
- Live filesystem watching.
- Persisting the mention index between app launches.
- Mentioning files outside the selected project.
- User configuration for include or exclude rules.

## 2. Definitions

**Selected Project**: The project currently active in Pi Agent Native.

**Composer**: The text input surface where the user writes a prompt.

**File Mention**: An editable plain-text reference to a file or folder inside the Selected Project that the user inserts into the composer.

**Mention Picker**: A composer suggestion surface that helps the user insert a File Mention.

**Mention Query**: The active text range beginning with `@` that drives Mention Picker search.

**Mention Index**: The app-session cache of searchable file and folder paths for a Selected Project.

**Display Name**: The last path component shown as the primary label for a Mention Picker result.

**Workspace-Relative Path**: A POSIX path relative to the Selected Project root.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall open the Mention Picker when the user types an `@` that starts a Mention Query.
- **REQ-002**: The app shall treat `@` as the start of a Mention Query only at the beginning of composer text, after whitespace, or after an opening delimiter.
- **REQ-002A**: Opening delimiters for Mention Query activation are `(`, `[`, `{`, `<`, single quote, and double quote.
- **REQ-003**: The app shall keep the Mention Query active only while the cursor remains in the query range and the query contains no whitespace.
- **REQ-003A**: The app shall close the Mention Picker when the composer selection is not a collapsed insertion point.
- **REQ-003B**: When composer text contains multiple eligible `@` characters, the active Mention Query is the nearest eligible query start before the collapsed cursor whose range contains the cursor.
- **REQ-004**: The app shall not open the Mention Picker for email-like or embedded `@` text such as `me@example.com`.
- **REQ-005**: The app shall search files and folders under the Selected Project.
- **REQ-006**: The app shall not open the Mention Picker when there is no Selected Project.
- **REQ-007**: The Mention Index shall exclude noisy generated, dependency, and hidden paths by default.
- **REQ-008**: The default excluded paths shall include `.git/`, `.build/`, `DerivedData/`, `node_modules/`, `.DS_Store`, and hidden paths unless the query starts with `.`.
- **REQ-008A**: Hidden-path handling shall be query-aware: `.git/`, `.build/`, `DerivedData/`, `node_modules/`, and `.DS_Store` are hard exclusions; other hidden entries may be kept in the session index with an `isHidden` flag, or loaded through a separate dot-query scan, but must not appear for non-dot queries.
- **REQ-009**: When the Selected Project is a Git repository, the Mention Index shall prefer Git-tracked and Git-unignored paths.
- **REQ-010**: When Git is unavailable or the Selected Project is not a Git repository, the Mention Index shall fall back to recursive filesystem scanning with default exclusions.
- **REQ-011**: The Mention Index shall be built lazily the first time the Mention Picker opens for the current Selected Project.
- **REQ-012**: The Mention Index shall be cached per selected project path for the current app session.
- **REQ-013**: The Mention Index shall be rebuilt when the Selected Project changes.
- **REQ-014**: The Mention Index shall be rebuilt when the user invokes refresh state.
- **REQ-015**: The Mention Index shall include in-project symlink entries.
- **REQ-016**: The Mention Index shall not recursively follow directory symlinks.
- **REQ-017**: Before insertion, the app shall resolve the selected path and verify that it remains inside the Selected Project root.
- **REQ-018**: Mention Picker results shall match by display name and workspace-relative path.
- **REQ-018A**: Mention Picker matching shall be case-insensitive.
- **REQ-019**: Mention Picker results shall be capped at 12 visible results.
- **REQ-020**: Mention Picker ranking shall prioritize exact display-name prefix, display-name substring, path prefix, and path substring, in that order.
- **REQ-021**: When scores tie, Mention Picker ranking shall prefer shorter paths, then case-insensitive alphabetical workspace-relative path.
- **REQ-022**: Folders shall be preferred over files only when result scores otherwise tie.
- **REQ-022A**: An empty Mention Query shall show up to 12 eligible project entries after default exclusions, preferring root-level and shorter paths before case-insensitive alphabetical workspace-relative path.
- **REQ-023**: The Mention Picker shall appear as a compact overlay directly above the composer input area.
- **REQ-024**: The Mention Picker shall align to the composer leading edge and match the composer content area's width.
- **REQ-025**: Each Mention Picker row shall show the display name on the left and the workspace-relative path on the right.
- **REQ-026**: The highlighted Mention Picker row shall use the app's accent or selection treatment.
- **REQ-027**: The Mention Picker shall show one disabled row for empty, no-match, or unavailable states.
- **REQ-028**: While the Mention Picker is open, Up and Down shall move the highlighted result.
- **REQ-029**: While the Mention Picker is open, Return and Tab shall insert the highlighted result.
- **REQ-030**: While the Mention Picker is open, Escape shall close the picker without changing composer text.
- **REQ-030A**: The composer shall consume only picker-owned key events while the Mention Picker is open: unmodified Up, unmodified Down, Escape, unmodified Return, keypad Return, and unmodified Tab. Modifier-key variants such as Option-Up, Command-Down, Shift-Return, and Shift-Tab shall fall through to existing text-view or app behavior unless explicitly owned by the picker in a later issue.
- **REQ-031**: Pointer hover shall update the highlighted row.
- **REQ-032**: Pointer click shall insert the clicked row.
- **REQ-032A**: Disabled status rows shall not be hover-highlightable or insertable.
- **REQ-033**: Inserting a File Mention shall replace only the active Mention Query range.
- **REQ-034**: File mentions shall be inserted as `@` plus the workspace-relative path plus one trailing space.
- **REQ-035**: Folder mentions shall end with a trailing slash before the trailing space.
- **REQ-036**: Paths with spaces shall remain literal plain text in the first version.
- **REQ-037**: The existing prompt RPC command shall continue sending a single string `message` value.
- **REQ-038**: File Mentions shall be sent as part of the prompt text and not as separate RPC attachments.
- **CON-001**: The implementation must not introduce structured attachments for this issue.
- **CON-002**: The implementation must not change the pi RPC prompt payload for this issue.
- **CON-003**: The implementation must not add live filesystem watching for this issue.
- **CON-004**: Standard macOS text editing gestures must remain owned by the text view.
- **CON-005**: Mention Picker navigation is local composer interaction and is not part of the Default Keymap.
- **GUD-001**: Prefer SwiftUI for picker presentation and AppKit text-view hooks for selection range and key event handling.
- **GUD-002**: Keep path scanning off the main actor when it can touch many filesystem entries.
- **PAT-001**: Keep Mention Query detection separate from result ranking and insertion so each behavior can be unit-tested independently.

## 4. Interfaces & Data Contracts

The existing prompt RPC contract remains unchanged:

```json
{
  "id": "request-id",
  "type": "prompt",
  "message": "Review @Sources/PiAgentNative/PiRPCClient.swift "
}
```

The implementation should expose conceptual data structures equivalent to the following:

```swift
struct MentionQuery: Equatable {
    let range: Range<String.Index>
    let rawText: String
    let searchText: String
}

struct MentionIndexEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let relativePath: String
    let isDirectory: Bool
    let isSymlink: Bool
    let isHidden: Bool
    let resolvedURL: URL
}

struct MentionSearchResult: Identifiable, Equatable {
    let entry: MentionIndexEntry
    let score: Int
    let displayNameMatched: Bool
}

struct MentionPickerState: Equatable {
    let query: MentionQuery
    let results: [MentionSearchResult]
    let highlightedResultID: MentionSearchResult.ID?
    let status: MentionPickerStatus
}

enum MentionPickerStatus: Equatable {
    case ready
    case indexing
    case noMatches
    case unavailable
}
```

Required components:

| Component | Responsibility |
|---|---|
| Mention query detector | Find the active `@` query based on composer text and cursor position. |
| Mention index provider | Build, cache, invalidate, and refresh project path entries. |
| Mention searcher | Filter, rank, and cap results for the current query. |
| Mention picker view | Render rows, highlight state, empty states, pointer hover, and click insertion. |
| Composer event bridge | Route Up, Down, Return, Tab, and Escape to the picker only while it is open. |
| Composer selection bridge | Expose the AppKit text view cursor/selection range to SwiftUI state and safely convert between `NSRange` and `String.Index` ranges before query replacement. |
| Mention inserter | Replace the active query range with the selected plain-text File Mention. |

Implementation notes:

- Bridge AppKit selection with `NSRange`/UTF-16 offsets at the `NSTextView` boundary, and convert to Swift `String.Index` only inside the query detector/inserter. This avoids corrupting ranges for non-ASCII prompt text.
- Route picker keyboard handling before the existing `SubmitTextView` Return and Shift-Tab handling, then fall through to `super.keyDown(with:)` for all non-picker events.
- Perform mention insertion through the `NSTextView` text storage/editing APIs so undo, redo, selection, and scroll position remain consistent; do not replace the whole SwiftUI binding string for insertion when a narrower text-view replacement is available.
- Keep index construction outside the main actor. Return immutable entries to the `@MainActor` app state only after a project-path check confirms the selected project has not changed.
- Prefer `git ls-files -co --exclude-standard` for Git repositories, then supplement directory entries from filesystem enumeration so folders can appear as results.
- Use `URL.standardizedFileURL` and `resolvingSymlinksInPath()` for both the selected-project root and selected result before root containment checks. Compare path components, not string prefixes, so `/repo-other` does not pass as inside `/repo`.

Insertion format:

| Entry type | Inserted text |
|---|---|
| File | `@path/to/file.ext ` |
| Folder | `@path/to/folder/ ` |

### Implementation Handoff Notes

- Keep Mention Query detection, search ranking, path insertion, and project-root safety in pure Swift types where practical so they can be covered by XCTest without launching the app.
- The composer bridge must expose both text changes and the current selection range. Picker commands should be routed before the existing submit behavior only while the Mention Picker is open; when closed, standard text editing and the existing Return / Shift-Return / Shift-Tab behavior must remain unchanged.
- Treat non-collapsed composer selections as no active Mention Query for the first version. The picker should derive its active query from the collapsed cursor, not from arbitrary selected text.
- Hidden path behavior needs an explicit model. `.git/`, `.build/`, `DerivedData/`, `node_modules/`, and `.DS_Store` should stay excluded, but other hidden entries should either be indexed with an `isHidden` flag or loaded through an `includeHidden` index path so queries beginning with `.` can show valid hidden results.
- For Git repositories, prefer `git ls-files --cached --others --exclude-standard` or equivalent Git-aware enumeration for file entries, then derive visible folder entries from those paths. If Git enumeration fails, fall back to filesystem scanning with the same default exclusions.
- Empty `@` queries should not be treated as an error state. They should show the initial capped result set described by `REQ-022A`, while a non-empty query with no matches should show the disabled no-match row.
- Disabled status rows are display-only. They should never become the highlighted selectable result and should never trigger insertion through keyboard or pointer events.
- Indexing should run off the main actor and apply results only if the Selected Project path still matches the request that started the index build. Selected Project changes, Refresh State, and index failures must not leave stale picker rows visible.
- Project-root safety must compare resolved path components, not raw string prefixes, so paths such as `/project-other` are not mistaken for descendants of `/project`.
- Directory symlinks may appear as entries, but recursive scanning must not descend into them. Insertion is allowed only when the resolved selected path stays inside the Selected Project.
- The picker overlay should not be clipped by the composer container. It should stay aligned with the composer input leading edge and remain usable at narrow window widths.

## 5. Acceptance Criteria

- **AC-001**: Given a Selected Project exists and the composer is focused, When the user types `@`, Then the Mention Picker opens above the composer.
- **AC-002**: Given composer text is `Review @pi` and the cursor is after `pi`, When matching paths exist, Then the Mention Picker shows matching files and folders.
- **AC-003**: Given composer text is `me@example.com`, When the cursor is in or after that email-like text, Then the Mention Picker does not open.
- **AC-004**: Given no Selected Project exists, When the user types `@`, Then the Mention Picker does not open.
- **AC-005**: Given the Selected Project is a Git repository, When the Mention Index is built, Then ignored build output is not suggested.
- **AC-006**: Given Git is unavailable, When the Mention Index is built, Then the app falls back to recursive filesystem scanning with default exclusions.
- **AC-007**: Given the Mention Picker is open, When the user presses Down, Then the highlighted result moves to the next result.
- **AC-008**: Given the Mention Picker is open, When the user presses Up, Then the highlighted result moves to the previous result.
- **AC-009**: Given a result is highlighted, When the user presses Return or Tab, Then the active Mention Query is replaced with the selected File Mention.
- **AC-010**: Given the Mention Picker is open, When the user presses Escape, Then the picker closes and composer text remains unchanged.
- **AC-011**: Given the pointer hovers a result row, When the row is hover-active, Then that row becomes highlighted.
- **AC-012**: Given the user clicks a result row, When the result resolves inside the Selected Project, Then the result is inserted as a File Mention.
- **AC-012A**: Given the Mention Picker is showing an unavailable, indexing, or no-match status row, When the user presses Return, Tab, or clicks the row, Then no File Mention is inserted.
- **AC-013**: Given a selected file path is `Sources/PiAgentNative/PiRPCClient.swift`, When inserted, Then composer text contains `@Sources/PiAgentNative/PiRPCClient.swift `.
- **AC-014**: Given a selected folder path is `Sources/PiAgentNative`, When inserted, Then composer text contains `@Sources/PiAgentNative/ `.
- **AC-015**: Given a selected symlink resolves outside the Selected Project, When insertion is attempted, Then no File Mention is inserted.
- **AC-016**: Given standard text editing gestures are used in the composer, When the Mention Picker is closed, Then the text view handles those gestures normally.
- **AC-016A**: Given the Mention Picker is open, When the user presses a modifier-key text navigation gesture such as Option-Up or Command-Down, Then the text view keeps handling that gesture normally.
- **AC-017**: Given the prompt contains one or more File Mentions, When the prompt is sent, Then the RPC payload still contains a single string `message` field.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for query detection, ranking, exclusion rules, insertion formatting, and project-root safety; UI smoke tests for picker opening, navigation, and insertion.
- **Frameworks**: Swift XCTest for pure logic and AppKit-compatible tests where possible. Manual macOS UI verification is acceptable until a UI automation target exists.
- **Package setup**: If the package still has no test target, add a focused `PiAgentNativeCoreTests` XCTest target that imports `PiAgentNativeCore` with `@testable`.
- **Test Data Management**: Use temporary project directories with files, folders, hidden paths, ignored paths, paths with spaces, and symlinks.
- **CI/CD Integration**: Run `swift build` and any added XCTest target in the repository build workflow.
- **Coverage Requirements**: Unit tests should cover every accepted activation rule, every insertion format, the result cap, result tie-breakers, and symlink escape rejection.
- **Performance Testing**: Add a lightweight index-build test with a large temporary tree if the implementation introduces asynchronous scanning. Indexing must not block text entry on the main actor.

## 7. Rationale & Context

The first version uses editable plain text because the current app sends prompts through a single string RPC command. Introducing attachments or structured message blocks would require a broader conversation-content architecture and is outside issue 1.

The picker is scoped to the Selected Project because Pi Agent Native runs `pi` inside a selected workspace. Workspace-relative paths keep prompts portable and understandable to both the user and the agent process.

Git-aware indexing avoids noisy generated output in normal repositories, while the filesystem fallback keeps the feature usable for non-Git folders. Avoiding live filesystem watching keeps implementation risk low and makes refresh behavior explicit.

Mention Picker keyboard handling is local composer interaction, not a Default Keymap feature. This preserves the existing domain decision that text editing and focused surfaces own their local keys.

No ADR is required for this version because the decisions are reversible UI and scope decisions, not hard-to-reverse architectural commitments.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Local filesystem - Required to enumerate selected-project files and folders.
- **EXT-002**: Git command-line interface - Optional source for tracked and unignored project paths.
- **EXT-003**: pi RPC process - Receives the existing prompt string that may contain File Mentions.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: None.

### Data Dependencies

- **DAT-001**: Selected Project path - Required root for Mention Index construction and File Mention insertion.
- **DAT-002**: Composer text and selection range - Required to detect and replace the active Mention Query.

### Technology Platform Dependencies

- **PLT-001**: macOS 14 or newer - Required platform for Pi Agent Native.
- **PLT-002**: SwiftUI and AppKit interop - Required because the shell is SwiftUI and the composer uses an AppKit text view.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Git-backed indexing:
Use NUL-separated Git output for path safety when possible.
Tracked and unignored file paths should be indexed, and parent directory entries should be synthesized so folders can appear even though Git does not track directories directly.
Hard-excluded paths remain excluded even if Git returns them.
```

```text
Hidden path search:
Query: "@gi"   -> no .github/ result by default
Query: "@.g"   -> .github/ may appear
.git/ remains excluded in both cases
```

```text
Empty query:
Input: "@"
Result: show up to 12 eligible project entries instead of "No matches"
```

```text
Activation examples:
@pi                -> active query "pi"
Review @pi         -> active query "pi"
Review (@pi        -> active query "pi"
me@example.com     -> no active query
Review @path name  -> inactive after whitespace enters the query
```

```text
Ranking example for query "pi":
1. PiAgentNative/
2. PiAgentNativeApp.swift
3. PiRPCClient.swift
4. Sources/PiAgentNative/
```

```text
Insertion examples:
Input:  "Review @pi and explain startup"
Pick:   Sources/PiAgentNative/PiRPCClient.swift
Output: "Review @Sources/PiAgentNative/PiRPCClient.swift and explain startup"

Input:  "@agent"
Pick:   Sources/PiAgentNative/
Output: "@Sources/PiAgentNative/ "
```

```text
Unavailable state:
If the selected project path cannot be indexed, the picker may show:
No project files available

The composer text must remain unchanged.
```

```text
Symlink safety:
Selected Project: /repo
Entry path:       linked-docs
Resolved path:    /private/docs
Result:           reject insertion because the resolved path escapes /repo
```

## 10. Validation Criteria

- Mention Query detection does not activate for embedded `@` characters.
- Mention Index excludes the default noisy paths.
- Git repositories prefer Git-tracked and Git-unignored paths.
- Filesystem fallback works for non-Git folders.
- Result ranking follows the specified score order and visible cap.
- Empty `@` queries show the initial capped result set, while non-empty unmatched queries show the disabled no-match row.
- Keyboard and pointer insertion replace only the active Mention Query.
- Folder mentions end with `/ `.
- File mentions end with ` ` and do not add a slash.
- Symlink insertion cannot escape the Selected Project root.
- The prompt RPC payload remains a single string message.
- Existing composer send, newline, thinking-level cycling, copy, paste, undo, redo, deletion, and cursor movement behavior remain intact.

## 11. Engineer Handoff

Recommended implementation sequence:

1. Add a `PiAgentNativeCoreTests` test target in `Package.swift` for pure mention logic.
2. Add pure logic types under `Sources/PiAgentNative/`:
   - `MentionQueryDetector.swift`
   - `MentionIndexProvider.swift`
   - `MentionSearcher.swift`
   - `MentionInserter.swift`
3. Add focused XCTest coverage under `Tests/PiAgentNativeCoreTests/` for activation rules, UTF-16 cursor offsets, ranking, exclusions, insertion formatting, and symlink escape rejection.
4. Extend `AppModel` with mention-picker state, selected-project cache invalidation, async index loading, and `refreshState()` invalidation.
5. Extend `PromptTextView`/`SubmitTextView` with selection-change reporting and picker key routing. Preserve existing submit, Shift-Return newline, Shift-Tab reasoning, and standard AppKit editing behavior.
6. Add a SwiftUI `MentionPickerView` in or near `ChatSurfaceView.swift`, positioned above the composer and driven by `AppModel` state.
7. Run `swift test` and `swift build`, then manually verify picker open, keyboard navigation, pointer insertion, no-project behavior, and prompt RPC string preservation.

Likely files/modules:

| File | Expected change |
|---|---|
| `Package.swift` | Add `PiAgentNativeCoreTests` test target if tests are introduced. |
| `Sources/PiAgentNative/AppModel.swift` | Own mention state, index lifecycle, insertion action, project-change invalidation, refresh invalidation. |
| `Sources/PiAgentNative/PromptTextView.swift` | Report cursor/selection, intercept picker keys, expose insertion hook while preserving existing text editing. |
| `Sources/PiAgentNative/ChatSurfaceView.swift` | Render `MentionPickerView` above the composer and wire hover/click selection. |
| `Sources/PiAgentNative/MentionQueryDetector.swift` | Pure active-query detection. |
| `Sources/PiAgentNative/MentionIndexProvider.swift` | Git-aware and filesystem fallback indexing. |
| `Sources/PiAgentNative/MentionSearcher.swift` | Filtering, scoring, sorting, result cap, hidden-query filtering. |
| `Sources/PiAgentNative/MentionInserter.swift` | Plain-text replacement and root-containment safety. |
| `Tests/PiAgentNativeCoreTests/*` | Logic regression coverage. |

Primary risks to watch:

- Key event regressions in the AppKit composer, especially Return submit, Shift-Return newline, Shift-Tab reasoning, undo/redo, and cursor movement.
- Main-thread stalls while indexing large repositories.
- Race conditions where async index results from a previous selected project overwrite the current project state.
- Unsafe path validation caused by string-prefix checks or symlinks resolving outside the selected project.
- Hidden-path behavior drifting from the query-aware rule in `REQ-008A`.
- Git-only indexing missing directory rows; folder suggestions should still work.

## 12. Related Specifications / Further Reading

- [Pi Agent Native domain context](../CONTEXT.md)
- [Default Keymap and Keyboard Shortcut Design](./spec-design-default-keymap.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 1: Implement @ file add picker](https://github.com/MatheusBBarni/pi-agent-native/issues/1)
