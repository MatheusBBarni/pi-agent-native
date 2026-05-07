---
title: Skill Selection Command and Picker Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, composer, skills, macos]
---

# Introduction

This specification defines first-version support for selecting Pi coding agent skills from the Pi Agent Native composer. The goal is to let users type or pick `/skill:<skill-id>` tokens, validate them against the running Pi coding agent, and apply the selected skills as one-shot context to the next normal prompt.

## 1. Purpose & Scope

This specification applies to the Pi Agent Native macOS composer, skill availability data loaded from the running Pi coding agent, the `/skill:` composer slash command, the skill picker, selected-skill chips, and the prompt text sent through the existing RPC prompt command.

The intended audience is implementation agents and maintainers adding GitHub issue 16: "Add /skill:<skill-id> command support".

In scope:

- Detecting active `/skill:` queries in the composer.
- Showing a compact Skill Picker only for active `/skill:` queries.
- Completing `/skill:<skill-id>` tokens from picker selection.
- Supporting repeated `/skill:<skill-id>` tokens separated by whitespace.
- Validating every requested skill against the available skills reported by the running Pi coding agent.
- Showing pending selected skills as removable chips.
- Appending unique skills to the pending selection across repeated valid slash-command submissions.
- Applying pending skills to the next normal prompt by prepending a native-generated natural-language skill instruction to the RPC prompt message.
- Clearing pending selected skills after the next normal prompt is submitted.

Out of scope:

- Immediately executing a skill when `/skill:<skill-id>` is submitted.
- General slash-command picker behavior for `/` or non-`/skill:` text.
- Native filesystem scanning of `.agents/skills` folders.
- Structured RPC skill-selection fields.
- Persistent selected skills across prompts, sessions, projects, or app launches.
- Comma-separated skill lists.
- Mixing `/skill:` tokens and natural-language prompt text in one composer submission.
- Skill autocomplete when the running Pi coding agent cannot provide available skills.

## 2. Definitions

**Pi Coding Agent**: The running `pi` process launched by Pi Agent Native in RPC mode.

**Composer**: The text input surface where the user writes a prompt.

**Skill**: A named agent capability available to the running Pi coding agent.

**Composer Slash Command**: A composer input beginning with `/` that Pi Agent Native interprets before sending normal prompt text.

**Skill Selection**: A Composer Slash Command that selects one or more Skills as context for the next normal prompt.

**Skill Query**: The active text range beginning with `/skill:` that drives Skill Picker search.

**Skill Picker**: A composer suggestion surface that helps the user find and select Skills for a Skill Selection.

**Selected Skill Chip**: A visible composer control that shows one selected Skill before it is consumed by the next normal prompt.

**Skill Instruction**: Native-generated prompt text that tells the Pi Coding Agent which Skills to use for the current request.

