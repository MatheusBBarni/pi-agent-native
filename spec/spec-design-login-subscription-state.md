---
title: Login and Subscription State Design
version: 1.1
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, authentication, subscriptions, macos]
---

# Introduction

This specification defines the first-version login and subscription state model for Pi Agent Native. The goal is to make authentication, model access, subscription access, model availability, and subscription-required actions move through one explicit state machine so login, logout, refresh, and error paths cannot expose stale access from a previous account.

## 1. Purpose & Scope

This specification applies to the Pi Agent Native macOS app shell, login sheet, model picker, app model state, RPC refresh flow, and any app action or agent interaction that depends on authenticated model access or subscription access.

The intended audience is implementation agents and maintainers adding GitHub issue 11: "Fix login flow with subscriptions".

In scope:

- Representing authentication, model access, and subscription access as explicit, separate states.
- Preserving API-key user flows by not treating API-key model availability as subscription entitlement.
- Refreshing model- and subscription-derived access immediately after successful login and other credential changes.
- Resetting stale model- and subscription-derived UI state on logout and credential replacement.
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

**Model Access**: The user's current ability to run model-backed agent interactions from any supported credential source, including API-key credentials and subscription credentials.

**Access Refresh**: A deliberate refresh of Authentication State, Model Access, and Subscription Access after login, logout, app launch, RPC restart, or user-invoked refresh.

**Subscription-Gated Action**: An App Action or agent interaction that requires active Subscription Access before it can run.

**Provider Login**: A login flow for a supported provider, including API-key save or subscription OAuth/device-code login.

**Credential Store**: The `pi` credential directory and `auth.json` file currently written under `~/.pi/agent` unless `PI_CODING_AGENT_DIR` overrides it.

**RPC Process**: The running `pi --mode rpc` process launched and supervised by Pi Agent Native.

**Refresh Epoch**: A native monotonically increasing identifier for one Access Refresh attempt. Responses from older epochs must not update access state after a newer epoch has started.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall model Authentication State separately from Model Access and Subscription Access.
- **REQ-002**: The app shall represent Model Access with at least these states: unknown, refreshing, unavailable, available, and failed.
- **REQ-003**: The app shall represent Subscription Access with at least these states: unknown, refreshing, inactive or missing, active, and failed.
- **REQ-004**: The app shall treat unknown, refreshing, inactive or missing, and failed Subscription Access as not active.
- **REQ-005**: API-key credentials may provide active Model Access without active Subscription Access.
- **REQ-006**: Model-backed actions that do not require subscriptions shall be enabled only when Model Access is available.
- **REQ-007**: Subscription-Gated Actions shall be enabled only when the latest Access Refresh completed successfully and Subscription Access is active.
- **REQ-008**: Prompt sending shall be gated by Model Access unless the selected model or action is explicitly subscription-gated.
- **REQ-009**: After API-key credentials are saved successfully, the app shall clear stale model- and subscription-derived state and perform an Access Refresh.
- **REQ-010**: After a subscription login process exits successfully, the app shall clear stale model- and subscription-derived state, restart or reconnect the RPC process as needed, and perform an Access Refresh.
- **REQ-011**: If a subscription login process fails, is stopped, exits non-zero, or is dismissed before success handling runs, the app shall not mark Authentication State as authenticated and shall not mark Subscription Access as active.
- **REQ-012**: Logout shall clear credentials for the selected provider or the whole app-level credential context, clear Authentication State, clear Model Access, clear Subscription Access, clear available models derived from old credentials, and refresh the UI immediately.
- **REQ-013**: The app shall not show model access or subscription access from a previous account after login, logout, provider switch, credential replacement, app launch, RPC exit, or RPC restart.
- **REQ-014**: Authentication errors and subscription lookup errors shall be surfaced through status text and process log details.
- **REQ-015**: Access Refresh shall request the running RPC process state and available models using the existing `get_state` and `get_available_models` commands unless the RPC protocol grows a more precise access-status command.
- **REQ-016**: Access Refresh shall correlate its `get_state` and `get_available_models` responses to a Refresh Epoch and shall ignore stale responses from older epochs.
- **REQ-017**: A refresh shall not become successful until both required responses for the current Refresh Epoch have succeeded.
- **REQ-018**: A failed `get_state` or `get_available_models` response during the current Access Refresh shall put Model Access and Subscription Access into failed or inactive states as appropriate and preserve a user-visible error.
- **REQ-019**: The app shall derive first-version active Model Access from fresh usable model availability returned by `pi`.
- **REQ-020**: The app shall derive first-version active Subscription Access only when fresh usable model availability belongs to a subscription-backed credential context. API-key-backed model availability shall not by itself mark Subscription Access active.
- **REQ-021**: The implementation shall identify the refreshed credential context from the native login method, readable credential-store metadata, or a future RPC access-status field. If the credential source cannot be determined, Subscription Access shall remain unknown or inactive instead of active.
- **REQ-022**: The model picker shall distinguish unauthenticated, refreshing, no model access, model access without active subscription, active subscription access, and refresh error states instead of showing only "No authenticated models found."
- **REQ-023**: Existing API-key providers and subscription providers shall continue to appear in the login sheet.
- **REQ-024**: The app shall not persist Subscription Access as authoritative app state across launches; app launch must refresh access from the current credential/RPC state.
- **REQ-025**: Closing the login sheet through Done, Escape, or modal dismissal shall use the same success/failure handling rules for any completed subscription login process.
- **CON-001**: The native app must not parse provider-specific billing pages, checkout state, or account dashboards.
- **CON-002**: The `pi` Credential Store remains the credential authority; native state may cache UI state but must not redefine credential semantics.
- **CON-003**: Access-gated UI must fail closed during asynchronous refreshes.
- **PAT-001**: Add a typed state model, for example `AuthAccessState`, rather than scattering optional booleans across `AppModel` and views.
- **PAT-002**: Centralize access gating in `AppModel` helpers so views render state and do not duplicate access rules.
- **PAT-003**: Add credential-store read and removal helpers to `NativeAuthStore` instead of making views edit `auth.json` directly.
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

