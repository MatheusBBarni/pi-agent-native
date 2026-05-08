---
title: Steering and Follow-Up Queue UI Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, queue, rpc, inspector]
---

# Introduction

This specification defines the first native Queue Surface for Pi Agent Native. The goal is to represent pending steering and follow-up work as visible, inspectable queue entries instead of only a numeric pending count, using the typed Pi RPC queue update event as the source of truth.

## 1. Purpose & Scope

This specification applies to Pi Agent Native's RPC queue decoding, reducer effects, AppModel queue state, Inspector UI, and queue-focused tests.

The intended audience is implementation agents and maintainers adding GitHub issue 21: "Add steering and follow-up queue UI".

In scope:

- Decode `queue_update` events into typed queue entries.
- Preserve the existing pending message count behavior while adding visible queue entry state.
- Distinguish steering queue entries from follow-up queue entries.
- Render queue entries in a native Queue Surface, with the Inspector as the first implementation surface.
- Show enough summary text for users to identify each queued item.
- Handle empty, loading, count-only, and active queue states without blocking chat use.
- Add unit coverage for queue event reduction and visible queue state formatting.

Out of scope:

- Creating new controls to submit steering or follow-up messages.
- Editing, reordering, deleting, clearing, or retrying queued work.
- Changing Pi RPC queue delivery semantics.
- Persisting queue entries in `SessionStore`.
- Treating queue entries as chat history before Pi drains them into agent work.
- Rendering image attachments for queued messages in the first slice.
- Adding notifications or badges outside the first Queue Surface.

## 2. Definitions

**Pi RPC**: The line-delimited JSON protocol used by Pi Agent Native to communicate with the running Pi coding agent.

**Queued Work**: A user-facing prompt-like message accepted by Pi Agent Native while the Pi coding agent is busy and waiting for later delivery to the agent.

**Steering Queue Entry**: Queued Work that is intended to steer the currently running agent work before follow-up work is processed.

**Follow-Up Queue Entry**: Queued Work that is intended to run after current agent work and any steering queue entries are drained.

**Queue Surface**: A native UI surface that shows Queued Work entries and their delivery category.

**Inspector**: The persistent right-side shell region that shows project, process, model, and tool activity context for the current conversation.

**Tool Activity**: Native UI state for tool calls and tool results, separate from Queued Work.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall represent queued steering and follow-up messages as typed native queue entries.
- **REQ-002**: The app shall preserve the existing `pendingMessageCount` behavior for compatibility with running-session status.
- **REQ-003**: The app shall derive `pendingMessageCount` from full queue entries when a `queue_update` event is available.
- **REQ-004**: The app shall continue to accept count-only queue state from `get_state.pendingMessageCount` when full queue entries are not available.
- **REQ-005**: A `queue_update` event with empty `steering` and empty `followUp` arrays shall clear visible queue entries and set the pending message count to zero.
- **REQ-006**: The app shall distinguish Steering Queue Entries from Follow-Up Queue Entries in the UI.
- **REQ-007**: Each visible queue entry shall show a stable category label and a summary derived from the queued message text.
- **REQ-008**: Queue entry summaries shall preserve enough text to identify the queued item while preventing long messages from breaking Inspector layout.
- **REQ-009**: The Queue Surface shall handle empty state with a concise "no queued work" presentation.
- **REQ-010**: The Queue Surface shall handle loading or unknown detail state without blocking normal chat, composer, or tool activity use.
- **REQ-011**: If `get_state.pendingMessageCount` reports a nonzero count before any full `queue_update` arrives, the Queue Surface shall show a count-only state rather than inventing placeholder entries.
- **REQ-012**: The Queue Surface shall update live from Pi RPC `queue_update` events while a run is active.
- **REQ-013**: The first Queue Surface shall live in the Inspector near existing process/model/tool context.
- **REQ-014**: Queue entries shall not be appended to the conversation until Pi emits normal message events for delivered work.
- **REQ-015**: Queue entries shall not be persisted in native project/session state.
- **REQ-016**: Queue UI state shall be cleared when starting a new chat, switching sessions, stopping/restarting the RPC process, or receiving an authoritative empty `queue_update`.
- **REQ-017**: The app shall not use the process log as the primary queue inspection surface.
- **REQ-018**: The implementation shall not conflate Queued Work with Tool Activity entries, even though both can appear in the Inspector.
- **REQ-019**: The app shall track whether full queue detail has been received for the active RPC session, so count-only `get_state` data does not accidentally overwrite visible queue entries.
- **REQ-020**: If `get_state.pendingMessageCount` is `0`, the visible queue display state shall clear for the active session.
- **REQ-021**: Queue detail shall be scoped to the active RPC process/session generation; stale queue entries from a previous process, new chat, or session switch must never be displayed after the active context changes.
- **REQ-022**: Non-string elements inside `steering` or `followUp` arrays shall not create visible queue entries.
- **CON-001**: Pi RPC `queue_update` currently carries `steering` and `followUp` as arrays of strings; the first native model shall preserve those strings and avoid assuming hidden ids or timestamps.
- **CON-002**: The first slice shall be read-only queue visibility.
- **CON-003**: Queue rendering must not block prompt submission, streaming updates, extension UI, or tool activity rendering.
- **CON-004**: The UI must remain useful if a session only reports a numeric pending count.
- **CON-005**: Do not change prompt submission, steering controls, follow-up controls, or `streamingBehavior` handling as part of this issue except where state clearing is required for queue display correctness.
- **CON-006**: Invalid queue array elements shall be ignored for visible entries instead of stringified into user-facing text.
- **PAT-001**: Add a small value model, such as `QueuedWorkEntry`, with `kind`, `text`, and computed `summary` fields.
- **PAT-002**: Add formatting logic for queue entry summaries in a testable non-view type.
- **PAT-003**: Route queue updates through `PiRPCEventReducer` effects instead of mutating AppModel directly from decode code.
- **PAT-004**: Keep queue state in AppModel or a small observable store; do not place queue parsing in `InspectorView`.
- **PAT-005**: Prefer one state-setting reducer effect that carries both visible queue entries and the derived pending count, instead of emitting independent effects that can get out of sync.

