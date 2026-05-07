---
title: Login and Subscription State Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, authentication, subscriptions, macos]
---

# Introduction

This specification defines the first-version login and subscription state model for Pi Agent Native. The goal is to make authentication, subscription access, model availability, and subscription-required actions move through one explicit state machine so login, logout, refresh, and error paths cannot expose stale access from a previous account.

## 1. Purpose & Scope

This specification applies to the Pi Agent Native macOS app shell, login sheet, model picker, app model state, RPC refresh flow, and any app action or agent interaction that depends on authenticated subscription access.

The intended audience is implementation agents and maintainers adding GitHub issue 11: "Fix login flow with subscriptions".

In scope:

- Representing authentication and subscription access as explicit, separate states.
- Refreshing subscription-derived access immediately after successful login and other credential changes.
- Resetting stale subscription-derived UI state on logout and credential replacement.
- Gating subscription-required actions only after the latest access refresh is known.
- Surfacing authentication and subscription lookup errors without granting stale access.
- Preserving current API-key and subscription login providers.

Out of scope:

- Adding new subscription providers.
- Implementing direct billing-provider APIs in the native app.
- Changing the provider credential file format owned by `pi`.
- Redesigning pricing, plans, checkout, or account management.
- Persisting subscription access decisions across app launches as authoritative state.

## 2. Definitions

**Authentication State**: The user's current credential relationship with Pi Agent Native, such as unauthenticated, login in progress, authenticated, or authentication error.

**Subscription Access**: The access level derived from the latest authenticated provider state that determines whether subscription-required app actions may proceed.

**Access Refresh**: A deliberate refresh of Authentication State and Subscription Access after login, logout, app launch, RPC restart, or user-invoked refresh.

**Subscription-Gated Action**: An App Action or agent interaction that requires active Subscription Access before it can run.

**Provider Login**: A login flow for a supported provider, including API-key save or subscription OAuth/device-code login.

**Credential Store**: The `pi` credential directory and `auth.json` file currently written under `~/.pi/agent` unless `PI_CODING_AGENT_DIR` overrides it.

**RPC Process**: The running `pi --mode rpc` process launched and supervised by Pi Agent Native.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall model Authentication State separately from Subscription Access.
- **REQ-002**: The app shall represent Subscription Access with at least these states: unknown, refreshing, inactive or missing, active, and failed.
- **REQ-003**: The app shall treat unknown, refreshing, inactive or missing, and failed Subscription Access as not active.
- **REQ-004**: After API-key credentials are saved successfully, the app shall clear stale subscription-derived state and perform an Access Refresh.
- **REQ-005**: After a subscription login process exits successfully, the app shall clear stale subscription-derived state, restart or reconnect the RPC process as needed, and perform an Access Refresh.
- **REQ-006**: If a subscription login process fails, is stopped, or exits non-zero, the app shall not mark Authentication State as authenticated and shall not mark Subscription Access as active.
- **REQ-007**: Logout shall clear credentials for the selected provider or the whole app-level credential context, clear Authentication State, clear Subscription Access, clear available models derived from old credentials, and refresh the UI immediately.
- **REQ-008**: The app shall not show subscription access from a previous account after login, logout, provider switch, credential replacement, app launch, RPC exit, or RPC restart.
- **REQ-009**: Subscription-Gated Actions shall be enabled only when the latest Access Refresh completed successfully and Subscription Access is active.
- **REQ-010**: Prompt sending, model selection, and other gated flows shall fail closed when Subscription Access is unknown, refreshing, inactive or missing, or failed.
- **REQ-011**: Authentication errors and subscription lookup errors shall be surfaced through status text and process log details.
- **REQ-012**: Access Refresh shall request the running RPC process state and available models using the existing `get_state` and `get_available_models` commands unless the RPC protocol grows a more precise access-status command.
- **REQ-013**: The app shall derive first-version active Subscription Access from the refreshed provider/model availability returned by `pi`, not from the subscription login process exit status alone.
- **REQ-014**: A failed `get_state` or `get_available_models` response during Access Refresh shall put Subscription Access into failed state and preserve a user-visible error.
- **REQ-015**: The model picker shall distinguish unauthenticated, authenticated without active access, active access, refreshing, and failed states instead of showing only "No authenticated models found."
- **REQ-016**: Existing API-key providers and subscription providers shall continue to appear in the login sheet.
- **REQ-017**: The app shall not persist Subscription Access as authoritative app state across launches; app launch must refresh access from the current credential/RPC state.
- **CON-001**: The native app must not parse provider-specific billing pages, checkout state, or account dashboards.
- **CON-002**: The `pi` Credential Store remains the credential authority; native state may cache UI state but must not redefine credential semantics.
- **CON-003**: Access-gated UI must fail closed during asynchronous refreshes.
- **PAT-001**: Add a typed state model, for example `AuthAccessState`, rather than scattering optional booleans across `AppModel` and views.
- **PAT-002**: Centralize access gating in `AppModel` helpers so views render state and do not duplicate access rules.
- **GUD-001**: Prefer concise, actionable UI messages such as "Subscription access is refreshing", "No active subscription found", and "Could not refresh subscription access."

