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

## Relationships

- A **Keymap** contains zero or more **Keybindings**.
- A **Keybinding** targets exactly one **App Action**.
- The first keybinding release ships only the **Default Keymap**.
- Future user-customized keymaps may override the **Default Keymap**, but are outside the first release scope.

## Example dialogue

> **Dev:** "Should users edit shortcuts in the first release?"
> **Domain expert:** "No. Ship a discoverable **Default Keymap** now, but model every shortcut as a **Keybinding** for an **App Action** so customization can be added later."

## Flagged ambiguities

- "keymaps/keybindings" was used broadly in issue 15. Resolved: the first release includes only a **Default Keymap** and no user-editable keybinding customization.
