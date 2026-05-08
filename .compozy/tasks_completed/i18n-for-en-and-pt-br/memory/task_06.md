# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 06: localize app action labels, DefaultKeymap help, sidebar commands, macOS menu labels, and app-owned command palette rows for English and pt-BR while preserving action IDs, key equivalents, scopes, shortcut labels, and verbatim technical values.

## Important Decisions
- Work in `/Users/matheusbbarni/projects/worktree/0da35094-a39f-4028/pi-agent-native`; `AGENTS.md`/`CLAUDE.md` were not present there or in the original project path, so the provided AGENTS instruction (`rtk` prefix) is the active repo guidance.

## Learnings
- Shared memory notes an existing project-wide SwiftPM coverage limitation from prior i18n work: total line coverage was 30.77% on 2026-05-08, so this task should report coverage honestly unless a scoped coverage gate is available.
- After this task's tests, `swift test --enable-code-coverage` plus `llvm-cov report` reports 32.14% total line coverage. The task's functional tests pass, but the PRD's project-level 80% coverage target is still unmet.

## Files / Surfaces
- Planned surfaces: `DefaultKeymap`, `AppShellView`, `AppModel`, `CommandPalette`, `PiAgentNativeApp`, localization resources, and related tests/tracking files.
- Touched surfaces: `DefaultKeymap` localized action/help accessors; `AppModel` command palette/menu label localization; `AppShellView` sidebar, keybinding help, and command palette shell labels; `ChatSurfaceView` action help/accessibility labels; `PiAgentNativeApp` menu labels; `Localizable.strings`; `LocalizationRequiredKeys`; `DefaultKeymapTests`; `CommandPaletteTests`.

## Errors / Corrections
- Corrected remaining task-scope hardcoded app-action help labels in `ChatSurfaceView` after a post-implementation scan.

## Ready for Next Run
- Functional verification passed: focused task suite and full `swift test --enable-code-coverage` both ran with 160 tests total and 0 failures on 2026-05-08.
- Do not mark Task 06 completed unless the workflow accepts the documented project-wide coverage limitation or defines a scoped coverage gate; current project-level line coverage is 32.14%, below the explicit 80% target.
