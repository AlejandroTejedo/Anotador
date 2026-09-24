import Foundation

/// HTTP clients for API-key and local providers. Everything is plain
/// URLSession + JSONSerialization: no third-party dependencies.
enum LLMClient {
    static let requestTimeout: TimeInterval = 600
    static let systemPrompt = "Eres un anotador de reuniones meticuloso. Respondes solo con JSON válido."

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        return URLSession(configuration: config)
    }()

    // MARK: - Summaries

    @concurrent
    static func summarize(prompt: String, config: ProviderConfig) async throws -> MeetingNotes {
        try validate(config)
        let text: String = switch config.provider.kind {
        case .openAICompatible: try await openAIChat(prompt: prompt, config: config)
        case .anthropic: try await anthropicMessage(prompt: prompt, config: config)
        case .ollama: try await ollamaChat(prompt: prompt, config: config)
        case .grokCLI: throw AnotadorError.invalidEndpoint
        }
        return try NotesPrompt.decodePayload(text, providerName: config.provider.shortName)
    }

    static func validate(_ config: ProviderConfig) throws {
        if config.provider.requiresAPIKey, config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            throw AnotadorError.missingAPIKey(config.provider.shortName)
        }
        if config.provider.usesModel, config.trimmedModel.isEmpty {
            throw AnotadorError.missingModel(config.provider.shortName)
        }
        guard config.endpointBase != nil else { throw AnotadorError.invalidEndpoint }
    }

    /// Output format strategies, most to least strict. Servers that reject one
    /// (older local builds, some proxies) get the next.
    enum JSONMode: CaseIterable {
        case schema, jsonObject, none
    }

    static func openAIChatBody(prompt: String, model: String, mode: JSONMode) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]
        switch mode {
        case .schema:
            body["response_format"] = [
                "type": "json_schema",
                "json_schema": ["name": "meeting_notes", "strict": true, "schema": NotesPrompt.strictSchema]
            ]
        case .jsonObject:
            body["response_format"] = ["type": "json_object"]
        case .none:
            break
        }
        return body
    }

    private static func openAIChat(prompt: String, config: ProviderConfig) async throws -> String {
        let url = config.endpointBase!.appendingPathComponent("chat/completions")
        var lastError: Error?
        for mode in JSONMode.allCases {
            let body = openAIChatBody(prompt: prompt, model: config.trimmedModel, mode: mode)
            do {
                let json = try await post(url: url, body: body, headers: bearer(config), config: config)
                guard let choice = (json["choices"] as? [[String: Any]])?.first,
                      let message = choice["message"] as? [String: Any] else {
                    throw AnotadorError.summaryFailed(String(localized: "\(config.provider.shortName) devolvió una respuesta sin contenido."))
                }
                if let refusal = message["refusal"] as? String, !refusal.isEmpty {
                    throw AnotadorError.summaryFailed(String(localized: "\(config.provider.shortName) rechazó la petición: \(refusal)"))
                }
                if choice["finish_reason"] as? String == "length" {
                    throw AnotadorError.summaryFailed(String(localized: "La respuesta de \(config.provider.shortName) se cortó por longitud. Prueba un modelo con más contexto."))
                }
                return (message["content"] as? String) ?? ""
            } catch let error as HTTPFailure where error.isFormatRejection && mode != .none {
                lastError = error
                continue
            }
        }
        throw lastError ?? AnotadorError.summaryFailed(String(localized: "\(config.provider.shortName) no pudo redactar las notas."))
    }

    static func anthropicBody(prompt: String, model: String, structured: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16_000,
            "system": systemPrompt,
            "messages": [["role": "user", "content": prompt]]
        ]
        if structured {
            body["output_config"] = ["format": ["type": "json_schema", "schema": NotesPrompt.strictSchema]]
        }
        return body
    }

    private static func anthropicMessage(prompt: String, config: ProviderConfig) async throws -> String {
        let url = config.endpointBase!.appendingPathComponent("messages")
        let headers = [
            "x-api-key": config.apiKey,
            "anthropic-version": "2023-06-01"
        ]
        var lastError: Error?
        for structured in [true, false] {
            do {
                let json = try await post(
                    url: url,
                    body: anthropicBody(prompt: prompt, model: config.trimmedModel, structured: structured),
                    headers: headers,
                    config: config
                )
                switch json["stop_reason"] as? String {
                case "refusal":
                    throw AnotadorError.summaryFailed(String(localized: "Claude rechazó redactar estas notas."))
                case "max_tokens":
                    throw AnotadorError.summaryFailed(String(localized: "La respuesta de Claude se cortó por longitud. Pulsa Reintentar."))
                default:
                    break
                }
                let blocks = json["content"] as? [[String: Any]] ?? []
                return blocks
                    .filter { $0["type"] as? String == "text" }
                    .compactMap { $0["text"] as? String }
                    .joined()
            } catch let error as HTTPFailure where error.isFormatRejection && structured {
                lastError = error
                continue
            }
        }
        throw lastError ?? AnotadorError.summaryFailed(String(localized: "Claude no pudo redactar las notas."))
    }

    /// Rough token estimate (≈3 chars/token for Spanish) plus room for the answer.
    static func ollamaContextSize(for prompt: String) -> Int {
        let needed = prompt.count / 3 + 4_096
        let rounded = ((needed + 4_095) / 4_096) * 4_096
        return min(max(rounded, 8_192), 131_072)
    }

    private static func ollamaChat(prompt: String, config: ProviderConfig) async throws -> String {
        let url = config.endpointBase!.appendingPathComponent("api/chat")
        let body: [String: Any] = [
            "model": config.trimmedModel,
            "stream": false,
            "format": NotesPrompt.strictSchema,
            "options": ["num_ctx": ollamaContextSize(for: prompt), "temperature": 0.2],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]
        let json = try await post(url: url, body: body, headers: [:], config: config)
        guard let message = json["message"] as? [String: Any], let content = message["content"] as? String else {
            throw AnotadorError.summaryFailed(String(localized: "Ollama devolvió una respuesta sin contenido."))
        }
        return content
    }

    // MARK: - Model discovery

    @concurrent
    static func listModels(config: ProviderConfig) async throws -> [String] {
        guard let base = config.endpointBase else { throw AnotadorError.invalidEndpoint }
        if config.provider.requiresAPIKey, config.apiKey.isEmpty {
            throw AnotadorError.missingAPIKey(config.provider.shortName)
        }
        let json: [String: Any]
        switch config.provider.kind {
        case .grokCLI:
            return []
        case .ollama:
            json = try await get(url: base.appendingPathComponent("api/tags"), headers: [:], config: config)
            let models = json["models"] as? [[String: Any]] ?? []
            return models.compactMap { $0["name"] as? String }.sorted()
        case .anthropic:
            var url = URLComponents(url: base.appendingPathComponent("models"), resolvingAgainstBaseURL: false)!
            url.queryItems = [URLQueryItem(name: "limit", value: "100")]
            json = try await get(
                url: url.url!,
                headers: ["x-api-key": config.apiKey, "anthropic-version": "2023-06-01"],
                config: config
            )
        case .openAICompatible:
            json = try await get(url: base.appendingPathComponent("models"), headers: bearer(config), config: config)
        }
        let data = json["data"] as? [[String: Any]] ?? []
        return data.compactMap { $0["id"] as? String }.sorted()
    }

    // MARK: - HTTP

    struct HTTPFailure: LocalizedError {
        var status: Int
        var message: String
        var provider: AIProvider
        var model: String

        /// 400/422 complaining about the output format → worth retrying looser.
        var isFormatRejection: Bool {
            guard status == 400 || status == 422 else { return false }
            let text = message.lowercased()
            return ["response_format", "json_schema", "json_object", "output_config", "structured", "schema"]
                .contains { text.contains($0) }
        }

        var errorDescription: String? {
            let name = provider.shortName
            switch status {
            case 401, 403:
                return String(localized: "\(name) rechazó la API key (\(status)). Revísala en Ajustes → Modelo.")
            case 404:
                return String(localized: "\(name) no encuentra el modelo “\(model)”. Elige otro en Ajustes → Modelo.")
            case 429:
                return String(localized: "\(name) ha limitado las peticiones o no te queda saldo (429). Espera un poco o revisa tu cuenta.")
            case 500...599:
                return String(localized: "\(name) tiene problemas ahora mismo (\(status)). Pulsa Reintentar en un rato.")
            default:
                let detail = message.isEmpty ? "" : ": \(message.prefix(400))"
                return String(localized: "\(name) devolvió un error \(status)\(detail)")
            }
        }
    }

    private static func bearer(_ config: ProviderConfig) -> [String: String] {
        config.apiKey.isEmpty ? [:] : ["Authorization": "Bearer \(config.apiKey)"]
    }

    private static func post(url: URL, body: [String: Any], headers: [String: String], config: ProviderConfig) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await send(request, config: config)
    }

    private static func get(url: URL, headers: [String: String], config: ProviderConfig) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await send(request, config: config)
    }

    private static func send(_ request: URLRequest, config: ProviderConfig) async throws -> [String: Any] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AnotadorError.summaryFailed(connectionMessage(error, config: config))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(status) else {
            throw HTTPFailure(
                status: status,
                message: errorMessage(from: json) ?? String(decoding: data.prefix(400), as: UTF8.self),
                provider: config.provider,
                model: config.trimmedModel
            )
        }
        guard let json else {
            throw AnotadorError.summaryFailed(String(localized: "\(config.provider.shortName) devolvió algo que no es JSON."))
        }
        return json
    }

    static func errorMessage(from json: [String: Any]?) -> String? {
        guard let json else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let error = json["error"] as? String { return error }
        if let message = json["message"] as? String { return message }
        return nil
    }

    static func connectionMessage(_ error: URLError, config: ProviderConfig) -> String {
        let name = config.provider.shortName
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            if config.provider.isLocal {
                let address = config.endpointBase?.absoluteString ?? "localhost"
                return String(localized: "No puedo conectar con \(name) en \(address). ¿Está abierto y con el servidor activo?")
            }
            return String(localized: "No puedo conectar con \(name). Revisa la conexión o la URL.")
        case .notConnectedToInternet:
            return String(localized: "Sin conexión a internet. La transcripción está guardada; pulsa Reintentar cuando vuelva la red.")
        case .timedOut:
            return String(localized: "\(name) tardó demasiado en responder. Pulsa Reintentar.")
        case .appTransportSecurityRequiresSecureConnection:
            return String(localized: "macOS bloquea http:// a ese servidor. Usa https://, localhost o una IP.")
        default:
            return String(localized: "\(name): \(error.localizedDescription)")
        }
    }
}