## 4. Interfaces & Data Contracts

### Pi RPC Event Contract

The upstream Pi RPC event is:

```json
{
  "type": "queue_update",
  "steering": ["Focus on error handling"],
  "followUp": ["After that, summarize the result"]
}
```

Required native interpretation:

| RPC field | Native meaning |
|---|---|
| `steering` | Ordered list of Steering Queue Entry text |
| `followUp` | Ordered list of Follow-Up Queue Entry text |
| missing or non-array `steering` | Treat as empty for visible entries; do not crash |
| missing or non-array `followUp` | Treat as empty for visible entries; do not crash |
| non-string elements in either array | Ignore for visible entries; do not crash and do not stringify |

Pi RPC also supports queuing through `prompt` with `streamingBehavior: "steer"` or `streamingBehavior: "followUp"`, plus explicit `steer` and `follow_up` commands. This issue only renders the resulting queue state; it does not add or redesign submission controls.

### Native Queue Model Contract

The implementation shall expose a native model equivalent to:

```swift
enum QueuedWorkKind: String, Equatable {
    case steering
    case followUp
}

struct QueuedWorkEntry: Identifiable, Equatable {
    var id: String
    var kind: QueuedWorkKind
    var text: String
    var position: Int

    var title: String
    var summary: String
}
```

Required behavior:

- `id` may be deterministic from `kind` and `position` because the RPC event does not provide ids.
- `position` is zero-based within its category.
- `title` must be "Steering" for steering entries and "Follow-up" for follow-up entries.
- `summary` must trim leading/trailing whitespace, collapse internal whitespace, and use a clear fallback such as "Empty queued message" if the source text is empty after trimming.
- Very long summaries must be truncated for UI presentation by shared formatting logic or SwiftUI line limits.
- Invalid non-string queue array elements must not create visible queue entries.
- Non-array `steering` or `followUp` fields must produce no visible entries for that category.

### Queue State Contract

The implementation shall expose queue display state equivalent to:

```swift
enum QueuedWorkDisplayState: Equatable {
    case loading
    case empty
    case countOnly(Int)
    case entries([QueuedWorkEntry])
}
```

State rules:

| Input | Required state |
|---|---|
| App has not received queue detail and no count is known | `loading` or `empty`, depending existing app connection conventions |
| `get_state.pendingMessageCount == 0` | `empty`; clear any visible queue detail for the active session |
| `get_state.pendingMessageCount > 0` and no queue detail exists | `countOnly(count)` |
| `queue_update` with entries | `entries(entries)` |
| `queue_update` with both arrays empty | `empty` |
| New chat, session switch, RPC stop/restart | `empty` unless a subsequent count or queue event says otherwise |
| `get_state.pendingMessageCount > 0` after queue detail exists and the count matches visible entry count | Preserve the existing visible queue detail |
| `get_state.pendingMessageCount > 0` after queue detail exists and the count differs from visible entry count | Replace the detail display with `countOnly(count)` rather than showing stale or fake entries |

