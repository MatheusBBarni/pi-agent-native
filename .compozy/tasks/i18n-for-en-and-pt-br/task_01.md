---
status: pending
title: "Add SwiftPM Localization Resources"
type: infra
complexity: medium
dependencies: []
---

# Task 01: Add SwiftPM Localization Resources

## Overview
Add the base localization resource structure required by the TechSpec. This task makes `PiAgentNativeCore` capable of loading English and Brazilian Portuguese resources through SwiftPM before any UI surface is migrated.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST add English and pt-BR localization resource directories for the core target.
- MUST wire SwiftPM resource processing for `PiAgentNativeCore`.
- MUST include `.strings` resources and only add `.stringsdict` entries for count-sensitive strings.
- MUST keep resource locale names consistent with the selected `AppLanguage` raw values.
- MUST provide a minimal resource lookup test that proves resources are available from the core target.
</requirements>

## Subtasks
- [ ] 1.1 Add `en.lproj` and `pt-BR.lproj` resource directories under the core target.
- [ ] 1.2 Add initial `Localizable.strings` files for both languages.
- [ ] 1.3 Add initial `.stringsdict` files only for planned plural/count keys.
- [ ] 1.4 Update SwiftPM package configuration so the core target processes resources.
- [ ] 1.5 Add a minimal resource availability test.
- [ ] 1.6 Run the focused resource test and confirm the full package still builds.

## Implementation Details
Create the resource structure described in the TechSpec "Data Models" section. Attach `Sources/PiAgentNative/Resources` to the `PiAgentNativeCore` target in `Package.swift`.

### Relevant Files
- `Package.swift` — currently has no `defaultLocalization` or target resources.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — new English localization resource.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — new Brazilian Portuguese localization resource.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.stringsdict` — new count-sensitive English resource if needed.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.stringsdict` — new count-sensitive pt-BR resource if needed.
- `Tests/PiAgentNativeCoreTests/LocalizationTests.swift` — new resource lookup coverage.

### Dependent Files
- `Sources/PiAgentNative/Localization/L10n.swift` — task_02 depends on `Bundle.module` resource availability.
- `Scripts/build-app.sh` — task_10 packages the SwiftPM-generated resource bundle.
- `Sources/PiAgentNativeExecutable/PiAgentNativeApp.swift` — executable target will need public core localization access.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Defines supported languages and app-owned scope.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Requires native `.strings` and `.stringsdict` resources.
- [ADR-004: Use Warning-Based Coverage Checks and SwiftPM Resource Bundle Packaging](adrs/adr-004.md) — Requires SwiftPM resource bundle packaging later.

## Deliverables
- SwiftPM resource configuration for `PiAgentNativeCore`.
- Initial `en` and `pt-BR` localization resources.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for core resource availability **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] English `Localizable.strings` contains a known smoke-test key.
  - [ ] pt-BR `Localizable.strings` contains the same smoke-test key.
  - [ ] Optional `.stringsdict` resources load when plural keys exist.
- Integration tests:
  - [ ] `Bundle.module` can resolve the known key from the processed core target resources.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `swift build` succeeds with processed localization resources.
- The core target can load English and pt-BR resources without UI changes.
