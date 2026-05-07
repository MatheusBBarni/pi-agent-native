---
title: Default Keymap and Keybinding Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, keybindings, macos]
---

# Introduction

This specification defines the first-version keyboard interaction design for Pi Agent Native. The goal is to ship a discoverable Default Keymap for common shell actions while preserving standard macOS text editing behavior and leaving user-customized keymaps out of scope.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's macOS app shell, sidebar commands, chat surface, composer, modals, and Keybinding Help surface.

The intended audience is implementation agents and maintainers adding first-version keybinding support. The implementation must centralize keybinding definitions so command handling, menus, hover help, and Keybinding Help render from a shared source of truth.

In scope:

- Default Keymap only.
- App-wide and focused keybindings.
- Keybinding Help modal opened from the sidebar Help command.
- Hover help for sidebar commands that have keybindings.
- Sidebar and inspector pane toggles.
- Escape behavior for modal dismissal and stop generation.

Out of scope:

- User-editable keybinding customization.
- Keybinding persistence.
- Importing or exporting keymaps.
- Project/session cycling keybindings.
- Command picker and file picker navigation keybindings beyond standard platform behavior.
- Operating-system-wide keybindings.

## 2. Definitions

**App Action**: A user-intent command that Pi Agent Native can perform from the UI or keyboard.

**Keybinding**: A keyboard gesture assigned to exactly one App Action in a Keymap.

**Keymap**: The active collection of Keybindings available in Pi Agent Native.

**Default Keymap**: The built-in Keymap shipped with Pi Agent Native before user customization exists.

**Focused Keybinding**: A Keybinding that fires only when the current UI focus can safely perform its App Action.

**App-Wide Keybinding**: A Keybinding that can fire anywhere in the active Pi Agent Native window unless a modal or system text interaction owns the gesture.

**Keybinding Help**: A discoverable surface that lists the Default Keymap in user-facing language.

**Sidebar Command**: A shell-level App Action presented as a button in the left sidebar.

**Pane Toggle**: An App Action that shows or hides a persistent shell region such as the sidebar or inspector.

**Modal Dismissal**: An App Action that closes the active modal without changing the underlying conversation state.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall define a centralized registry for all first-version App Actions and Keybindings.
- **REQ-002**: The app shall ship a Default Keymap only.
- **REQ-003**: The app shall bind New chat to Command-N as an App-Wide Keybinding.
- **REQ-004**: The app shall expose a Help Sidebar Command that opens Keybinding Help.
- **REQ-005**: The Help Sidebar Command shall be placed near the lower sidebar utility commands in this order: Process log, Help, Login, Settings.
- **REQ-006**: Sidebar Commands with Keybindings shall show hover help in the format `{Action label} - {Keybinding label}`.
- **REQ-007**: Keybinding Help shall list the Default Keymap grouped by Shell, Chat, Composer, and Navigation.
- **REQ-008**: The app shall support toggling sidebar visibility with Command-Option-S.
- **REQ-009**: The app shall support toggling inspector visibility with Command-Option-I.
- **REQ-010**: The chat surface shall remain usable when either sidebar or inspector is hidden.
- **REQ-011**: Escape shall close the active modal when a modal is open.
- **REQ-012**: Escape shall stop generation when generation is streaming and no modal owns focus.
- **REQ-013**: The implementation shall keep Start Pi RPC and Stop Pi RPC available as menu actions without default keybindings in the first version.
- **REQ-014**: The implementation shall remove the current provisional Command-Shift-R Start/Stop Pi RPC keybinding and Command-Shift-N New Session keybinding.
- **REQ-015**: Keybinding dispatch shall use exact modifier matching, except for platform-provided equivalent handling, so extra modifiers do not accidentally trigger focused composer actions.
- **REQ-016**: Command-Return shall not stop generation. Escape is the only first-version default keybinding for Stop generation.
- **REQ-017**: Modal Dismissal shall be dispatched before any app-wide or chat-level Escape action.
- **REQ-018**: The implementation shall expose shared action dispatch helpers so sidebar buttons, menu commands, keybinding dispatch, and help labels call the same App Action behavior.
- **CON-001**: User-customized keybinding editing is not part of this version.
- **CON-002**: Keybinding persistence is not part of this version.
- **CON-003**: Project/session cycling and command/file picker navigation keybindings are deferred.
- **CON-004**: Composer text editing behavior must take precedence over conflicting Keybindings.
- **CON-005**: The app must not steal standard text input gestures for text selection, deletion, cursor movement, paste, copy, cut, undo, redo, or newline insertion.
- **CON-006**: Sidebar and inspector visibility state is runtime UI state for this issue; persisting pane visibility is out of scope.
- **GUD-001**: Use standard macOS key equivalents where possible: Command-N for New chat, Command-O for Open project, Command-, for Settings.
- **GUD-002**: Generate menu labels, hover help labels, and Keybinding Help rows from the centralized registry to avoid drift.
- **PAT-001**: Model each keybinding record with an App Action identifier, user-facing action label, key equivalent, modifiers, scope, help group, and enabled-state rule.
- **PAT-002**: Keep platform-local text handling inside `PromptTextView` for Return, Shift-Return, and Shift-Tab, but have it call shared App Action behavior rather than duplicating business logic.
- **PAT-003**: Implement app-wide keybindings through SwiftUI commands where possible, and use a single window-level keyboard event bridge only for focused or priority-sensitive cases that SwiftUI commands cannot express reliably.

