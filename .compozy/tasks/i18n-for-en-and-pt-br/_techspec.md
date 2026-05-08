# i18n for English and Brazilian Portuguese TechSpec

## Executive Summary

Implement localization with SwiftPM-processed `.strings` and `.stringsdict` resources, a small localization facade, and an `AppLanguage` preference persisted through the existing `UserDefaults` settings pattern. SwiftUI surfaces use the selected locale, while model-owned app strings resolve through the facade at assignment time.

Primary trade-off: assignment-time localization is lower-risk for the current string-heavy app model, but previously assigned app-owned statuses/log entries may remain in the prior language until refreshed. V1 accepts that behavior to avoid a broad key/value state refactor.

## System Architecture

### Component Overview

- `AppLanguage`: enum for supported languages: English and Brazilian Portuguese.
- `LocalizationStore` / facade: resolves localized app-owned strings from `Bundle.module`.
- `SettingsStore`: persists selected language in `UserDefaults`.
- `AppModel`: exposes selected language and applies it to app-owned status/help strings.
- `SettingsSheetView`: adds language selector in the configuration modal.
- SwiftUI views: replace hardcoded app-owned visible/accessibility strings with localized values.
- Resource bundle: stores `en.lproj` and `pt-BR.lproj` localization files.
- Build script: copies SwiftPM resource bundle into the generated `.app`.

## Implementation Design

### Core Interfaces

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portugueseBrazil = "pt-BR"

    var id: String { rawValue }
    var localeIdentifier: String { rawValue }
}
```

```swift
struct L10n {
    var language: AppLanguage
    var bundle: Bundle = .module

    func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: args)
    }
}
```

### Data Models

- `AppLanguage`
  - `rawValue: String`
  - values: `en`, `pt-BR`
  - persisted under a dedicated `UserDefaults` key, e.g. `appLanguage`.

- `SettingsStore`
  - add `@Published var appLanguage: AppLanguage`
  - write changes to `UserDefaults`.
  - initialize from persisted value, defaulting to English.

- Localization resources
  - `Sources/PiAgentNative/Resources/en.lproj/Localizable.strings`
  - `Sources/PiAgentNative/Resources/pt-BR.lproj/Localizable.strings`
  - `.stringsdict` files only where pluralization or count-sensitive strings need them.

### API Endpoints

None. This feature is local app UI behavior and does not add network or RPC endpoints.

## Integration Points

- SwiftPM package resources: add `defaultLocalization: "en"` and process the `Resources` directory in `PiAgentNativeCore`.
- App bundle script: copy the SwiftPM-generated resource bundle into `Contents/Resources`.
- macOS generated `Info.plist`: include localization metadata if required for correct language discovery.
- `UserDefaults`: persist app language alongside existing settings such as UI font size and theme.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `Package.swift` | Modified | Adds localization resources | Add default localization and processed resources |
| `Scripts/build-app.sh` | Modified | Packaged app may miss resources | Copy SwiftPM resource bundle |
| `SettingsStore` | Modified | New persisted setting | Add language property and default |
| `SettingsSheetView` | Modified | New selector in configuration modal | Add language picker |
| `AppModel` | Modified | Many app-owned status strings | Resolve model-owned strings through facade |
| SwiftUI views | Modified | Hardcoded app UI strings | Replace visible/help/accessibility strings |
| `DefaultKeymap` | Modified | User-facing titles/help groups | Localize titles without changing key equivalents |
| Auth/login/status helpers | Modified | Security-sensitive copy | Localize app copy, preserve provider/raw output |
| Tests | Modified/New | Existing English assertions | Add lookup/persistence/warning tests and update exact-string tests |

## Testing Approach

### Unit Tests

- `AppLanguage` persistence loads defaults and saved values.
- Localization lookup returns English and pt-BR values.
- Missing-key coverage reporter emits warnings for missing required keys.
- `SettingsStore` publishes and persists language changes.
- Representative model-owned strings resolve in the selected language.
- Verbatim technical content remains unchanged when interpolated or displayed.

### Integration Tests

- SwiftPM build can access localization resources through `Bundle.module`.
- Packaged `.app` build contains the SwiftPM resource bundle.
- Settings modal language selection updates visible app-owned UI after state changes.

No full-screen snapshot/UI test suite is required for V1.

## Development Sequencing

### Build Order

1. Add localization resources and package configuration - no dependencies.
2. Add `AppLanguage` and localization facade - depends on step 1.
3. Add language persistence to `SettingsStore` and `AppModel` - depends on step 2.
4. Add configuration modal language selector - depends on step 3.
5. Localize shared app-owned model strings and keymap/help surfaces - depends on step 2.
6. Localize SwiftUI visible/help/accessibility strings - depends on steps 2 and 4.
7. Update build script resource copying - depends on step 1.
8. Add lookup, persistence, warning, and package-resource tests - depends on steps 1-7.
9. Run maintainer-led and AI-assisted review checklist - depends on step 8.

### Technical Dependencies

- SwiftPM resource processing must work in both `swift build` and packaged `.app` output.
- Maintainer must provide or approve pt-BR translations.
- Existing tests with exact English assertions must be updated without weakening behavior coverage.

## Monitoring and Observability

- Emit localization coverage warnings during test or verification runs.
- Track missing keys by language and key name.
- Use GitHub Issues for post-release localization reports.
- No runtime telemetry is required for V1.

## Technical Considerations

### Key Decisions

- Decision: assignment-time localization for model-owned app strings.
  Rationale: lower churn than converting app state to localization keys.
  Trade-off: stale existing statuses may remain in prior language after switching.

- Decision: `.strings` and `.stringsdict`.
  Rationale: simple native resource format for SwiftPM and manual bundling.
  Trade-off: less modern than String Catalogs.

- Decision: warning-based coverage.
  Rationale: supports iterative maintainer review.
  Trade-off: missing keys can ship if warnings are ignored.

- Decision: unit-first test strategy.
  Rationale: catches core lookup/persistence/resource issues without heavy UI test setup.
  Trade-off: manual QA must catch layout and truncation issues.

### Known Risks

- Packaged app cannot find resources.
  Mitigation: verify resource bundle copying in `Scripts/build-app.sh`.

- App-owned and technical strings get mixed.
  Mitigation: only localize app-owned keys; keep provider names, paths, logs, prompts, assistant output, RPC output, and tool content verbatim.

- Runtime language switch leaves stale statuses.
  Mitigation: accepted V1 behavior from ADR-003; refresh high-visibility settings-controlled UI immediately.

- Missing translations are treated as warnings.
  Mitigation: maintainer release checklist must review warnings before release.

## Architecture Decision Records

- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — V1 localizes app-owned UI and preserves technical/generated artifacts verbatim.
- [ADR-002: Use Complete UI Parity With In-App Language Selection](adrs/adr-002.md) — V1 includes complete parity and a visible configuration-modal selector.
- [ADR-003: Use Assignment-Time Localization With Native Strings Resources](adrs/adr-003.md) — V1 uses `.strings`/`.stringsdict` and assignment-time localization.
- [ADR-004: Use Warning-Based Coverage Checks and SwiftPM Resource Bundle Packaging](adrs/adr-004.md) — V1 uses warnings, unit tests, and copies the SwiftPM resource bundle.
