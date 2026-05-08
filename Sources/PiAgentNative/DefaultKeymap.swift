import AppKit
import SwiftUI

public enum AppActionID: String, CaseIterable {
    case newChat
    case openProject
    case openCommandPalette
    case focusComposer
    case refreshState
    case openSettings
    case openProcessLog
    case openKeybindingHelp
    case toggleSidebar
    case toggleInspector
    case sendPrompt
    case stopGeneration
    case insertComposerNewline
    case cycleThinkingLevel
    case closeActiveModal
}

public enum KeybindingScope: String, CaseIterable {
    case appWide = "App-wide"
    case focused = "Focused"
    case chat = "Chat"
    case composer = "Composer"
    case navigation = "Navigation"

    func overlaps(_ other: KeybindingScope) -> Bool {
        if self == .appWide || other == .appWide {
            return true
        }

        if self == other {
            return true
        }

        if self == .focused || other == .focused {
            return true
        }

        return false
    }
}

public enum KeybindingHelpGroup: String, CaseIterable {
    case shell = "Shell"
    case chat = "Chat"
    case composer = "Composer"
    case navigation = "Navigation"

    func localizedTitle(l10n: L10n) -> String {
        switch self {
        case .shell:
            return l10n.string("keybinding.help_group.shell")
        case .chat:
            return l10n.string("keybinding.help_group.chat")
        case .composer:
            return l10n.string("keybinding.help_group.composer")
        case .navigation:
            return l10n.string("keybinding.help_group.navigation")
        }
    }
}

public enum KeybindingKey: Equatable {
    case character(String)
    case returnKey
    case escape
    case tab

    public var displayName: String {
        switch self {
        case let .character(value):
            return value.uppercased()
        case .returnKey:
            return "Return"
        case .escape:
            return "Escape"
        case .tab:
            return "Tab"
        }
    }

    public var keyEquivalent: KeyEquivalent {
        switch self {
        case let .character(value):
            return KeyEquivalent(Character(value))
        case .returnKey:
            return .return
        case .escape:
            return .escape
        case .tab:
            return .tab
        }
    }

    public func matches(_ event: NSEvent) -> Bool {
        switch self {
        case let .character(value):
            return event.charactersIgnoringModifiers?.lowercased() == value.lowercased()
        case .returnKey:
            return event.keyCode == 36 || event.keyCode == 76
        case .escape:
            return event.keyCode == 53
        case .tab:
            return event.keyCode == 48
        }
    }
}

public struct KeybindingDefinition: Identifiable, Equatable {
    public let actionID: AppActionID
    public let title: String
    public let key: KeybindingKey
    public let modifiers: EventModifiers
    public let scope: KeybindingScope
    public let helpGroup: KeybindingHelpGroup

    public var id: String {
        "\(actionID.rawValue)-\(scope.rawValue)-\(displayLabel)"
    }

    public var displayLabel: String {
        let modifierLabels = [
            modifiers.contains(.command) ? "Command" : nil,
            modifiers.contains(.control) ? "Control" : nil,
            modifiers.contains(.option) ? "Option" : nil,
            modifiers.contains(.shift) ? "Shift" : nil
        ].compactMap { $0 }

        return (modifierLabels + [key.displayName]).joined(separator: "-")
    }

    public func localizedTitle(l10n: L10n) -> String {
        actionID.localizedTitle(l10n: l10n)
    }

    public var eventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    public func matches(_ event: NSEvent) -> Bool {
        key.matches(event) && event.normalizedKeybindingModifiers == eventModifierFlags
    }
}

public enum KeybindingConflict: Equatable {
    case duplicate(KeybindingDefinition, KeybindingDefinition)
}