### Default Keymap

| Group | App Action | Keybinding | Scope |
|---|---|---:|---|
| Shell | New chat | Command-N | App-wide |
| Shell | Open project | Command-O | App-wide |
| Shell | Focus composer | Command-L | App-wide |
| Shell | Refresh state | Command-R | App-wide |
| Shell | Open settings | Command-, | App-wide |
| Shell | Open process log | Command-Shift-L | App-wide |
| Shell | Open Keybinding Help | Command-/ | App-wide |
| Shell | Toggle sidebar | Command-Option-S | App-wide |
| Shell | Toggle inspector | Command-Option-I | App-wide |
| Chat | Send prompt | Command-Return | Focused |
| Chat | Stop generation | Escape | Focused/App-wide in chat |
| Composer | Send prompt | Return | Focused |
| Composer | Insert newline | Shift-Return | Focused |
| Composer | Cycle thinking level | Shift-Tab | Focused |
| Navigation | Close active modal | Escape | Focused |

## 4. Interfaces & Data Contracts

The implementation should expose a centralized keybinding registry equivalent to this conceptual contract:

```swift
enum AppActionID: String, CaseIterable {
    case newChat
    case openProject
    case focusComposer
    case refreshState
    case openSettings
    case openProcessLog
    case openKeybindingHelp
    case toggleSidebar
    case toggleInspector
    case sendPrompt
    case stopGeneration
    case insertComposerNewline
    case cycleThinkingLevel
    case closeActiveModal
}

enum KeybindingScope {
    case appWide
    case focused
    case chat
    case composer
    case navigation
}

struct KeybindingDefinition {
    let actionID: AppActionID
    let title: String
    let keyEquivalent: String
    let modifiers: [String]
    let displayLabel: String
    let scope: KeybindingScope
    let helpGroup: String
}
```

Required generated consumers:

| Consumer | Required data |
|---|---|
| macOS menu commands | action title, key equivalent, modifiers, enabled state |
| Sidebar hover help | action title, display label |
| Keybinding Help modal | help group, action title, display label, scope |
| Keybinding dispatch | action identifier, scope, enabled state |

Current code handoff:

| Current surface | Existing state | Required issue 15 change |
|---|---|---|
| `PiAgentNativeApp` commands | `Command-Shift-R` toggles Pi RPC and `Command-Shift-N` creates a session | Replace provisional key equivalents with registry-backed menu commands; leave Start/Stop Pi RPC unbound |
| `SidebarView` | Owns `openProject()` privately and hardcodes command labels | Move or wrap Open Project and other App Actions behind shared dispatch so menus and sidebar use the same behavior |
| `SidebarCommand` | No hover help | Accept an optional `AppActionID` or registry definition and render `.help("{title} - {displayLabel}")` when a keybinding exists |
| `AppShellView` | Always renders sidebar and inspector; custom modals have click-to-dismiss only | Add runtime pane visibility state and a modal-aware Escape dispatch path |
| `ComposerView` | Send/stop button owns `Command-Return` and can abort while streaming | Remove abort behavior from the `Command-Return` keybinding; keep pointer click behavior for the stop button |
| `PromptTextView` | Handles Return and Shift-Tab with broad modifier checks | Use exact modifier checks for Return, Shift-Return, and Shift-Tab and leave standard editing gestures to `NSTextView` |
| `AppModel` | Contains action behavior but not keybinding metadata or modal close helper | Add small action helpers such as `closeActiveModal()`, `toggleSidebar()`, `toggleInspector()`, and action availability predicates |

## 5. Acceptance Criteria

