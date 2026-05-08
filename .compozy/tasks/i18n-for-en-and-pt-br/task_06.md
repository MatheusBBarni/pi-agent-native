---
status: pending
title: "Localize App Actions, Menus, and Command Palette"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 06: Localize App Actions, Menus, and Command Palette

## Overview
Localize app action labels, Default Keymap titles/help, sidebar commands, menu labels, and command palette app-owned rows. This task must preserve stable identifiers and key equivalents.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize user-facing app action titles and help groups.
- MUST preserve `AppActionID`, keybinding identities, scopes, and shortcut labels.
- MUST localize sidebar command titles and menu labels.
- MUST localize command palette app-owned titles, subtitles, keywords, and disabled reasons.
- MUST preserve project/session names, model IDs, provider names, external app names, and paths verbatim.
</requirements>

## Subtasks
- [ ] 6.1 Localize Default Keymap display labels without changing key equivalents.
- [ ] 6.2 Localize Keybinding Help group and action titles.
- [ ] 6.3 Localize sidebar command labels and hover help.
- [ ] 6.4 Localize macOS command menu labels and fallbacks.
- [ ] 6.5 Localize command palette static rows and disabled reasons.
- [ ] 6.6 Add tests for stable keybinding identity and localized labels.

## Implementation Details
Do not localize enum raw values used for identity. Add localized display accessors while keeping raw identifiers stable.

### Relevant Files
- `Sources/PiAgentNative/DefaultKeymap.swift` — app action titles, help groups, and help formatting.
- `Sources/PiAgentNative/AppShellView.swift` — sidebar commands and keybinding help view.
- `Sources/PiAgentNative/AppModel.swift` — command palette rows and disabled reasons.
- `Sources/PiAgentNative/CommandPalette.swift` — palette item display/search model.
- `Sources/PiAgentNativeExecutable/PiAgentNativeApp.swift` — macOS menu labels.
- `Sources/PiAgentNative/ExternalTargets.swift` — external target names stay verbatim.

### Dependent Files
- `Tests/PiAgentNativeTests/DefaultKeymapTests.swift` — exact keymap copy tests.
- `Tests/PiAgentNativeTests/CommandPaletteTests.swift` — palette filtering/disabled reason tests.
- `Tests/PiAgentNativeTests/HeaderActionTests.swift` — previous/next help text tests.
- `Tests/PiAgentNativeTests/InspectorPaneToggleTests.swift` — `DefaultKeymap.helpText` dependency.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Defines app-owned UI and verbatim values.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Defines lookup approach.

## Deliverables
- Localized app action, menu, sidebar, and command palette copy.
- Stable keybinding identity and shortcut behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for localized command palette and menu-facing labels **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Keybinding shortcut labels remain `Command-N`, `Command-O`, etc.
  - [ ] English app action title lookup matches current labels.
  - [ ] pt-BR app action title lookup returns translated labels.
  - [ ] Help text combines localized title with unchanged shortcut label.
  - [ ] Command palette disabled reason localizes while invocation stays unchanged.
- Integration tests:
  - [ ] Command palette filtering still finds localized app-owned rows without mutating project/session/model values.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Menus, sidebar commands, keybinding help, and command palette app-owned rows localize.
- Stable IDs and key equivalents remain unchanged.
