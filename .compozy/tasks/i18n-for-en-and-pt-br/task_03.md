---
status: pending
title: "Add Language Persistence and Settings Selector"
type: frontend
complexity: medium
dependencies:
  - task_02
---

# Task 03: Add Language Persistence and Settings Selector

## Overview
Add the user-visible language preference required by the PRD. The setting belongs in the configuration modal and should follow the existing `UserDefaults` and `@Published` settings pattern.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST persist selected `AppLanguage` through `UserDefaults`.
- MUST expose selected language through `AppModel`.
- MUST add an English/pt-BR selector to `SettingsSheetView`.
- MUST apply selected locale to SwiftUI rendering where appropriate.
- MUST clean up `UserDefaults` state in tests to avoid cross-test contamination.
</requirements>

## Subtasks
- [ ] 3.1 Add `appLanguage` to `SettingsStore`.
- [ ] 3.2 Add `AppModel` proxy access to the language setting.
- [ ] 3.3 Add a language picker to the configuration modal.
- [ ] 3.4 Apply selected locale to the shell view environment.
- [ ] 3.5 Add persistence and UI-state tests.
- [ ] 3.6 Confirm the fixed-width settings modal handles both language labels.

## Implementation Details
Use the same persistence shape as `customExecutablePath`, `uiFontSize`, `themeFamily`, and `themeVariant`. Keep selector labels app-owned and localizable.

### Relevant Files
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — owner of persisted settings.
- `Sources/PiAgentNative/AppModel.swift` — exposes settings to views.
- `Sources/PiAgentNative/SettingsSheetView.swift` — configuration modal selector location.
- `Sources/PiAgentNative/AppShellView.swift` — likely locale environment application point.
- `Tests/PiAgentNativeCoreTests/SettingsStoreLanguageTests.swift` — new persistence coverage.

### Dependent Files
- `Sources/PiAgentNative/Localization/AppLanguage.swift` — provided by task_02.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — selector copy.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — selector copy.
- `Sources/PiAgentNative/Theme.swift` — existing settings pattern reference.

### Related ADRs
- [ADR-002: Use Complete UI Parity With In-App Language Selection](adrs/adr-002.md) — Requires visible selector.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Requires `UserDefaults`/`@Published` language setting.

## Deliverables
- Persisted app language preference.
- Configuration modal language selector.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for settings-to-rendering state flow **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Missing `appLanguage` defaults to English.
  - [ ] Saved `pt-BR` value loads as Brazilian Portuguese.
  - [ ] Invalid persisted raw value falls back to English.
  - [ ] Setting `appLanguage` writes the expected raw value.
  - [ ] `AppModel.appLanguage` proxies `SettingsStore.appLanguage`.
- Integration tests:
  - [ ] Selected language can drive localized UI text in a representative view/model path.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can choose app language in the configuration modal.
- The selected language persists across app launches.
