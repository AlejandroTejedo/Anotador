import Foundation

/// Where the meeting notes get written. Transcription is always on-device;
/// only the finished transcript text (plus the user's notes) goes to the provider.
enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case grokCLI
    case xAI
    case openAI
    case anthropic
    case ollama
    case lmStudio
    case openAICompatible

    var id: String { rawValue }

    var name: String {
        switch self {
        case .grokCLI: "Grok (suscripción, CLI)"
        case .xAI: "Grok (API de xAI)"
        case .openAI: "ChatGPT (API de OpenAI)"
        case .anthropic: "Claude (API de Anthropic)"
        case .ollama: "Ollama (local)"
        case .lmStudio: "LM Studio (local)"
        case .openAICompatible: "Otro compatible con OpenAI"
        }
    }

    /// Short label for status messages ("Grok está redactando…").
    var shortName: String {
        switch self {
        case .grokCLI, .xAI: "Grok"
        case .openAI: "ChatGPT"
        case .anthropic: "Claude"
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        case .openAICompatible: "El modelo"
        }
    }

    var kind: Kind {
        switch self {
        case .grokCLI: .grokCLI
        case .anthropic: .anthropic
        case .ollama: .ollama
        case .xAI, .openAI, .lmStudio, .openAICompatible: .openAICompatible
        }
    }

    enum Kind: Sendable {
        case grokCLI
        case openAICompatible
        case anthropic
        /// Native /api/chat so we can raise num_ctx; the OpenAI shim can't, and
        /// Ollama silently truncates long transcripts to its default window.
        case ollama
    }

    var isLocal: Bool {
        self == .ollama || self == .lmStudio
    }

    var requiresAPIKey: Bool {
        self == .xAI || self == .openAI || self == .anthropic
    }

    /// Custom servers may or may not need a key; local ones never do.
    var acceptsAPIKey: Bool {
        requiresAPIKey || self == .openAICompatible
    }

    var usesModel: Bool { self != .grokCLI }

    var editableBaseURL: Bool {
        self == .ollama || self == .lmStudio || self == .openAICompatible
    }

    var defaultBaseURL: String {
        switch self {
        case .grokCLI: ""
        case .xAI: "https://api.x.ai/v1"
        case .openAI: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .ollama: "http://localhost:11434"
        case .lmStudio: "http://localhost:1234/v1"
        case .openAICompatible: "http://localhost:8080/v1"
        }
    }

    /// Sensible starting point; the Settings screen can list what the account really has.
    var defaultModel: String {
        switch self {
        case .grokCLI: ""
        case .xAI: "grok-4"
        case .openAI: "gpt-5"
        case .anthropic: "claude-opus-5"
        case .ollama: "llama3.1"
        case .lmStudio: ""
        case .openAICompatible: ""
        }
    }

    var keyHelpURL: URL? {
        switch self {
        case .xAI: URL(string: "https://console.x.ai")
        case .openAI: URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        default: nil
        }
    }

    var privacyNote: String {
        switch self {
        case .grokCLI:
            "El texto de la transcripción va a xAI a través del CLI de Grok con tu suscripción."
        case .xAI, .openAI, .anthropic:
            "El texto de la transcripción va a \(shortName) con tu API key. Se factura por uso en tu cuenta."
        case .ollama, .lmStudio:
            "Todo se queda en este Mac: el modelo corre en local."
        case .openAICompatible:
            "El texto va al servidor que configures."
        }
    }
}

/// Everything a summarizer call needs, resolved once on the main actor.
struct ProviderConfig: Sendable, Equatable {
    var provider: AIProvider
    var model: String
    var baseURL: String
    var apiKey: String

    var trimmedModel: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }

    var endpointBase: URL? {
        var raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { raw = provider.defaultBaseURL }
        while raw.hasSuffix("/") { raw.removeLast() }
        guard let url = URL(string: raw), let scheme = url.scheme, scheme.hasPrefix("http") else { return nil }
        return url
    }
}

/// Persistence for provider choice. Non-secret values live in UserDefaults
/// (shared with @AppStorage); API keys live in the Keychain.
enum ProviderSettings {
    static let providerKey = "aiProvider"

    static func modelKey(_ provider: AIProvider) -> String { "aiModel.\(provider.rawValue)" }
    static func baseURLKey(_ provider: AIProvider) -> String { "aiBaseURL.\(provider.rawValue)" }
    static func keychainAccount(_ provider: AIProvider) -> String { "apikey.\(provider.rawValue)" }

    static func current(defaults: UserDefaults = .standard) -> ProviderConfig {
        config(for: currentProvider(defaults: defaults), defaults: defaults)
    }

    /// No Keychain access: safe to call from view bodies.
    static func currentProvider(defaults: UserDefaults = .standard) -> AIProvider {
        defaults.string(forKey: providerKey).flatMap(AIProvider.init(rawValue:)) ?? .grokCLI
    }

    static func config(for provider: AIProvider, defaults: UserDefaults = .standard) -> ProviderConfig {
        let model = defaults.string(forKey: modelKey(provider)) ?? provider.defaultModel
        let baseURL = defaults.string(forKey: baseURLKey(provider)) ?? provider.defaultBaseURL
        let key = provider.acceptsAPIKey ? (Keychain.read(account: keychainAccount(provider)) ?? envAPIKey(for: provider)) : ""
        return ProviderConfig(provider: provider, model: model, baseURL: baseURL, apiKey: key ?? "")
    }

    /// Lets developers run without touching the Keychain.
    static func envAPIKey(for provider: AIProvider) -> String? {
        let env = ProcessInfo.processInfo.environment
        let value: String? = switch provider {
        case .xAI: env["XAI_API_KEY"]
        case .openAI: env["OPENAI_API_KEY"]
        case .anthropic: env["ANTHROPIC_API_KEY"]
        default: nil
        }
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
