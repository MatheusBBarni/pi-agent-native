---
title: Default Keymap and Keyboard Shortcut Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, keybindings, macos]
---

# Introduction

This specification defines the first-version keyboard interaction design for Pi Agent Native. The goal is to ship a discoverable Default Keymap for common shell actions while preserving standard macOS text editing behavior and leaving user-customized keymaps out of scope.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's macOS app shell, sidebar commands, chat surface, composer, modals, and keyboard shortcut help surface.

The intended audience is implementation agents and maintainers adding first-version keybinding support. The implementation must centralize keybinding definitions so command handling, menus, hover help, and Keyboard Shortcuts help render from a shared source of truth.

In scope:

- Default Keymap only.
- App-wide and focused keybindings.
- Keyboard Shortcuts modal opened from the sidebar Help command.
- Hover help for sidebar commands that have keybindings.
- Sidebar and inspector pane toggles.
- Escape behavior for modal dismissal and stop generation.

Out of scope:

- User-editable keybinding customization.
- Keybinding persistence.
- Importing or exporting keymaps.
- Project/session cycling shortcuts.
- Command picker and file picker navigation shortcuts beyond standard platform behavior.
- Operating-system-wide global shortcuts.

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
- **CON-001**: User-customized keybinding editing is not part of this version.
- **CON-002**: Keybinding persistence is not part of this version.
- **CON-003**: Project/session cycling and command/file picker navigation shortcuts are deferred.
- **CON-004**: Composer text editing behavior must take precedence over conflicting Keybindings.
- **CON-005**: The app must not steal standard text input gestures for text selection, deletion, cursor movement, paste, copy, cut, undo, redo, or newline insertion.
- **GUD-001**: Use standard macOS key equivalents where possible: Command-N for New chat, Command-O for Open project, Command-, for Settings.
- **GUD-002**: Generate menu labels, hover help labels, and Keybinding Help rows from the centralized registry to avoid drift.
- **PAT-001**: Model each keybinding record with an App Action identifier, user-facing action label, key equivalent, modifiers, scope, help group, and enabled-state rule.

### Default Keymap

| Group | App Action | Keybinding | Scope |
|---|---|---:|---|
| Shell | New chat | Command-N | App-wide |
| Shell | Open project | Command-O | App-wide |
| Shell | Focus composer | Command-L | App-wide |
| Shell | Refresh state | Command-R | App-wide |
| Shell | Open settings | Command-, | App-wide |
| Shell | Open process log | Command-Shift-L | App-wide |
| Shell | Open Keyboard Shortcuts | Command-/ | App-wide |
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
| Keyboard Shortcuts modal | help group, action title, display label, scope |
| Shortcut dispatch | action identifier, scope, enabled state |

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
- **AC-010**: Given the user clicks the Help Sidebar Command, Then Keyboard Shortcuts help opens.
- **AC-011**: Given Keyboard Shortcuts help is open, When the user views it, Then all Default Keymap bindings are listed by group.
- **AC-012**: Given the sidebar is visible, When the user presses Command-Option-S, Then the sidebar is hidden and the chat surface remains usable.
- **AC-013**: Given the inspector is visible, When the user presses Command-Option-I, Then the inspector is hidden and the chat surface remains usable.
- **AC-014**: Given text is selected in the composer, When the user uses standard macOS copy, paste, undo, redo, deletion, or cursor movement shortcuts, Then the text editor handles those gestures normally.
- **AC-015**: Given the Pi menu is open, When the user views Start Pi RPC or Stop Pi RPC, Then those menu actions are present but have no first-version default keybinding.

## 6. Test Automation Strategy

- **Test Levels**: Unit and UI smoke tests.
- **Frameworks**: Swift XCTest for registry and action behavior; manual or future UI automation for keyboard dispatch in the macOS shell.
- **Test Data Management**: Use a preview or test AppModel with seeded projects, sessions, streaming state, modal state, and composer text.
- **CI/CD Integration**: Run Swift package build and available XCTest targets in the existing repository build workflow when tests are added.
- **Coverage Requirements**: Unit tests should cover registry uniqueness, duplicate keybinding detection, expected display labels, and action availability rules.
- **Performance Testing**: No dedicated performance tests are required. Keybinding dispatch must be synchronous and must not perform blocking IO.

## 7. Rationale & Context

The first version prioritizes predictable native keyboard operation over customization. Default-only keybindings reduce implementation risk while still requiring a centralized registry so future customization can be added without replacing scattered shortcut handlers.

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
1. If Keyboard Shortcuts help, settings, login, model picker, or process log is open, Escape closes that modal.
2. Else if generation is streaming, Escape stops generation.
3. Else Escape is a no-op.
```

```text
Deferred behavior:
Command-Shift-[ and Command-Shift-] must not be introduced for session navigation in this version because "next session" and "previous session" are not yet defined by the domain model.
```

## 10. Validation Criteria

- The Default Keymap has no duplicate keybinding conflicts within the same scope.
- Every keybinding in the registry appears in Keyboard Shortcuts help.
- Every Sidebar Command with a keybinding has hover help that matches the registry display label.
- Standard composer text editing behavior works after keybinding implementation.
- Sidebar and inspector visibility toggles do not reset project, session, composer, message, or streaming state.
- Project/session cycling and command/file picker navigation are absent from the first Default Keymap.

## 11. Related Specifications / Further Reading

- [Pi Agent Native domain context](../CONTEXT.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 15: Add keymaps and keybindings](https://github.com/MatheusBBarni/pi-agent-native/issues/15)