enum ModelAccessState: Equatable {
    case unknown
    case refreshing
    case unavailable(reason: String?)
    case available(providerID: String?)
    case failed(message: String)
}

struct AuthAccessState: Equatable {
    var authentication: AuthenticationState
    var modelAccess: ModelAccessState
    var subscriptionAccess: SubscriptionAccessState
    var refreshEpoch: Int
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

The first-version model-access decision shall be:

- Available when the latest refresh succeeds and at least one usable model is returned for the current credential context.
- Unavailable when the latest refresh succeeds but no usable model is returned.
- Failed when either required refresh command returns an error or cannot be sent.

The first-version subscription-access decision shall be:

- Active when the latest refresh succeeds, at least one usable model is returned, and the credential context is known to be subscription-backed.
- Inactive or missing when the latest refresh succeeds but no usable subscription-backed access is found.
- Unknown or inactive when usable models are returned but the credential source cannot be distinguished from API-key access.
- Failed when either required refresh command returns an error or cannot be sent.

If a future RPC response provides a dedicated subscription/access field, the implementation may prefer that field while preserving the same native states and acceptance criteria.

### Login Sheet Contract

- API-key save calls the existing credential save path and then triggers Access Refresh.
- Subscription login calls the existing provider login command runner.
- A zero exit status from the subscription login process means credentials may have changed; it does not by itself mean Subscription Access is active.
- Closing the login sheet after successful subscription login must not leave access active until Access Refresh completes.
- Closing the login sheet through Escape or another modal dismissal must not skip required success or failure handling for a completed subscription login process.

### Logout Contract

The app shall provide a logout or credential-clearing path as part of this issue. The path must:

- Stop active login processes for the affected provider.
- Remove or invalidate the relevant credential entry through `NativeAuthStore`, preserving unrelated provider credentials unless the user chooses app-wide logout.
- Restart the RPC process when connected.
- Clear `availableModels`, selected model display if stale, Model Access, and Subscription Access immediately.
- Run Access Refresh if credentials remain for another provider.

## 5. Acceptance Criteria

- **AC-001**: Given the app has no usable credentials, When it launches or refreshes state, Then Authentication State is unauthenticated or unknown, Model Access is unavailable or unknown, and Subscription Access is not active.
- **AC-002**: Given a user saves a valid API key, When the save succeeds, Then stale model- and subscription-derived state is cleared and Access Refresh starts immediately.
- **AC-003**: Given a user completes subscription login and the login process exits with status 0, When the login sheet is closed or the success is observed, Then the RPC process restarts or reconnects and Access Refresh starts immediately.
- **AC-004**: Given a subscription login process exits non-zero, When the UI updates, Then Subscription Access is not active and the failure is visible in status text or process log.
- **AC-005**: Given Access Refresh is in progress, When the user views gated controls, Then model-backed actions and Subscription-Gated Actions are disabled or blocked with a refreshing state unless the action does not require model access.
- **AC-006**: Given Access Refresh succeeds with one or more usable API-key-backed models, When the UI updates, Then Model Access is available and Subscription Access is not active.
- **AC-007**: Given Access Refresh succeeds with one or more usable subscription-backed models, When the UI updates, Then Model Access is available, Subscription Access is active, and Subscription-Gated Actions may proceed.
- **AC-008**: Given Access Refresh succeeds with no usable models for the authenticated credential context, When the UI updates, Then the app shows authenticated-without-active-model-access or no-active-access state.
- **AC-009**: Given Access Refresh fails, When the UI updates, Then the app shows a refresh error and does not grant model or subscription access from any previous successful refresh.
- **AC-010**: Given the user logs out, When logout completes, Then auth-derived UI, available models, selected stale model display, model access, and subscription-derived access are reset.
- **AC-011**: Given existing provider lists, When the login sheet opens, Then Anthropic, ChatGPT / OpenAI Codex, GitHub Copilot subscription login, and current API-key providers remain available.
- **AC-012**: Given no active Subscription Access, When the user attempts a Subscription-Gated Action, Then the action does not run and a clear state-specific reason is surfaced.
- **AC-013**: Given Access Refresh A is in progress, When Access Refresh B starts and response A arrives later, Then response A is ignored and cannot overwrite B's access state.
- **AC-014**: Given subscription login exits with status 0, When the user dismisses the login sheet through Done, Escape, or another modal dismissal path, Then the same success handling clears stale access, restarts RPC, and starts Access Refresh exactly once.
- **AC-015**: Given an API-key-backed account has usable models, When the app renders subscription-only controls, Then those controls remain disabled unless a subscription-backed credential context is refreshed as active.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for state transitions and gating helpers; integration-style AppModel tests with mocked RPC command responses; view-model or UI tests for login/model-picker state rendering where practical.
- **Frameworks**: XCTest and existing SwiftPM test targets.
- **Test Data Management**: Use temporary credential directories for NativeAuthStore behavior and deterministic mock RPC responses for `get_state` and `get_available_models`.
- **CI/CD Integration**: Existing `swift test` must pass. New tests should run without real provider credentials, network access, or a real `pi` subscription.
- **Coverage Requirements**: Cover login success, login failure, refresh success with API-key-backed models, refresh success with subscription-backed models, refresh success without models, refresh failure, stale refresh response ordering, logout, credential replacement, and RPC exit/restart clearing behavior.
- **Performance Testing**: No load testing is required. Access Refresh should use existing RPC commands and should not block the main thread.

## 7. Rationale & Context

The current code saves API keys and runs subscription login commands, then restarts the RPC process. It also refreshes model availability, but the app does not model authentication, model access, and subscription access as explicit states. This makes it difficult for the UI to distinguish no credentials, API-key-backed model access, active subscription access, missing or inactive subscription, refresh in progress, and refresh failure.

The native app should not become a billing-provider client. The existing `pi` credential and RPC layer is the authority for authenticated capabilities. Pi Agent Native's responsibility is to clear stale derived state, request fresh capability state at the right moments, fail closed while the state is unknown, avoid conflating API-key model availability with subscription entitlement, and render the resulting access state clearly.

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
3. App clears stale Model Access and Subscription Access, then marks access refreshing.
4. App restarts RPC and sends get_state plus get_available_models.
5. App marks Subscription Access active only after refreshed model availability confirms usable subscription-backed access.
```

```text
Scenario: Account switch
1. Account A has active Subscription Access.
2. User logs out or replaces credentials.
3. App immediately clears Account A access and available models.
4. Until Account B refresh succeeds, Subscription-Gated Actions remain disabled.
```

```text
Scenario: API-key access
1. User saves an OpenAI API key.
2. App clears stale access and refreshes RPC state.
3. get_available_models returns usable API-key-backed models.
4. App marks Model Access available.
5. App does not mark Subscription Access active from API-key-backed models.
```

```text
Scenario: Stale refresh response
1. Refresh A starts after account A login.
2. User logs out or replaces credentials, starting Refresh B.
3. Refresh A's get_available_models response arrives after Refresh B starts.
4. App ignores Refresh A because its Refresh Epoch is stale.
```

```text
Scenario: Refresh error
1. User logs in successfully.
2. get_available_models fails.
3. App shows failed access and does not reuse previous active access.
```

## 10. Validation Criteria

- `swift test` passes.
- New state-transition tests prove stale active access is cleared before refresh after login, logout, and credential replacement.
- New gating tests prove unknown, refreshing, inactive, and failed Subscription Access cannot run Subscription-Gated Actions.
- New gating tests prove API-key-backed Model Access does not enable Subscription-Gated Actions.
- New AppModel tests prove successful refresh with API-key-backed models enables Model Access without Subscription Access.
- New AppModel tests prove successful refresh with subscription-backed models enables both Model Access and Subscription Access.
- New AppModel tests prove stale Refresh Epoch responses cannot overwrite a newer refresh state.
- New AppModel tests prove successful refresh without models shows authenticated-without-active-model-access state.
- Manual validation confirms model picker copy distinguishes unauthenticated, refreshing, no model access, model access without active subscription, active subscription, and refresh error states.
- Manual validation confirms existing API-key and subscription provider choices still appear and existing login commands still launch.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [README.md](../README.md)
- [docs/improvements.md](../docs/improvements.md)