**Normal Prompt**: Composer text that is not handled as a Composer Slash Command.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall recognize `/skill:<skill-id>` as a Composer Slash Command form.
- **REQ-002**: The app shall support multiple skills in one Skill Selection by accepting repeated `/skill:<skill-id>` tokens separated by whitespace.
- **REQ-003**: The app shall reject comma-separated skill lists such as `/skill:diagnose,zoom-out`.
- **REQ-004**: The app shall reject mixed Skill Selection and Normal Prompt text such as `/skill:diagnose fix this crash`.
- **REQ-005**: The app shall treat a submitted Skill Selection as selection for the next Normal Prompt, not as immediate skill execution.
- **REQ-006**: The app shall validate every requested skill id against the available skills reported by the running Pi Coding Agent before changing pending selected skills.
- **REQ-007**: If one or more requested skill ids are unknown, unavailable, duplicated inside the submitted command line, or malformed, the app shall not partially apply the submitted Skill Selection.
- **REQ-008**: If available skills cannot be loaded from the running Pi Coding Agent, Skill Selection shall be unavailable.
- **REQ-009**: The app shall not scan native filesystem skill directories to validate skill ids.
- **REQ-010**: A valid submitted Skill Selection shall append unique new Skills to the pending selected skills.
- **REQ-011**: Submitting a skill that is already pending shall not create a duplicate Selected Skill Chip.
- **REQ-012**: The app shall clear composer text after successfully handling a valid submitted Skill Selection.
- **REQ-013**: The app shall show one Selected Skill Chip for each pending selected Skill.
- **REQ-014**: Each Selected Skill Chip shall expose a remove control for that Skill.
- **REQ-015**: When more than one Skill is pending, the app shall expose a clear-all control.
- **REQ-016**: Pending selected Skills shall be cleared after the next Normal Prompt is submitted.
- **REQ-017**: The app shall open the Skill Picker only when the cursor is inside an active `/skill:` query.
- **REQ-018**: The app shall not open a picker for `/`, `/help`, `/model`, or other non-`/skill:` slash-prefixed text.
- **REQ-019**: The app shall keep the Skill Query active only while the cursor remains in the query range and the query token contains no whitespace.
- **REQ-020**: Skill Picker results shall match by skill id and display name when display name is available.
- **REQ-021**: Skill Picker results shall be capped at 12 visible results.
- **REQ-022**: Skill Picker ranking shall prioritize exact id prefix, id substring, display-name prefix, and display-name substring, in that order.
- **REQ-023**: The Skill Picker shall appear as a compact overlay directly above the composer input area.
- **REQ-024**: The Skill Picker shall align to the composer leading edge and match the composer content area's width.
- **REQ-025**: Each Skill Picker row shall show the skill id and, when available, a short description or display name.
- **REQ-026**: The highlighted Skill Picker row shall use the app's accent or selection treatment.
- **REQ-027**: The Skill Picker shall show one disabled row for empty, no-match, loading, or unavailable states.
- **REQ-028**: While the Skill Picker is open, Up and Down shall move the highlighted result.
- **REQ-029**: While the Skill Picker is open, Return and Tab shall complete the active `/skill:` token with the highlighted result.
- **REQ-030**: While the Skill Picker is open, Escape shall close the picker without changing composer text.
- **REQ-031**: Pointer hover shall update the highlighted row.
- **REQ-032**: Pointer click shall complete the active `/skill:` token with the clicked result.
- **REQ-033**: Completing a Skill Picker result shall replace only the active Skill Query range.
- **REQ-034**: Completing a Skill Picker result shall insert `/skill:<skill-id>` plus one trailing space.
- **REQ-035**: Choosing a Skill Picker row shall not create a Selected Skill Chip until the slash-command line is submitted.
- **REQ-036**: When a Normal Prompt is submitted with pending selected Skills, the app shall send the Pi Coding Agent a single prompt message containing a Skill Instruction followed by the user's prompt text.
- **REQ-037**: The Skill Instruction shall use natural language that the Pi Coding Agent understands, such as `Use these skills for this request: diagnose, zoom-out.`.
- **REQ-038**: The user-visible conversation message shall show the user's original Normal Prompt, not the generated Skill Instruction prefix.
- **REQ-039**: The existing RPC prompt command shall continue sending a single string `message` value.
- **CON-001**: The implementation must not introduce a structured skill payload in the RPC prompt command for this issue.
- **CON-002**: The implementation must not persist pending selected Skills.
- **CON-003**: The implementation must not silently accept unvalidated skill ids.
- **CON-004**: Standard macOS text editing shortcuts must remain owned by the text view.
- **CON-005**: Skill Picker navigation is local composer interaction and is not part of the Default Keymap.
- **GUD-001**: Prefer sharing picker interaction primitives with the Mention Picker while keeping Skill Query parsing and Skill result ranking separate.
- **GUD-002**: Keep skill availability refresh tied to Pi RPC state or command discovery rather than local filesystem state.
- **PAT-001**: Keep slash-command parsing, skill validation, pending selection state, picker search, and prompt decoration as separate testable units.

## 4. Interfaces & Data Contracts

The existing prompt RPC contract remains a single string message:

```json
{
  "id": "request-id",
  "type": "prompt",
  "message": "Use these skills for this request: diagnose, zoom-out.\n\nInvestigate why the app crashes after login."
}
```

The user-visible conversation message should preserve the original user prompt:

```text
Investigate why the app crashes after login.
```

The implementation should expose conceptual data structures equivalent to the following:

```swift
struct AvailableSkill: Identifiable, Equatable {
    let id: String
    let displayName: String?
    let description: String?
}

struct SkillQuery: Equatable {
    let range: Range<String.Index>
    let rawText: String
    let searchText: String
}

struct SkillSearchResult: Identifiable, Equatable {
    let skill: AvailableSkill
    let score: Int
}

struct SkillPickerState: Equatable {
    let query: SkillQuery
    let results: [SkillSearchResult]
    let highlightedResultID: SkillSearchResult.ID?
    let status: SkillPickerStatus
}

enum SkillPickerStatus: Equatable {
    case ready
    case loading
    case noMatches
    case unavailable
}

struct PendingSkillSelection: Equatable {
    let skills: [AvailableSkill]
}

enum SkillSelectionParseResult: Equatable {
    case selection(skillIDs: [String])
    case normalPrompt(String)
    case invalid(reason: String)
}
```

Required components:

| Component | Responsibility |
|---|---|
| Available skill provider | Load and refresh available skills from the running Pi Coding Agent. |
| Skill query detector | Find the active `/skill:` query based on composer text and cursor position. |
| Skill searcher | Filter, rank, and cap results for the current query. |
| Skill picker view | Render rows, highlight state, empty states, pointer hover, and click completion. |
| Composer event bridge | Route Up, Down, Return, Tab, and Escape to the Skill Picker only while it is open. |
| Slash-command parser | Distinguish Skill Selection from Normal Prompt text and invalid slash-command text. |
| Skill validator | Resolve every requested skill id against available skills and enforce all-or-nothing application. |
| Pending skill store | Maintain one-shot pending Skills, append unique Skills, remove one Skill, clear all Skills, and clear after prompt submission. |
| Prompt decorator | Prefix the RPC prompt message with a Skill Instruction while keeping user-visible text unchanged. |

Skill selection syntax:

| Input | Result |
|---|---|
| `/skill:diagnose` | Select `diagnose` for the next Normal Prompt. |
| `/skill:diagnose /skill:zoom-out` | Select `diagnose` and `zoom-out` for the next Normal Prompt. |
| `/skill:diagnose,zoom-out` | Invalid. |
| `/skill:diagnose fix this crash` | Invalid mixed command and prompt text. |
| `/help` | Not handled by this feature. No Skill Picker opens. |

Skill Picker completion format:

| Selected result | Inserted text |
|---|---|
| `diagnose` | `/skill:diagnose ` |
| `grill-with-docs` | `/skill:grill-with-docs ` |

Skill Instruction format:

```text
Use this skill for this request: diagnose.

<user prompt>
```

```text
Use these skills for this request: diagnose, zoom-out.

<user prompt>
```

## 5. Acceptance Criteria

- **AC-001**: Given available skills are loaded and the composer is focused, When the user types `/skill:`, Then the Skill Picker opens above the composer.
- **AC-002**: Given composer text is `/skill:dia` and the cursor is after `dia`, When `diagnose` is available, Then the Skill Picker shows `diagnose`.
- **AC-003**: Given composer text is `/help`, When the cursor is after `/help`, Then the Skill Picker does not open.
- **AC-004**: Given available skills cannot be loaded, When the user types `/skill:`, Then the Skill Picker shows an unavailable state.
- **AC-005**: Given the Skill Picker is open, When the user presses Down, Then the highlighted result moves to the next result.
- **AC-006**: Given the Skill Picker is open, When the user presses Up, Then the highlighted result moves to the previous result.
- **AC-007**: Given `diagnose` is highlighted, When the user presses Return or Tab, Then the active Skill Query is replaced with `/skill:diagnose `.
- **AC-008**: Given the Skill Picker is open, When the user presses Escape, Then the picker closes and composer text remains unchanged.
- **AC-009**: Given the pointer hovers a Skill Picker row, When the row is hover-active, Then that row becomes highlighted.
- **AC-010**: Given the user clicks a Skill Picker row, Then the active Skill Query is completed with the clicked skill id and no Selected Skill Chip is created yet.
- **AC-011**: Given `/skill:diagnose` is submitted and `diagnose` is available, Then a `diagnose` Selected Skill Chip appears and the composer text clears.
- **AC-012**: Given `/skill:diagnose /skill:zoom-out` is submitted and both skills are available, Then both Selected Skill Chips appear and the composer text clears.
- **AC-013**: Given `/skill:unknown` is submitted, Then no Selected Skill Chip is added and a clear user-facing error is shown.
- **AC-014**: Given `/skill:diagnose /skill:unknown` is submitted, Then no partial Skill Selection is applied and a clear user-facing error is shown.
- **AC-015**: Given `diagnose` is already pending, When `/skill:diagnose /skill:zoom-out` is submitted, Then only `zoom-out` is added and `diagnose` is not duplicated.
- **AC-016**: Given a Selected Skill Chip is visible, When its remove control is activated, Then that skill is removed from the pending selection.
- **AC-017**: Given more than one Selected Skill Chip is visible, When clear-all is activated, Then all pending selected Skills are removed.
- **AC-018**: Given pending selected Skills exist and the user submits a Normal Prompt, Then the RPC prompt message starts with the correct Skill Instruction.
- **AC-019**: Given pending selected Skills exist and the user submits a Normal Prompt, Then the user-visible conversation shows the original Normal Prompt without the generated Skill Instruction.
- **AC-020**: Given pending selected Skills exist and the user submits a Normal Prompt, Then pending selected Skills are cleared after submission.
- **AC-021**: Given no pending selected Skills exist and the user submits a Normal Prompt, Then the existing prompt RPC message remains unchanged.
- **AC-022**: Given standard text editing shortcuts are used in the composer, When the Skill Picker is closed, Then the text view handles those shortcuts normally.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for slash-command parsing, query detection, ranking, validation, pending selection state, prompt decoration, and duplicate handling; UI smoke tests for picker opening, navigation, completion, chip removal, and prompt submission.
- **Frameworks**: Swift XCTest for pure logic and AppKit-compatible composer tests where possible. Manual macOS UI verification is acceptable until a UI automation target exists.
- **Test Data Management**: Use injected available-skill lists with ids, display names, and descriptions. Include known, unknown, duplicate, malformed, and multi-skill command inputs.
- **CI/CD Integration**: Run `swift build` and any added XCTest target in the repository build workflow.
- **Coverage Requirements**: Unit tests should cover every accepted syntax form, every rejected syntax form, unavailable skill data, all-or-nothing validation, duplicate suppression, one-shot clearing, and prompt decoration.
- **Performance Testing**: No dedicated performance tests are required. Skill search must operate over the available-skill list without blocking text entry on the main actor.

