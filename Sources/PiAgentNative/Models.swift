import Foundation
import SwiftUI

enum ChatRole: String {
    case user
    case assistant
    case system
    case tool
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: ChatRole
    var title: String
    var text: String
    var thinking: String
    var contentBlocks: [MessageContentBlock]
    var timestamp: Date
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: ChatRole,
        title: String = "",
        text: String,
        thinking: String = "",
        contentBlocks: [MessageContentBlock]? = nil,
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.text = text
        self.thinking = thinking
        self.contentBlocks = contentBlocks ?? Self.blocks(text: text, thinking: thinking)
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    mutating func appendText(_ delta: String) {
        guard !delta.isEmpty else { return }
        text += delta
        appendOrMerge(.text(delta))
    }

    mutating func appendThinking(_ delta: String) {
        guard !delta.isEmpty else { return }
        thinking += delta
        appendOrMerge(.thinking(delta))
    }

    mutating func replaceText(_ replacement: String, blocks: [MessageContentBlock]? = nil) {
        text = replacement
        contentBlocks = blocks ?? Self.blocks(text: replacement, thinking: thinking)
    }

    mutating func appendToolCall(_ call: ToolCallPresentation) {
        contentBlocks.append(.toolCall(call))
    }

    mutating func appendToolResult(_ result: ToolResultPresentation) {
        contentBlocks.append(.toolResult(result))
    }

    private mutating func appendOrMerge(_ block: MessageContentBlock) {
        switch (contentBlocks.last, block) {
        case (.text(let existing), .text(let delta)):
            contentBlocks[contentBlocks.count - 1] = .text(existing + delta)
        case (.thinking(let existing), .thinking(let delta)):
            contentBlocks[contentBlocks.count - 1] = .thinking(existing + delta)
        default:
            contentBlocks.append(block)
        }
    }

    private static func blocks(text: String, thinking: String) -> [MessageContentBlock] {
        var blocks: [MessageContentBlock] = []
        if !thinking.isEmpty {
            blocks.append(.thinking(thinking))
        }
        if !text.isEmpty {
            blocks.append(.text(text))
        }
        return blocks
    }
}

struct ProjectItem: Identifiable, Equatable, Codable {
    var id = UUID().uuidString
    var name: String
    var path: String
}

struct StoredSession: Identifiable, Equatable, Codable {
    var id: String
    var projectPath: String
    var projectName: String
    var title: String
    var status: String
    var sessionFile: String
    var updatedAt: Date
}

struct GitBranchDetails: Equatable {
    var branch: String = "Not a git repository"
    var hasChanges: Bool = false
    var changeSummary: String = "No changes"
    var changedFileCount: Int? = nil
}

enum QueuedWorkKind: String, Equatable {
    case steering
    case followUp

    var title: String {
        switch self {
        case .steering:
            return "Steering"
        case .followUp:
            return "Follow-up"
        }
    }

    func title(l10n: L10n) -> String {
        switch self {
        case .steering:
            return l10n.string("inspector.queued_work.kind.steering")
        case .followUp:
            return l10n.string("inspector.queued_work.kind.follow_up")
        }
    }
}

struct QueuedWorkEntry: Identifiable, Equatable {
    var id: String
    var kind: QueuedWorkKind
    var text: String
    var position: Int

    init(kind: QueuedWorkKind, text: String, position: Int) {
        self.id = "\(kind.rawValue)-\(position)"
        self.kind = kind
        self.text = text
        self.position = position
    }

    var title: String {
        kind.title
    }

    func title(l10n: L10n) -> String {
        kind.title(l10n: l10n)
    }

    var summary: String {
        Self.normalizedSummary(for: text)
    }

    func summary(l10n: L10n) -> String {
        let normalized = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? l10n.string("inspector.queued_work.empty_message") : normalized
    }

    func summary(maxLength: Int) -> String {
        let normalized = summary
        guard maxLength > 3, normalized.count > maxLength else {
            return normalized
        }
        return String(normalized.prefix(maxLength - 2)) + "..."
    }

    func summary(maxLength: Int, l10n: L10n) -> String {
        let normalized = summary(l10n: l10n)
        guard maxLength > 3, normalized.count > maxLength else {
            return normalized
        }
        return String(normalized.prefix(maxLength - 2)) + "..."
    }

    static func normalizedSummary(for text: String) -> String {
        let normalized = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? "Empty queued message" : normalized
    }
}

enum QueuedWorkDisplayState: Equatable {
    case empty
    case countOnly(Int)
    case entries([QueuedWorkEntry])
}

struct EventLog: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String
    var timestamp: Date = Date()
}

enum ToolActivityStatus: String, Codable, Equatable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled

    var isRunning: Bool {
        self == .queued || self == .running
    }

    var isError: Bool {
        self == .failed || self == .cancelled
    }
}

struct ToolActivity: Identifiable, Equatable {
    let id: String
    var toolCallId: String
    var name: String
    var summary: String
    var output: String
    var stdout: String
    var stderr: String
    var result: String
    var status: ToolActivityStatus
    var isRunning: Bool
    var isError: Bool

    init(
        id: String,
        toolCallId: String? = nil,
        name: String,
        summary: String,
        output: String,
        stdout: String = "",
        stderr: String = "",
        result: String = "",
        status: ToolActivityStatus? = nil,
        isRunning: Bool,
        isError: Bool
    ) {
        self.id = id
        self.toolCallId = toolCallId ?? id
        self.name = name
        self.summary = summary
        self.output = output
        self.stdout = stdout
        self.stderr = stderr
        self.result = result
        self.status = status ?? (isRunning ? .running : (isError ? .failed : .succeeded))
        self.isRunning = isRunning
        self.isError = isError
    }

    mutating func updateStatus(_ status: ToolActivityStatus) {
        self.status = status
        isRunning = status.isRunning
        isError = status.isError
    }
}

struct PiModel: Identifiable, Equatable {
    var provider: String
    var modelId: String
    var name: String

    var id: String {
        "\(provider)/\(modelId)"
    }

    var displayName: String {
        name.isEmpty || name == modelId ? modelId : name
    }
}

enum AppThemeFamily: String, CaseIterable, Identifiable {
    case nord
    case dracula
    case catppuccin
    case one
    case nightOwl

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nord: return "Nord"
        case .dracula: return "Dracula"
        case .catppuccin: return "Catppuccin"
        case .one: return "One"
        case .nightOwl: return "Night Owl"
        }
    }
}

enum AppThemeVariant: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
}

struct LoginProvider: Identifiable, Equatable, Hashable {
    var id: String
    var name: String
}

extension LoginProvider {
    static let subscriptionProviders = LoginProviderCatalog.subscriptionProviders
    static let apiKeyProviders = LoginProviderCatalog.apiKeyProviders
}
