# Task 11 Localization Verification Checklist

Date: 2026-05-08

## Automated Evidence

- `rtk swift test`
  - Result: PASS
  - Evidence: 185 XCTest tests, 0 failures.
  - Includes `BuildAppScriptTests` debug and release resource-bundle packaging checks.
- `rtk ./Scripts/build-app.sh debug`
  - Result: PASS
  - Packaged app: `.build/Pi Agent.app`
  - Packaged localization bundle: `Contents/Resources/PiAgentNative_PiAgentNativeCore.bundle`
  - Localizations observed: `en.lproj/Localizable.strings`, `pt-br.lproj/Localizable.strings`
- `rtk swift test --enable-code-coverage`
  - Result: PASS
  - Evidence: 185 XCTest tests, 0 failures.
- `rtk xcrun llvm-cov report ... -ignore-filename-regex='(\\.build|Tests)'`
  - Result: PROJECT-WIDE COVERAGE BELOW TARGET
  - Project source line coverage: 33.45%
  - Required target in task text: 80%
  - Task-scoped localization-owned line coverage for `Localization/*`, `SettingsStore`, and `SubscriptionLoginStatusSummary`: 93.78%

## Missing-Key Warning Review

- Default required-key reporter:
  - Covered by `LocalizationCoverageTests.testCoverageReporterReturnsNoWarningsForBundleModuleRequiredKeys`.
  - Result from `rtk swift test`: no warnings for bundle-module required keys.
- Intentional missing-key reporter:
  - Covered by `LocalizationCoverageTests.testCoverageReporterReturnsStructuredWarningsForMissingKeys`.
  - Expected maintainer-review warning messages:
    - `Missing localization key 'missing.key' for en.`
    - `Missing localization key 'present.key' for pt-BR.`
    - `Missing localization key 'missing.key' for pt-BR.`
  - Behavior: warnings are structured and visible to tests, but warning coverage does not fail by default.

## Representative Surface Coverage

- Settings and language selector: `LocalizationResourceTests`, `SettingsStoreLanguageTests`.
- App shell, sidebar, menus, App Actions, and Keybinding Help: `LocalizationResourceTests`, `DefaultKeymapTests`, `CommandPaletteTests`.
- Chat and composer: `AppModelLocalizationTests`, `ContextAttachmentPromptDecoratorTests`, `MentionInserterTests`, `PiRPCEventReducerTests`.
- Auth, login, model picker, provider login URL: `AuthAccessStateTests`, `SubscriptionLoginStatusSummaryTests`, `AppModelLocalizationTests`.
- Inspector, Process Log, Queued Work, Change Review: `AppModelLocalizationTests`, `InspectorPaneToggleTests`, `QueuedWorkDisplayStateTests`.
- Extension dialogs and RPC/tool surfaces: `LocalizationResourceTests`, `PiRPCEventReducerTests`.

## Verbatim Boundary Review

- Provider names remain verbatim: `SubscriptionLoginStatusSummaryTests`, `AppModelLocalizationTests`.
- Provider login URLs and OAuth output remain verbatim: `SubscriptionLoginStatusSummaryTests`, `AppModelLocalizationTests`, `AuthAccessStateTests`.
- User prompts and inserted skill/file payloads remain verbatim: `AppModelLocalizationTests`, `ContextAttachmentPromptDecoratorTests`, `SkillSelectionTests`.
- Assistant text, RPC payloads, tool output, and extension UI request content remain verbatim: `PiRPCEventReducerTests`.
- Paths, project names, model IDs, branch names, raw diffs, and log details remain verbatim: `AppModelLocalizationTests`, `CommandPaletteTests`, `ExternalTargetsTests`.

## Maintainer Review Items

- Review pt-BR terminology for auth, Subscription Access, Model Access, App Action, Keybinding Help, Inspector, Open Project, Open Externally, and Queued Work.
- Review screenshots/manual flows for truncation or layout issues; V1 intentionally does not add full UI snapshot coverage.
- Review the project-wide coverage gap. The localization-owned scope is above 80%, but the full SwiftPM source report remains below the task target because many SwiftUI view files are unexercised by unit tests.
- Confirm that zero default required-key warnings is acceptable for release readiness.

## AI-Assisted Secondary Review Prompt

Review the English and Brazilian Portuguese app-owned strings in:

- `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings`
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings`
- `Sources/PiAgentNative/Resources/en.lproj/Localizable.stringsdict`
- `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.stringsdict`

Check for:

- mixed-language app-owned UI in V1 surfaces;
- pt-BR terminology that is literal, awkward, or inconsistent with the domain language in `CONTEXT.md`;
- accidental translation of provider names, URLs, paths, model IDs, prompts, assistant text, diffs, logs, RPC payloads, or tool output;
- missing plural or interpolation parity between English and pt-BR.
