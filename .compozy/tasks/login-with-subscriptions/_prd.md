# PRD: Login With Subscriptions

## Overview

Pi Agent Native needs a clearer subscription login experience for users who switch between existing provider-backed accounts. The app already starts provider login flows for Anthropic, ChatGPT / OpenAI Codex, and GitHub Copilot, but the Login modal does not make the current provider attempt easy to trust.

The MVP will focus on provider login state clarity. Users should be able to start a subscription login, see whether that provider is starting, waiting, refreshing, confirmed, failed, or stopped, and avoid mistaking stale access from one provider for confirmed access from another.

Pi Agent Native does not sell or manage subscriptions. Provider accounts, billing, and credentials remain owned by the provider login flow and Pi credential context.

## Goals

- Show a clear state for the active subscription login attempt across all current subscription providers.
- Reduce confusion for users who switch between providers.
- Confirm usable access only after provider login completion and access verification.
- Keep existing subscription providers available in the Login modal.
- Preserve manual fallback paths when browser/provider handoff is incomplete.

## User Stories

- As a power user, I want to switch between subscription providers so I can use the account that matches my current work.
- As a power user, I want to know which provider is currently logging in so I do not confuse one provider's state with another.
- As a power user, I want a clear confirmed or failed state before I rely on model-backed actions.
- As a first-time user, I want the Login modal to tell me what is happening after I start provider login.
- As a user with a browser or provider handoff issue, I want a visible fallback link and status so I can recover without guessing.

## Core Features

| Priority | Feature | Description |
| --- | --- | --- |
| Critical | Provider login state sequence | The modal shows clear states: not started, starting, waiting for provider, refreshing access, confirmed, failed, and stopped. |
| Critical | Active provider identity | The modal makes the selected provider and current login attempt visible throughout the flow. |
| Critical | Access confirmation | The modal treats login as confirmed only after the latest access check reports usable provider-backed access. |
| High | Failure and stopped states | The modal distinguishes provider failure, user-stopped login, and access refresh failure. |
| High | Manual handoff fallback | When a Provider Login URL is available, the modal keeps a visible Open Link action for recovery. |
| Medium | Provider switching clarity | Switching providers should reset or clearly separate attempt state so stale status does not look active for the new provider. |

## User Experience

Primary flow:

1. User opens Login and chooses Subscription.
2. User selects Anthropic, ChatGPT / OpenAI Codex, or GitHub Copilot.
3. User starts login.
4. The modal shows that login has started for the selected provider.
5. If browser handoff is available, the modal indicates that the user should continue with the provider.
6. After provider completion, the modal shows that Pi Agent Native is checking access.
7. The modal shows either confirmed access or a clear failure state.

Provider switching flow:

1. User changes selected provider after a previous provider was used.
2. The modal shows the selected provider's current state separately from stale access.
3. User starts login for the new provider.
4. Confirmed state must refer to the current provider attempt or latest verified provider-backed access.

UX principles:

- Use plain status copy, not terminal-only output, as the primary signal.
- Do not imply Pi Agent Native manages subscriptions.
- Do not treat opening a browser link as successful login.
- Keep process output available for troubleshooting, but do not make it the main user journey.

## High-Level Technical Constraints

- The feature must preserve the existing provider-owned login model.
- The feature must cover all current subscription providers shown in the modal.
- Browser-open success is not an authentication success signal.
- Subscription-backed access must remain disabled or unconfirmed while access is unknown, refreshing, failed, or stale.
- Unknown or unsafe provider handoff states should require explicit user action instead of silent success.

## Non-Goals

- Pi Agent Native will not sell, manage, cancel, renew, or inspect subscription plans.
- The MVP will not add a full provider account dashboard.
- The MVP will not add native app-owned OAuth redirect handling.
- The MVP will not add provider history, usage analytics, or account profile details.
- The MVP will not redesign API-key login except where shared status language requires consistency.

## Phased Rollout Plan

### MVP: Provider State Clarity

- Add explicit status states for current subscription login attempts.
- Show provider-specific progress and confirmation in the Login modal.
- Preserve Open Link fallback when a Provider Login URL is available.
- Confirm access only after the latest access check.

Success criteria: users can tell which provider is logging in and whether it is waiting, refreshing, confirmed, failed, or stopped.

### Phase 2: Provider Switching Guardrails

- Improve stale-state handling when changing selected providers.
- Add clearer messaging when previous access exists but current provider access is not confirmed.
- Add copy for common provider handoff failures.

Success criteria: users switching providers do not misread stale access as current provider confirmation.

### Phase 3: Login Control Center

- Consider richer provider status, troubleshooting guidance, and account-switch help.
- Consider direct redirect handling only if provider workflows require Pi Agent Native to own that boundary.

Success criteria: support burden drops without expanding subscription ownership.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| State clarity coverage | 100% | Every subscription login attempt has a visible current state. |
| Provider confusion reduction | -80% | Fewer reports that login is stuck, ambiguous, or tied to the wrong provider. |
| Time to clear outcome | p75 under 60 seconds | Time from Start Login to confirmed, failed, or waiting-for-user state. |
| Stale status prevention | 100% | Provider switching never shows prior provider confirmation as current provider confirmation. |
| Recovery visibility | 100% | Detected Provider Login URLs remain manually reopenable. |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Users expect subscription plan details | Use copy that clearly says provider accounts and subscriptions are managed externally. |
| Provider login behavior varies | Show honest waiting, failed, and fallback states instead of overpromising completion. |
| Users mistake browser opening for login success | Reserve confirmed state for verified usable access. |
| Power users switch providers quickly | Tie visible status to the selected provider and current attempt. |
| Terminal output remains confusing | Make structured status the primary signal and keep terminal output secondary. |

## Architecture Decision Records

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — V1 keeps provider CLIs and Pi credentials as the authority for subscription login.
- [ADR-002: Prioritize Provider Login State Clarity](adrs/adr-002.md) — MVP focuses on clear provider login states for users switching providers.

## Open Questions

- Should confirmed access automatically close the Login modal or remain visible until the user clicks Done.
- Should provider display names use current labels or explicitly mention Claude Code for the Anthropic subscription flow.
- Should the modal show the last confirmed provider while another provider login is in progress.
