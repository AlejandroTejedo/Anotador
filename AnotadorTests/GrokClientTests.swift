import Foundation
import Testing
@testable import Anotador

struct GrokClientTests {
    @Test func formatsTranscriptForTheModel() {
        let lines = [
            TranscriptLine(lane: .you, text: "Hola", startedAt: 1),
            TranscriptLine(lane: .others, text: "Listos", startedAt: 8)
        ]
        #expect(
            NotesPrompt.formattedTranscript(lines)
            == "[00:01] Tú: Hola\n[00:08] Participantes: Listos"
        )
    }

    @Test func refusesShortTranscripts() {
        #expect(!NotesPrompt.canSummarize("corto"))
        #expect(NotesPrompt.canSummarize(String(repeating: "a", count: 80)))
    }

    @Test func detectsAuthFailures() {
        #expect(GrokClient.isAuthFailure(stdout: "please login", stderr: ""))
        #expect(GrokClient.isAuthFailure(stdout: "", stderr: "Auth expired"))
        #expect(!GrokClient.isAuthFailure(stdout: "ok", stderr: ""))
        // Transcript words like "author" or "blogin" must not look like auth errors.
        #expect(!GrokClient.isAuthFailure(stdout: "", stderr: "the author of the plugin crashed"))
    }

    @Test func mapsMaxTurnsToARetryableMessage() {
        let message = GrokClient.failureMessage(stdout: "", stderr: "Error: max turns reached")
        #expect(GrokClient.isMaxTurnsFailure("max turns reached"))
        #expect(message.contains("Reintentar"))
        #expect(!message.localizedCaseInsensitiveContains("max turns reached"))
    }

    @Test func keepsEnoughTurnsForAFullSummary() {
        let args = GrokClient.arguments(promptPath: "/tmp/p.md", workDir: "/tmp/w")
        #expect(args.contains("--max-turns"))
        let turns = args[args.firstIndex(of: "--max-turns")! + 1]
        #expect(Int(turns)! >= 8)
        #expect(args.contains("--verbatim"))
        #expect(args.contains("--no-subagents"))
    }

    @Test func decodesEnvelopeAndFencedJSON() throws {
        let inner = """
        {"title":"Sync","tldr":"OK","summary":"Resumen","key_points":[{"point":"A","timestamp":"01:00","quote":"cita"}],"decisions":["seguir"],"action_items":[{"task":"enviar","owner":"Luis","due":"hoy"}],"open_questions":[],"risks":[],"next_steps":[],"topics":["api"]}
        """
        struct Envelope: Encodable { var text: String }
        let envelope = String(data: try JSONEncoder().encode(Envelope(text: inner)), encoding: .utf8)!
        let fromEnvelope = try GrokClient.decodeNotes(from: envelope)
        #expect(fromEnvelope.title == "Sync")
        #expect(fromEnvelope.actionItems.first?.owner == "Luis")

        let fenced = "```json\n\(inner)\n```"
        let fromFence = try GrokClient.decodeNotes(from: fenced)
        #expect(fromFence.keyPoints.first?.quote == "cita")

        let encoded = try JSONEncoder().encode(fromFence)
        let roundTrip = try JSONDecoder().decode(MeetingNotes.self, from: encoded)
        #expect(roundTrip.keyPoints.first?.id == fromFence.keyPoints.first?.id)
    }

    @Test func rejectsGarbage() {
        #expect(throws: AnotadorError.self) {
            try GrokClient.decodeNotes(from: "esto no es json")
        }
    }

    @Test func promptIncludesNotesAndCustomInstructions() {
        let prompt = NotesPrompt.buildPrompt(
            transcript: "[00:01] Tú: hola",
            notes: "Agenda: presupuesto",
            style: .sales,
            customInstructions: "Sé breve"
        )
        #expect(prompt.contains("Agenda: presupuesto"))
        #expect(prompt.contains("Sé breve"))
        #expect(prompt.contains("Ventas"))
        #expect(prompt.contains("[00:01] Tú: hola"))
    }

    @Test func promptMarksMissingNotes() {
        let prompt = NotesPrompt.buildPrompt(
            transcript: "x",
            notes: "  ",
            style: .auto,
            customInstructions: ""
        )
        #expect(prompt.contains("(sin notas manuales)"))
        #expect(!prompt.contains("Instrucciones extra"))
    }
}
