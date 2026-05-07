---
title: Header Control App Action Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, header, actions, macos]
---

# Introduction

This specification defines how visible header controls in Pi Agent Native map to concrete app actions. The goal is to remove inert icon controls from the app chrome, wire the sidebar header to Toggle sidebar, Previous Session, and Next Session actions, route all supported header interactions through shared App Action behavior, and make unavailable actions clearly disabled without regressing the existing header layout.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's sidebar titlebar header, chat header, composer toolbar/header area, and any existing visible header-like control that appears as an icon or compact button.

The intended audience is implementation agents and maintainers adding GitHub issue 12: "Add actions to Header buttons".

In scope:

- Auditing visible header controls and identifying which ones are actionable.
- Converting supported icon-only header controls from decorative images to buttons or menus.
- Wiring the sidebar-left icon to Toggle sidebar.
- Wiring the left and right chevrons to Previous Session and Next Session.
- Routing header controls through `AppModel.performAppAction(_:)` or existing centralized app behavior.
- Disabling or hiding controls when their action is unavailable.
- Preserving current header layout, spacing, styling, tooltips, and accessibility expectations.
- Adding focused tests for stateful header actions and availability rules.

Out of scope:

- Introducing project-level navigation history.
- Adding user-customizable header buttons.
- Redesigning the app titlebar or sidebar layout.
- Adding new keyboard shortcuts beyond the existing Default Keymap.
- Replacing already-working composer controls unrelated to inert header controls.

## 2. Definitions

**App Action**: A user-intent command that Pi Agent Native can perform from the UI or keyboard.

**Header Control**: An icon or text control in a window, sidebar, chat, or composer header that invokes one concrete App Action.

**Pane Toggle**: An App Action that shows or hides a persistent shell region such as the sidebar or inspector.

**Open Externally**: An App Action that launches the Selected Project in another app or destination.

**External Target Menu**: The header dropdown that lists available External Targets for Open Externally.

**Selected Project**: The project currently active in Pi Agent Native.

**Selected Session**: The conversation session currently active inside the Selected Project.

**Project Session List**: The ordered list of known sessions for a Selected Project as shown in the sidebar.

**Previous Session**: An App Action that switches from the Selected Session to the preceding session in the Project Session List.

