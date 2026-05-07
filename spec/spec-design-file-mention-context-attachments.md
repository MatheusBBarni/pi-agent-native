---
title: File Mention Context Attachments Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, composer, mentions, attachments, macos]
---

# Introduction

This specification defines the first structured context attachment slice for Pi Agent Native File Mentions. The goal is to keep the existing `@` Mention Picker and editable composer behavior while adding validated native attachment state that users can inspect before prompt submission.

## 1. Purpose & Scope

This specification applies to the macOS composer, File Mention selection, selected-project path validation, attachment preview UI, prompt decoration, and prompt RPC construction.

The intended audience is implementation agents and maintainers adding GitHub issue 25: "Add structured context attachments for File Mentions".

In scope:

- Creating native Context Attachment state when a Mention Picker result is selected.
- Showing resolved file and folder attachments separately from ordinary prompt text.
- Revalidating attachments before submission.
- Surfacing missing, moved, wrong-kind, and out-of-project attachment failures before prompt submission.
- Keeping the editable plain-text File Mention path in the composer.
- Decorating the outgoing prompt text with validated attachment references while the Pi RPC prompt command has no structured file-context payload.
- Clearing or invalidating attachment state when the Selected Project changes.
- Tests for resolution, invalidation, project switching, prompt decoration, and RPC payload construction.

Out of scope:

- Uploading file bytes to Pi RPC.
- Reading file contents in the native app and injecting those contents into the prompt.
- Introducing a new Pi RPC file attachment payload before Pi supports one.
- Replacing the composer text view with rich inline mention tokens.
- Live filesystem watching.
- Persisting Context Attachments between app launches or sessions.
- Supporting attachments outside the Selected Project.
- Supporting drag-and-drop attachment creation.

## 2. Definitions

**Selected Project**: The project currently active in Pi Agent Native.

**Composer**: The text input surface where the user writes a prompt.

**File Mention**: An editable plain-text reference to a file or folder inside the Selected Project.

**Mention Picker**: A composer suggestion surface that helps the user insert a File Mention.

**Mention Index Entry**: The indexed file or folder candidate selected from the Mention Picker.

**Context Attachment**: A validated native reference to a file or folder inside the Selected Project that is shown separately from ordinary composer text and intentionally included with the next prompt.

**Attachment Resolution**: The process of validating that a Context Attachment still exists, has the expected file or folder kind, and resolves inside the current Selected Project.

**Attachment Chip**: A compact composer control that represents one Context Attachment outside the editable prompt text.

**Attachment Status**: The current validation state of a Context Attachment.

**Workspace-Relative Path**: A POSIX path relative to the Selected Project root.

