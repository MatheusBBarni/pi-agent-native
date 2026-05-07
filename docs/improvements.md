# Native Pi Shell Architecture Improvements

This document records the recommended architecture direction for Pi Agent Native after inspecting the current repository.

## Current shape

The app is a small SwiftPM macOS 14 SwiftUI application that currently builds successfully with `swift build`.

Current layout:

```text
Sources/PiAgentNative/
  AppModel.swift          # mostly everything: state, RPC events, sessions, git, actions
  PiRPCClient.swift       # process launch + JSONL stdin/stdout transport
  AuthStore.swift         # API key + OAuth helper process
  SessionStore.swift      # native sidebar persistence
  AppShellView.swift      # shell/sidebar/modal composition
  ChatSurfaceView.swift   # chat/composer/model controls
  InspectorView.swift     # process/git/model status
  Theme.swift             # palettes/theme helpers
```

The main architectural issue is that `AppModel.swift` acts as the app coordinator, domain store, RPC reducer, session manager, git service, and UI state container at once. This is acceptable for a prototype, but it will become the bottleneck for a full native pi shell.

## Recommended architecture

Use a layered native host around pi RPC:

```text
PiAgentNativeApp
└── AppShell / SwiftUI Views
    └── AppStore / AppCoordinator
        ├── WorkspaceStore
        ├── ConversationStore
        ├── SessionStore
        ├── ToolActivityStore
        ├── AuthStore
        ├── SettingsStore
        └── Services
            ├── PiRPCService
            │   ├── PiProcessSupervisor
            │   ├── PiLaunchResolver
            │   ├── JSONLTransport
            │   └── Typed RPC commands/events
            ├── GitService
            ├── OAuthLoginService
            └── File/AttachmentService
```

The high-level recommendation is:

> SwiftUI shell + typed app stores + process-supervised pi RPC transport + reducer-driven event handling.

Keep this app as a native SwiftUI host over `pi --mode rpc`, not an embedded JS/Node app.

## Proposed source tree

```text
Sources/
  PiAgentNativeExecutable/
    PiAgentNativeApp.swift

  PiAgentNative/
    App/
      AppStore.swift
      AppCoordinator.swift
      AppState.swift

    RPC/
      PiRPCClient.swift
      PiRPCTransport.swift
      PiProcessSupervisor.swift
      PiLaunchResolver.swift
      PiRPCCommand.swift
      PiRPCEvent.swift
      PiRPCModels.swift
      PiRPCEventReducer.swift

    Workspace/
      WorkspaceStore.swift
      GitService.swift
      ProjectItem.swift

    Sessions/
      NativeSessionIndexStore.swift
      StoredSession.swift

    Conversation/
      ConversationStore.swift
      ChatMessage.swift
      MessageContentBlock.swift

    Tools/
      ToolActivityStore.swift
      ToolActivityView.swift

    ExtensionUI/
      ExtensionUIRouter.swift
      ExtensionUIDialogs.swift

    Auth/
      NativeAuthStore.swift
      OAuthLoginService.swift
      LoginProvider.swift

    Settings/
      SettingsStore.swift
      SettingsSheetView.swift

    UI/
      AppShellView.swift
      SidebarView.swift
      ChatSurfaceView.swift
      ComposerView.swift
      InspectorView.swift
      Theme.swift
      Components/
```

## 1. Typed RPC layer

Replace `[String: Any]` dictionaries with typed commands and events.

Suggested files:

```text
Sources/PiAgentNative/RPC/
  PiRPCClient.swift
  PiRPCTransport.swift
  PiLaunchResolver.swift
  PiRPCCommand.swift
  PiRPCEvent.swift
  PiRPCModels.swift
  PiRPCEventReducer.swift
```

Benefits:

- Safer decoding of `message_update`, `tool_execution_*`, `queue_update`, and `extension_ui_request`.
- Easier support for more protocol features: `steer`, `follow_up`, `compact`, `bash`, `get_commands`, extension UI.
- Better logs and debugging.

Keep the existing strict LF JSONL framing. It matches pi RPC documentation and is correct.

## 2. Process supervisor

Separate process lifecycle from protocol parsing.

A `PiProcessSupervisor` should own:

- `Process`
- stdin/stdout/stderr pipes
- termination handling
- generation IDs
- launch diagnostics
- running state

Suggested API:

```swift
final class PiProcessSupervisor {
    func start(workspace: URL, command: PiLaunchCommand) throws
    func stop()
    func restart(workspace: URL, command: PiLaunchCommand) throws
}
```

Then `PiRPCClient` can focus on:

```swift
send(command)
events async stream
responses async stream
```

## 3. App coordinator and stores

Shrink `AppModel` into a coordinator that composes smaller stores.

Suggested files:

```text
Sources/PiAgentNative/App/
  AppStore.swift
  AppCoordinator.swift
  AppState.swift
  AppAction.swift
```

Responsibility split:

| Current responsibility | Recommended home |
|---|---|
| selected project | `WorkspaceStore` |
| session sidebar | `NativeSessionIndexStore` |
| messages | `ConversationStore` |
| tool list | `ToolActivityStore` |
| model/thinking state | `AgentStateStore` |
| process log | `ProcessLogStore` |
| git status | `GitService` |
| RPC event handling | `PiRPCEventReducer` |

## 4. Conversation domain

Create a domain model that can faithfully represent pi messages.

Suggested files:

```text
Sources/PiAgentNative/Conversation/
  Conversation.swift
  ChatMessage.swift
  MessageContentBlock.swift
  ToolCallPresentation.swift
  ThinkingBlock.swift
```

Current `ChatMessage` collapses too much into `text` and `thinking`. pi streams structured content. Preserve content blocks:

```swift
enum MessageContentBlock {
    case text(String)
    case thinking(String)
    case toolCall(ToolCall)
    case toolResult(ToolResult)
    case image(ImageAttachment)
}
```

This enables a richer Codex-style UI:

- inline tool calls
- expandable thinking
- bash output panes
- image attachments
- better streaming updates

## 5. Tool activity as first-class UI

`ToolActivity` already exists, but tool activity should become more visible and structured.

Recommended UX:

- Inline tool calls in the conversation.
- Right inspector for active and completed tools.
- Expandable stdout/stderr/result.
- Status states: queued, running, succeeded, failed, cancelled.
- Correlation by `toolCallId`.

Suggested files:

```text
Sources/PiAgentNative/Tools/
  ToolActivityStore.swift
  ToolActivityView.swift
  ToolOutputView.swift
```

## 6. Extension UI protocol

pi RPC supports `extension_ui_request` / `extension_ui_response`. A native pi shell should support this directly instead of only logging extension UI requests.

Suggested files:

```text
Sources/PiAgentNative/ExtensionUI/
  ExtensionUIRequest.swift
  ExtensionUIRouter.swift
  ExtensionUIDialogs.swift
```

Support at least:

- `select`
- `confirm`
- `input`
- `editor`
- `notify`
- `setStatus`
- `setWidget`
- `setTitle`
- `set_editor_text`

This is key for native compatibility with pi extensions and skills.

## 7. Workspace and session architecture

Current project/session persistence is a good start, but should become explicit stores.

```text
WorkspaceStore
  projects
  selectedProject
  recentWorkspaces
  add/remove/reorder

NativeSessionIndexStore
  local index of pi sessions reported by RPC
  selected session per workspace
```

Important principle:

> Native `sessions.json` should be an index/cache, not the authority.

pi session files remain authoritative. The native app should record only the project path, session id, display title, status, and session file path reported over RPC.

## 8. Settings and authentication

Keep `NativeAuthStore`, but separate auth and settings responsibilities.

Suggested files:

```text
Sources/PiAgentNative/Auth/
  NativeAuthStore.swift
  OAuthLoginService.swift
  LoginProviderCatalog.swift

Sources/PiAgentNative/Settings/
  SettingsStore.swift
  SettingsView.swift
```

Suggested additions:

- executable picker validation
- `PI_MONO_PATH` display
- resolved command preview
- auth status per provider
- session directory setting
- environment overrides view

## Highest-value next steps

1. Introduce typed RPC commands/events while keeping the current UI unchanged.
2. Extract `PiProcessSupervisor` and `JSONLTransport` from `PiRPCClient.swift`.
3. Move RPC event handling out of `AppModel` into a reducer.
4. Model conversation content as structured blocks, not flat strings.
5. Implement extension UI request/response.
6. Expose tool activity inline and in the inspector.
7. Add tests for RPC parsing and reducing.

Suggested test coverage:

- fragmented stdout records
- CRLF input tolerance
- non-JSON process output
- streaming text deltas
- streaming thinking deltas
- tool start/update/end correlation
- extension UI request/response handling
- process restart generation isolation

## Summary

The repository is pointed in the right direction. The main need is decomposition and typed protocol boundaries before adding more native shell features.

The recommended end state is a native SwiftUI app that treats pi RPC as a typed, supervised service and renders pi's structured agent/session/tool/extension events with native macOS UI.
