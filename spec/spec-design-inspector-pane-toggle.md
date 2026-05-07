---
title: Inspector Pane Toggle Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, inspector, pane-toggle, macos]
---

# Introduction

This specification defines the collapse and expand behavior for Pi Agent Native's Inspector. The goal is to let users reclaim horizontal space while keeping the Inspector easy to restore and preserving the existing App Action, Default Keymap, and shell layout behavior.

## 1. Purpose & Scope

This specification applies to the macOS app shell, chat header, Inspector region, AppModel pane state, and tests for the Inspector Pane Toggle.

The intended audience is implementation agents and maintainers adding GitHub issue 13: "Add collapse/expand button in Right Sidebar".

In scope:

- Add a visible Header Control that toggles the Inspector.
- Use the existing `.toggleInspector` App Action for all Inspector collapse and expand behavior.
- Keep the toggle discoverable when the Inspector is hidden.
- Resize the main chat surface cleanly when the Inspector is hidden or shown.
- Preserve Inspector contents and behavior when expanded.
- Preserve Inspector visibility state across in-app project/session navigation during the current launch.
- Add focused tests for action routing, availability, and state preservation.

Out of scope:

- Persisting Inspector visibility across app launches in this issue.
- Renaming source files or UI types from `InspectorView`.
- Redesigning Inspector content.
- Adding new keybindings beyond the existing Command-Option-I Default Keymap entry.
- Adding user-customizable pane layout, split-view resizing, or draggable widths.
- Changing left sidebar behavior except where shared Header Control styling is reused.

## 2. Definitions

**App Action**: A user-intent command that Pi Agent Native can perform from the UI or keyboard.

**Header Control**: An icon or text control in a window, sidebar, chat, or composer header that invokes one concrete App Action.

**Pane Toggle**: An App Action that shows or hides a persistent shell region such as the sidebar or inspector.

**Inspector**: The persistent right-side shell region that shows project, process, model, and tool activity context for the current conversation.

**Selected Project**: The project currently active in Pi Agent Native.

**Selected Session**: The conversation session currently active inside the Selected Project.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall provide a visible Header Control for toggling the Inspector.
- **REQ-002**: The Inspector Header Control shall remain visible and operable when the Inspector is hidden.
- **REQ-003**: The Inspector Header Control shall call `AppModel.performAppAction(.toggleInspector)`.
- **REQ-004**: Inspector visibility shall continue to be stored in `AppModel.isInspectorVisible`.
- **REQ-005**: The Header Control enabled state shall derive from `AppModel.canPerformAppAction(.toggleInspector)`.
- **REQ-006**: When an active modal blocks non-modal App Actions, the Inspector Header Control shall be disabled or no-op through centralized action availability.
- **REQ-007**: The Header Control shall communicate whether activating it will show or hide the Inspector through dynamic accessibility text and at least one visible state change, such as distinct tint, selected background, pressed appearance, or distinct SF Symbol. It must not render identical visible states for shown and hidden Inspector states.
- **REQ-008**: The Header Control shall expose an accessibility label that describes the next action, such as "Hide inspector" when visible and "Show inspector" when hidden.
- **REQ-009**: The Header Control help text shall include the existing Toggle inspector action name and should include the Command-Option-I keybinding when available from `DefaultKeymap`.
- **REQ-010**: Hiding the Inspector shall remove the Inspector region from the shell layout so the chat surface expands into the reclaimed horizontal space.
- **REQ-011**: Showing the Inspector shall restore the existing Inspector region at its current fixed width unless a separate future resizing feature changes pane widths.
- **REQ-012**: Toggling the Inspector shall not change the Selected Project, Selected Session, conversation messages, composer text, streaming state, tool activity, process log, model selection, thinking level, or left sidebar visibility.
- **REQ-013**: Inspector content shall remain unchanged when the Inspector is shown again after being hidden.
- **REQ-014**: Inspector visibility shall be preserved across project selection and session switching within the same app launch.
- **REQ-015**: Inspector visibility shall not be added to `SessionStore` persistence in this issue because existing pane visibility is runtime UI state.
- **REQ-016**: The implementation shall not introduce a second concept named "right sidebar"; user-facing and implementation-facing design language shall use Inspector.
- **REQ-017**: The existing Command-Option-I keybinding and menu command shall continue to toggle the same Inspector state as the Header Control.
- **CON-001**: The Inspector Header Control must not duplicate state mutation in the view layer.
- **CON-002**: The collapsed Inspector state is runtime shell layout state for this issue.
- **CON-003**: The Header Control must not be placed only inside the Inspector, because that would make it unavailable when the Inspector is hidden.
- **CON-004**: The shell must remain usable at supported window widths when the Inspector is hidden or shown.
- **PAT-001**: Place the Inspector Header Control in the chat header trailing area near the existing External Target Menu so it remains visible in both states.
- **PAT-002**: Reuse a shared icon Header Control component if issue 12 introduced one; otherwise keep the implementation local and small.
- **PAT-003**: Prefer SF Symbols that match the current shell style, such as a right-sidebar symbol, and use Theme colors consistent with existing header controls.

