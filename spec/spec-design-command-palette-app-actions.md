---
title: Command Palette App Actions Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, command-palette, actions, macos]
---

# Introduction

This specification defines a native Command Palette for Pi Agent Native App Actions. The goal is to let users discover and run shell-level app behavior from a keyboard-accessible overlay without turning composer slash commands, File Mentions, or Skill Selection into a general command system.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's macOS shell, App Action registry, Default Keymap, menus, sidebar/header action dispatch, selected project/session data, model and thinking controls, and modal handling.

The intended audience is implementation agents and maintainers adding GitHub issue 23: "Add native command palette for App Actions".

In scope:

- Adding a native Command Palette overlay.
- Adding an app-wide keybinding for opening the Command Palette.
- Listing static App Actions with labels, optional keybindings, and enabled state.
- Listing parameterized Palette Items for known projects, selected-project sessions, available models, thinking levels, and external targets.
- Filtering Palette Items by typed Palette Query text.
- Keyboard and pointer navigation inside the palette.
- Dispatching selected Palette Items through the same AppModel paths used by menus, sidebar commands, header controls, keybindings, and existing controls.
- Handling disabled or unavailable actions without running them.
- Ensuring composer slash commands, `@` File Mentions, and `/skill:` Skill Selection remain composer-local behavior.
- Tests for filtering, enabled-state behavior, and shared dispatch.

Out of scope:

- User-customizable command palette entries.
- Persisting recent or favorite Palette Items.
- Fuzzy matching beyond deterministic title, subtitle, and keyword matching.
- Arbitrary shell command execution.
- Replacing Keybinding Help.
- Turning `/` into a general command picker.
- Palette-driven file mentions or skill selection.
- Reordering, pinning, or grouping customization.

## 2. Definitions

**App Action**: A user-intent command that Pi Agent Native can perform from the UI or keyboard.

**Command Palette**: A keyboard-accessible native shell surface that filters and runs available App Actions and state-derived app actions.

**Palette Item**: A selectable row in the Command Palette that invokes one concrete App Action or one parameterized shared AppModel action.

**Palette Query**: The text typed into the Command Palette to filter Palette Items.

**Static Palette Item**: A Palette Item backed by an `AppActionID` and routed through `AppModel.performAppAction(_:)`.

**Parameterized Palette Item**: A Palette Item backed by app state and a value, such as a specific project, session, model, thinking level, or external target.

**Default Keymap**: The built-in Keymap shipped with Pi Agent Native before user customization exists.

**Composer Slash Command**: A composer input beginning with `/` that Pi Agent Native interprets before sending normal prompt text.

**Mention Picker**: A composer suggestion surface that helps the user insert a File Mention.

