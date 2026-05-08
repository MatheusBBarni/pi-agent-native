# i18n for English and Brazilian Portuguese

## Overview

Pi Agent Native should support complete app-authored UI localization in English and Brazilian Portuguese. V1 serves English-first and pt-BR-first users equally across the native macOS shell while preserving user prompts, assistant output, paths, provider names, model IDs, raw terminal output, and RPC/tool content verbatim.

The feature solves a product trust and accessibility problem: Brazilian Portuguese users should be able to operate the app chrome, settings, auth, errors, help, and core controls without switching mental context to English. V1 should be a complete app UI feature, not a partial translation pass, with lightweight coverage and QA guardrails to prevent regression.

## Problem

Pi Agent Native currently has English app-authored UI spread across SwiftUI surfaces including chat, settings, login, process log, inspector, app menus, help text, accessibility labels, status text, and tests. There is no existing localization setup, so every new UI string increases the cost of future localization.

For a coding-agent shell, localization also affects trust. Users need to understand app-authored states such as login, stopped generation, provider command output, settings, error states, and accessibility labels. At the same time, technical artifacts must remain verbatim so users can debug reliably.

### Market Data

Brazil is a large digital market: [DataReportal Digital 2025: Brazil](https://datareportal.com/reports/digital-2025-brazil) reports 183M internet users and 217M cellular mobile connections in Brazil in January 2025. Software localization guidance also shows strong user preference for native-language product experiences, including the widely cited CSA Research finding that 76% of global consumers prefer product information in their own language.

## Summary / Differentiator

The differentiator is not merely "Portuguese translation." It is a trustworthy bilingual developer tool surface: app-owned UI becomes native-language friendly, while technical outputs remain exact and debuggable.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Complete App UI Localization | Critical | Localize all app-authored end-user UI in English and pt-BR across core surfaces. |
| F2 | Verbatim Technical Boundary | Critical | Preserve prompts, assistant output, paths, model/provider names, raw logs, RPC output, and tool content exactly as received. |
| F3 | Critical Flow Coverage | Critical | Verify first-run/no-project state, project selection, chat composer, login/auth, settings, inspector, process log, keybinding help, extension dialogs, and error states in both locales. |
| F4 | Accessibility Localization | High | Localize app-owned accessibility labels, hints, and values in both languages. |
| F5 | Translation Quality Guardrails | High | Maintain lightweight checks for missing locale coverage and reviewed terminology for auth, consent, errors, and execution context. |
| F6 | pt-BR Product Validation | Medium | Measure whether pt-BR improves usability and adoption before expanding into deeper content localization or more languages. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| App Shell and Menus | Localize app-owned navigation, menu labels, headers, and command surfaces. |
| Chat Surface | Localize chrome, controls, empty states, picker UI, tool labels, and app-owned status text while preserving conversation content. |
| Login and Settings | Localize provider selection UI, auth state explanations, settings labels, and action buttons. |
| Inspector and Process Log | Localize app-owned labels and controls while keeping process output verbatim. |
| Keybinding Help | Localize user-facing action labels and help text while preserving key equivalents. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Localized UI coverage | 100% of app-owned V1 UI surfaces | String inventory and locale coverage check |
| Translation completeness | 100% English and pt-BR entries | Localization catalog completion check |
| Critical-flow localization defects | 0 launch-blocking defects | Manual QA pass in both locales |
| Accessibility coverage | 100% localized app-owned accessibility strings | Accessibility string audit |
| Mixed-language boundary defects | 0 critical defects | QA scenarios for logs, paths, assistant output, auth, and errors |
| pt-BR user sentiment | >= 80% positive feedback from pilot users | Short feedback survey or issue labels |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Proceed with complete app-authored UI localization for English and pt-BR, bounded by a strict verbatim-content rule.
- **Key trade-offs:** Full UI parity improves trust but requires broad inventory and QA. Native localization is pragmatic, but still needs ownership rules. Mixed-language screens may remain when verbatim technical output appears inside localized chrome.
- **Risks identified:** Partial localization could damage trust; translating technical output could damage debugging; missing coverage in auth/errors could create user misunderstanding.
- **Stretch goal (V2+):** Language-aware agent UX, where user language preference can inform future prompt/content behavior without changing V1's verbatim technical boundary.

## Out of Scope (V1)

- **Assistant output localization** — Preserved verbatim to avoid altering model meaning.
- **User prompt translation** — User-authored content should remain exactly as entered.
- **Raw terminal/RPC/tool output translation** — Technical output must stay debuggable and supportable.
- **Additional languages beyond English and pt-BR** — Deferred until V1 proves value.
- **Full translation management platform** — Too much infrastructure before multi-locale scale exists.
- **Localized App Store or marketing assets** — Useful later, but V1 targets in-app UI.

## Architecture Decision Records

- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — V1 localizes complete app-authored UI in English and pt-BR while preserving user/generated/system artifacts verbatim.

## Open Questions

- Who owns final pt-BR terminology review for auth, error, and execution-context language?
- Should V1 include an explicit in-app language selector, or rely on macOS app language preferences?
- What pilot feedback channel should be used to measure pt-BR satisfaction?
- Should release notes explicitly describe the verbatim-content boundary?
