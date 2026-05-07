# Pi Agent Native

Pi Agent Native is a native macOS shell for the `pi` coding agent. This context defines user-facing concepts for operating the shell, its conversations, and its keyboard interaction model.

## Language

**App Action**:
A user-intent command that Pi Agent Native can perform from the UI or keyboard.
_Avoid_: command, operation

**Keybinding**:
A keyboard gesture assigned to exactly one **App Action** in a **Keymap**.
_Avoid_: shortcut, hotkey

**Keymap**:
The active collection of **Keybindings** available in Pi Agent Native.
_Avoid_: shortcut list, keybinding settings

**Default Keymap**:
The built-in **Keymap** shipped with Pi Agent Native before user customization exists.
_Avoid_: hardcoded shortcuts, starter keymap

**Focused Keybinding**:
A **Keybinding** that fires only when the current UI focus can safely perform its **App Action**.
_Avoid_: contextual shortcut, local hotkey

**App-Wide Keybinding**:
A **Keybinding** that can fire anywhere in the active Pi Agent Native window unless a modal or system text interaction owns the gesture.
_Avoid_: global shortcut, universal hotkey

**Keybinding Help**:
A discoverable surface that lists the **Default Keymap** in user-facing language.
_Avoid_: shortcut docs, hotkey reference

**Command Palette**:
A keyboard-accessible native shell surface that filters and runs available **App Actions** and state-derived app actions.
_Avoid_: slash command picker, terminal command prompt, skill picker

**Palette Item**:
A selectable row in the **Command Palette** that invokes one concrete **App Action** or one parameterized shared AppModel action.
_Avoid_: slash command, menu clone

**Palette Query**:
The text typed into the **Command Palette** to filter **Palette Items**.
_Avoid_: composer text, prompt

**Sidebar Command**:
A shell-level **App Action** presented as a button in the left sidebar.
_Avoid_: sidebar shortcut, side menu item

**Header Control**:
An icon or text control in a window, sidebar, chat, or composer header that invokes one concrete **App Action**.
_Avoid_: decorative header button, chrome icon

**Pane Toggle**:
An **App Action** that shows or hides a persistent shell region such as the sidebar or inspector.
_Avoid_: collapse shortcut, panel switch

**Inspector**:
The persistent right-side shell region that shows project, process, model, and tool activity context for the current conversation.
_Avoid_: right sidebar, side panel

**Modal Dismissal**:
An **App Action** that closes the active modal without changing the underlying conversation state.
_Avoid_: cancel shortcut, close shortcut

**Selected Project**:
The project currently active in Pi Agent Native.
_Avoid_: current workspace, active folder

**Selected Session**:
The conversation session currently active inside the **Selected Project**.
_Avoid_: current chat, active thread

**Project Session List**:
The ordered list of known sessions for a **Selected Project** as shown in the sidebar.
_Avoid_: session history, navigation stack

**Previous Session**:
An **App Action** that switches from the **Selected Session** to the preceding session in the **Project Session List**.
_Avoid_: back, go back

**Next Session**:
An **App Action** that switches from the **Selected Session** to the following session in the **Project Session List**.
_Avoid_: forward, go forward

**Open Project**:
An **App Action** that chooses or switches the **Selected Project** inside Pi Agent Native.
_Avoid_: open externally, launch project

**Open Externally**:
An **App Action** that launches the **Selected Project** in another app or destination.
_Avoid_: open project, reveal project

**External Target**:
A supported destination for **Open Externally**, such as Finder, Terminal, an editor, or a repository URL.
_Avoid_: app option, launcher item

**External Target Menu**:
The header dropdown that lists available **External Targets** for **Open Externally**.
_Avoid_: open project menu, app launcher

**External Target Scan**:
A launch-time check that discovers which known **External Targets** are available on the user computer.
_Avoid_: app indexing, full disk scan

**External Target Catalog**:
The known set of **External Targets** Pi Agent Native knows how to detect and launch.
_Avoid_: installed apps list, app inventory

**External Launch Failure**:
A failed attempt to complete **Open Externally** for a **Selected Project** and **External Target**.
_Avoid_: app error, open failure