**Skill Picker**: A composer suggestion surface that helps the user find and select Skills for a Skill Selection.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall provide a native Command Palette overlay.
- **REQ-002**: The Command Palette shall open through a first-version App-Wide Keybinding.
- **REQ-003**: The first-version open-palette keybinding shall be Command-K.
- **REQ-004**: The Command Palette shall also be openable from a menu item wired to the same App Action.
- **REQ-005**: Opening the Command Palette shall not mutate composer text.
- **REQ-006**: Opening the Command Palette shall not submit or parse a Composer Slash Command.
- **REQ-007**: Opening the Command Palette shall not insert, remove, or submit a File Mention.
- **REQ-008**: Opening the Command Palette shall not complete or submit a Skill Selection.
- **REQ-009**: The Command Palette shall own its own Palette Query text separate from `composerText`.
- **REQ-010**: The Command Palette shall show Palette Items with a title and optional subtitle.
- **REQ-011**: Static Palette Items shall show the Default Keymap display label when a keybinding exists.
- **REQ-012**: Palette Items without keybindings shall remain listable without an empty keybinding badge.
- **REQ-013**: Palette Items shall be filtered by Palette Query text.
- **REQ-014**: Filtering shall match title, subtitle, and keywords case-insensitively.
- **REQ-015**: Empty Palette Query shall show an initial useful list of available shell actions.
- **REQ-016**: Results shall be deterministic for a given app state and query.
- **REQ-017**: Results shall be capped to a bounded visible list; the first implementation should show at most 12 visible rows before scrolling.
- **REQ-018**: The highlighted result shall be keyboard navigable with Up and Down.
- **REQ-019**: Return shall run the highlighted enabled Palette Item.
- **REQ-020**: Tab may also run the highlighted enabled Palette Item if it does not conflict with text entry focus inside the palette.
- **REQ-021**: Escape shall close the Command Palette without running a Palette Item.
- **REQ-022**: Pointer hover shall update the highlighted Palette Item.
- **REQ-023**: Pointer click shall run an enabled Palette Item.
- **REQ-024**: Disabled Palette Items shall not run from Return, Tab, pointer click, or double click.
- **REQ-025**: Unavailable actions may be hidden or shown disabled, but shown disabled items shall include a concise reason.
- **REQ-026**: Static Palette Items shall dispatch through `AppModel.performAppAction(_:)`.
- **REQ-027**: The palette shall not duplicate Static Palette Item behavior in the view layer.
- **REQ-028**: Parameterized project Palette Items shall call the same AppModel project-selection behavior used by the sidebar project list.
- **REQ-029**: Parameterized session Palette Items shall call the same AppModel session-switching behavior used by the sidebar session list.
- **REQ-030**: Parameterized model Palette Items shall call the same AppModel model-selection behavior used by the model picker.
- **REQ-031**: Parameterized thinking-level Palette Items shall call the same AppModel thinking-level behavior used by the thinking menu.
- **REQ-032**: Parameterized external-target Palette Items shall call the same AppModel external launch behavior used by the External Target Menu.
- **REQ-033**: The Command Palette shall close before dispatching a selected action whose normal `canPerformAppAction(_:)` path would otherwise be blocked by the palette's own modal state.
- **REQ-034**: If another modal is active, the open-palette App Action shall be unavailable.
- **REQ-035**: If a Palette Item dispatch opens another modal, only the Command Palette should close first; unrelated modals must not be closed.
- **REQ-036**: The Command Palette shall not appear as a selectable row inside itself in the first implementation.
- **REQ-037**: The Command Palette shall include Static Palette Items for New chat, Open project, Focus composer, Refresh state, Open settings, Open process log, Open Keybinding Help, Toggle sidebar, Toggle inspector, Send prompt, and Stop generation when those items are relevant.
- **REQ-038**: The Command Palette shall include project Palette Items for known projects.
- **REQ-039**: The Command Palette shall include session Palette Items for sessions in the current Selected Project.
- **REQ-040**: The Command Palette shall include model Palette Items when available models are loaded.
- **REQ-041**: The Command Palette shall include thinking-level Palette Items for the supported first-version levels: off, minimal, low, medium, high, and xhigh.
- **REQ-042**: The Command Palette shall include external-target Palette Items when a Selected Project and available external targets exist.
- **REQ-043**: Running Send prompt from the palette shall use the existing Send prompt App Action availability and dispatch path.
- **REQ-044**: Running Stop generation from the palette shall use the existing Stop generation App Action availability and dispatch path.
- **REQ-045**: Palette filtering and dispatch shall be testable without rendering the full SwiftUI shell.
- **REQ-046**: The open-palette App Action shall be added to `AppActionID.allCases` and `DefaultKeymap.definitions` together so the existing `testEveryAppActionAppearsInDefaultKeymap` invariant remains true.
- **REQ-047**: If Login and Select model remain user-runnable shell actions in the first implementation, the palette shall include them either as new Static Palette Items backed by explicit App Actions or as parameterized/shared AppModel invocations; the implementation shall not leave those existing shell controls undiscoverable without a documented reason.
- **REQ-048**: The implementation shall define whether `isShowingCommandPalette` participates in `hasActiveModal`. If it does, `runCommandPaletteItem(_:)` must close the palette before calling `canPerformAppAction(_:)` through `performAppAction(_:)`. If it does not, the rest of the shell must still be disabled or otherwise protected while the palette is open.
- **REQ-049**: Palette dispatch shall resolve stored invocation IDs back to current app state at run time. If the referenced project, session, model, or external target no longer exists, the item shall become disabled or the run shall no-op with a concise unavailable reason; it must not dispatch against stale state.
- **REQ-050**: Session Palette Items shall use the same ordered current-project session list as the sidebar, including running-session priority and `updatedAt` ordering.
- **REQ-051**: Project Palette Items shall use the persisted project list order from `WorkspaceStore.projects`.
- **REQ-052**: Model Palette Items shall be generated only from `availableModels`; if `availableModels` is empty, model rows shall be omitted in the first implementation.
- **REQ-053**: External Target Palette Items shall be generated only from `availableExternalTargets` and only when a Selected Project exists.
- **REQ-054**: Command-K shall be registered through the Default Keymap and the app `Commands` menu path; the existing Escape-only local keyboard monitor shall not become a second broad keybinding dispatcher unless a concrete focus bug requires it.
- **CON-001**: The Command Palette must not execute arbitrary shell commands.
- **CON-002**: The Command Palette must not replace Composer Slash Commands.
- **CON-003**: The Command Palette must not replace Keybinding Help.
- **CON-004**: The Command Palette must not persist custom actions, query history, or recent actions in the first slice.
- **CON-005**: The Command Palette must respect active-modal blocking rules.
- **GUD-001**: Use a compact centered overlay or modal sheet that visually matches existing modal surfaces.
- **GUD-002**: Use SF Symbols that match Palette Item categories when useful.
- **GUD-003**: Prefer action labels that match existing menu, sidebar, header, and control labels.
- **PAT-001**: Separate Palette Item construction, filtering, availability, and dispatch into testable units.
- **PAT-002**: Keep the SwiftUI view responsible for rendering, focus, and local palette navigation only.
- **PAT-003**: Keep the AppModel or a thin dispatcher responsible for running Palette Items.