**Prompt Decoration**: Text added by Pi Agent Native to the outgoing RPC prompt to describe validated Context Attachments to the agent while preserving the user's visible prompt text.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Selecting a Mention Picker result shall create or update a Context Attachment for the selected file or folder.
- **REQ-002**: Selecting a Mention Picker result shall continue inserting an editable plain-text File Mention into the composer.
- **REQ-003**: The Context Attachment shall store the Selected Project identity and project root path at creation time.
- **REQ-004**: The Context Attachment shall store the workspace-relative path, expected item kind, display name, and resolved URL from the selected Mention Index Entry.
- **REQ-005**: A Context Attachment ID shall be stable for the same selected project and workspace-relative path within the pending prompt.
- **REQ-006**: Re-selecting the same project-relative file or folder shall not create duplicate Attachment Chips.
- **REQ-007**: Re-selecting an existing attachment shall refresh its resolution state and keep only one attachment for that project-relative path.
- **REQ-008**: The composer shall show Attachment Chips outside the editable prompt text.
- **REQ-009**: Attachment Chips shall appear above the prompt editor and below pending Skill Selection chips when both surfaces exist.
- **REQ-010**: Each Attachment Chip shall show whether the attachment is a file or folder.
- **REQ-011**: Each Attachment Chip shall show a readable label and enough workspace-relative path detail to distinguish duplicate names.
- **REQ-012**: Each Attachment Chip shall have a remove action.
- **REQ-013**: Removing an Attachment Chip shall remove only the Context Attachment state and shall not mutate composer text.
- **REQ-014**: The editable composer text shall remain plain text and use the current `@path/from/project ` insertion format.
- **REQ-015**: Normal text editing, undo, cursor movement, and selection behavior shall not depend on the Attachment Chip list.
- **REQ-016**: The app shall re-run Attachment Resolution before prompt submission.
- **REQ-017**: Attachment Resolution shall verify that the attachment's Selected Project still matches the current Selected Project.
- **REQ-018**: Attachment Resolution shall verify that the attachment path exists.
- **REQ-019**: Attachment Resolution shall verify that the attachment path has the expected file or folder kind.
- **REQ-020**: Attachment Resolution shall resolve symlinks and verify that the resolved path is inside the current Selected Project root.
- **REQ-021**: Project-root containment shall compare resolved path components, not raw string prefixes.
- **REQ-022**: Missing attachments shall be surfaced before prompt submission.
- **REQ-023**: Moved attachments shall be treated as missing unless their workspace-relative path still resolves to a valid item.
- **REQ-024**: Wrong-kind attachments shall be surfaced before prompt submission.
- **REQ-025**: Out-of-project attachments shall be surfaced before prompt submission.
- **REQ-026**: If any pending Context Attachment is invalid before submission, the app shall not send the prompt.
- **REQ-027**: Invalid attachment feedback shall be shown inline in the composer area or status area, not in a blocking modal.
- **REQ-028**: Attachment validation failure shall keep composer text and Context Attachment state available for user correction.
- **REQ-029**: Successful prompt submission shall clear Context Attachments along with the composer text and pending Skill Selection state.
- **REQ-030**: Creating a new chat shall clear Context Attachments.
- **REQ-031**: Switching Selected Project shall clear Context Attachments from the previous Selected Project.
- **REQ-032**: Refresh State shall refresh attachment resolution for the current Selected Project and shall not silently remove invalid attachments.
- **REQ-033**: The native user message shown in the conversation shall preserve the user's visible prompt text, not the decorated RPC prompt.
- **REQ-034**: The outgoing RPC prompt shall include validated Context Attachments in a Pi-compatible way.
- **REQ-035**: The first implementation shall use prompt text decoration for Context Attachments because the current Pi RPC prompt command supports `message` and optional `images`, but no file-context payload.
- **REQ-036**: Prompt decoration shall be deterministic.
- **REQ-037**: Prompt decoration shall preserve Skill Prompt Decoration behavior by composing with it in one explicit order.
- **REQ-038**: Context Attachment prompt decoration shall not remove or rewrite user-authored File Mention text from the visible prompt.
- **REQ-039**: Prompt decoration shall include workspace-relative paths and file/folder kind, not absolute paths, unless needed for Pi compatibility in a future RPC contract.
- **REQ-040**: The first implementation shall not read file contents into the prompt.
- **REQ-041**: The first implementation shall not send Context Attachments as image attachments.
- **REQ-042**: The existing plain-text File Mention path shall continue working when no Context Attachments exist.
- **REQ-043**: The existing plain-text File Mention path shall continue appearing in the RPC message when attachment state is unavailable or not created.
- **CON-001**: Do not introduce a new Pi RPC file payload unless upstream Pi RPC documents one.
- **CON-002**: Do not make Context Attachments global across projects.
- **CON-003**: Do not add live filesystem watchers in this issue.
- **CON-004**: Do not make Attachment Chips rich-text tokens inside the AppKit text view.
- **GUD-001**: Keep attachment resolution in a pure Swift component where practical.
- **GUD-002**: Reuse Mention Index Entry, Mention Inserter, and project-root containment behavior where possible.
- **GUD-003**: Prefer the same visual density as Selected Skill chips for Attachment Chips.
- **PAT-001**: Separate attachment state, attachment resolution, prompt decoration, and composer rendering so each can be unit-tested independently.

## 4. Interfaces & Data Contracts

### Current Pi RPC Constraint

The native app currently constructs prompt commands with a single required `message` field:

```json
{
  "id": "request-id",
  "type": "prompt",
  "message": "Review @Sources/App.swift "
}
```

Upstream Pi RPC accepts prompt `images`, but no structured file-context payload is documented. This issue must therefore use prompt decoration for file and folder Context Attachments.

### Conceptual Swift Models

The implementation should expose data structures equivalent to the following:

```swift
struct ContextAttachment: Identifiable, Equatable {
    let id: String
    let projectID: ProjectItem.ID
    let projectPath: String
    let relativePath: String
    let displayName: String
    let kind: ContextAttachmentKind
    let createdResolvedURL: URL
    var status: ContextAttachmentStatus
}

enum ContextAttachmentKind: Equatable {
    case file
    case folder
}

enum ContextAttachmentStatus: Equatable {
    case valid(resolvedURL: URL)
    case missing
    case wrongKind(actualKind: ContextAttachmentKind?)
    case outOfProject
    case projectChanged
    case resolutionFailed(message: String)
}

struct AttachmentResolutionInput: Equatable {
    let attachment: ContextAttachment
    let selectedProject: ProjectItem?
}

struct AttachmentResolutionResult: Equatable {
    let attachmentID: ContextAttachment.ID
    let status: ContextAttachmentStatus
}
```

### Component Responsibilities