## 4. Interfaces & Data Contracts

### Current Code Mapping

| Component | Existing state | Required issue 13 behavior |
|---|---|---|
| `AppModel.isInspectorVisible` | Runtime boolean defaults to `true` | Remains the source of truth for Inspector visibility |
| `AppModel.performAppAction(.toggleInspector)` | Toggles `isInspectorVisible` | Used by the new Header Control |
| `AppModel.canPerformAppAction(.toggleInspector)` | Returns false when an active modal blocks non-modal actions | Used to enable or disable the new Header Control |
| `DefaultKeymap` | Defines Toggle inspector as Command-Option-I | Remains the keyboard path for the same App Action |
| `AppShellView` | Conditionally renders `InspectorView` at width 280 | Continues to remove or restore `InspectorView` based on `isInspectorVisible` |
| `ChatHeaderView` | Renders title, status, spacer, and `ExternalTargetMenuView` | Adds an Inspector Header Control near the trailing controls |
| `InspectorView` | Renders branch details and tool activity | Content and behavior remain unchanged |
| `SessionStore` | Persists projects, sessions, selected project, selected session | Does not persist Inspector visibility in this issue |

### Header Control Contract

The implementation shall provide behavior equivalent to:

```swift
Button {
    model.performAppAction(.toggleInspector)
} label: {
    Image(systemName: "sidebar.right")
        .foregroundStyle(model.isInspectorVisible ? Theme.secondaryText : Theme.accent)
}
.disabled(!model.canPerformAppAction(.toggleInspector))
.help(DefaultKeymap.helpText(for: .toggleInspector, title: "Toggle inspector") ?? "Toggle inspector")
.accessibilityLabel(model.isInspectorVisible ? "Hide inspector" : "Show inspector")
```

Exact symbol names and styling may differ, but action routing, centralized availability, discoverability while hidden, dynamic accessibility labels, and a visible difference between shown and hidden states are required.

### State Contract

`isInspectorVisible` shall behave as runtime shell state:

```text
Initial launch: true
Header Control click while visible: false
Header Control click while hidden: true
Command-Option-I while visible: false
Command-Option-I while hidden: true
Project/session navigation after hiding: remains false
New app launch: true, unless a future pane-persistence feature changes the contract
```

## 5. Acceptance Criteria

- **AC-001**: Given the Inspector is visible, When the user activates the Inspector Header Control, Then the app dispatches `.toggleInspector` and hides the Inspector.
- **AC-002**: Given the Inspector is hidden, When the user activates the Inspector Header Control, Then the app dispatches `.toggleInspector` and shows the Inspector.
- **AC-003**: Given the Inspector is hidden, When the chat header renders, Then the Inspector Header Control remains visible and discoverable.
- **AC-004**: Given the Inspector visibility changes, When the shell lays out, Then the chat surface expands or contracts without overlapping, clipping, or leaving an unusable blank pane.
- **AC-005**: Given the Inspector Header Control renders, When accessibility metadata is inspected, Then the label describes the next action: "Hide inspector" or "Show inspector".
- **AC-006**: Given the user uses Command-Option-I, When the keybinding dispatches, Then it toggles the same `isInspectorVisible` state as the Header Control.
- **AC-007**: Given a modal is active, When the user attempts to use the Inspector Header Control, Then Inspector visibility does not change.
- **AC-008**: Given the Inspector is hidden, When the user switches projects or sessions inside the current launch, Then the Inspector remains hidden.
- **AC-009**: Given the Inspector is hidden, When the user shows it again, Then branch details, process/model status, pending message count, and tool activity render through the existing Inspector content.
- **AC-010**: Given the Inspector is toggled, Then Selected Project, Selected Session, messages, composer text, streaming state, model name, thinking level, tool activity, process log, and left sidebar visibility are unchanged.
- **AC-011**: Given the app relaunches after issue 13, Then Inspector visibility starts from the existing default behavior and is not read from `SessionStore`.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for AppModel state and action availability; optional SwiftUI inspection or manual UI smoke checks for header placement and layout.
- **Frameworks**: XCTest using the existing SwiftPM test target.
- **Test Data Management**: Use seeded `AppModel` instances with projects, sessions, messages, composer text, streaming state, tool activity, and modal state.
- **CI/CD Integration**: Existing `swift test` must pass.
- **Coverage Requirements**:
  - Test `.toggleInspector` flips `isInspectorVisible` from true to false and false to true.
  - Test active modal state blocks `.toggleInspector`.
  - Test Inspector toggling preserves unrelated AppModel state.
  - Test project/session switching does not reset `isInspectorVisible`.
  - Test `AppPersistedState` does not gain an Inspector visibility field in this issue.