- **AC-001**: Given the app window is active, When the user presses Command-N, Then a new chat is created for the selected project.
- **AC-002**: Given the app window is active, When the user presses Command-O, Then the open-project flow is invoked.
- **AC-003**: Given the app window is active, When the user presses Command-L, Then keyboard focus moves to the composer.
- **AC-004**: Given a prompt exists in the composer and the composer is focused, When the user presses Return, Then the prompt is sent.
- **AC-005**: Given the composer is focused, When the user presses Shift-Return, Then a newline is inserted and the prompt is not sent.
- **AC-006**: Given the composer is focused, When the user presses Shift-Tab, Then the thinking level cycles and focus does not move.
- **AC-007**: Given generation is streaming and no modal is active, When the user presses Escape, Then generation is stopped.
- **AC-008**: Given a modal is active, When the user presses Escape, Then the modal closes and generation is not stopped by the same key event.
- **AC-009**: Given the user hovers the New chat Sidebar Command, Then hover help displays `New chat - Command-N`.
- **AC-010**: Given the user clicks the Help Sidebar Command, Then Keybinding Help opens.
- **AC-011**: Given Keybinding Help is open, When the user views it, Then all Default Keymap bindings are listed by group.
- **AC-012**: Given the sidebar is visible, When the user presses Command-Option-S, Then the sidebar is hidden and the chat surface remains usable.
- **AC-013**: Given the inspector is visible, When the user presses Command-Option-I, Then the inspector is hidden and the chat surface remains usable.
- **AC-014**: Given text is selected in the composer, When the user uses standard macOS copy, paste, undo, redo, deletion, or cursor movement gestures, Then the text editor handles those gestures normally.
- **AC-015**: Given the Pi menu is open, When the user views Start Pi RPC or Stop Pi RPC, Then those menu actions are present but have no first-version default keybinding.
- **AC-016**: Given generation is streaming and the composer is focused, When the user presses Command-Return, Then generation is not stopped by that keybinding.
- **AC-017**: Given the app menu is visible, When the user views New chat, Open project, Refresh state, Settings, Process log, and Keybinding Help, Then their displayed key equivalents match the Default Keymap registry.
- **AC-018**: Given the app has the first-version Default Keymap, When duplicate detection runs, Then Escape for Modal Dismissal and Escape for Stop generation are accepted only because the dispatch priority makes them mutually exclusive.
- **AC-019**: Given the user presses Command-Shift-N or Command-Shift-R, Then those provisional keybindings do not invoke New chat or Start/Stop Pi RPC.

## 6. Test Automation Strategy

- **Test Levels**: Unit and UI smoke tests.
- **Frameworks**: Swift XCTest for registry and action behavior; manual or future UI automation for keyboard dispatch in the macOS shell.
- **Test Data Management**: Use a preview or test AppModel with seeded projects, sessions, streaming state, modal state, and composer text.
- **CI/CD Integration**: Run Swift package build and available XCTest targets in the existing repository build workflow when tests are added.
- **Coverage Requirements**: Unit tests should cover registry uniqueness, duplicate keybinding detection, expected display labels, and action availability rules.
- **Recommended Tests**:
  - Add a `PiAgentNativeCoreTests` target if no test target exists yet.
  - Test that every first-version keybinding targets a known `AppActionID`, and that intentional multi-binding actions such as Send prompt are represented explicitly.
  - Test that keybinding display labels match the menu/help labels for Command-N, Command-O, Command-L, Command-R, Command-,, Command-Shift-L, Command-/, Command-Option-S, Command-Option-I, Command-Return, Return, Shift-Return, Shift-Tab, and Escape.
  - Test duplicate conflict detection by scope and priority, including the allowed Escape Modal Dismissal before Stop generation case.
  - Test action availability rules for no selected project, empty composer, streaming, and active modal states.
- **Performance Testing**: No dedicated performance tests are required. Keybinding dispatch must be synchronous and must not perform blocking IO.

## 7. Rationale & Context

The first version prioritizes predictable native keyboard operation over customization. Default-only keybindings reduce implementation risk while still requiring a centralized registry so future customization can be added without replacing scattered keybinding handlers.

Focused keybindings protect the composer and standard macOS text editing. App-wide keybindings are limited to shell-level actions that users expect to work from most places in the active window. Modal Dismissal has priority over stop-generation behavior to prevent Escape from closing a modal and aborting an active run with one key event.

The Help Sidebar Command and sidebar hover help make keybindings discoverable without introducing a settings editor. Pane toggles are included because issue 15 explicitly requires toggle sidebar or inspector behavior, and the current app shell has persistent sidebar and inspector regions.

No ADR is required for this version because the resolved decisions are reversible product and interaction-scope decisions rather than hard-to-reverse architectural commitments.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: macOS keyboard event system - Required for menu key equivalents, focused text input handling, and app-window keyboard dispatch.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: None.

### Data Dependencies

- **DAT-001**: None. The first version must not require persisted keybinding data.

### Technology Platform Dependencies