## 4. Interfaces & Data Contracts

### Native State Contract

The implementation shall expose an app-level state equivalent to this structure:

```swift
enum AuthenticationState: Equatable {
    case unknown
    case unauthenticated
    case authenticating(providerID: String)
    case authenticated(providerID: String?)
    case failed(message: String)
}

enum SubscriptionAccessState: Equatable {
    case unknown
    case refreshing
    case inactive(reason: String?)
    case active(providerID: String?)
    case failed(message: String)
}

struct AuthAccessState: Equatable {
    var authentication: AuthenticationState
    var subscriptionAccess: SubscriptionAccessState
    var lastRefreshStartedAt: Date?
    var lastRefreshCompletedAt: Date?
}
```

Names may differ, but the represented states and transitions are required.

### RPC Refresh Contract

Access Refresh shall send these commands to the running RPC process:

```json
{"type":"get_state","id":"<uuid>"}
{"type":"get_available_models","id":"<uuid>"}
```

The first-version active-access decision shall be:

- Active when the latest refresh succeeds and at least one available model is returned for an authenticated credential context.
- Inactive or missing when the latest refresh succeeds but no usable authenticated models are returned.
- Failed when either required refresh command returns an error or cannot be sent.

If a future RPC response provides a dedicated subscription/access field, the implementation may prefer that field while preserving the same native states and acceptance criteria.

### Login Sheet Contract

- API-key save calls the existing credential save path and then triggers Access Refresh.
- Subscription login calls the existing provider login command runner.
- A zero exit status from the subscription login process means credentials may have changed; it does not by itself mean Subscription Access is active.
- Closing the login sheet after successful subscription login must not leave access active until Access Refresh completes.

### Logout Contract

The app shall provide a logout or credential-clearing path as part of this issue. The path must:

- Stop active login processes for the affected provider.
- Remove or invalidate the relevant credential entry.
- Restart the RPC process when connected.
- Clear `availableModels`, selected model display if stale, and Subscription Access immediately.
- Run Access Refresh if credentials remain for another provider.

## 5. Acceptance Criteria

