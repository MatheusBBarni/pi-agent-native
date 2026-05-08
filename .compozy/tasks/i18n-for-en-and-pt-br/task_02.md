---
status: pending
title: "Add Core Localization API and Coverage Warnings"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Add Core Localization API and Coverage Warnings

## Overview
Create the core localization API that all later tasks depend on. This task introduces supported language modeling, localized string lookup, required-key inventory, and warning-based missing-key coverage.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST create `AppLanguage` with `en` and `pt-BR` identifiers.
- MUST create a localization facade that can force lookup for a selected language.
- MUST make localization API usable from `PiAgentNativeExecutable`.
- MUST create a required-key inventory and coverage reporter that returns warnings without failing by default.
- MUST preserve technical/user/generated content by leaving interpolation values unchanged.
</requirements>

## Subtasks
- [ ] 2.1 Add `AppLanguage` supported-language model.
- [ ] 2.2 Add the `L10n` facade for selected-language lookup.
- [ ] 2.3 Add required-key inventory for app-owned strings.
- [ ] 2.4 Add a warning-returning coverage reporter for missing keys.
- [ ] 2.5 Add tests for language metadata, lookup, formatting, and warnings.
- [ ] 2.6 Document the verbatim interpolation boundary in code comments only where needed.

## Implementation Details
Follow the TechSpec "Core Interfaces" section, but ensure selected-language lookup resolves the language-specific `.lproj` bundle before calling localized lookup. The API should be public where executable-target menu code needs it.

### Relevant Files
- `Sources/PiAgentNative/Localization/AppLanguage.swift` — new supported language type.
- `Sources/PiAgentNative/Localization/L10n.swift` — new selected-language lookup facade.
- `Sources/PiAgentNative/Localization/LocalizationRequiredKeys.swift` — new required-key inventory.
- `Sources/PiAgentNative/Localization/LocalizationCoverageReporter.swift` — new warning-based coverage reporter.
- `Tests/PiAgentNativeCoreTests/LocalizationTests.swift` — lookup and formatting tests.
- `Tests/PiAgentNativeCoreTests/LocalizationCoverageTests.swift` — missing-key warning tests.

### Dependent Files
- `Package.swift` — must already expose `Bundle.module` resources from task_01.
- `Sources/PiAgentNative/Settings/SettingsStore.swift` — task_03 persists `AppLanguage`.
- `Sources/PiAgentNativeExecutable/PiAgentNativeApp.swift` — later menu localization needs public API.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Defines verbatim technical boundary.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Defines selected-language facade and assignment-time strategy.
- [ADR-004: Use Warning-Based Coverage Checks and SwiftPM Resource Bundle Packaging](adrs/adr-004.md) — Defines warning-based coverage.

## Deliverables
- Core localization model and facade.
- Required-key warning reporter.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for selected-language resource lookup **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `AppLanguage` exposes stable `en` and `pt-BR` identifiers.
  - [ ] English lookup returns the English value for a known key.
  - [ ] pt-BR lookup returns the pt-BR value for a known key.
  - [ ] Formatting preserves raw interpolation values.
  - [ ] Missing required keys return structured warnings by language and key.
- Integration tests:
  - [ ] Coverage reporter reads actual processed resources from `Bundle.module`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Later tasks can localize app-owned strings through one shared API.
- Missing-key warnings are visible and non-failing by default.