## 4. Interfaces & Data Contracts

### App Action Additions

The implementation shall add a first-version App Action for opening the Command Palette:

```swift
enum AppActionID: String, CaseIterable {
    case openCommandPalette
}
```

`openCommandPalette` shall have a Command-K App-Wide Keybinding in the Default Keymap and shall appear in Keybinding Help. It should be grouped with shell actions.

The implementation must update the existing keymap tests when adding this action:

- Add a Command-K assertion to `testDefaultKeymapHasExpectedDisplayLabels`.
- Keep `testDefaultKeymapHasNoUnexpectedConflicts` passing.
- Keep `testEveryAppActionAppearsInDefaultKeymap` passing by adding the keybinding in the same change as the enum case.
- Confirm Command-K is not already used by any focused or app-wide keybinding.

### Palette Item Contract

The implementation should expose a model equivalent to:

```swift
struct CommandPaletteItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let keywords: [String]
    let iconSystemName: String?
    let keybindingLabel: String?
    let availability: CommandPaletteAvailability
    let invocation: CommandPaletteInvocation
}

enum CommandPaletteAvailability: Equatable {
    case enabled
    case disabled(reason: String)
}

enum CommandPaletteInvocation: Equatable {
    case appAction(AppActionID)
    case selectProject(ProjectItem.ID)
    case switchSession(StoredSession.ID)
    case selectModel(provider: String, modelID: String)
    case setThinkingLevel(String)
    case openExternalTarget(ExternalTargetID)
}
```

Exact names may differ, but the implementation must preserve these fields and dispatch categories.

The invocation payload should store stable identifiers, not whole mutable state objects. Dispatch must look up the current `ProjectItem`, `StoredSession`, `PiModel`, or `AvailableExternalTarget` immediately before running so stale palette rows cannot select deleted or outdated state.

### Palette State Contract

The app should hold state equivalent to:

```swift
struct CommandPaletteState: Equatable {
    var query: String
    var items: [CommandPaletteItem]
    var highlightedItemID: CommandPaletteItem.ID?
}
```

`AppModel` should include:

```swift
@Published var isShowingCommandPalette: Bool
@Published var commandPaletteQuery: String

func showCommandPalette()
func closeCommandPalette()
func commandPaletteItems() -> [CommandPaletteItem]
func filteredCommandPaletteItems(query: String) -> [CommandPaletteItem]
func runCommandPaletteItem(_ item: CommandPaletteItem)
```

Names may differ, but the behavior is required.

`showCommandPalette()` must refuse to open while any existing modal is active. The command palette may be modeled as an active modal after it is open, but the implementation must avoid the self-blocking dispatch bug by closing only the command palette before running the selected item.

The implementation should expose either a `hasActiveModalExcludingCommandPalette` predicate or an equivalent helper used only for opening the palette. `hasActiveModal` may include the Command Palette so the background shell is disabled while the overlay is open.

### Required First-Version Items