**Next Session**: An App Action that switches from the Selected Session to the following session in the Project Session List.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Every visible Header Control that looks interactive shall either invoke one concrete App Action, open one concrete menu, or be hidden until such behavior exists.
- **REQ-002**: Header Controls shall use centralized app behavior instead of duplicating state mutations in the view layer.
- **REQ-003**: Header Controls backed by an App Action shall call `AppModel.performAppAction(_:)` unless the existing action already has a dedicated shared AppModel method.
- **REQ-004**: Header Controls shall derive enabled or disabled state from `AppModel.canPerformAppAction(_:)` or an equivalent centralized availability predicate.
- **REQ-005**: Disabled Header Controls shall expose a concise help or accessibility hint explaining the unavailable prerequisite.
- **REQ-006**: The sidebar-left icon in the sidebar titlebar shall become a Header Control for the Toggle sidebar Pane Toggle.
- **REQ-007**: The Toggle sidebar Header Control shall use the existing `.toggleSidebar` App Action and preserve the Command-Option-S behavior from the Default Keymap.
- **REQ-008**: The sidebar-left chevron in the sidebar titlebar shall become a Header Control for Previous Session.
- **REQ-009**: The sidebar-right chevron in the sidebar titlebar shall become a Header Control for Next Session.
- **REQ-010**: Previous Session and Next Session shall navigate within the Project Session List for the Selected Project.
- **REQ-011**: Previous Session shall select the session immediately before the Selected Session in the Project Session List.
- **REQ-012**: Next Session shall select the session immediately after the Selected Session in the Project Session List.
- **REQ-013**: Previous Session and Next Session shall not wrap around at the beginning or end of the Project Session List.
- **REQ-014**: Previous Session and Next Session shall switch sessions through the same AppModel session-switching behavior used by selecting a session in the sidebar.
- **REQ-015**: If no Selected Session exists, Previous Session and Next Session shall be disabled.
- **REQ-016**: If the Selected Project has fewer than two known sessions, Previous Session and Next Session shall be disabled.
- **REQ-017**: If the Selected Session is first in the Project Session List, Previous Session shall be disabled.
- **REQ-018**: If the Selected Session is last in the Project Session List, Next Session shall be disabled.
- **REQ-019**: The Project Session List order used by Previous Session and Next Session shall match the order rendered by the sidebar for the Selected Project.
- **REQ-020**: The chat header shall keep the External Target Menu wired to Open Externally behavior.
- **REQ-021**: The External Target Menu shall remain disabled when no Selected Project exists and shall continue to explain that a project must be opened first.
- **REQ-022**: Header Control hover help shall prefer Default Keymap help text when a keybinding exists; controls without keybindings shall still expose action names.
- **REQ-023**: Header Controls shall include accessibility labels that name the invoked action, such as "Toggle sidebar", "Previous session", "Next session", or "Open externally".
- **REQ-024**: Header Control clicks shall respect active modal blocking rules; non-modal actions shall not run while a modal is active.
- **REQ-025**: User-visible failures from header-triggered actions shall use existing status text and process log patterns, not new blocking modals.
- **REQ-026**: Header layout and styling shall remain visually consistent with the existing app chrome.
- **CON-001**: Header Controls must not create behavior that conflicts with the existing Default Keymap specification.
- **CON-002**: Previous Session and Next Session shall not add keyboard shortcuts in this issue.
- **CON-003**: Decorative icons that are not controls must not be styled or placed in a way that implies clickability.
- **CON-004**: Previous Session and Next Session are session-list navigation controls, not project navigation controls and not a browser-like history stack.
- **CON-005**: Do not add `previousSession` or `nextSession` cases to `AppActionID` in this issue unless the Default Keymap invariant is also intentionally changed. The current test suite requires every `AppActionID` case to appear in `DefaultKeymap`, and this issue explicitly forbids new keybindings for Previous Session and Next Session.
- **CON-006**: Previous Session and Next Session shall compute adjacency from the current `sessionsForProject(_:)` result at click time. The implementation shall not introduce a persistent session navigation snapshot or history stack to stabilize ordering.
- **CON-007**: Converting `SidebarTitlebarControls` images to buttons shall preserve the existing titlebar drag and double-click-to-zoom behavior around the controls.
- **PAT-001**: Add a small reusable icon Header Control view when it reduces duplication between sidebar, chat, or composer header controls.
- **PAT-002**: Keep view-specific menu rendering in the view layer, but route menu item selections to shared AppModel methods.
- **GUD-001**: Use SF Symbols that match the App Action and provide `.help` plus accessibility labels for icon-only controls.

## 4. Interfaces & Data Contracts

### Header Control Inventory

The implementation shall audit the current controls and apply this mapping:

| Surface | Current control | Required behavior |
|---|---|---|
| `SidebarTitlebarControls` | `sidebar.left` icon | Convert to a button that calls `.toggleSidebar` |
| `SidebarTitlebarControls` | `chevron.left` icon | Convert to a button that calls Previous Session |
| `SidebarTitlebarControls` | `chevron.right` icon | Convert to a button that calls Next Session |
| `ChatHeaderView` | `ExternalTargetMenuView` | Keep menu wired to `model.openExternally(target)` and disabled without a Selected Project |
| `ComposerView` toolbar | Refresh button | Keep wired to `.refreshState` and disabled when unavailable through centralized action availability |
| `ComposerView` toolbar | Model picker button | Keep wired to `showModelPicker()` and document unavailable states if auth/access work changes the picker |
| `ComposerView` toolbar | Thinking menu | Keep wired to thinking-level AppModel methods |
| `ComposerView` toolbar | Send/stop button | Keep wired to `.sendPrompt` and `.stopGeneration` |

### Reusable Header Control Contract

The implementation may introduce a reusable view equivalent to:

```swift
struct HeaderIconButton: View {
    let systemImage: String
    let actionID: AppActionID?
    let accessibilityLabel: String
    let isEnabled: Bool
    let action: () -> Void
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .disabled(!isEnabled)
        .help(actionID.flatMap { DefaultKeymap.helpText(for: $0, title: accessibilityLabel) } ?? accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}
```

Exact naming and styling may differ, but action routing, availability, help text, and accessibility labels are required.

### Session Navigation Contract

The implementation shall expose AppModel behavior equivalent to:

