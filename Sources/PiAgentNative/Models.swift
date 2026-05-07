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
    var timestamp: Date
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: ChatRole,
        title: String = "",
        text: String,
        thinking: String = "",
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.text = text
        self.thinking = thinking
        self.timestamp = timestamp
        self.isStreaming = isStreaming
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
}

struct EventLog: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String
    var timestamp: Date = Date()
}

struct ToolActivity: Identifiable, Equatable {
    let id: String
    var name: String
    var summary: String
    var output: String
    var isRunning: Bool
    var isError: Bool
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
    static let subscriptionProviders: [LoginProvider] = [
        LoginProvider(id: "anthropic", name: "Anthropic"),
        LoginProvider(id: "openai-codex", name: "ChatGPT / OpenAI Codex"),
        LoginProvider(id: "github-copilot", name: "GitHub Copilot")
    ]

    static let apiKeyProviders: [LoginProvider] = [
        LoginProvider(id: "anthropic", name: "Anthropic"),
        LoginProvider(id: "openai", name: "OpenAI"),
        LoginProvider(id: "google", name: "Google Gemini"),
        LoginProvider(id: "openrouter", name: "OpenRouter"),
        LoginProvider(id: "amazon-bedrock", name: "Amazon Bedrock"),
        LoginProvider(id: "azure-openai-responses", name: "Azure OpenAI Responses"),
        LoginProvider(id: "deepseek", name: "DeepSeek"),
        LoginProvider(id: "xai", name: "xAI"),
        LoginProvider(id: "groq", name: "Groq"),
        LoginProvider(id: "cerebras", name: "Cerebras"),
        LoginProvider(id: "mistral", name: "Mistral"),
        LoginProvider(id: "zai", name: "ZAI"),
        LoginProvider(id: "moonshotai", name: "Moonshot AI"),
        LoginProvider(id: "huggingface", name: "Hugging Face"),
        LoginProvider(id: "fireworks", name: "Fireworks"),
        LoginProvider(id: "vercel-ai-gateway", name: "Vercel AI Gateway"),
        LoginProvider(id: "cloudflare-ai-gateway", name: "Cloudflare AI Gateway"),
        LoginProvider(id: "cloudflare-workers-ai", name: "Cloudflare Workers AI"),
        LoginProvider(id: "opencode", name: "OpenCode Zen"),
        LoginProvider(id: "opencode-go", name: "OpenCode Go"),
        LoginProvider(id: "kimi-coding", name: "Kimi For Coding"),
        LoginProvider(id: "minimax", name: "MiniMax"),
        LoginProvider(id: "minimax-cn", name: "MiniMax (China)"),
        LoginProvider(id: "xiaomi", name: "Xiaomi MiMo"),
        LoginProvider(id: "xiaomi-token-plan-cn", name: "Xiaomi MiMo Token Plan (China)"),
        LoginProvider(id: "xiaomi-token-plan-ams", name: "Xiaomi MiMo Token Plan (Amsterdam)"),
        LoginProvider(id: "xiaomi-token-plan-sgp", name: "Xiaomi MiMo Token Plan (Singapore)")
    ]
}
