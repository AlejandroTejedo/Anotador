import Foundation
import Testing
@testable import Anotador

struct ProviderTests {
    @Test func everyProviderHasNameAndSensibleDefaults() {
        for provider in AIProvider.allCases {
            #expect(!provider.name.isEmpty)
            #expect(!provider.shortName.isEmpty)
            if provider.kind != .grokCLI {
                #expect(URL(string: provider.defaultBaseURL) != nil)
            }
        }
        #expect(AIProvider.openAI.requiresAPIKey)
        #expect(AIProvider.xAI.requiresAPIKey)
        #expect(AIProvider.anthropic.requiresAPIKey)
        #expect(!AIProvider.ollama.requiresAPIKey)
        #expect(AIProvider.ollama.isLocal && AIProvider.lmStudio.isLocal)
        #expect(!AIProvider.grokCLI.usesModel)
    }

    @Test func endpointTrimsTrailingSlashesAndFallsBackToDefault() {
        var config = ProviderConfig(provider: .lmStudio, model: "m", baseURL: "http://localhost:1234/v1///", apiKey: "")
        #expect(config.endpointBase?.absoluteString == "http://localhost:1234/v1")
        config.baseURL = "  "
        #expect(config.endpointBase?.absoluteString == AIProvider.lmStudio.defaultBaseURL)
        config.baseURL = "ftp://nope"
        #expect(config.endpointBase == nil)
    }

    @Test func validationCatchesMissingKeyAndModel() {
        let noKey = ProviderConfig(provider: .openAI, model: "gpt-5", baseURL: "", apiKey: "")
        #expect(throws: AnotadorError.missingAPIKey("ChatGPT")) { try LLMClient.validate(noKey) }

        let noModel = ProviderConfig(provider: .ollama, model: " ", baseURL: "", apiKey: "")
        #expect(throws: AnotadorError.missingModel("Ollama")) { try LLMClient.validate(noModel) }

        let local = ProviderConfig(provider: .ollama, model: "llama3.1", baseURL: "", apiKey: "")
        #expect(throws: Never.self) { try LLMClient.validate(local) }
    }

    @Test func strictSchemaRequiresEveryProperty() throws {
        let schema = NotesPrompt.strictSchema
        let required = try #require(schema["required"] as? [String])
        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(Set(required) == Set(properties.keys))

        for key in ["key_points", "action_items"] {
            let items = try #require((properties[key] as? [String: Any])?["items"] as? [String: Any])
            let itemRequired = try #require(items["required"] as? [String])
            let itemProps = try #require(items["properties"] as? [String: Any])
            #expect(Set(itemRequired) == Set(itemProps.keys))
            #expect(items["additionalProperties"] as? Bool == false)
        }
    }

    @Test func openAIBodyDegradesGracefully() {
        let strict = LLMClient.openAIChatBody(prompt: "p", model: "m", mode: .schema)
        let format = strict["response_format"] as? [String: Any]
        #expect(format?["type"] as? String == "json_schema")

        let loose = LLMClient.openAIChatBody(prompt: "p", model: "m", mode: .jsonObject)
        #expect((loose["response_format"] as? [String: Any])?["type"] as? String == "json_object")

        let plain = LLMClient.openAIChatBody(prompt: "p", model: "m", mode: .none)
        #expect(plain["response_format"] == nil)
        #expect((plain["messages"] as? [[String: String]])?.last?["content"] == "p")
    }

    @Test func anthropicBodyUsesOutputConfig() {
        let body = LLMClient.anthropicBody(prompt: "p", model: "claude-opus-5", structured: true)
        #expect(body["max_tokens"] as? Int == 16_000)
        let format = (body["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "json_schema")
        #expect(LLMClient.anthropicBody(prompt: "p", model: "m", structured: false)["output_config"] == nil)
    }

    @Test func ollamaContextGrowsWithTranscript() {
        #expect(LLMClient.ollamaContextSize(for: "corto") == 8_192)
        let hour = String(repeating: "a", count: 60_000)
        let size = LLMClient.ollamaContextSize(for: hour)
        #expect(size >= 60_000 / 3 + 4_096)
        #expect(size % 4_096 == 0)
        #expect(LLMClient.ollamaContextSize(for: String(repeating: "a", count: 2_000_000)) == 131_072)
    }

    @Test func httpFailuresMapToActionableMessages() {
        func failure(_ status: Int, _ message: String = "") -> LLMClient.HTTPFailure {
            .init(status: status, message: message, provider: .openAI, model: "gpt-x")
        }
        #expect(failure(401).errorDescription?.contains("API key") == true)
        #expect(failure(404).errorDescription?.contains("gpt-x") == true)
        #expect(failure(429).errorDescription?.contains("429") == true)
        #expect(failure(400, "Invalid response_format: json_schema").isFormatRejection)
        #expect(!failure(400, "context length exceeded").isFormatRejection)
        #expect(!failure(500, "json_schema").isFormatRejection)
    }

    @Test func extractsErrorMessagesFromCommonShapes() {
        #expect(LLMClient.errorMessage(from: ["error": ["message": "bad key"]]) == "bad key")
        #expect(LLMClient.errorMessage(from: ["error": "model not found"]) == "model not found")
        #expect(LLMClient.errorMessage(from: nil) == nil)
    }

    @Test func decodesNotesWithMissingSectionsAndNulls() throws {
        let partial = """
        Aquí tienes: {"title":"Sync","tldr":"OK","summary":"S","key_points":[{"point":"A","timestamp":null,"quote":null}],"action_items":[{"task":"enviar","owner":null,"due":null}]}
        """
        let notes = try NotesPrompt.decodePayload(partial, providerName: "Ollama")
        #expect(notes.title == "Sync")
        #expect(notes.decisions.isEmpty)
        #expect(notes.keyPoints.first?.quote == nil)
        #expect(notes.actionItems.first?.owner == nil)
    }

    @Test func rejectsEmptyNotes() {
        #expect(throws: AnotadorError.self) {
            try NotesPrompt.decodePayload("{}", providerName: "X")
        }
    }

    @Test func placeholderTitleDetection() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let meeting = Meeting.untitled(now: now, localeIdentifier: "es-ES", style: .auto)
        #expect(meeting.hasPlaceholderTitle)
        meeting.title = "Reunión con Ana"
        #expect(!meeting.hasPlaceholderTitle)
        meeting.title = "  "
        #expect(meeting.hasPlaceholderTitle)
    }

    @Test func exportFilenameIsFinderSafe() {
        let meeting = Meeting(title: "Q3 1/2: plan")
        #expect(meeting.exportFilename == "Q3 1-2- plan.md")
        meeting.title = ""
        #expect(meeting.exportFilename == "Reunión.md")
    }
}