**Change Review Surface**:
A native surface for inspecting current repository changes in the **Selected Project**.
_Avoid_: git client, commit view, process log diff

**Repository Change Snapshot**:
The latest native model of changed files and diff hunks for the **Selected Project**.
_Avoid_: git status string, session artifact

**Changed File**:
A file path in a **Repository Change Snapshot** with a change state such as added, modified, deleted, renamed, or untracked.
_Avoid_: tool output file, attachment

**Diff Hunk**:
A parsed section of a file diff shown inside the **Change Review Surface**.
_Avoid_: patch command, log line

**File Mention**:
An editable plain-text reference to a file or folder inside the **Selected Project** that the user inserts into the composer.
_Avoid_: upload, embedded file

**Context Attachment**:
A validated native reference to a file or folder inside the **Selected Project** that is shown separately from ordinary composer text and intentionally included with the next prompt.
_Avoid_: file upload, binary attachment, global file reference

**Attachment Resolution**:
The process of validating that a **Context Attachment** still exists, has the expected file or folder kind, and resolves inside the current **Selected Project**.
_Avoid_: file watching, upload validation

**Attachment Chip**:
A compact composer control that represents one **Context Attachment** outside the editable prompt text.
_Avoid_: inline token, picker row

**Mention Picker**:
A composer suggestion surface that helps the user insert a **File Mention**.
_Avoid_: attachment browser, file dialog

**Mention Index**:
The app-session cache of searchable file and folder paths for a **Selected Project**.
_Avoid_: file watcher, attachment store

**Skill**:
A named agent capability available to the running Pi coding agent.
_Avoid_: plugin, command

**Composer Slash Command**:
A composer input beginning with `/` that Pi Agent Native interprets before sending normal prompt text.
_Avoid_: App Action, keyboard command

**Skill Selection**:
A **Composer Slash Command** that selects one or more **Skills** as context for the next normal prompt.
_Avoid_: skill invocation, skill execution

**Skill Picker**:
A composer suggestion surface that helps the user find and select **Skills** for a **Skill Selection**.
_Avoid_: command picker, plugin picker

**Selected Skill Chip**:
A visible composer control that shows one selected **Skill** before it is consumed by the next normal prompt.
_Avoid_: badge, tag

**Skill Instruction**:
Native-generated prompt text that embeds selected **Skill** content for the current request.
_Avoid_: RPC skill payload, hidden command

**Authentication State**:
The user's current credential relationship with Pi Agent Native, such as unauthenticated, login in progress, authenticated, or authentication error.
_Avoid_: login flag, signed-in boolean

**Subscription Access**:
The access level derived from the latest authenticated provider state that determines whether subscription-required app actions may proceed.
_Avoid_: paid flag, plan flag

**Model Access**:
The user's current ability to run model-backed agent interactions from any supported credential source, including API-key credentials and subscription credentials.
_Avoid_: subscription status, authenticated models

**Access Refresh**:
A deliberate refresh of **Authentication State**, **Model Access**, and **Subscription Access** after login, logout, app launch, RPC restart, or user-invoked refresh.
_Avoid_: model reload, auth ping

**Subscription-Gated Action**:
An **App Action** or agent interaction that requires active **Subscription Access** before it can run.
_Avoid_: premium action, paid action

**Queued Work**:
A user-facing prompt-like message accepted by Pi Agent Native while the Pi coding agent is busy and waiting for later delivery to the agent.
_Avoid_: pending count, buffered input

**Steering Queue Entry**:
Queued **Queued Work** that is intended to steer the currently running agent work before follow-up work is processed.
_Avoid_: interrupt message, live edit

**Follow-Up Queue Entry**:
Queued **Queued Work** that is intended to run after current agent work and any steering queue entries are drained.
_Avoid_: next task, reminder

**Queue Surface**:
A native UI surface that shows **Queued Work** entries and their delivery category.
_Avoid_: process log queue, hidden pending messages

**Session Compaction**:
A Pi operation that summarizes older conversation context so a session can continue within model context limits.
_Avoid_: compression, cleanup

**Compaction State**:
The current or latest user-facing status of **Session Compaction** for the active Pi RPC session.
_Avoid_: log line, compact flag

