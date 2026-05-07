# Pi Agent Native

Pi Agent Native is a native macOS shell for the `pi` coding agent. It launches
`pi` in RPC mode, runs it inside a selected workspace, and presents a
Codex-style SwiftUI interface for project sessions, model selection, tool
activity, process logs, and authentication.

## What it does

- Opens local project folders and runs `pi --mode rpc` with the project as the
  working directory.
- Streams assistant messages, thinking output, and tool execution status into a
  native chat surface.
- Persists the project list and known sessions between launches.
- Restores and switches previous `pi` sessions per project when session metadata
  is available from the RPC process.
- Shows repository branch state and dirty-worktree status for the selected
  project.
- Lets you choose models and thinking levels exposed by the running `pi`
  process.
- Supports API-key authentication and subscription login flows from the app.
- Builds either as a SwiftPM executable or a clickable `.app` bundle.

## Requirements

- macOS 14 or newer
- Swift 5.9 or newer
- A working `pi` coding-agent installation or a local `pi-mono` checkout
- Node.js and npm when running `pi` from source or from JavaScript build output

This package does not vendor or build `pi` automatically. Prepare `pi`
separately, then point the app at it by using the default folder convention,
environment variables, or the in-app custom executable field.

## Quick start

Run the SwiftPM executable during development:

```bash
swift run PiAgentNative
```

Build a clickable app bundle:

```bash
./Scripts/build-app.sh
open ".build/Pi Agent.app"
```

Build a release bundle:

```bash
./Scripts/build-app.sh release
open ".build/Pi Agent.app"
```

After launch, click **Open project**, choose a repository folder, authenticate
with a provider if needed, then send a prompt.

## Preparing `pi`

The app expects `pi` to be installed or built before launch. The default bundled
layout is:

```text
SomeFolder/
  Pi Agent.app
  pi-mono/
```

Prepare a local `pi-mono` checkout:

```bash
cd "/path/to/folder-containing-Pi Agent.app/pi-mono"
npm install
npm run build
```

To build the single-file `pi` binary used by the preferred local resolution
path:

```bash
cd "/path/to/folder-containing-Pi Agent.app/pi-mono/packages/coding-agent"
npm run build:binary
```

## How `pi` is resolved

At startup the app resolves the RPC command in this order:

1. The custom executable path saved in app settings, when present.
2. `PI_AGENT_EXECUTABLE`, when set.
3. `PI_MONO_PATH`, when set, otherwise a `pi-mono` folder next to the app or
   executable.
4. `<pi-mono>/packages/coding-agent/dist/pi`
5. `<pi-mono>/packages/coding-agent/dist/cli.js`
6. `<pi-mono>/node_modules/.bin/tsx` with
   `<pi-mono>/packages/coding-agent/src/cli.ts`
7. `pi` on `PATH`

JavaScript entry points are launched through `node`; source TypeScript entry
points are launched through `tsx`. Every resolved command is passed
`--mode rpc`.

Useful overrides:

```bash
PI_AGENT_EXECUTABLE=/absolute/path/to/pi swift run PiAgentNative
PI_MONO_PATH=/absolute/path/to/pi-mono swift run PiAgentNative
```

## Authentication

Open **Login** from the sidebar to configure credentials.

API-key login writes credentials to:

```text
~/.pi/agent/auth.json
```

Set `PI_CODING_AGENT_DIR` to use another auth directory:

```bash
PI_CODING_AGENT_DIR=/absolute/path/to/agent-auth swift run PiAgentNative
```

Subscription login runs the provider login command, displays its terminal
output, and opens detected login URLs in the browser. When the login exits
successfully, the app restarts the RPC process so the new credentials are
available.

## Sessions and local state

Pi Agent Native stores its own project and session sidebar state in:

```text
~/Library/Application Support/PiAgentNative/sessions.json
```

The actual agent session data still belongs to `pi`; the native app only records
the project path, session id, display title, status, and session file path
reported over RPC.

## Development

Common commands:

```bash
swift build
swift run PiAgentNative
./Scripts/build-app.sh
./Scripts/build-app.sh release
```

Project layout:

```text
Package.swift
Sources/PiAgentNative/
  AppModel.swift          # app state, RPC event handling, project/session logic
  PiRPCClient.swift       # process launch, command resolution, JSON-line RPC
  AuthStore.swift         # API-key storage and subscription login runner
  SessionStore.swift      # native sidebar/session persistence
  AppShellView.swift      # window shell and sidebar
  ChatSurfaceView.swift   # chat, composer, model/thinking controls
  InspectorView.swift     # branch and process status panel
Scripts/build-app.sh      # SwiftPM build plus .app bundle assembly
Assets/                   # app icon assets
```

The RPC client reads newline-delimited JSON from stdout and forwards stderr to
the process log. It also sets:

```text
NO_COLOR=1
FORCE_COLOR=0
PI_AGENT_NATIVE=1
```

The runtime `PATH` is prefixed with common Homebrew and system binary folders so
Node, npm, and `pi` can be found when the app is launched outside a shell.

## Troubleshooting

If the app says **Launch failed** or **No process**, open **Process log** from
the sidebar. It includes the resolved launch command, stderr output, non-JSON
RPC output, and process exit status.

If no models appear, open **Login**, add an API key or complete a subscription
login, then refresh the model picker.

If a local `pi-mono` checkout is not detected, set `PI_MONO_PATH` explicitly or
place `pi-mono` next to `Pi Agent.app`.

If `pi` works in a terminal but not from the app bundle, prefer
`PI_AGENT_EXECUTABLE` or use the in-app custom executable path so the app does
not depend on shell startup files.