### Current Code Mapping

| Component | Existing state | Required issue 21 behavior |
|---|---|---|
| `PiRPCQueueUpdate` | Stores `steeringCount` and `followUpCount` only | Store visible `QueuedWorkEntry` values for steering and follow-up strings |
| `PiRPCEventReducerEffect` | Has `setPendingMessageCount(Int)` | Add an effect that carries queue detail, or replace with a richer queue state effect |
| `PiRPCEventReducer` | Reduces queue updates to a count only | Reduces queue updates to queue entries and count |
| `AppModel.pendingMessageCount` | Numeric pending count | Remains available and is synchronized with queue detail |
| `AppModel` | No visible queue entry state | Owns or exposes queue display state for UI rendering |
| `InspectorView` | Shows "`N` queued" as a metric when count > 0 | Renders a Queue Surface with category labels, summaries, and empty/count-only states |
| `RPCTests` | Verifies queue count effect only | Verifies typed queue entries, formatting, and reducer output |

Implementation agents should also inspect existing reset paths in `AppModel.start()`, `AppModel.stop()`, `AppModel.newSession()`, `switch_session` response handling, and RPC process exit handling, because those paths are where stale queue detail can leak into a new active context.

## 5. Acceptance Criteria

- **AC-001**: Given Pi RPC emits `queue_update` with two steering strings and one follow-up string, When the reducer processes the event, Then AppModel exposes three queue entries and `pendingMessageCount == 3`.
- **AC-002**: Given a queue entry is created from the `steering` array, Then its category label is "Steering".
- **AC-003**: Given a queue entry is created from the `followUp` array, Then its category label is "Follow-up".
- **AC-004**: Given queued message text contains leading, trailing, or repeated whitespace, Then the visible summary is trimmed and whitespace-normalized.
- **AC-005**: Given queued message text is empty after trimming, Then the visible summary uses a nonblank fallback.
- **AC-006**: Given Pi RPC emits an empty `queue_update`, When the reducer processes the event, Then visible queue entries are cleared and `pendingMessageCount == 0`.
- **AC-007**: Given `get_state.pendingMessageCount == 2` before full queue details arrive, When the Inspector renders the Queue Surface, Then it shows a count-only state rather than fake entries.
- **AC-008**: Given a later full `queue_update` arrives, When the Inspector renders again, Then it replaces count-only state with specific queue entries.
- **AC-009**: Given there is no queued work, When the Inspector renders, Then the Queue Surface shows an empty state or omits entry rows without showing stale queue data.
- **AC-010**: Given the agent is streaming and queue updates arrive, Then conversation streaming, composer interaction, and tool activity rendering continue normally.
- **AC-011**: Given queued work is visible, When the user starts a new chat or switches sessions, Then stale queue entries are not shown for the new context.
- **AC-012**: Given queued work is visible, Then the process log is not required to identify whether each item is steering or follow-up.
- **AC-013**: Given queued work is visible, Then the queued text is not appended to chat history until normal message events represent delivered work.
- **AC-014**: Given visible queue entries exist, When the RPC process stops, exits, restarts, or a new session is requested, Then the Queue Surface clears before any new session state is shown.
- **AC-015**: Given full queue detail exists, When a count-only `get_state` response arrives, Then the app does not replace real visible entries with fake rows.
- **AC-016**: Given `get_state.pendingMessageCount == 0` and the app has stale queue detail from an older active context, When the state response is applied, Then the Queue Surface shows empty state.
- **AC-017**: Given a `queue_update` payload contains non-string values in either queue array, When the queue model is built, Then invalid values are ignored and the app does not crash.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for RPC queue model parsing, reducer effects, AppModel queue state application, and summary formatting; manual UI smoke tests for Inspector rendering.
- **Frameworks**: XCTest using the existing SwiftPM test targets.
- **Test Data Management**: Use in-memory `PiRPCQueueUpdate`, `PiRPCEventReducer`, `ConversationStore`, `ToolActivityStore`, and `AppModel` instances.
- **CI/CD Integration**: Existing `swift test` must pass.
- **Coverage Requirements**:
  - Decode `queue_update` arrays into ordered steering and follow-up queue entries.
  - Preserve pending count compatibility.
  - Clear entries on empty queue update.
  - Clear entries on process/session context changes.
  - Ignore invalid non-string queue array elements.
  - Preserve count-only fallback without replacing real queue detail with placeholder entries.
  - Normalize and truncate visible summaries.
  - Render or compute empty, count-only, and entry states.
  - Verify queue updates do not mutate conversation messages or tool activity.