**Compaction Result**:
The visible outcome of a completed, failed, or aborted **Session Compaction**.
_Avoid_: command response, process output

**Compaction Control**:
A native control that triggers **Session Compaction** for the active session when Pi RPC supports it.
_Avoid_: slash command button, hidden compact command

## Relationships

- A **Keymap** contains zero or more **Keybindings**.
- A **Keybinding** targets exactly one **App Action**.
- The first keybinding release ships only the **Default Keymap**.
- Future user-customized keymaps may override the **Default Keymap**, but are outside the first release scope.
- A **Focused Keybinding** belongs to a UI region that can perform the target **App Action** safely.
- An **App-Wide Keybinding** is reserved for shell-level actions that should work from most parts of the active window.
- Composer text editing takes precedence over conflicting **Keybindings**.
- **Keybinding Help** presents the **Default Keymap** and does not allow editing in the first release.
- The **Command Palette** is a native shell surface, not a **Composer Slash Command**.
- The **Command Palette** opens from an app-wide **Keybinding** and active shell UI, not from typing `/` in the composer.
- A **Palette Query** never changes composer text.
- A **Palette Item** backed by an **App Action** dispatches through the shared **App Action** path.
- A parameterized **Palette Item**, such as a project, session, model, thinking level, or external target row, dispatches through the same shared AppModel method used by the existing UI surface for that action.
- A disabled **Palette Item** must explain why it is unavailable and must not run.
- The **Command Palette** must not interfere with **Composer Slash Command**, **Mention Picker**, or **Skill Picker** behavior.
- A **Sidebar Command** exposes its **Keybinding** through hover help when one exists.
- The Help **Sidebar Command** opens **Keybinding Help**.
- A **Header Control** must invoke an existing **App Action** or be hidden until its action exists.
- A disabled **Header Control** must explain why the **App Action** is unavailable.
- A **Header Control** must not duplicate **App Action** behavior in the view layer.
- A **Pane Toggle** controls shell layout visibility without changing the current project, session, or conversation.
- The **Inspector** is a persistent shell region controlled by a **Pane Toggle**.
- The **Inspector** collapse control must remain available when the **Inspector** is hidden.
- **Modal Dismissal** takes precedence over stopping generation when a modal is active.
- **Previous Session** and **Next Session** are header **App Actions**, not first-version **Default Keymap** entries.
- **Previous Session** and **Next Session** use the **Project Session List** for the current **Selected Project**.
- **Previous Session** and **Next Session** do not wrap at the beginning or end of the **Project Session List**.
- Project/session keyboard cycling and picker navigation are outside the first **Default Keymap**.
- **Open Project** changes the **Selected Project** inside Pi Agent Native.
- **Open Externally** does not change the **Selected Project**.
- **Open Externally** launches exactly one **External Target** for the **Selected Project**.
- The **External Target Menu** lives in the chat header, trailing near the inspector.
- The **External Target Menu** shows **External Targets** found by the latest **External Target Scan**.
- An **External Target Scan** runs each time Pi Agent Native opens.
- An **External Target Scan** checks only the **External Target Catalog**.
- The **External Target Catalog** can grow without changing what **Open Externally** means.
- The **External Target Menu** hides unavailable **External Targets**.
- GitHub is not an **External Target** in the first **External Target Catalog**.
- Finder and Terminal are baseline **External Targets** on supported macOS.
- Installing or removing an external app while Pi Agent Native is open does not change the **External Target Menu** until the next app launch.
- An **External Launch Failure** is surfaced through status text and the process log, not a blocking modal.
- A **Change Review Surface** belongs to the **Selected Project**.
- A **Change Review Surface** shows the current worktree and index state, not only changes made by the current Pi session.
- A **Repository Change Snapshot** is refreshed from Git state for the **Selected Project**.
- A **Repository Change Snapshot** is refreshed after completed agent tool activity and when the user refreshes state.
- A **Changed File** is keyed by workspace-relative path and may also carry an original path for renamed files.
- A **Changed File** with untracked status appears as added in the first review slice.
- A **Diff Hunk** is display-only in the first review slice; applying, staging, discarding, or editing patches is out of scope.
- The **Change Review Surface** uses **Open Externally** paths for deeper review in external tools.
- A **File Mention** belongs to exactly one **Selected Project**.
- The first **File Mention** release sends mentions as part of prompt text, not as separate RPC attachments.
- A **File Mention** may produce one **Context Attachment** after **Attachment Resolution**.
- A **Context Attachment** belongs to exactly one **Selected Project**.
- A **Context Attachment** is invalidated when the **Selected Project** changes.
- A **Context Attachment** must pass **Attachment Resolution** before prompt submission.
- A **Context Attachment** is native composer state; it is not a file upload in the first release.
- An **Attachment Chip** shows resolved **Context Attachment** state separately from ordinary composer text.
- Prompt submission may decorate the outgoing prompt string with **Context Attachment** references while Pi RPC only supports text and image payloads.
- A **Mention Picker** searches files and folders under the **Selected Project**.
- A **Mention Picker** excludes noisy generated, dependency, and hidden paths by default.
- A **Mention Picker** opens only for an `@` mention query at the start of text, after whitespace, or after an opening delimiter.
- Inserting a **File Mention** replaces the active mention query with `@` plus the workspace-relative path and a trailing space.
- **Mention Picker** navigation is local composer interaction, not part of the **Default Keymap**.
- A **Mention Picker** ranks display-name matches ahead of path-only matches and caps visible results.
- A **Mention Picker** reads from a **Mention Index** for the active **Selected Project**.
- A **Mention Index** is rebuilt when the **Selected Project** changes or the user refreshes state.
- A **Mention Index** prefers Git-tracked and Git-unignored project paths when the **Selected Project** is a Git repository.
- A **Mention Picker** does not open when there is no **Selected Project**.
- A **Mention Picker** appears as a compact composer overlay above the composer input.
- A **Mention Picker** row shows display name and workspace-relative path.
- A **Mention Index** includes in-project symlink entries but does not recursively follow directory symlinks.
- A **File Mention** must resolve inside its **Selected Project** before insertion.
- A folder **File Mention** ends with a trailing slash.
- A **Mention Picker** supports both keyboard selection and pointer selection.
- A **Composer Slash Command** is handled by Pi Agent Native before prompt submission.
- A **Skill Selection** uses the `/skill:<skill-id>` form.
- Multiple **Skills** are selected by submitting repeated `/skill:<skill-id>` tokens separated by whitespace.
- Available **Skills** come from the running Pi coding agent, not from a native filesystem scan.
- If available **Skills** cannot be loaded from the running Pi coding agent, **Skill Selection** is unavailable.
- A **Skill Selection** selects **Skills** as context for the next normal prompt and does not immediately execute those **Skills** by itself.
- A **Skill Selection** must resolve every requested **Skill** before changing composer state.
- A **Skill Selection** is cleared after the next normal prompt is submitted.
- A **Skill Picker** follows the same local composer interaction model as the **Mention Picker**.
- A **Skill Picker** opens only for an active `/skill:` query.
- A **Skill Picker** does not open for other slash-prefixed composer text.
- Choosing a **Skill Picker** row completes the active `/skill:` token in composer text.
- Submitting a valid **Skill Selection** creates pending **Selected Skill Chips**.
- Submitting more valid **Skill Selection** commands appends unique **Skills** to the pending selection.
- A **Skill** already shown as a **Selected Skill Chip** is not added a second time.
- A **Selected Skill Chip** appears for each **Skill** in the pending **Skill Selection**.
- A **Selected Skill Chip** can remove its **Skill** before the next normal prompt is submitted.
- Multiple pending **Selected Skill Chips** can be cleared together.
- The next normal prompt carries pending **Skills** by prepending a **Skill Instruction** to the prompt sent to the Pi coding agent.
- Pi Agent Native shows the user's original prompt in the conversation, not the generated **Skill Instruction** prefix.
- **Authentication State**, **Model Access**, and **Subscription Access** are separate states.
- Successful login changes **Authentication State** before **Model Access** or **Subscription Access** is trusted.
- Pi Agent Native must perform an **Access Refresh** before enabling model-backed interactions or **Subscription-Gated Actions** after login.
- API-key credentials may provide **Model Access** without active **Subscription Access**.
- Logout clears **Authentication State**, **Model Access**, and **Subscription Access** so access from a previous account is never shown for a later account.
- Unknown or failed **Subscription Access** must not be treated as active access.
- **Subscription-Gated Actions** can run only when the latest **Access Refresh** reports active **Subscription Access**.
- **Queued Work** belongs to the active Pi RPC session and is not native session history.
- **Queued Work** appears in a **Queue Surface**, not only as a numeric pending count.
- A **Steering Queue Entry** is shown separately from a **Follow-Up Queue Entry**.
- A **Queue Surface** updates from Pi RPC queue updates while agent work is running.
- A **Queue Surface** must not replace the conversation, composer, tool activity, or process log.
- **Session Compaction** belongs to the active Pi RPC session and is not a native project setting.
- **Compaction State** must be visible outside the process log.
- A **Compaction Control** is available only when the active session can compact.
- A **Compaction Result** remains visible after **Session Compaction** completes, fails, or is aborted.
- **Session Compaction** does not create normal chat messages unless Pi RPC later reports message history containing a compaction summary.

