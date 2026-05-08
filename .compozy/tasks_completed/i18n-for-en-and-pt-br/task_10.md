---
status: completed
title: "Package Localization Resources in App Bundle"
type: infra
complexity: medium
dependencies:
    - task_01
---

# Task 10: Package Localization Resources in App Bundle

## Overview
Update manual app bundling so the clickable `.app` includes SwiftPM localization resources. This prevents `swift test` and `swift run` from passing while the packaged app cannot load translations.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST copy the SwiftPM-generated resource bundle into `Contents/Resources`.
- MUST NOT copy raw `.lproj` directories as the primary packaging strategy.
- MUST support debug and release build configurations.
- MUST preserve the existing `.build/Pi Agent.app` bundle path with a space in the name.
- MUST verify packaged app resources after bundling.
</requirements>

## Subtasks
- [x] 10.1 Discover the generated SwiftPM resource bundle after build.
- [x] 10.2 Copy the resource bundle into `Contents/Resources`.
- [x] 10.3 Add localization metadata to generated `Info.plist` if required.
- [x] 10.4 Verify debug and release packaging paths.
- [x] 10.5 Add or document a packaged-resource verification check.

## Implementation Details
Follow ADR-004: package the SwiftPM-generated bundle so `Bundle.module` lookup matches runtime expectations. Avoid hard-coded paths that break across build configurations when discoverable alternatives exist.

### Relevant Files
- `Scripts/build-app.sh` — manual `.app` assembly.
- `Package.swift` — resource bundle exists after task_01.
- `README.md` — documents build script usage.
- `.compozy/tasks/i18n-for-en-and-pt-br/_techspec.md` — packaging requirement.

### Dependent Files
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — packaged resource content.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — packaged resource content.
- `.build/Pi Agent.app/Contents/Resources` — generated verification target.

### Related ADRs
- [ADR-004: Use Warning-Based Coverage Checks and SwiftPM Resource Bundle Packaging](adrs/adr-004.md) — Requires SwiftPM resource bundle copying.

## Deliverables
- Updated app bundle script.
- Packaged resource verification.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for packaged app resource presence **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Script path handling preserves `.build/Pi Agent.app`.
  - [ ] Resource bundle discovery handles debug build output.
- Integration tests:
  - [ ] `rtk ./Scripts/build-app.sh` creates a `.app` with the SwiftPM resource bundle.
  - [ ] `rtk ./Scripts/build-app.sh release` creates a release `.app` with the SwiftPM resource bundle.
  - [ ] Packaged `Contents/Resources` contains `Localizable.strings` through the copied bundle.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Packaged debug and release apps contain localization resources.
- The build script continues to package the executable and icon correctly.
