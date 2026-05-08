---
status: pending
title: "Complete Localization Verification Sweep"
type: chore
complexity: high
dependencies:
  - task_04
  - task_05
  - task_06
  - task_07
  - task_08
  - task_09
  - task_10
---

# Task 11: Complete Localization Verification Sweep

## Overview
Complete the cross-surface localization verification pass after all implementation slices are in place. This task ensures exact-English tests have been updated responsibly, warning coverage is visible, and V1 surfaces meet the PRD quality gate.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST preserve behavior assertions while moving copy assertions to localized expectations.
- MUST verify missing-key warnings are produced and reviewed without failing by default.
- MUST confirm app-owned V1 surfaces have English and pt-BR coverage.
- MUST verify technical/user/generated content remains verbatim in representative flows.
- MUST run full Swift test and packaged app resource verification.
</requirements>

## Subtasks
- [ ] 11.1 Review all exact-English assertions touched by localization.
- [ ] 11.2 Add representative locale tests for each V1 surface group.
- [ ] 11.3 Run required-key warning coverage and record warnings for maintainer review.
- [ ] 11.4 Verify verbatim technical boundaries in auth, chat, logs, paths, diffs, and RPC/tool output.
- [ ] 11.5 Run full automated verification and package-resource check.
- [ ] 11.6 Prepare the maintainer and AI-assisted review checklist.

## Implementation Details
This is the final integration and verification task, not a substitute for tests in earlier tasks. Keep changes limited to test coverage gaps, required-key inventory gaps, verification documentation, and small fixes needed to complete the release gate.

### Relevant Files
- `.compozy/tasks/i18n-for-en-and-pt-br/_prd.md` — quality and scope requirements.
- `.compozy/tasks/i18n-for-en-and-pt-br/_techspec.md` — final verification requirements.
- `Tests/PiAgentNativeCoreTests/LocalizationTests.swift` — representative lookup coverage.
- `Tests/PiAgentNativeCoreTests/LocalizationCoverageTests.swift` — warning coverage.
- `Tests/PiAgentNativeCoreTests/SettingsStoreLanguageTests.swift` — persistence coverage.
- `Tests/PiAgentNativeTests/DefaultKeymapTests.swift` — exact-English keymap updates.
- `Tests/PiAgentNativeTests/CommandPaletteTests.swift` — command palette copy and behavior.
- `Tests/PiAgentNativeCoreTests/SubscriptionLoginStatusSummaryTests.swift` — auth copy and verbatim provider values.

### Dependent Files
- `Package.swift` — resource processing must be complete.
- `Scripts/build-app.sh` — packaged resource verification depends on task_10.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — coverage target.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — coverage target.
- `Sources/PiAgentNative/Resources/*/Localizable.stringsdict` — plural coverage target.
- `Sources/PiAgentNative/AppModel.swift` — representative assignment-time strings.
- `Sources/PiAgentNative/ChatSurfaceView.swift` — representative UI boundary checks.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Complete app-owned UI and verbatim boundary.
- [ADR-002: Use Complete UI Parity With In-App Language Selection](adrs/adr-002.md) — Configuration-modal language selector and quality gate.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Assignment-time stale-state acceptance.
- [ADR-004: Use Warning-Based Coverage Checks and SwiftPM Resource Bundle Packaging](adrs/adr-004.md) — Warning coverage and packaging.

## Deliverables
- Updated localization verification tests and checklist.
- Missing-key warning output ready for maintainer review.
- Packaged app resource verification evidence.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for final localization and packaging verification **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Localization lookup tests pass for English and pt-BR.
  - [ ] Coverage reporter emits warnings for intentionally missing keys.
  - [ ] Exact-English assertions are replaced with language-scoped expectations where appropriate.
  - [ ] Verbatim boundary tests pass for provider names, URLs, paths, model IDs, prompts, assistant text, diffs, logs, and tool output.
- Integration tests:
  - [ ] `rtk swift test` passes.
  - [ ] `rtk ./Scripts/build-app.sh debug` packages localization resources.
  - [ ] Required-key warning output is reviewed and does not hide launch-blocking omissions.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Full test suite passes with localized resources enabled.
- Packaged app contains the SwiftPM resource bundle.
- Maintainer review has enough warning and surface-inventory evidence to decide release readiness.