| Item type | Example title | Dispatch |
|---|---|---|
| Static App Action | New chat | `performAppAction(.newChat)` |
| Static App Action | Open project... | `performAppAction(.openProject)` |
| Static App Action | Focus composer | `performAppAction(.focusComposer)` |
| Static App Action | Refresh state | `performAppAction(.refreshState)` |
| Static App Action | Open process log | `performAppAction(.openProcessLog)` |
| Static App Action | Open Keyboard Shortcuts | `performAppAction(.openKeybindingHelp)` |
| Static App Action | Open settings | `performAppAction(.openSettings)` |
| Static App Action | Toggle sidebar | `performAppAction(.toggleSidebar)` |
| Static App Action | Toggle inspector | `performAppAction(.toggleInspector)` |
| Static App Action | Send prompt | `performAppAction(.sendPrompt)` |
| Static App Action | Stop generation | `performAppAction(.stopGeneration)` |
| Static App Action or shared invocation | Login | Existing login presentation path, preferably through a new `AppActionID` if promoted to shared shell action |
| Static App Action or shared invocation | Select model | Existing `showModelPicker()` path, preferably through a new `AppActionID` if promoted to shared shell action |
| Static App Action | Cycle thinking level | `performAppAction(.cycleThinkingLevel)` when included as a static action |
| Project | Switch project: `{project.name}` | `selectProject(project)` or the existing project-selection equivalent |
| Session | Switch session: `{session.title}` | `switchSession(session)` after sourcing rows from `sessionsForProject(selectedProject)` |
| Model | Select model: `{provider}/{modelID}` | `selectModel(model)` |
| Thinking level | Set thinking: `{level}` | `setThinkingLevel(level)` |
| External target | Open externally: `{target.displayName}` | `openExternally(target)` |

The engineer may defer Login, Select model, and Cycle thinking level only if the issue handoff explicitly records why those existing shell controls are excluded from the first palette slice.

### Filtering Contract

Filtering shall use normalized lowercase text:

1. Empty query returns the initial ordered list.
2. Exact title prefix matches rank before title substring matches.
3. Title substring matches rank before subtitle matches.
4. Subtitle matches rank before keyword matches.
5. Ties preserve source order.
6. Disabled items may be included or omitted, but if included they follow the same ranking and remain non-runnable.

### Dispatch Contract

Running a Palette Item shall:

1. Confirm the item is enabled.
2. Capture the invocation payload.
3. Resolve the invocation payload against current app state.
4. If resolution fails, do not dispatch and surface a concise unavailable reason.
5. Close only the Command Palette.
6. Dispatch the resolved invocation through the shared AppModel path.
7. Leave composer text unchanged unless the selected action itself is the existing Send prompt action and its normal dispatch sends and clears the prompt.

This order is required because `canPerformAppAction(_:)` blocks non-modal actions while a modal is active. The Command Palette must not block its own selected action after the user chooses an enabled item.

If `isShowingCommandPalette` is included in `hasActiveModal`, `runCommandPaletteItem(_:)` must close the palette before the call to `performAppAction(_:)`. If it is excluded from `hasActiveModal`, the SwiftUI shell must still block pointer/key interaction outside the palette while the palette is open.

## 5. Acceptance Criteria