| Component | Responsibility |
|---|---|
| Mention selection bridge | Creates or refreshes Context Attachment state when a Mention Picker result is inserted. |
| Attachment store in `AppModel` | Holds pending Context Attachments for the current composer prompt. |
| Attachment resolver | Validates project match, path existence, file/folder kind, symlink resolution, and project-root containment. |
| Attachment chip view | Renders resolved and invalid attachment state outside the prompt editor and provides remove actions. |
| Prompt decorator | Adds deterministic Context Attachment metadata to the outgoing prompt string. |
| Prompt submission coordinator | Revalidates attachments, blocks invalid submission, composes skill and attachment decorators, sends RPC command, and clears pending state after success. |

### Prompt Decoration Format

The first implementation should use a compact deterministic block before the user prompt and after any native Skill Prompt Decoration blocks:

```text
<context-attachments>
- file: Sources/PiAgentNative/AppModel.swift
- folder: Sources/PiAgentNative/RPC/
</context-attachments>

Review the app model and RPC layer.
```

Rules:

- File entries use `file: {workspace-relative-path}`.
- Folder entries use `folder: {workspace-relative-path}/`.
- Folder paths must have exactly one trailing slash in the decoration.
- Attachment entries preserve pending attachment order unless the UI later adds explicit reordering.
- The block is omitted when there are no valid Context Attachments.
- The decorated RPC prompt must remain a string passed to `PiRPCCommand.prompt`.
- The visible user message appended to the conversation must remain the trimmed user prompt without the context attachment block.

### Composition With Skills

If pending Skills and Context Attachments are both present, the outgoing prompt shall be:

```text
<skill ...>
...
</skill>

<context-attachments>
...
</context-attachments>

{user prompt}
```

The implementation may achieve this by applying the Context Attachment decorator before `SkillPromptDecorator.decoratedPrompt`, provided the final order matches the format above.

## 5. Acceptance Criteria

- **AC-001**: Given a Selected Project exists and a user selects a file from the Mention Picker, When insertion succeeds, Then the composer text contains the plain-text File Mention and the composer shows one file Attachment Chip.
- **AC-002**: Given a Selected Project exists and a user selects a folder from the Mention Picker, When insertion succeeds, Then the composer text contains the folder File Mention with trailing slash and the composer shows one folder Attachment Chip.
- **AC-003**: Given the same Mention Picker result is selected twice, When the second selection succeeds, Then only one Context Attachment exists for that selected-project relative path.
- **AC-004**: Given an Attachment Chip is removed, When the user removes it, Then the composer text is unchanged.
- **AC-005**: Given the user edits or deletes plain-text mention text after attachment creation, When the Attachment Chip still exists, Then the attachment remains pending until removed or invalidated.
- **AC-006**: Given an attached file is deleted before submission, When the user sends the prompt, Then the app does not send RPC and surfaces the attachment as missing.
- **AC-007**: Given an attached folder is replaced by a file before submission, When the user sends the prompt, Then the app does not send RPC and surfaces a wrong-kind attachment.
- **AC-008**: Given an attached symlink resolves outside the Selected Project before submission, When the user sends the prompt, Then the app does not send RPC and surfaces the attachment as out of project.
- **AC-009**: Given a Context Attachment belongs to project A, When the Selected Project changes to project B, Then the attachment state is cleared or marked projectChanged and cannot be submitted.
- **AC-010**: Given invalid Context Attachments exist, When the user attempts submission, Then composer text, pending Skills, and attachment state remain available for correction.
- **AC-011**: Given valid Context Attachments exist and the prompt is sent, Then `PiRPCCommand.prompt` receives a single string `message` containing the context attachment block and the user prompt.
- **AC-012**: Given valid Context Attachments and pending Skills exist, When the prompt is sent, Then the RPC `message` contains Skill Prompt Decoration blocks before the context attachment block.
- **AC-013**: Given no Context Attachments exist, When a prompt with plain-text File Mentions is sent, Then the RPC `message` remains compatible with the existing File Mention behavior.
- **AC-014**: Given a prompt with Context Attachments is sent, Then the conversation user message shows only the user's visible prompt text.
- **AC-015**: Given prompt submission succeeds, Then composer text, Context Attachments, Mention Picker state, and pending Skills are cleared.
- **AC-016**: Given Refresh State is invoked with pending Context Attachments, Then attachments for the current Selected Project are revalidated and invalid attachments remain visible.

## 6. Test Automation Strategy

