---
status: pending
title: "Localize Auth and Login Surfaces"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 05: Localize Auth and Login Surfaces

## Overview
Localize security-sensitive auth, subscription, login, and model-picker copy. This task must keep provider names, URLs, raw command output, and error payloads verbatim while translating app-owned framing.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize `AuthAccessState` app-owned messages.
- MUST localize `SubscriptionLoginStatusSummary` templates while preserving provider names and URLs.
- MUST localize `LoginSheetView` and model picker app-owned controls/labels.
- MUST preserve OAuth output, provider login URLs, provider names, model IDs, and error payloads verbatim.
- MUST include tests for security-sensitive interpolation boundaries.
</requirements>

## Subtasks
- [ ] 5.1 Localize model and subscription access state copy.
- [ ] 5.2 Localize subscription login status title/detail templates.
- [ ] 5.3 Localize login sheet labels, buttons, tabs, and helper text.
- [ ] 5.4 Localize model picker empty states and controls.
- [ ] 5.5 Preserve provider names, URLs, output, and errors as raw interpolation.
- [ ] 5.6 Update auth/login tests for both languages and verbatim values.

## Implementation Details
Auth copy is a launch-quality surface. Prefer explicit keys for each state rather than broad string reuse that could blur consent or failure semantics.

### Relevant Files
- `Sources/PiAgentNative/AuthAccessState.swift` — access and model-picker empty copy.
- `Sources/PiAgentNative/Auth/SubscriptionLoginStatusSummary.swift` — subscription login status copy.
- `Sources/PiAgentNative/LoginSheetView.swift` — login modal and model picker UI.
- `Sources/PiAgentNative/Auth/LoginProviderCatalog.swift` — provider names must stay verbatim.
- `Sources/PiAgentNative/AuthStore.swift` — OAuth output and URL handling must stay verbatim.
- `Tests/PiAgentNativeCoreTests/SubscriptionLoginStatusSummaryTests.swift` — exact status summary tests.
- `Tests/PiAgentNativeCoreTests/AuthAccessStateTests.swift` — access-state tests.

### Dependent Files
- `Sources/PiAgentNative/AppModel.swift` — login/access status assignments and logs.
- `Tests/PiAgentNativeCoreTests/OAuthLoginRunnerTests.swift` — raw output and URL behavior.
- `Tests/PiAgentNativeTests/SubscriptionLoginAppModelTests.swift` — app model login refresh behavior.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — auth keys.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — auth keys.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Auth UI localizes; technical artifacts do not.
- [ADR-002: Use Complete UI Parity With In-App Language Selection](adrs/adr-002.md) — Requires quality gate for complete parity.

## Deliverables
- Localized auth and login UI copy.
- Verbatim-preservation tests for provider names, URLs, output, and errors.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for login/model-picker localized states **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Not-started subscription login status localizes template in English and pt-BR.
  - [ ] Provider name remains unchanged inside localized status.
  - [ ] Provider Login URL remains unchanged inside localized UI.
  - [ ] Failure message payload remains unchanged.
  - [ ] Model picker empty states localize app-owned text.
- Integration tests:
  - [ ] Login sheet selected language changes app-owned controls but not provider names/output.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Auth and login surfaces are localized in both languages.
- Security-sensitive technical values remain exact.
