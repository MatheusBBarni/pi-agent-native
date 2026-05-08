# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- SwiftPM emits the core resource bundle as `PiAgentNative_PiAgentNativeCore.bundle` in debug builds; `pt-BR.lproj` source resources may appear lowercased as `pt-br.lproj` after processing, so future code/scripts should use `Bundle` localization APIs or copy the whole SwiftPM resource bundle rather than hardcoding locale folder casing.

## Open Risks
- The SwiftPM source coverage report remains far below the recurring 80% task target: after Task 11, `swift test --enable-code-coverage` passed but `llvm-cov report` with tests/build artifacts ignored showed 33.45% source line coverage on 2026-05-08. Task 11 used a localization-owned scope (`Localization/*`, `SettingsStore`, and `SubscriptionLoginStatusSummary`) as the scoped 80% gate, which measured 93.78% line coverage. Future tasks should report the project-wide coverage limitation unless a separate coverage scope/gate is defined.

## Handoffs