## Example dialogue

> **Dev:** "Should users edit shortcuts in the first release?"
> **Domain expert:** "No. Ship a discoverable **Default Keymap** now, but model every shortcut as a **Keybinding** for an **App Action** so customization can be added later."
>
> **Dev:** "Can the Return key be a normal app shortcut?"
> **Domain expert:** "No. Text editing owns Return-like behavior in the composer. The send action is a **Focused Keybinding**, not an app-wide one."
>
> **Dev:** "What is the first default keybinding for a new conversation?"
> **Domain expert:** "**New chat** is an **App Action** bound to Command-N as an **App-Wide Keybinding**."
>
> **Dev:** "Where does a user discover shortcuts?"
> **Domain expert:** "Sidebar commands show their **Keybindings** on hover, and the Help **Sidebar Command** opens **Keybinding Help**."
>
> **Dev:** "Is the command palette a slash-command picker opened by typing `/`?"
> **Domain expert:** "No. The **Command Palette** is a native shell surface for **App Actions**. Composer slash commands remain inside the composer."
>
> **Dev:** "Should palette rows duplicate action behavior in the view layer?"
> **Domain expert:** "No. A **Palette Item** backed by an **App Action** dispatches through the same shared **App Action** path as menus, sidebar commands, and keybindings."
>
> **Dev:** "Can the palette list projects, sessions, models, and thinking levels even though they need parameters?"
> **Domain expert:** "Yes. Treat them as parameterized **Palette Items** that call the same AppModel methods as the existing project list, session list, model picker, and thinking menu."
>
> **Dev:** "What happens to `/skill:` selection or `@` file mention text when the palette opens?"
> **Domain expert:** "Nothing is submitted or rewritten. The **Command Palette** owns only its **Palette Query** and must not mutate composer text."
>
> **Dev:** "Can a header show icon-only controls before their behavior exists?"
> **Domain expert:** "No. A visible **Header Control** must call a concrete **App Action**. Hide or disable controls whose action is not available."
>
> **Dev:** "What do the chevrons in the sidebar header do?"
> **Domain expert:** "They are **Previous Session** and **Next Session** controls. They move through the **Project Session List** for the **Selected Project** without adding keybindings."
>
> **Dev:** "Should sidebar and inspector keybindings wait for another feature?"
> **Domain expert:** "No. Sidebar and inspector visibility are **Pane Toggle** actions included in the first **Default Keymap**."
>
> **Dev:** "Does 'right sidebar' mean a second sidebar beside the project list?"
> **Domain expert:** "No. Use **Inspector** for the persistent right-side region that shows project, process, model, and tool context."
>
> **Dev:** "Should project/session cycling be in the first keybinding release?"
> **Domain expert:** "No. Defer project/session cycling and picker navigation until those surfaces have a focused navigation model. Keep Escape for **Modal Dismissal** and stop-generation behavior."
>
> **Dev:** "Does Open project mean launching the folder in another editor?"
> **Domain expert:** "No. **Open Project** chooses the **Selected Project** inside Pi Agent Native. Launching it elsewhere is **Open Externally**."
>
> **Dev:** "Where should external launch actions live?"
> **Domain expert:** "Use an **External Target Menu** in the trailing side of the chat header, near the inspector."
>
> **Dev:** "Should availability be saved between runs?"
> **Domain expert:** "No. Run an **External Target Scan** each time Pi Agent Native opens and show the available targets from that scan."
>
> **Dev:** "Should the scan discover every app that can open folders?"
> **Domain expert:** "No. Scan the known **External Target Catalog** only, so the menu stays predictable."
>
> **Dev:** "Should unavailable external apps appear disabled?"
> **Domain expert:** "No. Hide unavailable **External Targets** from the **External Target Menu**."
>
> **Dev:** "Should GitHub be listed beside installed apps?"
> **Domain expert:** "No. GitHub is excluded from the first **External Target Catalog**."
>
> **Dev:** "Should Finder and Terminal depend on the scan?"
> **Domain expert:** "Treat Finder and Terminal as baseline **External Targets** that are always available when a **Selected Project** exists."
>
> **Dev:** "Should newly installed apps appear immediately?"
> **Domain expert:** "No. **External Target Scan** results refresh after reopening Pi Agent Native."
>
> **Dev:** "How should launch errors be shown?"
> **Domain expert:** "Record an **External Launch Failure** in the process log and show a short status message. Do not add a blocking error modal in the first version."
>
> **Dev:** "Should native diff review show only files changed by the latest agent run?"
> **Domain expert:** "No. The first **Change Review Surface** shows the current **Selected Project** repository state. Attribution to a particular Pi turn can come later."
>
> **Dev:** "Is the review surface a git client for staging or applying patches?"
> **Domain expert:** "No. The first slice is inspect-only: show **Changed Files** and **Diff Hunks**, then offer **Open Externally** for deeper review."
>
> **Dev:** "Where does the review data come from?"
> **Domain expert:** "Build a **Repository Change Snapshot** from Git for the **Selected Project**, extending the current branch/change summary service rather than parsing process-log text."
>
> **Dev:** "When should changes refresh?"
> **Domain expert:** "Refresh after completed agent tool activity and when the user invokes refresh state. Do not watch the filesystem live in the first slice."
>
> **Dev:** "Should choosing a file from @ add a structured attachment?"
> **Domain expert:** "No. In the first version it inserts a plain-text **File Mention** into the composer and sends it inside the prompt string."
>
> **Dev:** "For the next File Mention slice, does structured attachment mean uploading file bytes to pi?"
> **Domain expert:** "No. Use **Context Attachment** for validated native file or folder references. Keep the first transport Pi-compatible by decorating prompt text unless Pi RPC adds a structured file context payload."
>
> **Dev:** "Should attached files remain hidden inside the editable composer text?"
> **Domain expert:** "No. Show each resolved **Context Attachment** as an **Attachment Chip** outside ordinary prompt text so the user can inspect and remove it without losing predictable text editing."
>
> **Dev:** "What happens when a mentioned file is moved, deleted, or escapes the selected project?"
> **Domain expert:** "Run **Attachment Resolution** before submission and surface invalid attachments before sending. Do not silently send stale or out-of-project paths."
>
> **Dev:** "Do Context Attachments survive switching projects?"
> **Domain expert:** "No. A **Context Attachment** is scoped to one **Selected Project** and is invalidated when the **Selected Project** changes."
>
> **Dev:** "Should @ search every path in the project?"
> **Domain expert:** "Search the **Selected Project**, but hide generated, dependency, and hidden paths by default so the **Mention Picker** stays useful."
>
> **Dev:** "Should every @ character open the picker?"
> **Domain expert:** "No. Open the **Mention Picker** only when @ starts a mention query, not inside ordinary text such as an email address."
>
> **Dev:** "What should selecting a file insert?"
> **Domain expert:** "Replace the active query with a plain-text **File Mention** in the form `@path/from/project `."
>
> **Dev:** "Are Up, Down, Return, Tab, and Escape picker shortcuts part of the Default Keymap?"
> **Domain expert:** "No. They are local **Mention Picker** interactions while the picker is open."
>
> **Dev:** "Should folders always appear before files?"
> **Domain expert:** "No. Use match quality first, then prefer folders only when scores tie."
>
> **Dev:** "Should the Mention Picker watch the filesystem live?"
> **Domain expert:** "No. Build a **Mention Index** lazily and refresh it when the selected project changes or the user refreshes state."
>
> **Dev:** "Should ignored build output appear in @ results?"
> **Domain expert:** "No. When the selected project is a Git repository, prefer Git-tracked and Git-unignored paths for the **Mention Index**."
>
> **Dev:** "Can @ mention paths outside the project through symlinks?"
> **Domain expert:** "No. Include symlink entries in the **Mention Index**, but only insert a **File Mention** if its resolved path stays inside the **Selected Project**."
>
> **Dev:** "Should folder mentions look different from file mentions?"
> **Domain expert:** "Yes. A folder **File Mention** ends with a trailing slash."
>
> **Dev:** "Can users click a Mention Picker row?"
> **Domain expert:** "Yes. The **Mention Picker** supports both keyboard and pointer selection."
>
> **Dev:** "Should missing project files show a modal error?"
> **Domain expert:** "No. Keep the composer unchanged and show a lightweight unavailable state only when a selected project cannot be indexed."
>
> **Dev:** "Where should file suggestions appear?"
> **Domain expert:** "Show the **Mention Picker** as a compact overlay above the composer, with each row showing display name and relative path."
>
> **Dev:** "Does `/skill:diagnose` immediately run the diagnose skill?"
> **Domain expert:** "No. `/skill:<skill-id>` is a **Skill Selection**. It selects **Skills** as context for the next normal prompt."
>
> **Dev:** "Should the selected skill stay active for the whole chat?"
> **Domain expert:** "No. A **Skill Selection** is one-shot and clears after the next normal prompt is submitted."
>
> **Dev:** "Should Pi Agent Native scan `.agents/skills` folders to validate skill ids?"
> **Domain expert:** "No. The running Pi coding agent is the authority for available **Skills**."
>
> **Dev:** "Should an exact `/skill:diagnose` command work when the app cannot load the skill list?"
> **Domain expert:** "No. **Skill Selection** requires validation against the running Pi coding agent's available **Skills**."
>
> **Dev:** "How do users select multiple skills?"
> **Domain expert:** "Submit repeated `/skill:<skill-id>` tokens separated by whitespace, such as `/skill:diagnose /skill:zoom-out`."
>
> **Dev:** "How does the user know a skill will affect the next prompt?"
> **Domain expert:** "Show a **Selected Skill Chip** for each pending **Skill**, with controls to remove one skill or clear all pending skills."
>
> **Dev:** "Does selecting skills require a structured RPC payload?"
> **Domain expert:** "No. Prepend a native-generated **Skill Instruction** to the next normal prompt by expanding the selected Skills' `SKILL.md` content into the single prompt string."
>
> **Dev:** "Should typing `/` open a general command picker?"
> **Domain expert:** "No. The **Skill Picker** opens only for active `/skill:` queries."
>
> **Dev:** "Should choosing a Skill Picker row immediately select the skill?"
> **Domain expert:** "No. Choosing a row completes the `/skill:<skill-id>` text token. Submitting the slash-command line creates the pending **Selected Skill Chips**."
>
> **Dev:** "What if the user already selected `diagnose` and submits `/skill:diagnose /skill:zoom-out`?"
> **Domain expert:** "Append only new **Skills** to the pending **Skill Selection**. Do not create duplicate **Selected Skill Chips**."
>
> **Dev:** "Does successful login automatically mean the user can run subscription-required actions?"
> **Domain expert:** "No. Successful login establishes **Authentication State**. Pi Agent Native must complete an **Access Refresh** before treating **Subscription Access** as active."
>
> **Dev:** "What should happen while subscription access is still being refreshed?"
> **Domain expert:** "Treat **Subscription Access** as unknown and keep **Subscription-Gated Actions** disabled until the latest refresh completes."
>
> **Dev:** "Can API-key credentials enable subscription-only actions if models are available?"
> **Domain expert:** "No. API-key credentials can provide **Model Access**, but **Subscription-Gated Actions** require active **Subscription Access** from a subscription-backed credential context."
>
> **Dev:** "Can logout leave the previous account's subscription status visible?"
> **Domain expert:** "No. Logout clears **Authentication State**, **Model Access**, and **Subscription Access** immediately."
>
> **Dev:** "Should an access refresh error grant access because the user was previously subscribed?"
> **Domain expert:** "No. Unknown or failed **Subscription Access** is not active access. Show the error without leaving stale access enabled."
>
> **Dev:** "Is the pending message count enough to explain why the run is still busy?"
> **Domain expert:** "No. Show **Queued Work** entries in a **Queue Surface** and distinguish **Steering Queue Entry** from **Follow-Up Queue Entry**."
>
> **Dev:** "Are steering and follow-up entries part of chat history?"
> **Domain expert:** "No. They belong to the active Pi RPC session queue until Pi drains them into agent work."
>
> **Dev:** "Is compaction just another process-log event?"
> **Domain expert:** "No. Show **Compaction State** in the shell and keep a **Compaction Result** visible after the event stream finishes."
>
> **Dev:** "Can users compact without an active session?"
> **Domain expert:** "No. The **Compaction Control** acts on the active Pi RPC session, so it is disabled when no selected session can compact."

