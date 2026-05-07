---
title: Session Compaction UX Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, compaction, rpc, inspector]
---

# Introduction

This specification defines the first native Session Compaction experience for Pi Agent Native. The goal is to make compaction state visible in the shell, let users trigger manual compaction when the active Pi RPC session supports it, and retain a concise visible result after compaction completes, fails, or is aborted.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's RPC compaction decoding, reducer effects, AppModel compaction state, command availability, Inspector UI, and compaction-focused tests.

The intended audience is implementation agents and maintainers adding GitHub issue 22: "Add compaction controls and context state UX".

In scope:

- Decode and model `compaction_start` and `compaction_end` events with reason, result, retry, abort, and error details.
- Preserve and display `get_state.isCompacting`.
- Add a native Compaction Control that sends `PiRPCCommand.compact()` when available.
- Disable or hide compaction controls when the selected app state cannot compact.
- Show active, completed, failed, aborted, and unavailable compaction states outside the process log.
- Render a concise, inspectable Compaction Result in the Inspector or equivalent shell surface.
- Keep process-log entries as secondary diagnostics.
- Add unit tests for event reduction, command availability, and visible state formatting.

Out of scope:

- Auto-compaction settings UI.
- Custom compaction instruction entry.
- Abort-compaction controls.
- Full token accounting dashboard.
- Editing or deleting compaction summaries.
- Persisting native compaction UI state separately from Pi session state.
- Replacing chat history rendering with native compaction-summary message rendering.
- Branch summarization UX.

## 2. Definitions

**Pi RPC**: The line-delimited JSON protocol used by Pi Agent Native to communicate with the running Pi coding agent.

**Session Compaction**: A Pi operation that summarizes older conversation context so a session can continue within model context limits.

**Compaction State**: The current or latest user-facing status of Session Compaction for the active Pi RPC session.

**Compaction Result**: The visible outcome of a completed, failed, or aborted Session Compaction.

**Compaction Control**: A native control that triggers Session Compaction for the active session when Pi RPC supports it.

**Inspector**: The persistent right-side shell region that shows project, process, model, queue, compaction, and tool activity context for the current conversation.

**Selected Session**: The conversation session currently active inside the Selected Project.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall model Session Compaction as structured runtime state, not only as process-log text.
- **REQ-002**: The app shall expose Compaction State in the chat shell outside the process log.
- **REQ-003**: The first Compaction State surface shall live in the Inspector near process/model/queue/tool context.
- **REQ-004**: The app shall expose a discoverable native Compaction Control when the active Pi RPC session can compact.
- **REQ-005**: Activating the Compaction Control shall send `PiRPCCommand.compact()` through the existing Pi RPC command path.
- **REQ-006**: The Compaction Control shall be disabled or hidden when no Selected Project exists.
- **REQ-007**: The Compaction Control shall be disabled or hidden when no Selected Session exists.
- **REQ-008**: The Compaction Control shall be disabled while the app is disconnected from Pi RPC.
- **REQ-009**: The Compaction Control shall be disabled while `isStreaming` is true.
- **REQ-010**: The Compaction Control shall be disabled while `isCompacting` is true.
- **REQ-011**: The Compaction Control shall follow existing modal-blocking behavior for non-modal app actions.
- **REQ-012**: A `compaction_start` event shall set active Compaction State and preserve the start reason when present.
- **REQ-013**: A `compaction_end` event with `result` shall set completed Compaction State and capture summary, `tokensBefore`, `firstKeptEntryId`, reason, and `willRetry`.
- **REQ-014**: A `compaction_end` event with `errorMessage` and no result shall set failed Compaction State and show the error message.
- **REQ-015**: A `compaction_end` event with `aborted == true` shall set aborted Compaction State.
- **REQ-016**: A successful `compact` command response containing a compaction result shall update the same Compaction Result state as the event path.
- **REQ-017**: A failed `compact` command response shall set failed Compaction State and retain the error in the process log.
- **REQ-018**: `get_state.isCompacting` shall refresh active/inactive Compaction State without erasing the latest completed or failed Compaction Result unless a session boundary changes.
- **REQ-019**: The visible Compaction Result shall include a concise status label and enough detail to explain what happened.
- **REQ-020**: The visible Compaction Result shall constrain long summaries so Inspector layout remains stable while allowing inspection of more detail where practical.
- **REQ-021**: Compaction State shall reset when starting a new chat, switching sessions, stopping RPC, or selecting a different project.
- **REQ-022**: Session Compaction shall not append a normal chat message directly from native state; chat history should change only from Pi RPC message history/events.
- **REQ-023**: The process log shall remain a secondary diagnostic surface for compaction start, completion, failure, and command errors.
- **CON-001**: Pi RPC owns compaction semantics and session file updates.
- **CON-002**: The native app must not infer token savings when Pi RPC does not provide token data.
- **CON-003**: Manual compaction is the only user-triggered compaction behavior in this issue.
- **CON-004**: Auto-compaction can be displayed as event/state information but cannot be configured in this issue.
- **PAT-001**: Add a compact value model, such as `CompactionStatus` or `CompactionDisplayState`, with active, completed, failed, aborted, unavailable, and idle cases.
- **PAT-002**: Add a typed `PiRPCCompactionEnd` model instead of carrying only `errorMessage`.
- **PAT-003**: Route compaction updates through `PiRPCEventReducer` effects.
- **PAT-004**: Add a dedicated App Action, such as `compactSession`, with no Default Keymap binding in this issue.
- **PAT-005**: Keep compaction result formatting in a testable non-view type.

