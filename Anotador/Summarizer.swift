import Foundation

/// Single entry point for turning a transcript into `MeetingNotes`,
/// whatever provider the user picked.
enum Summarizer {
    static func summarize(
        transcript: [TranscriptLine],
        notes: String,
        style: SummaryStyle,
        customInstructions: String,
        config: ProviderConfig
    ) async throws -> MeetingNotes {
        let spoken = NotesPrompt.formattedTranscript(transcript)
        guard NotesPrompt.canSummarize(spoken) else { throw AnotadorError.noSpeech }

        let prompt = NotesPrompt.buildPrompt(
            transcript: spoken,
            notes: notes,
            style: style,
            customInstructions: customInstructions
        )

        switch config.provider.kind {
        case .grokCLI:
            return try await GrokClient.summarize(prompt: prompt)
        case .openAICompatible, .anthropic, .ollama:
            return try await LLMClient.summarize(prompt: prompt, config: config)
        }
    }

    /// Cheap readiness check for UI hints (no network).
    static func readinessProblem(for config: ProviderConfig) -> String? {
        switch config.provider.kind {
        case .grokCLI:
            return GrokClient.resolveBinary() == nil ? AnotadorError.grokMissing.errorDescription : nil
        case .openAICompatible, .anthropic, .ollama:
            do {
                try LLMClient.validate(config)
                return nil
            } catch {
                return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
