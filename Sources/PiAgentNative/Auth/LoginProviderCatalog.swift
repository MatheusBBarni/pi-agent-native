import Foundation

enum LoginProviderCatalog {
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

    static func displayName(forID providerID: String) -> String {
        (subscriptionProviders + apiKeyProviders).first { $0.id == providerID }?.name ?? providerID
    }
}