- **AC-001**: Given no other modal is active, When the user presses Command-K, Then the Command Palette opens.
- **AC-002**: Given another modal is active, When the user presses Command-K, Then the Command Palette does not open.
- **AC-003**: Given the Command Palette is open, When the user types into the palette search field, Then `composerText` is unchanged.
- **AC-004**: Given the Command Palette is open with an empty query, Then it lists available shell App Actions with labels and keybinding labels where present.
- **AC-005**: Given the Command Palette query is `log`, When results are filtered, Then Open process log appears ahead of unrelated items.
- **AC-006**: Given a Selected Project exists, When the query matches one of its sessions, Then the matching Switch session Palette Item appears.
- **AC-007**: Given available models are loaded, When the query matches a model provider or id, Then matching Select model Palette Items appear.
- **AC-008**: Given an action is unavailable and shown, When the user highlights it, Then it shows a disabled reason.
- **AC-009**: Given an action is unavailable and shown disabled, When the user presses Return, Then the action is not dispatched.
- **AC-010**: Given New chat is highlighted and enabled, When the user presses Return, Then the palette closes and `performAppAction(.newChat)` is used.
- **AC-011**: Given a project Palette Item is highlighted, When the user presses Return, Then the palette closes and the same project-selection path used by the sidebar runs.
- **AC-012**: Given a session Palette Item is highlighted, When the user presses Return, Then the palette closes and the same session-switching path used by the sidebar runs.
- **AC-013**: Given a model Palette Item is highlighted, When the user presses Return, Then the palette closes and the same model-selection path used by the model picker runs.
- **AC-014**: Given a thinking-level Palette Item is highlighted, When the user presses Return, Then the palette closes and the same thinking-level path used by the thinking menu runs.
- **AC-015**: Given an external-target Palette Item is highlighted, When the user presses Return, Then the palette closes and the same Open Externally path used by the External Target Menu runs.
- **AC-016**: Given the Command Palette is open, When the user presses Escape, Then the palette closes and no Palette Item runs.
- **AC-017**: Given the composer contains `/skill:diagnose`, When the Command Palette opens and closes, Then the composer text is still `/skill:diagnose`.
- **AC-018**: Given a Mention Picker or Skill Picker would otherwise be active in the composer, When the Command Palette opens, Then palette input is separate and picker submission/completion does not run.
- **AC-019**: Given the Command Palette is closed, When the user types `/skill:` or `@` in the composer, Then existing Skill Picker and Mention Picker behavior is unchanged.
- **AC-020**: Given the Command Palette is implemented, Then tests cover filtering, enabled-state behavior, and dispatch through the shared App Action or AppModel paths.
- **AC-021**: Given `openCommandPalette` is added to `AppActionID`, Then the Default Keymap includes exactly one Command-K binding for it and the every-action-mapped keymap test passes.
- **AC-022**: Given a parameterized Palette Item references state that is removed before dispatch, When the user attempts to run it, Then no stale project, session, model, or external target action is dispatched.
- **AC-023**: Given the Command Palette is included in active modal state, When an enabled Static Palette Item is run, Then the palette closes before `performAppAction(_:)` checks availability.
- **AC-024**: Given the Command Palette is already open, When Command-K is pressed again, Then no second palette is stacked and composer text remains unchanged.
- **AC-025**: Given the sidebar would list sessions in running-session-first, newest-first order, When the Command Palette lists session Palette Items, Then their source order matches the sidebar before query ranking is applied.
- **AC-026**: Given there are no `availableModels`, When the Command Palette opens, Then no model Palette Items are shown.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for item construction, filtering, availability, and dispatch; focused AppModel tests for modal interaction; manual UI smoke tests for keyboard navigation and focus.
- **Frameworks**: Swift XCTest in existing SwiftPM test targets.
- **Test Data Management**: Use seeded `AppModel` instances with projects, sessions, available models, external targets, selected project state, active modal state, streaming state, and composer text.
- **Coverage Requirements**: Tests must cover Command-K action metadata, Default Keymap all-action coverage, query filtering order, disabled item non-dispatch, stale parameterized invocation non-dispatch, opening blocked by active modal, closing the palette before dispatch, static App Action dispatch, project selection dispatch, session switching dispatch, model selection dispatch, thinking-level dispatch, and composer text preservation.
- **Performance Testing**: No load testing is required. Item construction and filtering must be synchronous and bounded by the number of known projects, sessions, models, external targets, and static actions.

Suggested focused tests:

- `CommandPaletteItemProviderTests`
- `CommandPaletteFilteringTests`
- `CommandPaletteDispatchTests`
- `CommandPaletteModalTests`
- Update `DefaultKeymapTests` for `.openCommandPalette`, Command-K, conflict checks, and help visibility.

## 7. Rationale & Context

Pi Agent Native already has a centralized App Action path for keybindings, menus, sidebar commands, and many header controls. A Command Palette should make that action surface discoverable and fast without creating a competing command system.

Composer slash commands are prompt text features. The Command Palette is shell UI. Keeping those separate prevents `/skill:` selection, `@` File Mentions, and future composer parsing from becoming coupled to shell actions.

Some requested palette rows are parameterized and are not currently represented by `AppActionID`, such as selecting a specific project or model. Those rows should still use the existing shared AppModel methods from the UI that already performs that behavior. This keeps the implementation pragmatic while leaving room for a richer action registry later.

Command-K is a standard command-palette keybinding and is currently unused by the first Default Keymap. Adding it as an App-Wide Keybinding keeps the palette keyboard-accessible and discoverable in Keybinding Help.

No ADR is required for this issue because the decision is reversible UI/action wiring on top of the existing App Action architecture.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: macOS keyboard event system - Required for the Command-K App-Wide Keybinding and local palette navigation.