- **Performance Testing**: No dedicated performance test is required. The toggle must be synchronous and must not perform IO.

## 7. Rationale & Context

Issue 13 uses the phrase "right sidebar". The repository's code and documentation use `InspectorView`, `.toggleInspector`, and "inspector" for the persistent right-side region. The specification therefore resolves the feature to the Inspector and avoids introducing a second domain term.

The app already has a centralized App Action for Inspector visibility and a Default Keymap entry, so the lowest-risk implementation is a discoverable Header Control that dispatches the existing `.toggleInspector` action. Placing the control in the chat header keeps it reachable while the Inspector is collapsed. Placing it inside `InspectorView` would make expand impossible without relying on the keyboard shortcut.

Pane visibility is currently runtime UI state. `SessionStore` persists project and session sidebar state, but not left sidebar or Inspector visibility. Issue 13 should preserve the collapsed Inspector across in-app navigation because `AppModel` owns that state for the current launch, but it should not add launch persistence unless a future pane layout persistence feature changes the broader behavior.

No ADR is required because this is reversible UI/action wiring that follows the existing App Action model.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: macOS SwiftUI shell - Required for Header Control rendering, accessibility labels, and layout updates.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: Existing AppModel action dispatch - Required for `.toggleInspector`.
- **INF-002**: Existing Default Keymap registry - Required for Command-Option-I and help text.
- **INF-003**: Existing AppShellView layout - Required for conditional Inspector rendering.

### Data Dependencies

- **DAT-001**: None. This issue must not add persisted pane layout data.

### Technology Platform Dependencies

- **PLT-001**: macOS 14 or newer - Required platform for Pi Agent Native.
- **PLT-002**: SwiftUI Button and SF Symbols - Required for native header control behavior and iconography.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Scenario: Collapse from header
1. Inspector is visible.
2. User activates the trailing chat-header Inspector control.
3. The control calls performAppAction(.toggleInspector).
4. AppModel sets isInspectorVisible to false.
5. AppShellView stops rendering InspectorView and the chat surface expands.
```

```text
Scenario: Expand after collapse
1. Inspector is hidden.
2. The trailing chat-header Inspector control is still visible.
3. User activates the control.
4. AppModel sets isInspectorVisible to true.
5. AppShellView renders InspectorView at the existing width.
```

```text
Scenario: Modal blocks pane toggle
1. Settings modal is open.
2. User attempts to activate the Inspector Header Control.
3. canPerformAppAction(.toggleInspector) is false.
4. Inspector visibility is unchanged.
```

```text
Scenario: Navigation preserves runtime collapse
1. Inspector is hidden.
2. User switches from one session to another.
3. isInspectorVisible remains false.
4. User can still restore the Inspector from the chat header or Command-Option-I.
```

## 10. Validation Criteria

- The spec file exists at `spec/spec-design-inspector-pane-toggle.md`.
- `CONTEXT.md` resolves "right sidebar" to Inspector.
- The new control dispatches `.toggleInspector` rather than mutating `isInspectorVisible` directly in the view.
- The control remains visible when `isInspectorVisible == false`.
- Active modal state blocks the control through `canPerformAppAction`.
- Command-Option-I and the Header Control use the same AppModel state.
- Inspector toggling preserves unrelated model state.
- Inspector visibility remains runtime-only and is not added to `AppPersistedState`.
- `swift test` passes after implementation.
- Manual UI smoke testing confirms no overlap or clipped content when toggling at normal desktop window sizes.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [spec-design-default-keymap.md](spec-design-default-keymap.md)
- [spec-design-header-actions.md](spec-design-header-actions.md)
- [GitHub issue 13: Add collapse/expand button in Right Sidebar](https://github.com/MatheusBBarni/pi-agent-native/issues/13)
