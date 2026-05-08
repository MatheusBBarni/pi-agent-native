---
status: pending
title: "Localize Extension Dialog Controls"
type: frontend
complexity: low
dependencies:
  - task_02
---

# Task 09: Localize Extension Dialog Controls

## Overview
Localize only app-owned controls in extension UI dialogs. RPC-provided titles, messages, defaults, options, and response payloads must stay verbatim.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize app-owned controls such as Cancel, Selection, Confirm, Submit, and help/accessibility strings.
- MUST preserve `PiExtensionUIRequest` title, message, default value, and option labels verbatim.
- MUST preserve extension response payload semantics.
- SHOULD treat protocol-ish cancellation messages carefully and avoid localizing them unless proven app-owned.
- MUST add regression coverage for RPC-owned text preservation.
</requirements>

## Subtasks
- [ ] 9.1 Localize extension dialog control labels and help text.
- [ ] 9.2 Verify RPC-provided title/message/default/options remain raw.
- [ ] 9.3 Verify submitted and cancelled response payloads remain protocol-compatible.
- [ ] 9.4 Add focused tests for localized controls and verbatim request content.

## Implementation Details
Keep this task narrow. It depends on the core localization API but not the settings selector because tests can inject or call the facade directly.

### Relevant Files
- `Sources/PiAgentNative/ExtensionUI/ExtensionUIDialogs.swift` — app-owned dialog controls.
- `Sources/PiAgentNative/RPC/PiRPCModels.swift` — RPC-owned request values.
- `Sources/PiAgentNative/ExtensionUI/ExtensionUIRouter.swift` — request routing and cancellation.
- `Sources/PiAgentNative/AppModel.swift` — extension UI submit/cancel handling.
- `Sources/PiAgentNative/RPC/PiRPCCommand.swift` — response command payloads.
- `Tests/PiAgentNativeCoreTests/RPCTests.swift` — extension UI reducer coverage.

### Dependent Files
- `Sources/PiAgentNative/AppShellView.swift` — presents extension dialogs.
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings` — dialog control keys.
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings` — dialog control keys.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — RPC/tool content remains verbatim.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Defines localization lookup approach.

## Deliverables
- Localized app-owned extension dialog controls.
- Tests proving RPC request content and response payloads remain unchanged.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for extension dialog request/response boundary **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Cancel/Selection/Confirm/Submit controls resolve in both languages.
  - [ ] RPC title and message remain unchanged with pt-BR selected.
  - [ ] RPC default value and option labels remain unchanged.
  - [ ] Cancel response payload remains protocol-compatible.
- Integration tests:
  - [ ] Extension UI request round trip preserves request payload and submitted result.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Extension dialog controls localize.
- RPC-provided dialog content and responses remain verbatim.
