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

**Sidebar Command**:
A shell-level **App Action** presented as a button in the left sidebar.
_Avoid_: sidebar shortcut, side menu item

**Pane Toggle**:
An **App Action** that shows or hides a persistent shell region such as the sidebar or inspector.
_Avoid_: collapse shortcut, panel switch

**Modal Dismissal**:
An **App Action** that closes the active modal without changing the underlying conversation state.
_Avoid_: cancel shortcut, close shortcut

**Selected Project**:
The project currently active in Pi Agent Native.
_Avoid_: current workspace, active folder

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

**File Mention**:
An editable plain-text reference to a file or folder inside the **Selected Project** that the user inserts into the composer.
_Avoid_: attachment, structured token, embedded file

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
Native-generated prompt text that tells the Pi coding agent which **Skills** to use for the current request.
_Avoid_: RPC skill payload, hidden command

## Relationships

- A **Keymap** contains zero or more **Keybindings**.
- A **Keybinding** targets exactly one **App Action**.
- The first keybinding release ships only the **Default Keymap**.
- Future user-customized keymaps may override the **Default Keymap**, but are outside the first release scope.
- A **Focused Keybinding** belongs to a UI region that can perform the target **App Action** safely.
- An **App-Wide Keybinding** is reserved for shell-level actions that should work from most parts of the active window.
- Composer text editing takes precedence over conflicting **Keybindings**.
- **Keybinding Help** presents the **Default Keymap** and does not allow editing in the first release.
- A **Sidebar Command** exposes its **Keybinding** through hover help when one exists.
- The Help **Sidebar Command** opens **Keybinding Help**.
- A **Pane Toggle** controls shell layout visibility without changing the current project, session, or conversation.
- **Modal Dismissal** takes precedence over stopping generation when a modal is active.
- Project/session cycling and picker navigation are outside the first **Default Keymap**.
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
- A **File Mention** belongs to exactly one **Selected Project**.
- A **File Mention** is sent as part of the prompt text, not as a separate RPC attachment.
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
> **Dev:** "Should sidebar and inspector keybindings wait for another feature?"
> **Domain expert:** "No. Sidebar and inspector visibility are **Pane Toggle** actions included in the first **Default Keymap**."
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
> **Dev:** "Should choosing a file from @ add a structured attachment?"
> **Domain expert:** "No. In the first version it inserts a plain-text **File Mention** into the composer and sends it inside the prompt string."
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
> **Domain expert:** "No. Prepend a native-generated **Skill Instruction** to the next normal prompt because the Pi coding agent understands natural-language skill instructions."
>
> **Dev:** "Should typing `/` open a general command picker?"
> **Domain expert:** "No. The **Skill Picker** opens only for active `/skill:` queries."
>
> **Dev:** "Should choosing a Skill Picker row immediately select the skill?"
> **Domain expert:** "No. Choosing a row completes the `/skill:<skill-id>` text token. Submitting the slash-command line creates the pending **Selected Skill Chips**."
>
> **Dev:** "What if the user already selected `diagnose` and submits `/skill:diagnose /skill:zoom-out`?"
> **Domain expert:** "Append only new **Skills** to the pending **Skill Selection**. Do not create duplicate **Selected Skill Chips**."

## Flagged ambiguities

- "keymaps/keybindings" was used broadly in issue 15. Resolved: the first release includes only a **Default Keymap** and no user-editable keybinding customization.
- "global shortcuts" could mean operating system-wide shortcuts. Resolved: Pi Agent Native only needs **App-Wide Keybindings** inside the active app window.
- "open project" was used to mean both choosing a project in Pi Agent Native and launching it in another app. Resolved: **Open Project** is internal selection; **Open Externally** launches an **External Target**.
- "stable mention/token" in issue 1 could mean a structured attachment. Resolved: the first version uses an editable plain-text **File Mention**.
- "file picker" in issue 1 could mean a system file dialog. Resolved: this feature is a composer **Mention Picker**, not a modal file chooser.
- "invoke a skill" in issue 16 could mean immediately executing a skill or selecting it for later use. Resolved: `/skill:<skill-id>` performs **Skill Selection** for the next normal prompt.
- "concatenate multiple skills" in issue 16 could mean comma lists, mixed text, or repeated tokens. Resolved: the first version supports repeated `/skill:<skill-id>` tokens separated by whitespace.