## Flagged ambiguities

- "keymaps/keybindings" was used broadly in issue 15. Resolved: the first release includes only a **Default Keymap** and no user-editable keybinding customization.
- "global shortcuts" could mean operating system-wide shortcuts. Resolved: Pi Agent Native only needs **App-Wide Keybindings** inside the active app window.
- "command palette" in issue 23 could mean a composer slash-command picker or terminal command prompt. Resolved: it is a native **Command Palette** for **App Actions** and parameterized app state actions.
- "shell actions" in issue 23 means Pi Agent Native **App Actions**, not arbitrary shell commands.
- "open project" was used to mean both choosing a project in Pi Agent Native and launching it in another app. Resolved: **Open Project** is internal selection; **Open Externally** launches an **External Target**.
- "native diff and patch review" in issue 24 could imply staging, discarding, or applying patches. Resolved: the first **Change Review Surface** is inspect-only and shows current **Changed Files** and **Diff Hunks**.
- "changes produced during Pi sessions" in issue 24 could imply exact attribution to one agent run. Resolved: the first slice shows current **Selected Project** repository changes, refreshed after tool activity and manual refresh.
- "stable mention/token" in issue 1 could mean a structured attachment. Resolved: the first version uses an editable plain-text **File Mention**.
- "structured context attachments" in issue 25 could mean file uploads or a new Pi RPC file payload. Resolved: it means validated native **Context Attachment** state derived from **File Mention** selection, with Pi-compatible prompt decoration in the first slice.
- "file picker" in issue 1 could mean a system file dialog. Resolved: this feature is a composer **Mention Picker**, not a modal file chooser.
- "invoke a skill" in issue 16 could mean immediately executing a skill or selecting it for later use. Resolved: `/skill:<skill-id>` performs **Skill Selection** for the next normal prompt.
- "concatenate multiple skills" in issue 16 could mean comma lists, mixed text, or repeated tokens. Resolved: the first version supports repeated `/skill:<skill-id>` tokens separated by whitespace.
- "subscription state" in issue 11 could mean the login process exit status, model availability, or an independent billing-provider query. Resolved: use **Model Access** for model-backed availability, use **Subscription Access** for subscription-gated decisions, and require an **Access Refresh** after credential changes before enabling gated behavior.
- "header buttons" in issue 12 could mean decorative titlebar icons or action controls. Resolved: use **Header Control** for visible header controls that dispatch concrete **App Actions**.
- The chevrons in issue 12 could mean undefined navigation history. Resolved: they are **Previous Session** and **Next Session**, scoped to the **Project Session List** for the **Selected Project**.
- "right sidebar" in issue 13 means the **Inspector**, not the left project/session sidebar.
- "queue" in issue 21 means **Queued Work** accepted by the Pi RPC session for later steering or follow-up delivery, not tool activity status and not native session history.
- "context state" in issue 22 means **Compaction State** and **Compaction Result** for **Session Compaction**, not a full token-accounting dashboard.