- **Performance Testing**: No dedicated performance tests are required. Queue updates are small arrays of strings and must be processed synchronously without IO.

## 7. Rationale & Context

Issue 21 asks users to see pending steering and follow-up work without relying on the process log. The current native app has the typed RPC foundation from issue 3 and already decodes `queue_update`, but it only keeps `pendingMessageCount`. The Inspector currently displays this as a single "`N` queued" metric, which explains that something is pending but not what is pending or whether it is steering or follow-up work.

The Pi RPC contract emits full pending queues whenever they change. The native app should therefore keep visible queue entries from `queue_update` and reserve `get_state.pendingMessageCount` for compatibility and count-only fallback. Because queue entries have no upstream ids or timestamps, the first slice should avoid edit/reorder/delete behavior and use deterministic display ids only for SwiftUI rendering.

The current Pi RPC documentation also allows `prompt` commands submitted during streaming to become steering or follow-up work when `streamingBehavior` is set. That is a submission concern, not a visibility concern. This issue must render whatever queued work Pi reports through `queue_update` without changing the current native composer behavior.

The Inspector is the first Queue Surface because it already presents process, model, pending count, and tool activity context. This keeps the first slice focused and avoids redesigning chat history or composer submission behavior.

No ADR is required because this is a reversible UI and state-model extension built on the existing typed RPC reducer architecture.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Pi RPC `queue_update` event - Provides full steering and follow-up queue arrays.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: Existing typed Pi RPC event decoder - Required to decode `queue_update`.
- **INF-002**: Existing `PiRPCEventReducer` - Required to route queue updates into AppModel state.
- **INF-003**: Existing AppModel state relay - Required to refresh Inspector UI when queue state changes.
- **INF-004**: Existing Inspector UI - Required for the first Queue Surface.

### Data Dependencies

- **DAT-001**: None. Queue entries are runtime Pi RPC session state and must not be persisted by Pi Agent Native.

### Technology Platform Dependencies

- **PLT-001**: SwiftUI - Required to render the Queue Surface.
- **PLT-002**: Swift XCTest - Required for queue parser, reducer, and formatting tests.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```json
{
  "type": "queue_update",
  "steering": ["Focus on the failing test first", "Do not refactor unrelated files"],
  "followUp": ["After tests pass, summarize the patch"]
}
```

Expected visible entries:

```text
Steering: Focus on the failing test first
Steering: Do not refactor unrelated files
Follow-up: After tests pass, summarize the patch
```

```text
Scenario: Count-only state
1. get_state reports pendingMessageCount = 2.
2. No queue_update has arrived yet.
3. The Inspector shows that two queued items exist, but does not invent text.
4. A later queue_update replaces the count-only state with actual entries.
```

```text
Scenario: Queue drained
1. Inspector shows one Steering Queue Entry.
2. Pi RPC emits queue_update with steering = [] and followUp = [].
3. AppModel clears visible queue entries.
4. Inspector shows empty queued work state and pendingMessageCount becomes 0.
```

```text
Scenario: Long queued message
1. Pi RPC emits a 2,000-character follow-up string.
2. The queue model preserves the full text.
3. The visible summary is normalized and constrained so the Inspector layout remains stable.
```

## 10. Validation Criteria

- `CONTEXT.md` defines Queued Work, Steering Queue Entry, Follow-Up Queue Entry, and Queue Surface.
- `spec/spec-design-steering-follow-up-queue-ui.md` exists and follows the project spec naming convention.
- `PiRPCQueueUpdate` stores full visible queue entries, not only counts.
- `pendingMessageCount` remains accurate after queue updates and get-state fallback.
- Inspector UI distinguishes steering and follow-up entries.
- Empty, count-only, and active queue states have explicit UI behavior.
- Queue entries are not persisted in `SessionStore`.
- Queue entries are not appended directly to chat history.
- Unit tests cover queue parsing, reducer output, state application, and summary formatting.
- `swift test` passes after implementation.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [Pi RPC Mode documentation](https://pi.dev/docs/latest/rpc)
- [GitHub issue 3: Architecture: Typed RPC layer](https://github.com/MatheusBBarni/pi-agent-native/issues/3)
- [GitHub issue 21: Add steering and follow-up queue UI](https://github.com/MatheusBBarni/pi-agent-native/issues/21)
