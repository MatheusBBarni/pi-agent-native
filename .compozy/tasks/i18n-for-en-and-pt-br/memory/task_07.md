# Task Memory: task_07.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Localize chat/composer app-owned UI chrome for English and pt-BR while preserving prompt, assistant, tool, skill, mention, and context-attachment payloads verbatim.

## Important Decisions
- Suggested prompt display text will localize separately from the inserted prompt payload; the inserted prompt remains the existing English command text unless product requirements explicitly redefine prompt semantics.
- Context attachment kind/status localization is display-only; `ContextAttachmentKind.label` remains the raw `file`/`folder` prompt payload vocabulary.

## Learnings
- Pre-change baseline: `ChatSurfaceView.swift` still had hardcoded app-owned strings for empty conversation copy, composer placeholder/accessibility, picker statuses, chip help, and message tool/thinking labels.
- Verification on 2026-05-08: `swift test`, `swift test --enable-code-coverage`, `swift build`, and `git diff --check` exited 0; coverage report still showed total project line coverage below target at 32.48%.

## Files / Surfaces
- Planned surfaces: `ChatSurfaceView.swift`, context attachment display helpers, localization resources/required keys, and focused tests for prompt/tool/mention/skill boundaries.
- Touched for task scope: `ChatSurfaceView.swift`, `ContextAttachments.swift`, `AppModel.swift`, localization required keys/resources, `AppModelLocalizationTests.swift`, `RPCTests.swift`, `MentionInserterTests.swift`, and `ContextAttachmentPromptDecoratorTests.swift`.

## Errors / Corrections
- Initial targeted coverage filter used a non-existent XCTest selector and ran 0 tests; reran the actual focused suites and full `swift test`.

## Ready for Next Run
- Task implementation is in place and tests pass, but task tracking was not marked complete because the explicit 80% coverage success criterion is not met project-wide.
