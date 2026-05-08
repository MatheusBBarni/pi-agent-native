# TechSpec: Login With Subscriptions

## Executive Summary

Implement subscription login state clarity by moving structured user-facing attempt state into `OAuthLoginRunner`, while keeping PiRPC access confirmation in `AppModel`. The runner owns the terminal-like provider login lifecycle; `AppModel` bridges PiRPC `get_state` and `get_available_models` refresh outcomes back into the runner state.

Primary trade-off: `OAuthLoginRunner` becomes more than a raw process wrapper, but this keeps all provider login attempt facts in one place and avoids duplicating provider, URL, attempt ID, output, and exit-status state in `AppModel` or `LoginSheetView`.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `OAuthLoginRunner` | Own provider login process state and user-facing phase | Does not decide usable access without AppModel refresh input |
| `AppModel` | Starts/stops login, restarts PiRPC, runs Access Refresh, preserves session/model/reasoning | Only bridge from PiRPC confirmation to runner state |
| `AuthAccessRefreshTracker` | Correlates `get_state` and `get_available_models` responses | Existing access authority remains unchanged |
| `LoginSheetView` | Renders runner-owned state and secondary terminal output | No ad hoc lifecycle derivation in the view |
| `NativeAuthStore` | Reads/writes local credential snapshot | No subscription-plan management |

Data flow:

1. `LoginSheetView` calls `AppModel.startSubscriptionLogin(provider:)`.
2. `AppModel` tells `OAuthLoginRunner` to start and sets phase to starting/waiting.
3. `OAuthLoginRunner` captures provider output and Provider Login URLs.
4. On process exit, `AppModel.completeSubscriptionLogin` restarts PiRPC and marks runner state refreshing.
5. `AuthAccessRefreshTracker` completes from existing PiRPC refresh responses.
6. `AppModel` maps refresh success/failure back into the runner phase.
7. `LoginSheetView` renders the structured phase.

## Implementation Design

### Core Interfaces

The project is Swift, so core interfaces are Swift value models rather than Go structs.

```swift
enum SubscriptionLoginPhase: Equatable {
    case notStarted
    case starting
    case waitingForProvider(url: URL?)
    case refreshingAccess
    case confirmed(providerID: String?)
    case failed(message: String)
    case stopped
}

struct SubscriptionLoginAttemptState: Equatable {
    var provider: LoginProvider?
    var attemptID: UUID?
    var phase: SubscriptionLoginPhase = .notStarted
    var lastURL: URL?
    var exitStatus: Int32?
}
```

`OAuthLoginRunner` should expose:

- `@Published var attemptState: SubscriptionLoginAttemptState`
- transition helpers such as `markWaitingForProvider(url:)`, `markRefreshingAccess()`, `markConfirmed(providerID:)`, `markFailed(_:)`, and `markStopped()`
- existing `output`, `isRunning`, `lastURL`, `currentProvider`, and `currentAttemptID` can remain during migration if needed, but the view should prefer `attemptState`

### Data Models

`SubscriptionLoginPhase`:

- `notStarted`: no active or retained attempt.
- `starting`: process launch requested but not yet waiting on provider.
- `waitingForProvider`: provider flow is active; may include a Provider Login URL.
- `refreshingAccess`: provider process completed successfully and PiRPC Access Refresh is running.
- `confirmed`: latest refresh confirms usable provider-backed access.
- `failed`: process launch, provider exit, or access refresh failed.
- `stopped`: user stopped the login attempt before confirmation.

`SubscriptionLoginAttemptState`:

- `provider`: selected provider for the attempt.
- `attemptID`: stable attempt identity for stale completion suppression.
- `phase`: current user-facing phase.
- `lastURL`: latest detected Provider Login URL.
- `exitStatus`: provider process exit status when available.

### API Endpoints

No new HTTP or external API endpoints are required.

Existing PiRPC commands remain the confirmation surface:

| Command | Use |
| --- | --- |
| `get_state` | Confirms current PiRPC state after restart or refresh |
| `get_available_models` | Confirms model availability and subscription-backed provider access |

No new PiRPC command is required for MVP. A future access-status command can be considered later if provider identity inference becomes insufficient.

## Integration Points

### Provider Login CLI

`OAuthLoginService` continues to resolve and run the provider login command. Provider CLIs remain responsible for account authentication and credential writing.

### PiRPC

`AppModel` continues to restart PiRPC after successful provider login and run Access Refresh. Confirmation must be derived only from the current refresh epoch.

### macOS Browser Handoff

