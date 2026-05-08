# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Localize auth, login sheet, subscription-login summary, and model-picker app-owned copy for English and pt-BR while keeping provider names, provider URLs, OAuth output, model IDs, and error payloads verbatim.

## Important Decisions
- `SubscriptionLoginStatusSummary.swift` is referenced by the task but absent in the current worktree; implement it as a small testable helper backing `AccessStatusSummaryView`.
- Keep raw `String` payloads in `ModelAccessState`, `SubscriptionAccessState`, OAuth runner output, file paths, model IDs, and provider IDs/names as interpolation/display values; localize only the surrounding app-owned templates.

## Learnings
- Required repo guidance files `AGENTS.md` and `CLAUDE.md` are absent under both the supplied worktree and sibling repo path; only `/Users/matheusbbarni/.codex/RTK.md` was available and requires `rtk` command prefixes.
- `swift test --enable-code-coverage` passes, but the total project coverage remains below the task's recurring 80% target at 31.35% line coverage. This is consistent with the shared pre-existing coverage risk, not introduced by task 05. `AuthAccessState.swift` line coverage is 84.01%.

## Files / Surfaces
- Touched surfaces: `AuthAccessState.swift`, `LoginSheetView.swift`, `AppModel.swift`, `Auth/LoginProviderCatalog.swift`, new `Auth/SubscriptionLoginStatusSummary.swift`, localization resources, `LocalizationRequiredKeys.swift`, `AuthAccessStateTests.swift`, new `SubscriptionLoginStatusSummaryTests.swift`, and `AppModelLocalizationTests.swift`.

## Errors / Corrections
- The task's named status summary file did not exist; added the helper and tests instead of embedding more private string logic inside the SwiftUI view.

## Ready for Next Run
- Verification evidence: focused auth/login test selection passed 21 tests before the final branch test; final `AuthAccessStateTests` passed 18 tests; final `swift test --enable-code-coverage` passed 153 tests; `llvm-cov report` total line coverage was 31.35%.