## 7. Rationale & Context

The issue originally used "invoke a skill", which could mean immediate execution or selecting context for a later prompt. The resolved behavior is Skill Selection: `/skill:<skill-id>` selects one or more skills for the next Normal Prompt and does not execute the skill by itself.

The Pi Coding Agent already understands natural-language skill instructions such as "use skill diagnose for this request". Therefore the first version keeps the existing single-string prompt RPC contract and prepends a native-generated Skill Instruction to the RPC message when pending skills are present.

The user-visible conversation omits the generated Skill Instruction so the transcript reflects what the user typed while the agent still receives the required skill context. Selected Skill Chips make that hidden prompt decoration visible and removable before submission.

The Skill Picker follows the local interaction model established by the Mention Picker from issue 1, but it opens only for `/skill:` queries. It is not a general slash-command picker.

No ADR is required for this version because the decisions are reversible product and interaction-scope decisions. A future structured RPC skill-selection field can replace prompt decoration without changing the user-facing Skill Selection model.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Pi Coding Agent RPC process - Required to provide or validate available Skills and receive prompt messages.

### Third-Party Services

- **SVC-001**: None.

### Infrastructure Dependencies

- **INF-001**: None.

### Data Dependencies

- **DAT-001**: Available Skills - Required to populate the Skill Picker and validate Skill Selection.
- **DAT-002**: Composer text and selection range - Required to detect and replace the active Skill Query.
- **DAT-003**: Pending selected Skills - Required to render Selected Skill Chips and decorate the next Normal Prompt.

### Technology Platform Dependencies

- **PLT-001**: macOS 14 or newer - Required platform for Pi Agent Native.
- **PLT-002**: SwiftUI and AppKit interop - Required because the shell is SwiftUI and the composer uses an AppKit text view.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Activation examples:
/skill:             -> active Skill Query with empty search text
/skill:dia          -> active Skill Query "dia"
Use /skill:dia      -> invalid mixed text; picker may open while cursor is in token, but submission must reject
/help               -> no Skill Picker
/                   -> no Skill Picker
```

```text
Multi-skill command:
Input:  /skill:diagnose /skill:zoom-out
Result: Pending Selected Skill Chips: diagnose, zoom-out
Sent:   No RPC prompt is sent yet
```

```text
Picker completion:
Input:  /skill:dia
Pick:   diagnose
Output: /skill:diagnose 
State:  No Selected Skill Chip until the command line is submitted
```

```text
Prompt decoration:
Pending Skills: diagnose, zoom-out
User prompt:    Investigate the login crash.
RPC message:    Use these skills for this request: diagnose, zoom-out.

                Investigate the login crash.
Conversation:   Investigate the login crash.
```

```text
Unavailable state:
If available Skills cannot be loaded from the running Pi Coding Agent, the Skill Picker may show:
Skills unavailable

Submitting /skill:diagnose must fail because the id cannot be validated.
```

```text
All-or-nothing validation:
Input:  /skill:diagnose /skill:unknown
Result: No pending skills change
Error:  Unknown skill: unknown
```

## 10. Validation Criteria

- Skill Picker opens only for active `/skill:` queries.
- Skill Picker does not open for unrelated slash-prefixed text.
- Picker completion edits composer text and does not change pending selected skills.
- Submitted Skill Selection validates every requested skill against available Skills.
- Invalid Skill Selection does not partially apply.
- Valid repeated `/skill:<skill-id>` tokens append unique pending skills.
- Selected Skill Chips support remove-one and clear-all behavior.
- Pending selected Skills are one-shot and clear after the next Normal Prompt is submitted.
- RPC prompt messages include a natural-language Skill Instruction only when pending selected Skills exist.
- User-visible conversation messages do not include the generated Skill Instruction.
- Existing composer send, newline, thinking-level cycling, copy, paste, undo, redo, deletion, and cursor movement behavior remain intact.

## 11. Related Specifications / Further Reading

- [Pi Agent Native domain context](../CONTEXT.md)
- [File Mention Picker Design](./spec-design-file-mention-picker.md)
- [Default Keymap and Keyboard Shortcut Design](./spec-design-default-keymap.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 16: Add /skill:<skill-id> command support](https://github.com/MatheusBBarni/pi-agent-native/issues/16)