- **Test Levels**: Unit tests for models, attachment resolution, deduplication, project switching invalidation, prompt decoration, and RPC payload construction; view-level smoke tests if the project has or adds a UI automation layer.
- **Frameworks**: Swift XCTest in the existing test targets.
- **Test Data Management**: Use temporary Selected Project directories with files, folders, deleted paths, kind changes, symlinks, and sibling project paths such as `/tmp/project-other`.
- **Coverage Requirements**: Tests must cover valid files, valid folders, duplicate selection, remove without text mutation, deleted path, wrong kind, symlink escape, project switch, empty attachment decoration, skill-plus-attachment decoration order, and plain-text mention compatibility.
- **Performance Testing**: No large-tree performance testing is required because attachment resolution checks only pending attachments. Add a lightweight test with multiple pending attachments to confirm synchronous resolution is bounded by attachment count.

Suggested focused test files:

- `Tests/PiAgentNativeCoreTests/ContextAttachmentResolverTests.swift`
- `Tests/PiAgentNativeCoreTests/ContextAttachmentPromptDecoratorTests.swift`
- `Tests/PiAgentNativeTests/ContextAttachmentSubmissionTests.swift`

## 7. Rationale & Context

Issue 1 deliberately kept File Mentions as editable plain text because the native app sends prompts through Pi RPC as a string `message`. Issue 25 evolves that behavior by adding native state around selected mentions so users can see exactly which files and folders are intended as context and can catch stale paths before submission.

The term "structured context attachment" does not mean file upload in this slice. Upstream Pi RPC currently documents images on prompt commands, but not structured file references. Sending file references through a deterministic text block keeps the behavior Pi-compatible and leaves room to switch the transport later behind the prompt decoration boundary.

Attachment Chips are separate from the AppKit text view because inline rich tokens would risk standard macOS editing behavior and undo semantics. Keeping the text view plain preserves the predictable composer behavior established by the Mention Picker.

No ADR is required for this issue because the transport decision is explicitly constrained by current Pi RPC capabilities and remains reversible when Pi adds structured file-context support.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Local filesystem - Required to validate attachment existence, kind, symlink resolution, and selected-project containment.
- **EXT-002**: Pi RPC process - Receives a prompt string containing deterministic Context Attachment decoration.

### Data Dependencies

- **DAT-001**: Selected Project - Provides attachment scope and project-root path for resolution.
- **DAT-002**: Mention Index Entry - Provides initial relative path, display name, kind, and resolved URL when the attachment is created.
- **DAT-003**: Composer text - Remains editable user prompt text and is not the source of truth for pending Context Attachments after creation.

### Technology Platform Dependencies

- **PLT-001**: macOS AppKit text view - Composer text editing remains plain text.
- **PLT-002**: SwiftUI - Attachment Chips are rendered in the composer surface.

## 9. Examples & Edge Cases

### File Attachment

Visible composer text:

```text
Review @Sources/PiAgentNative/AppModel.swift 
```

Pending attachment:

```text
file Sources/PiAgentNative/AppModel.swift valid
```

Outgoing RPC message:

```text
<context-attachments>
- file: Sources/PiAgentNative/AppModel.swift
</context-attachments>

Review @Sources/PiAgentNative/AppModel.swift
```

### Folder Attachment

Visible composer text:

```text
Review @Sources/PiAgentNative/RPC/ 
```

Outgoing RPC message:

```text
<context-attachments>
- folder: Sources/PiAgentNative/RPC/
</context-attachments>

Review @Sources/PiAgentNative/RPC/
```

### Attachment Removed But Text Kept

If a user removes the Attachment Chip but leaves `@Sources/App.swift` in the composer, the outgoing prompt contains the plain text mention only. This preserves the issue 1 path.

### Text Deleted But Attachment Kept

If a user deletes `@Sources/App.swift` from the composer but leaves the Attachment Chip, the outgoing prompt includes the context attachment block. The chip is the native state source of truth after selection.

### Project Switch

If project A has `Sources/App.swift` attached and the user switches to project B, the attachment must not silently retarget to project B's `Sources/App.swift`.

## 10. Validation Criteria

- `swift test` passes.
- `git diff --check` reports no whitespace errors.
- Context Attachment resolution rejects sibling-prefix escapes such as `/tmp/project-other` for root `/tmp/project`.
- Context Attachment prompt decoration is deterministic and covered by unit tests.
- Existing Mention Picker tests continue to pass without changing plain-text insertion rules.
- Existing Skill Prompt Decoration tests continue to pass.
- Issue 25 acceptance criteria are all represented by tests or explicit manual verification notes.

## 11. Related Specifications / Further Reading

- [File Mention Picker Design](./spec-design-file-mention-picker.md)
- [Skill Selection Picker Design](./spec-design-skill-selection-picker.md)
- [Pi SDK prompt options](/Users/matheusbbarni/other-tools/pi-mono/packages/coding-agent/docs/sdk.md)
- [Pi RPC command types](/Users/matheusbbarni/other-tools/pi-mono/packages/coding-agent/src/modes/rpc/rpc-types.ts)