- **PLT-001**: macOS 14 or newer - Required platform for Pi Agent Native.
- **PLT-002**: SwiftUI and AppKit interop - Required because the shell is SwiftUI and the composer uses an AppKit text view.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Example sidebar hover help:
New chat - Command-N
Open project - Command-O
Process log - Command-Shift-L
Help - Command-/
Settings - Command-,
```

```text
Escape priority:
1. If Keybinding Help, settings, login, model picker, or process log is open, Escape closes that modal.
2. Else if generation is streaming, Escape stops generation.
3. Else Escape is a no-op.
```

```text
Exact composer modifier handling:
1. Return with no modifiers submits the prompt.
2. Shift-Return inserts a newline.
3. Command-Return submits the prompt only through the explicit Command-Return keybinding and only when sending is available.
4. Command-Return does not inherit the send/stop button toggle behavior while streaming.
5. Shift-Tab cycles thinking level only when the composer owns focus and no picker or modal owns the interaction.
```

```text
Deferred behavior:
Command-Shift-[ and Command-Shift-] must not be introduced for session navigation in this version because "next session" and "previous session" are not yet defined by the domain model.
```

## 10. Validation Criteria

- The Default Keymap has no duplicate keybinding conflicts within the same scope.
- Every keybinding in the registry appears in Keybinding Help.
- Every Sidebar Command with a keybinding has hover help that matches the registry display label.
- Standard composer text editing behavior works after keybinding implementation.
- Sidebar and inspector visibility toggles do not reset project, session, composer, message, or streaming state.
- Project/session cycling and command/file picker navigation are absent from the first Default Keymap.
- Existing provisional keybindings Command-Shift-N and Command-Shift-R are removed.
- Command-Return cannot abort generation; Escape remains the stop-generation keybinding.
- The app builds with `swift build` and any added tests pass with `swift test`.
- If the local sandbox blocks SwiftPM network or cache writes, rerun validation in a normal developer shell and record the blocker in the handoff.

## 11. Engineer Handoff Plan

1. Add a `KeybindingDefinition` registry in `Sources/PiAgentNative`, including `AppActionID`, scope, help group, display label generation, enabled-state metadata, and duplicate validation.
2. Add small shared App Action helpers on `AppModel` or a thin action dispatcher for New chat, Open project, Focus composer, Refresh state, Open settings, Open process log, Open Keybinding Help, Toggle sidebar, Toggle inspector, Send prompt, Stop generation, Cycle thinking level, and Close active modal.
3. Replace hardcoded SwiftUI `.keyboardShortcut` declarations in `PiAgentNativeApp` and `ComposerView` with registry-backed bindings where SwiftUI commands are appropriate.
4. Add runtime state for sidebar visibility, inspector visibility, and Keybinding Help modal visibility; keep pane visibility persistence out of scope.
5. Add focus plumbing to `PromptTextView` so Command-L can make the composer first responder without disturbing normal `NSTextView` editing.
6. Tighten `SubmitTextView.keyDown(with:)` to exact focused composer bindings and leave all other key events to `super`.
7. Render Keybinding Help from the registry grouped by Shell, Chat, Composer, and Navigation.
8. Render Sidebar Command hover help from the registry and insert the Help Sidebar Command between Process log and Login.
9. Add focused unit tests for registry labels, duplicate detection, action availability, and allowed Escape priority.
10. Validate with `swift build` and `swift test`; then manually smoke-test keybindings in a macOS run because keyboard dispatch depends on AppKit/SwiftUI focus behavior.

## 12. Loophole Review

| Loophole | Fix in this strategy |
|---|---|
| The issue title could imply user-editable keymaps | Scope is Default Keymap only; persistence and customization are explicit non-goals |
| "Global shortcut" could mean an OS-wide hotkey | Scope is App-Wide Keybinding inside the active app window only |
| Existing Command-Shift-N and Command-Shift-R provisional keybindings conflict with the Default Keymap | They must be removed or left unbound as specified |
| Escape can both close a modal and abort generation | Modal Dismissal has explicit priority and consumes the event |
| SwiftUI button `Command-Return` can abort while streaming | Command-Return is constrained to Send prompt only; pointer stop remains separate |
| AppKit composer currently accepts broad modifier combinations | Exact modifier matching is required for focused composer keybindings |
| Sidebar/menu/help labels can drift | Registry-backed consumers are required |
| Open Project logic is private to `SidebarView` | Shared App Action dispatch is required before menu keybindings are wired |
| Pane toggles could accidentally reset app state | Acceptance and validation require project, session, composer, message, and streaming state preservation |
| Tests may be skipped because the repo has no test target | The handoff explicitly calls for adding a focused test target |

## 13. Related Specifications / Further Reading

- [Pi Agent Native domain context](../CONTEXT.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 15: Add keymaps and keybindings](https://github.com/MatheusBBarni/pi-agent-native/issues/15)