`LoginSheetView` may still call `NSWorkspace.shared.open(url)` for Provider Login URLs. Browser-open success only moves the attempt into waiting state; it never confirms login.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `OAuthLoginRunner` | Modified | Adds structured attempt phase state | Add value model and transition helpers |
| `AppModel` | Modified | Bridges login lifecycle and PiRPC refresh outcomes into runner state | Update start, stop, completion, refresh success/failure paths |
| `LoginSheetView` | Modified | Renders structured state instead of relying on raw runner flags | Add focused status view and keep terminal output secondary |
| `AuthAccessRefreshTracker` | Unchanged | Existing refresh correlation remains authoritative | No new behavior required |
| `Model selection` | Modified | Preserve current model/reasoning if still supported after refresh | Validate refreshed availability before keeping selection |
| Tests | Modified | Add unit coverage for runner transitions and AppModel bridge | No SwiftUI view tests required for MVP |

## Testing Approach

### Unit Tests

Required:

- `OAuthLoginRunner` transitions from starting to waiting when process starts and/or URL appears.
- URL detection updates `attemptState.lastURL` and waiting phase.
- Stop moves the active attempt to stopped.
- Non-zero provider exit moves attempt to failed.
- Zero provider exit moves attempt to refreshing through `AppModel`.
- Access Refresh success moves attempt to confirmed.
- Access Refresh failure moves attempt to failed.
- Stale attempt completion does not update the current attempt.
- Selected model and reasoning are preserved when the refreshed provider still supports the selected model.
- Selected model is invalidated or requires user selection when refreshed availability no longer supports it.

Manual verification:

- Login modal displays not started, waiting, refreshing, confirmed, failed, and stopped states.
- Provider switching does not show stale confirmation as current provider confirmation.
- Terminal output remains visible but secondary.

No SwiftUI view tests are required for MVP.

### Integration Tests

No external-provider integration tests are required. Existing XCTest AppModel-style tests should simulate PiRPC responses using deterministic `get_state` and `get_available_models` data.

## Development Sequencing

### Build Order

1. Add `SubscriptionLoginPhase` and `SubscriptionLoginAttemptState` to the auth/login domain - no dependencies.
2. Add runner-owned `attemptState` and transition helpers to `OAuthLoginRunner` - depends on step 1.
3. Update `AppModel.startSubscriptionLogin`, `stopSubscriptionLogin`, and completion paths to drive runner transitions - depends on step 2.
4. Update Access Refresh handling to mark runner confirmed or failed from current PiRPC refresh outcome - depends on step 3.
5. Preserve current session, model, and reasoning after successful refresh when the refreshed model list still supports the selection - depends on step 4.
6. Update `LoginSheetView` to render the structured runner state and keep terminal output secondary - depends on steps 2 through 4.
7. Add unit tests for runner transitions and AppModel refresh confirmation - depends on steps 2 through 5.
8. Run targeted auth/login tests, then `swift test` if unrelated existing failures are resolved or documented - depends on step 7.

### Technical Dependencies

- Existing SwiftPM/XCTest setup.
- Existing PiRPC `get_state` and `get_available_models` commands.
- Existing provider login command resolution.
- Known unrelated test failures may need documentation if full `swift test` remains red outside this scope.

## Monitoring and Observability

Use existing process log/event log surfaces.

Recommended log events:

| Event | Fields |
| --- | --- |
| `subscription login state` | provider ID, attempt ID, phase |
| `provider login url detected` | provider ID, attempt ID, URL host |
| `access refresh linked to login` | provider ID, attempt ID, refresh epoch |
| `subscription login confirmed` | provider ID, attempt ID |
| `subscription login failed` | provider ID, attempt ID, reason |

Do not log full callback URLs if they may contain tokens or codes. Prefer host/path-safe summaries.

## Technical Considerations

### Key Decisions

- Runner owns login attempt state because it already owns the provider login process.
- AppModel remains the only bridge between PiRPC access refresh and runner confirmation.
- Existing PiRPC refresh commands remain the MVP confirmation source.
- Session continuity follows terminal behavior: preserve the current session, model, and reasoning when still valid after refresh.
- Unit tests plus manual modal verification are sufficient for MVP.

### Known Risks

| Risk | Mitigation |
| --- | --- |
| Runner and `authAccess` drift | Only AppModel maps refresh results into runner confirmation. |
| Process exit is mistaken for login success | Reserve confirmed phase for Access Refresh success. |
| Provider identity inference is insufficient later | Consider a future PiRPC access-status command. |
| Model no longer exists after provider switch | Require explicit user model selection when refreshed availability does not support the previous selection. |
| URL may include sensitive callback data | Log only safe URL summaries. |

## Architecture Decision Records

- [ADR-001: Keep Subscription Login Provider-CLI Mediated](adrs/adr-001.md) — V1 keeps provider CLIs and Pi credentials as the authority for subscription login.
- [ADR-002: Prioritize Provider Login State Clarity](adrs/adr-002.md) — MVP focuses on clear provider login states for users switching providers.
- [ADR-003: Own Subscription Login Attempt State in OAuthLoginRunner](adrs/adr-003.md) — Structured login attempt state lives in the runner, with AppModel bridging PiRPC refresh confirmation.
