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
        KeybindingDefinition(actionID: .toggleSidebar, title: "Toggle sidebar", key: .character("s"), modifiers: [.command, .option], scope: .appWide, helpGroup: .shell),
        KeybindingDefinition(actionID: .toggleInspector, title: "Toggle inspector", key: .character("i"), modifiers: [.command, .option], scope: .appWide, helpGroup: .shell),
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

    public static func title(for actionID: AppActionID) -> String? {
        firstDefinition(for: actionID)?.title
    }

    public static func helpText(for actionID: AppActionID, title: String? = nil) -> String? {
        guard let definition = firstDefinition(for: actionID) else { return nil }
        return "\(title ?? definition.title) - \(definition.displayLabel)"
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
