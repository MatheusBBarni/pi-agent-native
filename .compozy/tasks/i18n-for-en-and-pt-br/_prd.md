# i18n for English and Brazilian Portuguese PRD

## Overview

Pi Agent Native will support complete app-owned UI localization in English and Brazilian Portuguese. V1 gives English-first and pt-BR-first users equivalent access to the native macOS app chrome, controls, settings, auth flows, help text, accessibility labels, and app-owned error/status language.

The feature exists to improve trust, comprehension, and accessibility for Brazilian Portuguese users without altering technical artifacts. User prompts, assistant output, model IDs, provider names, file paths, raw terminal output, RPC payloads, and tool content remain verbatim so the app stays debuggable and supportable.

Brazil is a large digital market, with [DataReportal reporting 183M internet users in Brazil in January 2025](https://datareportal.com/reports/digital-2025-brazil). Developer tools also commonly expose display-language support, including [VS Code's Portuguese Brazil locale](https://code.visualstudio.com/docs/configure/locales). V1 should therefore be a quality-first localization release, not a partial market test.

## Goals

- Deliver complete English and pt-BR parity for app-owned V1 UI surfaces.
- Give users visible control over app language in the configuration modal.
- Preserve all user-authored, generated, system, and technical content verbatim.
- Make technical accuracy override localization whenever the two conflict.
- Reach zero launch-blocking localization defects across included V1 surfaces.
- Complete maintainer-led review, supported by AI-assisted secondary review, before release.
- Route post-release localization feedback through GitHub Issues.

## User Stories

- As a Brazilian Portuguese-first developer, I want the app UI in pt-BR so that I can operate Pi Agent Native without relying on English for app controls and states.
- As an English-first developer, I want the app UI to remain complete and polished in English so that localization does not degrade the default experience.
- As a bilingual developer, I want to switch the app language inside Pi Agent Native so that I can choose the UI language that fits my current workflow.
- As a user debugging a coding-agent session, I want paths, logs, model output, and tool output to remain exact so that translated UI does not obscure technical meaning.
- As a keyboard and assistive-technology user, I want labels, hints, and help text localized so that the app remains understandable beyond visible labels.

## Core Features

1. Complete app-owned UI localization: every included app-authored user-facing surface is available in English and pt-BR.
2. In-app language selector: users can choose English or Brazilian Portuguese from the configuration modal.
3. Verbatim-content boundary: prompts, assistant output, paths, provider/model names, raw terminal/RPC output, and tool/generated content remain unchanged.
4. Critical flow parity: first-run/no-project state, project selection, chat controls, login/auth, settings, inspector, process log, keybinding help, extension dialogs, and app-owned errors are reviewed in both locales.
5. Accessibility localization: app-owned accessibility labels, hints, and values are localized.
6. Quality guardrails: missing, incorrect, or mixed-language app-owned UI in V1 surfaces is treated as launch-blocking.
7. pt-BR terminology review: auth, error, execution-context, and app-action language receives maintainer-led review supported by AI-assisted secondary review.

## User Experience

A user can open Pi Agent Native, open the configuration modal, choose the app language, and see app-owned chrome, controls, navigation, settings, login copy, help text, and accessibility labels in the chosen language.

When the user enters prompts, reads assistant responses, inspects paths, views raw process output, or sees model/provider identifiers, that content remains exactly as produced or entered. Technical clarity always takes precedence over localization.

The expected V1 journey is:

1. User opens the app.
2. User opens the configuration modal.
3. User selects English or Brazilian Portuguese.
4. App-owned UI surfaces render in the chosen language.
5. User starts or resumes a coding-agent session.
6. Technical content remains verbatim while app controls and app-owned status text stay localized.
7. User can switch language again from the configuration modal.

## High-Level Technical Constraints

- The product must distinguish app-owned UI text from user-authored, generated, system, and technical content.
- Technical accuracy, debuggability, and supportability must always override localization.
- The language selector must live in the configuration modal.
- The language selector must not imply that prompts, assistant output, logs, paths, or provider/model names will be translated.
- The localized experience must preserve existing domain language from `CONTEXT.md`, including App Action, Keybinding, Inspector, Open Project, Open Externally, Authentication State, Provider Login URL, and Queued Work.
- V1 must support maintainer-led review with AI-assisted secondary review.

## Non-Goals (Out of Scope)

- Translating assistant output.
- Translating user prompts.
- Translating raw terminal output, RPC payloads, tool output, paths, model IDs, provider names, or external app names.
- Supporting languages beyond English and Brazilian Portuguese.
- Building a full translation management platform.
- Localizing App Store metadata, marketing copy, screenshots, or release campaigns.
- Adding language-aware agent behavior in V1.

## Phased Rollout Plan

### MVP (Phase 1)

- Complete app-owned UI parity in English and pt-BR.
- Visible in-app language selector in the configuration modal.
- Verbatim-content boundary applied across core flows.
- Maintainer-led review and AI-assisted secondary review completed.
- Zero launch-blocking localization defects.

Success criteria to proceed: all V1 included surfaces pass review in both languages, and no critical mixed-language or boundary defects remain.

### Phase 2

- Improve feedback collection from pt-BR users through GitHub Issues.
- Refine terminology based on real usage and support feedback.
- Expand localization checks to newly added app-owned UI surfaces.

Success criteria to proceed: pt-BR feedback confirms the UI feels coherent, and localization regressions stay below release-blocking thresholds.

### Phase 3

- Evaluate additional languages.
- Consider language-aware agent UX as a separate product effort.
- Consider localized marketing or distribution assets if pt-BR usage justifies it.

Success criteria: measurable demand exists beyond English and pt-BR, and V1 quality remains stable.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| App-owned UI coverage | 100% of V1 included surfaces | Surface inventory and review checklist |
| Translation completeness | 100% English and pt-BR completion | Locale coverage review |
| Launch-blocking defects | 0 | Maintainer-led QA and AI-assisted review |
| Accessibility localization | 100% app-owned labels/hints/values | Accessibility audit |
| Boundary defects | 0 critical | QA scenarios for prompts, logs, paths, assistant output, auth, and errors |
| Review quality | Maintainer approval plus AI-assisted review completed | Review sign-off before release |
| Feedback intake | GitHub Issues used for localization reports | Issues labeled/tracked after release |

## Risks and Mitigations

- Risk: Users expect the app to translate assistant output or logs.
  Mitigation: Make the language selector and release notes clear that only app UI changes language.

- Risk: Localization weakens technical clarity.
  Mitigation: Treat technical accuracy as higher priority than localization and preserve technical artifacts verbatim.

- Risk: Partial or inconsistent localization damages trust.
  Mitigation: Treat missing app-owned localization in V1 surfaces as launch-blocking.

- Risk: pt-BR terminology feels literal or unnatural.
  Mitigation: Use maintainer-led review and AI-assisted secondary review before release.

- Risk: Full parity increases release scope.
  Mitigation: Keep V1 limited to English and pt-BR app-owned UI, and defer additional languages, marketing assets, and content localization.

- Risk: Accessibility strings lag behind visible UI.
  Mitigation: Include accessibility strings in the same V1 review checklist as visible text.

## Architecture Decision Records

- [ADR-001: Scope English and Brazilian Portuguese UI Localization](adrs/adr-001.md) — V1 localizes complete app-authored UI in English and pt-BR while preserving user/generated/system artifacts verbatim.
- [ADR-002: Use Complete UI Parity With In-App Language Selection](adrs/adr-002.md) — V1 uses complete UI parity plus a visible language selector, with maintainer-led and AI-assisted review as the quality gate.

## Open Questions

No blocking open questions remain for the PRD. Post-release localization issues will be collected through GitHub Issues.
