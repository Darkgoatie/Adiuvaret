import Foundation

/// The wire format a provider speaks.
public enum ProviderAPI: String, Sendable, Equatable {
    /// POST /chat/completions with Bearer authentication. Most providers use this.
    case openAICompatible
    /// POST /v1/messages with an x-api-key header.
    case anthropic
}

/// An online model provider the user can connect with their own API key. A chat with one of these models is sent to that provider.
public struct Provider: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let api: ProviderAPI
    public let host: String
    public let basePath: String
    /// Where the user creates a key.
    public let keyPage: URL
    /// A short hint of what the key looks like, shown as the field's placeholder. Never used to accept or reject a key.
    public let keyHint: String
    /// Models offered before the live list is fetched, newest first.
    public let suggestedModels: [String]
    public let note: String

    public init(id: String, name: String, api: ProviderAPI, host: String, basePath: String, keyPage: String, keyHint: String, suggestedModels: [String], note: String = "") {
        self.id = id; self.name = name; self.api = api; self.host = host; self.basePath = basePath
        self.keyPage = URL(string: keyPage)!; self.keyHint = keyHint; self.suggestedModels = suggestedModels; self.note = note
    }
}

public enum Providers {
    public static let all: [Provider] = [
        Provider(id: "openai", name: "OpenAI (ChatGPT)", api: .openAICompatible, host: "api.openai.com", basePath: "/v1",
                 keyPage: "https://platform.openai.com/api-keys", keyHint: "sk-…", suggestedModels: ["gpt-4.1", "gpt-4.1-mini", "gpt-4o"],
                 note: "A ChatGPT subscription does not include API use. API use is billed separately."),
        Provider(id: "anthropic", name: "Anthropic (Claude)", api: .anthropic, host: "api.anthropic.com", basePath: "/v1",
                 keyPage: "https://platform.claude.com/settings/keys", keyHint: "sk-ant-…", suggestedModels: ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-opus-4-5"],
                 note: "A Claude subscription does not include API use. API use is billed separately."),
        Provider(id: "google", name: "Google (Gemini)", api: .openAICompatible, host: "generativelanguage.googleapis.com", basePath: "/v1beta/openai",
                 keyPage: "https://aistudio.google.com/api-keys", keyHint: "AIza…", suggestedModels: ["gemini-2.5-flash", "gemini-2.5-pro"],
                 note: "Google AI Studio has a free tier."),
        Provider(id: "zai", name: "Z.AI (GLM)", api: .openAICompatible, host: "api.z.ai", basePath: "/api/paas/v4",
                 keyPage: "https://z.ai/manage-apikey/apikey-list", keyHint: "Paste your key", suggestedModels: ["glm-4.6", "glm-4.5-air"]),
        Provider(id: "kimi", name: "Kimi (Moonshot)", api: .openAICompatible, host: "api.moonshot.ai", basePath: "/v1",
                 keyPage: "https://platform.kimi.ai/console/api-keys", keyHint: "sk-…", suggestedModels: ["kimi-k2-0905-preview", "kimi-k2-turbo-preview"]),
        Provider(id: "deepseek", name: "DeepSeek", api: .openAICompatible, host: "api.deepseek.com", basePath: "",
                 keyPage: "https://platform.deepseek.com/api_keys", keyHint: "sk-…", suggestedModels: ["deepseek-chat", "deepseek-reasoner"]),
        Provider(id: "mistral", name: "Mistral", api: .openAICompatible, host: "api.mistral.ai", basePath: "/v1",
                 keyPage: "https://console.mistral.ai/api-keys", keyHint: "Paste your key", suggestedModels: ["mistral-large-latest", "mistral-small-latest"]),
        Provider(id: "xai", name: "xAI (Grok)", api: .openAICompatible, host: "api.x.ai", basePath: "/v1",
                 keyPage: "https://console.x.ai", keyHint: "xai-…", suggestedModels: ["grok-4", "grok-3-mini"]),
        Provider(id: "openrouter", name: "OpenRouter", api: .openAICompatible, host: "openrouter.ai", basePath: "/api/v1",
                 keyPage: "https://openrouter.ai/settings/keys", keyHint: "sk-or-…", suggestedModels: ["openai/gpt-4.1-mini", "anthropic/claude-sonnet-4.5"],
                 note: "One key for hundreds of models from many labs."),
        Provider(id: "groq", name: "Groq", api: .openAICompatible, host: "api.groq.com", basePath: "/openai/v1",
                 keyPage: "https://console.groq.com/keys", keyHint: "gsk_…", suggestedModels: ["llama-3.3-70b-versatile", "openai/gpt-oss-20b"],
                 note: "Very fast open models. Has a free tier.")
    ]

    public static func provider(_ id: String) -> Provider? { all.first { $0.id == id } }

    /// The id of one model of one provider, used to pick it in chat: "provider:model".
    public static func modelID(provider: String, model: String) -> String { "\(provider):\(model)" }

    public static func parseModelID(_ id: String) -> (provider: Provider, model: String)? {
        guard let colon = id.firstIndex(of: ":") else { return nil }
        let pid = String(id[..<colon]); let model = String(id[id.index(after: colon)...])
        guard let p = provider(pid), !model.isEmpty, model.count <= 120 else { return nil }
        return (p, model)
    }

    public static func isAllowed(_ url: URL, for provider: Provider) -> Bool {
        url.scheme == "https" && url.host?.lowercased() == provider.host && url.port == nil && url.user == nil && url.password == nil
    }
}

/// What a pasted key may look like. It only rejects text that cannot be a key; whether it works is checked by the provider.
public enum APIKey {
    public static func clean(_ pasted: String) -> String {
        var t = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["bearer ", "authorization: bearer ", "x-api-key:", "x-api-key: "] where t.lowercased().hasPrefix(prefix) { t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
        if t.count >= 2, let f = t.first, let l = t.last, (f == "\"" && l == "\"") || (f == "'" && l == "'") { t = String(t.dropFirst().dropLast()) }
        return t
    }

    public static func isPlausible(_ key: String) -> Bool {
        (12...400).contains(key.count) && key.unicodeScalars.allSatisfy { $0.isASCII && !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0) }
    }

    /// Keeps the first and last characters for display, never the whole key.
    public static func masked(_ key: String) -> String {
        guard key.count > 10 else { return "••••" }
        return String(key.prefix(4)) + "••••" + String(key.suffix(4))
    }
}
