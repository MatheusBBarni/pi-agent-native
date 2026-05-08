---
status: completed
title: "Localize Chat and Composer UI"
type: frontend
complexity: high
dependencies:
    - task_02
    - task_03
---

# Task 07: Localize Chat and Composer UI

## Overview
Localize chat chrome, composer controls, empty states, accessibility labels, mention picker, and skill picker app-owned UI. The task must protect prompt, assistant, tool, skill, and mention semantics from accidental translation.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST localize chat/composer app-owned labels, help text, empty states, and accessibility strings.
- MUST preserve user prompts, assistant output, tool output, tool names, and tool argument summaries verbatim.
- MUST preserve `/skill:` tokens, skill IDs, mention paths, and context attachment prompt payloads.
- MUST not change suggested prompt click behavior unless display text is separated from inserted prompt text.
- MUST add tests for localized chrome and verbatim conversation/tool content.
</requirements>

## Subtasks
- [ ] 7.1 Localize chat header and composer controls.
- [ ] 7.2 Localize empty conversation and picker empty states.
- [ ] 7.3 Localize mention picker and skill picker app-owned rows/statuses.
- [ ] 7.4 Localize message chrome labels while preserving message/tool content.
- [ ] 7.5 Review suggested prompt behavior and avoid changing outgoing prompt semantics.
- [ ] 7.6 Add tests for localized chrome and unchanged prompt/tool payloads.

## Implementation Details
Treat UI chrome and inserted/generated content as separate concerns. Suggested prompts are risky because displayed text is also assigned to `composerText`.

### Relevant Files
- `Sources/PiAgentNative/ChatSurfaceView.swift` — primary chat/composer UI surface.
- `Sources/PiAgentNative/PromptTextView.swift` — composer placeholder and key handling.
- `Sources/PiAgentNative/ContextAttachments.swift` — attachment display and prompt decoration.
- `Sources/PiAgentNative/SkillSelection.swift` — skill picker and `/skill:` prompt semantics.
- `Sources/PiAgentNative/MentionModels.swift` — mention picker status model.
- `Sources/PiAgentNative/Conversation/MessageContentBlock.swift` — assistant/tool block display.
- `Sources/PiAgentNative/RPC/PiRPCEventReducer.swift` — assistant/tool output ingestion.

### Dependent Files
- `Sources/PiAgentNative/AppModel.swift` — composer send semantics and picker state.
- `Sources/PiAgentNative/DefaultKeymap.swift` — help labels reused in chat controls.
- `Tests/PiAgentNativeTests/SkillSelectionTests.swift` — `/skill:` behavior.
- `Tests/PiAgentNativeCoreTests/RPCTests.swift` — assistant/tool output preservation.
- `Tests/PiAgentNativeCoreTests/ContextAttachmentPromptDecoratorTests.swift` — prompt decoration boundary.

### Related ADRs
- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — Preserves prompts, assistant output, and tool content verbatim.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — Defines localization approach.

## Deliverables
- Localized chat/composer UI chrome.
- Tests preserving prompt/tool/assistant boundaries.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for composer, picker, and message display behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Chat control label resolves in English and pt-BR.
  - [ ] Suggested prompt click writes the exact intended prompt to `composerText`.
  - [ ] Assistant message text remains byte-for-byte unchanged.
  - [ ] Tool output text and argument summary remain byte-for-byte unchanged.
  - [ ] `/skill:` token and skill ID remain unchanged.
- Integration tests:
  - [ ] Localized picker UI still inserts the same mention path and selected skill instruction.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Chat and composer app-owned UI localizes in both languages.
- Prompt and generated content semantics remain unchanged.
