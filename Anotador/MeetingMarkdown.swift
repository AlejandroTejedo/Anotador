import Foundation

enum MeetingMarkdown {
    static func export(
        title: String,
        createdAt: Date,
        duration: TimeInterval,
        notes: String,
        document: MeetingNotes?,
        lines: [TranscriptLine]
    ) -> String {
        var parts: [String] = ["# \(title)", ""]
        parts.append("_\(createdAt.formatted(date: .long, time: .shortened))_")
        if duration > 0 {
            parts.append("Duración: \(TranscriptLine.clock(duration))")
        }
        parts.append("")

        if let document {
            append(document, to: &parts)
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append("## Notas durante la reunión")
            parts.append(trimmedNotes)
            parts.append("")
        }

        if !lines.isEmpty {
            parts.append("## Transcripción")
            parts.append(contentsOf: lines.map(\.markdownLine))
        }

        return parts.joined(separator: "\n")
    }

    private static func append(_ document: MeetingNotes, to parts: inout [String]) {
        parts.append("## En una frase")
        parts.append(document.tldr)
        parts.append("")
        parts.append("## Resumen")
        parts.append(document.summary)
        parts.append("")

        if !document.keyPoints.isEmpty {
            parts.append("## Puntos clave")
            for point in document.keyPoints {
                var line = "- \(point.point)"
                if let timestamp = point.timestamp, !timestamp.isEmpty {
                    line += " (\(timestamp))"
                }
                parts.append(line)
                if let quote = point.quote, !quote.isEmpty {
                    parts.append("  > \(quote)")
                }
            }
            parts.append("")
        }

        appendBullets("Decisiones", document.decisions, to: &parts)
        if !document.actionItems.isEmpty {
            parts.append("## Acciones")
            parts.append(contentsOf: document.actionItems.map(\.markdownLine))
            parts.append("")
        }
        appendBullets("Preguntas abiertas", document.openQuestions, to: &parts)
        appendBullets("Riesgos", document.risks, to: &parts)
        appendBullets("Próximos pasos", document.nextSteps, to: &parts)
    }

    private static func appendBullets(_ title: String, _ items: [String], to parts: inout [String]) {
        guard !items.isEmpty else { return }
        parts.append("## \(title)")
        items.forEach { parts.append("- \($0)") }
        parts.append("")
    }
}

extension TranscriptLine {
    var markdownLine: String {
        "[\(timestampLabel)] **\(lane.name):** \(text)"
    }
}

extension ActionItem {
    var markdownLine: String {
        var line = "- \(task)"
        if let owner, !owner.isEmpty { line += " — \(owner)" }
        if let due, !due.isEmpty { line += " · \(due)" }
        return line
    }
}

extension Meeting {
    /// Finder-safe: no slashes or colons from titles like "Q3 1/2: plan".
    var exportFilename: String {
        let cleaned = title
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "Reunión" : cleaned) + ".md"
    }

    func markdownExport() -> String {
        MeetingMarkdown.export(
            title: title,
            createdAt: createdAt,
            duration: duration,
            notes: notes,
            document: notesDocument,
            lines: lines
        )
    }
}