public enum DefaultKeymap {
    public static let definitions: [KeybindingDefinition] = [
        KeybindingDefinition(actionID: .newChat, title: "New chat", key: .character("n"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .openProject, title: "Open project", key: .character("o"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .openCommandPalette, title: "Open Command Palette", key: .character("k"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .focusComposer, title: "Focus composer", key: .character("l"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .refreshState, title: "Refresh state", key: .character("r"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .openSettings, title: "Open settings", key: .character(","), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .openProcessLog, title: "Open process log", key: .character("l"), modifiers: [.command, .shift], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .openKeybindingHelp, title: "Open Keyboard Shortcuts", key: .character("/"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .toggleSidebar, title: "Toggle sidebar", key: .character("b"), modifiers: [.command], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .toggleInspector, title: "Toggle inspector", key: .character("b"), modifiers: [.command, .shift], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .sendPrompt, title: "Send prompt", key: .returnKey, modifiers: [.command], scope: .focused, helpGroup: .chat),
        KeybindingDefinition(actionID: .stopGeneration, title: "Stop generation", key: .escape, modifiers: [], scope: .chat, helpGroup: .chat),
        KeybindingDefinition(actionID: .sendPrompt, title: "Send prompt", key: .returnKey, modifiers: [], scope: .focused, helpGroup: .composer),
        KeybindingDefinition(actionID: .insertComposerNewline, title: "Insert newline", key: .returnKey, modifiers: [.shift], scope: .focused, helpGroup: .composer),
        KeybindingDefinition(actionID: .cycleThinkingLevel, title: "Cycle thinking level", key: .tab, modifiers: [.shift], scope: .focused, helpGroup: .composer),
        KeybindingDefinition(actionID: .closeActiveModal, title: "Close active modal", key: .escape, modifiers: [], scope: .focused, helpGroup: .navigation)
    ]

    public static func firstDefinition(for actionID: AppActionID) -> KeybindingDefinition? {
        definitions.first { $0.actionID == actionID }
    }

    public static func definitions(for actionID: AppActionID) -> [KeybindingDefinition] {
        definitions.filter { $0.actionID == actionID }
    }

    public static func definitions(in group: KeybindingHelpGroup) -> [KeybindingDefinition] {
        definitions.filter { $0.helpGroup == group }
    }

    public static func displayLabel(for actionID: AppActionID) -> String? {
        firstDefinition(for: actionID)?.displayLabel
    }

    public static func appWideDefinition(matching event: NSEvent) -> KeybindingDefinition? {
        definitions.first { $0.scope == .appWide && $0.matches(event) }
    }

    public static func title(for actionID: AppActionID) -> String? {
        firstDefinition(for: actionID)?.title
    }

    public static func title(for actionID: AppActionID, l10n: L10n) -> String? {
        guard firstDefinition(for: actionID) != nil else { return nil }
        return actionID.localizedTitle(l10n: l10n)
    }

    public static func helpText(for actionID: AppActionID, title: String? = nil, l10n: L10n? = nil) -> String? {
        guard let definition = firstDefinition(for: actionID) else { return nil }
        let displayTitle = title ?? l10n.map { definition.localizedTitle(l10n: $0) } ?? definition.title
        return "\(displayTitle) - \(definition.displayLabel)"
    }

    public static func conflicts(in definitions: [KeybindingDefinition] = definitions) -> [KeybindingConflict] {
        var conflicts: [KeybindingConflict] = []

        for lhsIndex in definitions.indices {
            for rhsIndex in definitions.index(after: lhsIndex)..<definitions.endIndex {
                let lhs = definitions[lhsIndex]
                let rhs = definitions[rhsIndex]
                guard lhs.key == rhs.key, lhs.modifiers == rhs.modifiers else { continue }
                guard !isAllowedPriorityPair(lhs, rhs) else { continue }
                if lhs.scope.overlaps(rhs.scope) {
                    conflicts.append(.duplicate(lhs, rhs))
                }
            }
        }

        return conflicts
    }

    private static func isAllowedPriorityPair(_ lhs: KeybindingDefinition, _ rhs: KeybindingDefinition) -> Bool {
        let actionIDs = Set([lhs.actionID, rhs.actionID])
        let scopes = Set([lhs.scope, rhs.scope])
        return actionIDs == Set([.closeActiveModal, .stopGeneration]) &&
            scopes == Set([.focused, .chat])
    }
}

extension AppActionID {
    func localizedTitle(l10n: L10n) -> String {
        l10n.string(localizationKey)
    }

    private var localizationKey: String {
        switch self {
        case .newChat:
            return "app_action.new_chat.title"
        case .openProject:
            return "app_action.open_project.title"
        case .openCommandPalette:
            return "app_action.open_command_palette.title"
        case .focusComposer:
            return "app_action.focus_composer.title"
        case .refreshState:
            return "app_action.refresh_state.title"
        case .openSettings:
            return "app_action.open_settings.title"
        case .openProcessLog:
            return "app_action.open_process_log.title"
        case .openKeybindingHelp:
            return "app_action.open_keybinding_help.title"
        case .toggleSidebar:
            return "app_action.toggle_sidebar.title"
        case .toggleInspector:
            return "app_action.toggle_inspector.title"
        case .sendPrompt:
            return "app_action.send_prompt.title"
        case .stopGeneration:
            return "app_action.stop_generation.title"
        case .insertComposerNewline:
            return "app_action.insert_composer_newline.title"
        case .cycleThinkingLevel:
            return "app_action.cycle_thinking_level.title"
        case .closeActiveModal:
            return "app_action.close_active_modal.title"
        }
    }
}

extension NSEvent {
    var normalizedKeybindingModifiers: NSEvent.ModifierFlags {
        modifierFlags.intersection([.command, .control, .option, .shift])
    }
}

extension View {
    @ViewBuilder
    public func keybindingShortcut(_ actionID: AppActionID) -> some View {
        if let definition = DefaultKeymap.firstDefinition(for: actionID) {
            keyboardShortcut(definition.key.keyEquivalent, modifiers: definition.modifiers)
        } else {
            self
        }
    }
}