## 4. Interfaces & Data Contracts

### Pi RPC Command Contract

The native Compaction Control shall send:

```json
{"type": "compact"}
```

The upstream command also accepts optional custom instructions:

```json
{"type": "compact", "customInstructions": "Focus the summary on file changes"}
```

Custom instruction input is out of scope for this issue. The first native Compaction Control shall send the no-instructions form.

### Pi RPC State Contract

`get_state` includes:

```typescript
interface RpcSessionState {
  isCompacting: boolean;
  autoCompactionEnabled: boolean;
  messageCount: number;
  pendingMessageCount: number;
}
```

Required native behavior:

- Read `isCompacting` into active Compaction State.
- Treat `autoCompactionEnabled` as optional display information only if it is easy to expose; do not add a settings toggle in this issue.
- Do not require `messageCount` thresholds to enable manual compaction because Pi RPC is the authority for whether `compact` succeeds.

### Pi RPC Event Contract

Compaction start:

```json
{"type": "compaction_start", "reason": "threshold"}
```

Compaction end success:

```json
{
  "type": "compaction_end",
  "reason": "threshold",
  "result": {
    "summary": "Summary of conversation...",
    "firstKeptEntryId": "abc123",
    "tokensBefore": 150000,
    "details": {}
  },
  "aborted": false,
  "willRetry": false
}
```

Compaction end failure:

```json
{
  "type": "compaction_end",
  "reason": "manual",
  "result": null,
  "aborted": false,
  "willRetry": false,
  "errorMessage": "API quota exceeded"
}
```

Required native event model:

```swift
enum CompactionReason: String, Equatable {
    case manual
    case threshold
    case overflow
    case unknown
}

struct PiRPCCompactionResult: Equatable {
    var summary: String
    var firstKeptEntryId: String
    var tokensBefore: Int?
}

struct PiRPCCompactionEnd: Equatable {
    var reason: CompactionReason
    var result: PiRPCCompactionResult?
    var aborted: Bool
    var willRetry: Bool
    var errorMessage: String?
}
```

Exact names may differ, but the model must preserve the fields needed to format completed, failed, and aborted states.

### Native Display State Contract

The implementation shall expose state equivalent to:

```swift
enum CompactionDisplayState: Equatable {
    case unavailable(String)
    case idle
    case running(reason: CompactionReason?)
    case completed(CompactionResultDisplay)
    case failed(message: String, reason: CompactionReason?)
    case aborted(reason: CompactionReason?)
}

struct CompactionResultDisplay: Equatable {
    var reason: CompactionReason?
    var summary: String
    var tokensBefore: Int?
    var firstKeptEntryId: String
    var willRetry: Bool
}
```

Formatting requirements:

- Running manual compaction: "Compacting session".
- Running threshold or overflow compaction: include automatic reason when known.
- Completed compaction: include "Compacted" plus tokens-before detail when available.
- Failed compaction: include "Compaction failed" plus the error message.
- Aborted compaction: include "Compaction aborted".
- Overflow compaction with `willRetry == true`: explain that Pi will retry after compaction.

### Current Code Mapping

| Component | Existing state | Required issue 22 behavior |
|---|---|---|
| `PiRPCCommand.compact()` | Exists but is not exposed in UI | Triggered by native Compaction Control |
| `PiRPCEvent.compactionStart` | Carries raw payload | Preserve reason in typed compaction state |
| `PiRPCEvent.compactionEnd` | Carries only `errorMessage` | Preserve result, reason, aborted, willRetry, and error |
| `PiRPCEventReducer` | Sets `isCompacting` and appends process-log text | Emits structured compaction state effects |
| `AppModel.isCompacting` | Boolean from events/get_state | Remains available and synchronizes with display state |
| `AppModel.performAppAction` | No compaction action | Adds a manual compaction App Action or equivalent shared dispatch |
| `AppModel.canPerformAppAction` | No compaction availability rule | Adds selected-project/session, connection, modal, streaming, and compacting availability |
| `InspectorView` | Does not show compaction state | Renders Compaction State, Compaction Control, and latest result |
| `RPCTests` | Tests generic compaction effects only indirectly | Tests compaction event decoding/reduction and formatting |

## 5. Acceptance Criteria

- **AC-001**: Given Pi RPC reports `isCompacting == true`, When the Inspector renders, Then active Compaction State is visible outside the process log.
- **AC-002**: Given a Selected Project, Selected Session, connected Pi RPC process, no active modal, no streaming, and no active compaction, When the Inspector renders, Then the Compaction Control is available.
- **AC-003**: Given no Selected Project exists, When the Inspector renders, Then the Compaction Control is disabled or hidden with a clear unavailable state.
- **AC-004**: Given no Selected Session exists, When the Inspector renders, Then the Compaction Control is disabled or hidden with a clear unavailable state.
- **AC-005**: Given the app is streaming, When the Inspector renders, Then the Compaction Control is disabled.
- **AC-006**: Given compaction is already running, When the Inspector renders, Then the Compaction Control is disabled and active state is visible.
- **AC-007**: Given the user activates the enabled Compaction Control, Then the app sends `PiRPCCommand.compact()`.
- **AC-008**: Given `compaction_start` with reason `manual`, When the reducer processes it, Then Compaction State becomes running with manual reason.
- **AC-009**: Given `compaction_end` with a result summary and `tokensBefore`, When the reducer processes it, Then Compaction Result shows completion details.
- **AC-010**: Given `compaction_end` with `errorMessage`, When the reducer processes it, Then Compaction Result shows failed status and the error message.
- **AC-011**: Given `compaction_end` with `aborted == true`, When the reducer processes it, Then Compaction Result shows aborted status.
- **AC-012**: Given overflow compaction ends with `willRetry == true`, Then the visible result says Pi will retry after compaction.
- **AC-013**: Given a successful `compact` response returns a result before or after `compaction_end`, Then the latest visible Compaction Result is consistent and not duplicated.
- **AC-014**: Given a failed `compact` response, Then the UI shows failed Compaction State and the process log records the failure.
- **AC-015**: Given the user starts a new chat, switches sessions, stops RPC, or changes selected project, Then stale Compaction Result is cleared for the new context.
- **AC-016**: Given Compaction State changes, Then normal chat use, queue rendering, tool activity rendering, and composer focus are not blocked except for the disabled manual compaction action.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for RPC compaction event parsing, reducer effects, AppModel action availability, command dispatch, and display formatting; manual UI smoke tests for Inspector controls.
- **Frameworks**: XCTest using existing SwiftPM test targets.
- **Test Data Management**: Use in-memory `PiRPCEvent`, `PiRPCEventReducer`, `ConversationStore`, `ToolActivityStore`, and seeded `AppModel` instances.
- **CI/CD Integration**: Existing `swift test` must pass.
- **Coverage Requirements**:
  - Decode `compaction_start` reason.
  - Decode successful `compaction_end` result fields.
  - Decode failed and aborted `compaction_end`.
  - Reduce compaction events into display state and `isCompacting`.
  - Apply successful and failed `compact` responses to display state.
  - Verify manual compaction availability rules.
  - Verify no Default Keymap binding is added for manual compaction in this issue.
