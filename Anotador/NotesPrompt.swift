import Foundation

/// Provider-independent pieces: prompt, output schema and tolerant decoding.
enum NotesPrompt {
    static let minimumSpokenCharacters = 80

    /// Strict-mode schema (OpenAI / xAI / Anthropic structured outputs): every
    /// property is required, optional values are nullable instead.
    static let strictSchemaJSON = """
    {"type":"object","additionalProperties":false,"required":["title","tldr","summary","key_points","decisions","action_items","open_questions","risks","next_steps","topics"],"properties":{"title":{"type":"string"},"tldr":{"type":"string"},"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["point","timestamp","quote"],"properties":{"point":{"type":"string"},"timestamp":{"type":["string","null"]},"quote":{"type":["string","null"]}}}},"decisions":{"type":"array","items":{"type":"string"}},"action_items":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["task","owner","due"],"properties":{"task":{"type":"string"},"owner":{"type":["string","null"]},"due":{"type":["string","null"]}}}},"open_questions":{"type":"array","items":{"type":"string"}},"risks":{"type":"array","items":{"type":"string"}},"next_steps":{"type":"array","items":{"type":"string"}},"topics":{"type":"array","items":{"type":"string"}}}}
    """

    static var strictSchema: [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(strictSchemaJSON.utf8))) as? [String: Any] ?? [:]
    }

    static func formattedTranscript(_ lines: [TranscriptLine]) -> String {
        lines
            .map { "[\($0.timestampLabel)] \($0.lane.name): \($0.text)" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canSummarize(_ spoken: String) -> Bool {
        spoken.count >= minimumSpokenCharacters
    }

    static func buildPrompt(
        transcript: String,
        notes: String,
        style: SummaryStyle,
        customInstructions: String
    ) -> String {
        let notesBlock = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "(sin notas manuales)"
            : notes
        let extra = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        Eres el anotador de reuniones de Anotador. Recibes una transcripción local y las notas que el usuario escribió durante la llamada.
        Redacta notas de reunión al nivel de Notion AI Meeting Notes, o mejor: no se puede escapar ningún detalle operativo.

        Reglas:
        - Escribe en el mismo idioma de la reunión.
        - No inventes nombres, cifras, fechas ni acuerdos.
        - Extrae TODOS los compromisos, decisiones, números, plazos y owners.
        - Cada punto clave debe citar un fragmento real (quote) y el timestamp si existe.
        - Distingue hechos, decisiones y opiniones.
        - Si algo quedó ambiguo, va a open_questions. Nunca lo completes tú.
        - Las notas manuales del usuario tienen prioridad como contexto.
        - Estilo de estructura: \(style.name). \(style.promptHint)
        \(extra.isEmpty ? "" : "- Instrucciones extra del usuario:\n\(extra)")

        Devuelve solo un objeto JSON con estas claves: title, tldr, summary, key_points (lista de {point, timestamp, quote}), decisions, action_items (lista de {task, owner, due}), open_questions, risks, next_steps, topics. Sin texto antes ni después.

        # Notas del usuario
        \(notesBlock)

        # Transcripción
        \(transcript)
        """
    }

    /// Accepts bare JSON, fenced JSON or JSON surrounded by prose.
    static func decodePayload(_ text: String, providerName: String) throws -> MeetingNotes {
        var payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.hasPrefix("```") {
            payload = payload
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = payload.firstIndex(of: "{"), let end = payload.lastIndex(of: "}"), start < end {
            payload = String(payload[start...end])
        }
        guard !payload.isEmpty, let data = payload.data(using: .utf8) else {
            throw AnotadorError.summaryFailed("\(providerName) devolvió una respuesta vacía.")
        }
        do {
            let notes = try JSONDecoder().decode(MeetingNotes.self, from: data)
            guard !notes.isEmpty else {
                throw AnotadorError.summaryFailed("\(providerName) devolvió unas notas vacías.")
            }
            return notes
        } catch let error as AnotadorError {
            throw error
        } catch {
            throw AnotadorError.summaryFailed("No pude leer las notas que devolvió \(providerName).")
        }
    }
}