```swift
func canNavigateToPreviousSession() -> Bool
func canNavigateToNextSession() -> Bool
func navigateToPreviousSession()
func navigateToNextSession()
```

Names may differ, but the behavior must:

- Read the current Selected Project.
- Build the Project Session List using the same ordering as `sessionsForProject(_:)`.
- Find the Selected Session in that ordered list.
- Switch to the adjacent session before or after the current session by calling the same switching path used by sidebar session rows.
- Disable or no-op when there is no adjacent session.

### Availability Contract

Header Controls backed by App Actions shall use these first-version availability rules:

| App Action | Available when |
|---|---|
| Toggle sidebar | No active modal blocks the action |
| Toggle inspector | No active modal blocks the action |
| Previous Session | Selected Project and Selected Session exist, no active modal blocks the action, and an earlier session exists in the Project Session List |
| Next Session | Selected Project and Selected Session exist, no active modal blocks the action, and a later session exists in the Project Session List |
| Refresh state | Selected Project exists and no active modal blocks the action |
| Open Externally | Selected Project exists |
| Send prompt | Existing `canSendPrompt` is true and no active modal blocks the action |
| Stop generation | Streaming is active and no active modal blocks the action |

If an action's existing `canPerformAppAction(_:)` behavior differs, update the central predicate rather than overriding availability inside the header view.

Previous Session and Next Session may be represented as dedicated `AppModel` methods such as `canNavigateToPreviousSession()`, `navigateToPreviousSession()`, `canNavigateToNextSession()`, and `navigateToNextSession()` instead of `AppActionID` cases. This is the preferred first-version approach because the current `AppActionID` enum is coupled to `DefaultKeymap` coverage and these controls intentionally have no first-version keybindings.

## 5. Acceptance Criteria

- **AC-001**: Given the sidebar titlebar renders, When the user clicks the sidebar-left Header Control, Then the sidebar toggles through the `.toggleSidebar` App Action.
- **AC-002**: Given an active modal is open, When the user attempts to invoke the sidebar toggle Header Control, Then the toggle action does not run.
- **AC-003**: Given the sidebar-left Header Control is visible, When the user inspects help or accessibility metadata, Then it identifies "Toggle sidebar" and includes the keybinding help when available.
- **AC-004**: Given the Selected Project has three known sessions and the middle one is selected, When the user clicks the left chevron Header Control, Then the app switches to the previous session in the Project Session List.
- **AC-005**: Given the Selected Project has three known sessions and the middle one is selected, When the user clicks the right chevron Header Control, Then the app switches to the next session in the Project Session List.
- **AC-006**: Given the first session in the Project Session List is selected, When the sidebar titlebar renders, Then Previous Session is disabled and Next Session remains enabled when a next session exists.
- **AC-007**: Given the last session in the Project Session List is selected, When the sidebar titlebar renders, Then Next Session is disabled and Previous Session remains enabled when a previous session exists.
- **AC-008**: Given only one session exists for the Selected Project, When the sidebar titlebar renders, Then both Previous Session and Next Session are disabled.
- **AC-009**: Given no Selected Session exists, When the sidebar titlebar renders, Then Previous Session and Next Session are disabled.
- **AC-010**: Given an active modal is open, When the user attempts Previous Session or Next Session, Then the selected session does not change.
- **AC-011**: Given a Selected Project exists, When the user opens the External Target Menu and chooses a target, Then `model.openExternally(target)` runs and the Selected Project remains unchanged.
- **AC-012**: Given no Selected Project exists, When the chat header renders, Then the External Target Menu is disabled and communicates "Open a project first."
- **AC-013**: Given the composer refresh Header Control is clicked while a Selected Project exists and no modal is active, Then `.refreshState` is dispatched through shared App Action behavior.
- **AC-014**: Given no Selected Project exists, When the refresh Header Control renders, Then it is disabled or otherwise unavailable according to centralized action availability.
- **AC-015**: Given the app is streaming, When the send/stop Header Control is clicked, Then `.stopGeneration` is dispatched and send prompt is not dispatched.
- **AC-016**: Given the app is idle with a valid prompt, When the send/stop Header Control is clicked, Then `.sendPrompt` is dispatched.
- **AC-017**: Given a header-triggered external launch fails, When the failure is handled, Then status text and process log use the existing failure reporting pattern.
- **AC-018**: Given the app renders after implementation, Then no visible header icon remains as an inert decorative control that appears clickable.
- **AC-019**: Given existing header layout snapshots or manual inspection, Then header spacing, sizing, and visual style do not regress.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for AppModel action availability and dispatch; focused SwiftUI/view-model tests where practical; manual UI smoke checks for header layout and click behavior.
- **Frameworks**: XCTest and existing SwiftPM test targets.
- **Test Data Management**: Use seeded `AppModel` instances with selected project, no project, active modal, streaming, and prompt states. Use injected external target launchers for Open Externally failure tests.
- **CI/CD Integration**: Existing `swift test` must pass.
- **Coverage Requirements**: Cover sidebar toggle dispatch, previous/next session availability and dispatch, active-modal blocking, refresh availability, external menu disabled state, send/stop dispatch switching, and external launch failure reporting.
- **Performance Testing**: No dedicated performance testing is required. Header action dispatch must be synchronous and must not perform blocking IO beyond existing AppModel behavior.

