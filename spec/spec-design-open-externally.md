---
title: Open Externally Target Menu Design
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Pi Agent Native
tags: [design, app, macos, external-targets]
---

# Introduction

This specification defines the first-version Open Externally feature for Pi Agent Native. The goal is to let users launch the Selected Project in supported external macOS destinations from a header menu while keeping internal project selection separate from external launching.

## 1. Purpose & Scope

This specification applies to the Pi Agent Native macOS app shell, selected project state, chat header, external app discovery, and external launch error reporting.

The intended audience is implementation agents and maintainers adding the Open Externally menu. The implementation must preserve the existing meaning of Open Project as the internal project chooser and use Open Externally for launching the current project in another app or destination.

In scope:

- Header External Target Menu placed at the trailing end of the chat header, close to the inspector.
- Launch-time External Target Scan over a known External Target Catalog.
- Baseline Finder and Terminal targets.
- Installed app targets shown only when available.
- Launching the Selected Project path, including paths with spaces.
- Non-blocking launch error reporting through status text and the process log.

Out of scope:

- GitHub target support.
- Discovering every installed app that can open folders.
- File-system watching for newly installed or removed apps.
- Refreshing the External Target Scan while the app is open.
- User customization of the External Target Catalog.
- Persisting scan results.
- Blocking error modals for launch failures.

## 2. Definitions

**Selected Project**: The project currently active in Pi Agent Native.

**Open Project**: An App Action that chooses or switches the Selected Project inside Pi Agent Native.

**Open Externally**: An App Action that launches the Selected Project in another app or destination.

**External Target**: A supported destination for Open Externally, such as Finder, Terminal, or an editor.

**External Target Menu**: The header dropdown that lists available External Targets for Open Externally.

**External Target Scan**: A launch-time check that discovers which known External Targets are available on the user computer.

**External Target Catalog**: The known set of External Targets Pi Agent Native knows how to detect and launch.

**External Launch Failure**: A failed attempt to complete Open Externally for a Selected Project and External Target.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The app shall provide an External Target Menu in the chat header, trailing near the inspector.
- **REQ-002**: The External Target Menu shall act on the Selected Project only.
- **REQ-003**: The External Target Menu shall not change the Selected Project, selected session, messages, composer text, or agent process state.
- **REQ-004**: The app shall run an External Target Scan each time Pi Agent Native opens.
- **REQ-005**: The External Target Scan shall check only the External Target Catalog.
- **REQ-006**: The first External Target Catalog shall include Finder, Terminal, Xcode, Zed, Cursor, VS Code, Android Studio, and Antigravity.
- **REQ-007**: Finder and Terminal shall be treated as baseline External Targets on supported macOS.
- **REQ-008**: Installed app targets shall appear only when found by the External Target Scan.
- **REQ-009**: Unavailable External Targets shall be hidden from the External Target Menu.
- **REQ-010**: GitHub shall not be included in the first External Target Catalog.
- **REQ-011**: If no Selected Project exists, the External Target Menu shall be disabled.
- **REQ-012**: The disabled External Target Menu shall communicate that the user must open a project first.
- **REQ-013**: Launching an External Target shall pass the Selected Project path correctly, including paths with spaces.
- **REQ-014**: An External Launch Failure shall append a process log entry with target name, project path, and failure detail.
- **REQ-015**: An External Launch Failure shall set status text to a short user-facing error such as `Could not open in Zed`.
- **CON-001**: The app must not perform an unbounded full-disk app discovery scan.
- **CON-002**: The app must not persist External Target Scan results in the first version.
- **CON-003**: Installing or removing external apps while Pi Agent Native is open must not change the External Target Menu until the next app launch.
- **CON-004**: Launch failures must not use a blocking modal in the first version.
- **GUD-001**: Use target labels that match user-recognizable app names.
- **GUD-002**: Use icons where the platform or app bundle can provide a reliable icon; otherwise use a stable fallback symbol.
- **PAT-001**: Model each External Target with a stable identifier, display label, detection strategy, launch strategy, and optional icon source.

## 4. Interfaces & Data Contracts

The implementation should expose an External Target Catalog equivalent to this conceptual contract:

```swift
enum ExternalTargetID: String, CaseIterable {
    case finder
    case terminal
    case xcode
    case zed
    case cursor
    case vscode
    case androidStudio
    case antigravity
}

struct ExternalTargetDefinition {
    let id: ExternalTargetID
    let displayName: String
    let bundleIdentifiers: [String]
    let commandNames: [String]
    let isBaselineMacTarget: Bool
}

struct AvailableExternalTarget {
    let definition: ExternalTargetDefinition
    let launchReference: ExternalLaunchReference
}

enum ExternalLaunchReference {
    case baselineMacTarget
    case appBundleURL(String)
    case commandPath(String)
}
```

Required consumers:

| Consumer | Required data |
|---|---|
| External Target Scan | target identifier, bundle identifiers, command names, baseline flag |
| External Target Menu | display name, availability, icon or fallback symbol |
| Launch action | launch reference, Selected Project path |
| Process log | target display name, Selected Project path, failure detail |

Recommended first-version detection signals:

| Target | Availability rule |
|---|---|
| Finder | Always available on supported macOS |
| Terminal | Always available on supported macOS |
| Xcode | Available when Xcode bundle is found |
| Zed | Available when Zed bundle or `zed` command is found |
| Cursor | Available when Cursor bundle or `cursor` command is found |
| VS Code | Available when Visual Studio Code bundle or `code` command is found |
| Android Studio | Available when Android Studio bundle is found |
| Antigravity | Available when Antigravity bundle or known launch command is found |

The scan should check bounded locations and platform lookup mechanisms, such as:

- `/Applications`
- `/System/Applications`
- `~/Applications`
- Launch Services bundle lookup when reliable
- PATH command lookup as a fallback for known editor commands

## 5. Acceptance Criteria

- **AC-001**: Given a Selected Project exists, When the chat header renders, Then the External Target Menu appears at the trailing end of the header near the inspector.
- **AC-002**: Given no Selected Project exists, When the chat header renders, Then the External Target Menu is disabled and communicates `Open a project first`.
- **AC-003**: Given Pi Agent Native opens, When initialization runs, Then an External Target Scan checks only the External Target Catalog.
- **AC-004**: Given only baseline targets are available, When the user opens the External Target Menu, Then Finder and Terminal are shown.
- **AC-005**: Given Zed is not installed and no `zed` command is available, When the user opens the External Target Menu, Then Zed is hidden.
- **AC-006**: Given Cursor is installed, When the user opens the External Target Menu, Then Cursor is shown.
- **AC-007**: Given the Selected Project path contains spaces, When the user opens the project in Terminal or an editor, Then the exact Selected Project path is passed as one path argument.
- **AC-008**: Given the user launches Finder from the External Target Menu, When the launch succeeds, Then Finder opens or reveals the Selected Project.
- **AC-009**: Given the user launches Terminal from the External Target Menu, When the launch succeeds, Then Terminal opens at the Selected Project path.
- **AC-010**: Given a launch attempt fails, When the failure is handled, Then status text shows a short failure message and the process log contains target name, project path, and error detail.
- **AC-011**: Given an external app is installed while Pi Agent Native is open, When the user opens the External Target Menu before reopening the app, Then the newly installed app is not shown.
- **AC-012**: Given the user reopens Pi Agent Native after installing an external app, When the External Target Scan runs, Then the app appears if it is in the External Target Catalog and detection succeeds.
- **AC-013**: Given the user opens the External Target Menu, Then GitHub is not listed.
- **AC-014**: Given the user launches an External Target, Then the Selected Project, selected session, message list, composer text, and running agent state are unchanged by the launch action.

## 6. Test Automation Strategy

- **Test Levels**: Unit and manual UI smoke tests.
- **Frameworks**: Swift XCTest for catalog, scan filtering, launch command construction, and error handling rules; manual macOS UI checks for menu placement and launch behavior.
- **Test Data Management**: Use temporary project paths, including paths with spaces. Use injected scan results rather than depending on the developer machine's installed apps in unit tests.
- **CI/CD Integration**: Run Swift package build and available XCTest targets in CI when test targets are added.
- **Coverage Requirements**: Unit tests should cover catalog membership, GitHub exclusion, hide-unavailable filtering, baseline target availability, and path argument construction.
- **Performance Testing**: No dedicated performance tests are required. The launch-time scan must be bounded to the known catalog and must not block the UI for an unbounded filesystem traversal.

## 7. Rationale & Context

The issue originally used “open project” for two meanings: selecting a project inside Pi Agent Native and launching that project elsewhere. The domain language now reserves Open Project for internal project selection and uses Open Externally for external app launches.

The External Target Menu belongs in the chat header because it acts on the current Selected Project, not on the project list itself. Placing it at the trailing side near the inspector keeps it visible while separating it from sidebar project selection.

The first version scans a known External Target Catalog at app launch. This keeps the menu predictable and avoids noisy or unsafe discovery of every app that can open folders. Finder and Terminal are baseline macOS targets. App-specific targets are hidden unless detected. GitHub is excluded from the first catalog by product decision.

No ADR is required for this version because the resolved choices are reversible product and interaction-scope decisions rather than hard-to-reverse architectural commitments.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: macOS application launching - Required to open the Selected Project in Finder, Terminal, and installed app targets.
- **EXT-002**: macOS application discovery signals - Required to detect known app bundles and command-line launchers.

### Third-Party Services

- **SVC-001**: None. GitHub is explicitly out of scope for the first External Target Catalog.

### Infrastructure Dependencies

- **INF-001**: None.

### Data Dependencies

- **DAT-001**: Selected Project path - Required input for every Open Externally action.

### Technology Platform Dependencies

- **PLT-001**: macOS 14 or newer - Required platform for Pi Agent Native.
- **PLT-002**: SwiftUI and AppKit interop - Required because the app shell is SwiftUI and external launch/discovery capabilities are platform APIs.

### Compliance Dependencies

- **COM-001**: None.

## 9. Examples & Edge Cases

```text
Menu contents when only baseline targets are available:
Finder
Terminal
```

```text
Menu contents when Cursor and Zed are detected:
Finder
Terminal
Cursor
Zed
```

```text
No selected project:
External Target Menu is disabled.
Tooltip or help text: Open a project first
```

```text
Launch failure process log detail:
title: open externally failed
detail: target=Zed projectPath=/Users/example/My Project error=<platform error>
```

```text
Path with spaces:
/Users/example/Projects/My Swift App

The path must be passed as one URL or one process argument, never split on spaces.
```

## 10. Validation Criteria

- The External Target Catalog excludes GitHub.
- The External Target Scan runs on app launch and checks only catalog targets.
- The External Target Menu hides unavailable targets.
- Finder and Terminal appear whenever a Selected Project exists.
- Installed app targets appear only when detected by the scan.
- The External Target Menu is disabled when no Selected Project exists.
- External launch actions preserve current Pi Agent Native project/session/conversation state.
- Launch failures are visible in status text and process log without a blocking modal.
- Paths with spaces are handled as a single project path.

## 11. Related Specifications / Further Reading

- [Pi Agent Native domain context](../CONTEXT.md)
- [Native Pi Shell Architecture Improvements](../docs/improvements.md)
- [GitHub issue 14: Open project in a text editor](https://github.com/MatheusBBarni/pi-agent-native/issues/14)