- **Performance Testing**: No dedicated performance testing is required. Compaction UI updates are small state transitions and must not perform blocking IO.

## 7. Rationale & Context

Issue 22 asks users to understand and control long-running session context. The native app already receives `isCompacting` from `get_state`, has `PiRPCCommand.compact()`, and decodes `compaction_start` and `compaction_end`, but the current reducer stores only a boolean and appends process-log text. Users therefore cannot inspect what happened without opening the log, and they cannot trigger compaction from the native shell.

The first slice should expose a manual Compaction Control and structured Compaction State in the Inspector. The Inspector is the right first surface because it already contains session/process/model/queue/tool context and can show durable operational state without changing chat history semantics.

Pi RPC remains the authority for compaction behavior, summary content, token counts, retry behavior, and session file updates. The native app should display and dispatch, not recalculate compaction thresholds or edit session history.

No ADR is required because this is reversible UI/state modeling on the existing typed RPC command and reducer path.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Pi RPC `compact` command - Required for manual compaction.
- **EXT-002**: Pi RPC `compaction_start` and `compaction_end` events - Required for live compaction state.
- **EXT-003**: Pi RPC `get_state` response - Required for `isCompacting` refresh state.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: Existing typed Pi RPC command path - Required to send `compact`.
- **INF-002**: Existing typed Pi RPC event decoder - Required to decode compaction events.
- **INF-003**: Existing `PiRPCEventReducer` - Required to route compaction state into AppModel.
- **INF-004**: Existing Inspector UI - Required for the first Compaction State surface.

### Data Dependencies

- **DAT-001**: Runtime Pi RPC session state only. The native app must not persist compaction display state separately.

### Technology Platform Dependencies

- **PLT-001**: SwiftUI - Required to render the Inspector control and state.
- **PLT-002**: Swift XCTest - Required for model, reducer, and availability tests.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Scenario: Manual compaction
1. Selected Project and Selected Session exist.
2. Pi RPC is connected, not streaming, and not compacting.
3. User activates Compact Session.
4. App sends {"type":"compact"}.
5. App shows running Compaction State.
6. App shows completed Compaction Result when result arrives.
```

```json
{
  "type": "compaction_end",
  "reason": "manual",
  "result": {
    "summary": "The user implemented keybindings and queue UI specs...",
    "firstKeptEntryId": "entry-123",
    "tokensBefore": 150000
  },
  "aborted": false,
  "willRetry": false
}
```

Expected visible result:

```text
Compacted from 150,000 tokens
The user implemented keybindings and queue UI specs...
```

```text
Scenario: Failed compaction
1. Compaction starts.
2. Pi RPC emits compaction_end with errorMessage = "API quota exceeded".
3. App sets isCompacting to false.
4. Inspector shows "Compaction failed" and the error.
5. Process log also records the failure.
```

```text
Scenario: Overflow retry
1. Pi RPC emits compaction_end with reason overflow, result present, and willRetry true.
2. Inspector shows compaction completed.
3. Inspector also indicates Pi will retry after compaction.
```

## 10. Validation Criteria

- `CONTEXT.md` defines Session Compaction, Compaction State, Compaction Result, and Compaction Control.
- `spec/spec-design-session-compaction-ux.md` exists and follows the project spec naming convention.
- Manual compaction is dispatched through a shared action path, not by direct view-layer RPC calls.
- Compaction availability is centralized and tested.
- `compaction_start` and `compaction_end` preserve reason, result, abort, retry, and error details.
- Inspector UI shows running, completed, failed, aborted, unavailable, and idle compaction states.
- Compaction results clear on session/project/RPC context changes.
- No Default Keymap binding is added for manual compaction in this issue.
- Unit tests cover compaction event reduction, command availability, command dispatch, and display formatting.
- `swift test` passes after implementation.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 3: Architecture: Typed RPC layer](https://github.com/MatheusBBarni/pi-agent-native/issues/3)
- [GitHub issue 22: Add compaction controls and context state UX](https://github.com/MatheusBBarni/pi-agent-native/issues/22)