## 7. Rationale & Context

Issue 12 says header buttons should not be inert. The current code already wires the chat header External Target Menu to Open Externally and wires composer controls to AppModel behavior, but `SidebarTitlebarControls` renders `sidebar.left`, `chevron.left`, and `chevron.right` as plain images. Those icons look like controls but cannot be clicked.

The sidebar icon has a matching existing App Action, Toggle sidebar, so it should become a real Header Control. The user clarified that the chevrons are Previous Session and Next Session controls. They should navigate through the same ordered session list shown in the sidebar for the Selected Project, not through a separate browser-like history stack. These controls do not introduce first-version keybindings.

The implementation must account for the current session-ordering behavior: `switchSession(_:)` touches the selected session, and `sessionsForProject(_:)` sorts by running state and `updatedAt`. Previous Session and Next Session therefore operate on the current rendered Project Session List at the time of each click. This issue does not change sidebar ordering semantics.

No ADR is required for this version because the decision is reversible UI/action wiring and follows the existing App Action architecture.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: macOS app shell - Provides SwiftUI and AppKit event handling for header controls.

### Infrastructure Dependencies

- **INF-001**: Existing AppModel action dispatch - Header Controls must use shared App Action behavior.
- **INF-002**: Existing Default Keymap registry - Header Control help text should reuse keybinding labels where available.
- **INF-003**: Existing NativeSessionIndexStore session ordering - Previous Session and Next Session must match the sidebar Project Session List.

### Technology Platform Dependencies

- **PLT-001**: SwiftUI Button and Menu controls - Required for accessible header actions.
- **PLT-002**: SF Symbols - Required for existing iconography.

## 9. Examples & Edge Cases

```text
Scenario: Sidebar toggle
1. Sidebar titlebar renders a sidebar-left icon.
2. User clicks the icon.
3. The control calls performAppAction(.toggleSidebar).
4. AppModel toggles isSidebarVisible.
```

```text
Scenario: Previous session
1. Sidebar titlebar renders a left chevron.
2. The Selected Session is not first in the Project Session List.
3. User clicks the left chevron.
4. The app switches to the preceding session in the Project Session List.
```

```text
Scenario: Next session unavailable
1. Sidebar titlebar renders a right chevron.
2. The Selected Session is last in the Project Session List.
3. The right chevron is disabled and explains that there is no next session.
```

```text
Scenario: Modal blocks non-modal action
1. Settings modal is open.
2. User attempts to trigger a header toggle.
3. AppModel.canPerformAppAction returns false.
4. The header action does not mutate pane state.
```

## 10. Validation Criteria

- `swift test` passes.
- Tests prove Header Controls use centralized App Action availability where stateful.
- Tests prove sidebar toggle, Previous Session, and Next Session dispatch are blocked while a modal is active.
- Tests prove Previous Session and Next Session use the Project Session List order and disable at list boundaries.
- Tests prove Previous Session and Next Session do not require new `AppActionID` or `DefaultKeymap` entries.
- Manual UI validation confirms visible header controls are clickable, disabled with explanation, or hidden.
- Manual UI validation confirms header layout and styling remain consistent.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [spec-design-default-keymap.md](spec-design-default-keymap.md)
- [spec-design-open-externally.md](spec-design-open-externally.md)