- **AC-001**: Given the app has no usable credentials, When it launches or refreshes state, Then Authentication State is unauthenticated or unknown and Subscription Access is not active.
- **AC-002**: Given a user saves a valid API key, When the save succeeds, Then stale subscription-derived state is cleared and Access Refresh starts immediately.
- **AC-003**: Given a user completes subscription login and the login process exits with status 0, When the login sheet is closed or the success is observed, Then the RPC process restarts or reconnects and Access Refresh starts immediately.
- **AC-004**: Given a subscription login process exits non-zero, When the UI updates, Then Subscription Access is not active and the failure is visible in status text or process log.
- **AC-005**: Given Access Refresh is in progress, When the user views gated controls, Then Subscription-Gated Actions are disabled or blocked with a refreshing state.
- **AC-006**: Given Access Refresh succeeds with one or more usable models, When the UI updates, Then Subscription Access is active and gated actions may proceed.
- **AC-007**: Given Access Refresh succeeds with no usable authenticated models, When the UI updates, Then the app shows authenticated-without-active-subscription or no-active-access state.
- **AC-008**: Given Access Refresh fails, When the UI updates, Then the app shows a refresh error and does not grant access from any previous successful refresh.
- **AC-009**: Given account A had active Subscription Access, When the user logs out or replaces credentials with account B, Then account A's Subscription Access is cleared before account B refresh completes.
- **AC-010**: Given the user logs out, When logout completes, Then auth-derived UI, available models, selected stale model display, and subscription-derived access are reset.
- **AC-011**: Given existing provider lists, When the login sheet opens, Then Anthropic, ChatGPT / OpenAI Codex, GitHub Copilot subscription login, and current API-key providers remain available.
- **AC-012**: Given no active Subscription Access, When the user attempts a Subscription-Gated Action, Then the action does not run and a clear state-specific reason is surfaced.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for state transitions and gating helpers; integration-style AppModel tests with mocked RPC command responses; view-model or UI tests for login/model-picker state rendering where practical.
- **Frameworks**: XCTest and existing SwiftPM test targets.
- **Test Data Management**: Use temporary credential directories for NativeAuthStore behavior and deterministic mock RPC responses for `get_state` and `get_available_models`.
- **CI/CD Integration**: Existing `swift test` must pass. New tests should run without real provider credentials, network access, or a real `pi` subscription.
- **Coverage Requirements**: Cover login success, login failure, refresh success with models, refresh success without models, refresh failure, logout, credential replacement, and RPC exit/restart clearing behavior.
- **Performance Testing**: No load testing is required. Access Refresh should use existing RPC commands and should not block the main thread.

## 7. Rationale & Context

The current code saves API keys and runs subscription login commands, then restarts the RPC process. It also refreshes model availability, but the app does not model authentication and subscription access as explicit states. This makes it difficult for the UI to distinguish no credentials, active subscription, missing or inactive subscription, refresh in progress, and refresh failure.

The native app should not become a billing-provider client. The existing `pi` credential and RPC layer is the authority for authenticated capabilities. Pi Agent Native's responsibility is to clear stale derived state, request fresh capability state at the right moments, fail closed while the state is unknown, and render the resulting access state clearly.

No ADR is required for this version because the decision is reversible UI/application state modeling around the current RPC contract. A future dedicated RPC access-status command can replace the model-availability inference without changing the domain language or user-facing states.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: `pi` coding agent RPC process - Provides state, model availability, and command execution.
- **EXT-002**: Provider login CLIs - Existing subscription login commands write or update credentials in the Credential Store.

### Third-Party Services

- **SVC-001**: Existing subscription providers - Anthropic, ChatGPT / OpenAI Codex, and GitHub Copilot remain supported through the current provider login command runner.

### Infrastructure Dependencies

- **INF-001**: Credential Store - `~/.pi/agent/auth.json` or `PI_CODING_AGENT_DIR` override remains the credential location.

### Technology Platform Dependencies

- **PLT-001**: macOS SwiftUI app runtime - State updates must remain main-actor safe.
- **PLT-002**: SwiftPM test runner - Automated validation must use `swift test`.

## 9. Examples & Edge Cases

```text
Scenario: Successful subscription login
1. User starts ChatGPT / OpenAI Codex subscription login.
2. Provider login process exits with status 0.
3. App clears stale Subscription Access and marks access refreshing.
4. App restarts RPC and sends get_state plus get_available_models.
5. App marks Subscription Access active only after refreshed model availability confirms usable access.
```

```text
Scenario: Account switch
1. Account A has active Subscription Access.
2. User logs out or replaces credentials.
3. App immediately clears Account A access and available models.
4. Until Account B refresh succeeds, Subscription-Gated Actions remain disabled.
```

```text
Scenario: Refresh error
1. User logs in successfully.
2. get_available_models fails.
3. App shows failed Subscription Access and does not reuse previous active access.
```

## 10. Validation Criteria

- `swift test` passes.
- New state-transition tests prove stale active access is cleared before refresh after login, logout, and credential replacement.
- New gating tests prove unknown, refreshing, inactive, and failed Subscription Access cannot run Subscription-Gated Actions.
- New AppModel tests prove successful refresh with models enables access and successful refresh without models shows authenticated-without-active-subscription state.
- Manual validation confirms model picker copy distinguishes unauthenticated, refreshing, no active subscription, active subscription, and refresh error states.
- Manual validation confirms existing API-key and subscription provider choices still appear and existing login commands still launch.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [README.md](../README.md)
- [docs/improvements.md](../docs/improvements.md)