### Infrastructure Dependencies

- **INF-001**: Existing AppModel action dispatch - Required for Static Palette Items.
- **INF-002**: Existing Default Keymap registry - Required for keybinding labels and Command-K metadata.
- **INF-003**: Existing project/session stores - Required for project and session Palette Items.
- **INF-004**: Existing model and thinking AppModel methods - Required for model and thinking Palette Items.
- **INF-005**: Existing external target catalog and launcher - Required for Open Externally Palette Items.

### Technology Platform Dependencies

- **PLT-001**: SwiftUI - Required for the palette overlay and rows.
- **PLT-002**: AppKit text input interop - Required to keep composer input separate from palette input.

## 9. Examples & Edge Cases

### Static App Action

```text
Query: log
Result: Open process log    Command-Shift-L
Dispatch: close palette, performAppAction(.openProcessLog)
```

### Parameterized Session Item

```text
Query: auth
Result: Switch session: Fix login auth state
Dispatch: close palette, switchSession(session)
```

### Disabled Item

```text
Query: send
Result: Send prompt    disabled: Enter a prompt and select a project
Return: no dispatch
```

### Composer Separation

```text
Before: composerText = "/skill:diagnose "
Action: open Command Palette, type "settings", Escape
After: composerText = "/skill:diagnose "
```

## 10. Validation Criteria

- `swift test` passes.
- `git diff --check` reports no whitespace errors.
- Command-K appears once in the Default Keymap registry and Keybinding Help.
- The Pi app menu contains one Command Palette item wired to `.openCommandPalette`.
- Every Static Palette Item backed by `AppActionID` dispatches through `performAppAction(_:)`.
- Every Parameterized Palette Item dispatches through the existing shared AppModel method for that behavior.
- Disabled Palette Items are non-runnable.
- Composer slash command, Mention Picker, and Skill Picker tests continue to pass.

## 11. Related Specifications / Further Reading

- [Default Keymap and Keybinding Design](./spec-design-default-keymap.md)
- [Header Control App Action Design](./spec-design-header-actions.md)
- [Skill Selection Command and Picker Design](./spec-design-skill-selection-picker.md)
- [File Mention Picker Design](./spec-design-file-mention-picker.md)

## 12. Implementation Handoff

Likely files and modules:

- `Sources/PiAgentNative/DefaultKeymap.swift`: add `.openCommandPalette`, Command-K metadata, display label coverage, and conflict validation.
- `Sources/PiAgentNative/AppModel.swift`: add palette presentation/query state, item construction, filtered results, dispatch helpers, modal predicates, and the `.openCommandPalette` action case.
- `Sources/PiAgentNative/AppShellView.swift`: render the native overlay, focus its search field, support Escape/Return/Tab/Up/Down/pointer navigation, and keep existing composer pickers isolated.
- `Sources/PiAgentNativeExecutable/PiAgentNativeApp.swift`: add the app menu item that uses `DefaultKeymap` and `.openCommandPalette`.
- `Sources/PiAgentNative/ChatSurfaceView.swift`: reuse existing model, thinking, send/stop, external target, and picker behavior; avoid duplicating dispatch inside palette view code.
- `Tests/PiAgentNativeTests`: add focused command palette tests and update default keymap expectations.

Planner confidence loop:

1. Initial risk: "command palette" could mean slash commands or shell commands. Fixed by domain language and constraints: native Command Palette only, no arbitrary shell execution, no composer mutation.
2. Initial risk: static actions and parameterized rows could fork behavior. Fixed by requiring App Actions through `performAppAction(_:)` and parameterized rows through existing `AppModel` methods.
3. Initial risk: palette modal state could block its own dispatch. Fixed by requiring a palette-specific close-before-dispatch path and an "active modal excluding palette" predicate.
4. Initial risk: session rows could sort differently from the sidebar. Fixed by requiring `sessionsForProject(selectedProject)` as the source.
5. Initial risk: Command-K handling could be implemented outside the keymap/menu source of truth. Fixed by requiring Default Keymap plus app `Commands`, not a second broad keyboard dispatcher.
6. Remaining external limitation: GitHub issue body and project-board mutation were not available from this workspace. The local spec is implementation-ready; the issue tracker still needs the spec link/body update and any status transition performed through the team's GitHub project tooling.
