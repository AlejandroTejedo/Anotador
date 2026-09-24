import Foundation
import Testing
@testable import Anotador

struct MeetingMarkdownTests {
    @Test func includesTitleDateAndNotes() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let markdown = MeetingMarkdown.export(
            title: "Sync de producto",
            createdAt: date,
            duration: 125,
            notes: "Revisar API",
            document: nil,
            lines: [
                TranscriptLine(lane: .you, text: "Empezamos", startedAt: 3)
            ]
        )
        #expect(markdown.contains("# Sync de producto"))
        #expect(markdown.contains("Duración: 02:05"))
        #expect(markdown.contains("## Notas durante la reunión"))
        #expect(markdown.contains("Revisar API"))
        #expect(markdown.contains("[00:03] **Tú:** Empezamos"))
    }

    @Test func skipsEmptyOptionalSections() {
        let markdown = MeetingMarkdown.export(
            title: "Vacía",
            createdAt: .now,
            duration: 0,
            notes: "   ",
            document: nil,
            lines: []
        )
        #expect(!markdown.contains("Duración:"))
        #expect(!markdown.contains("## Notas durante la reunión"))
        #expect(!markdown.contains("## Transcripción"))
    }

    @Test func rendersSummaryDocument() {
        let notes = MeetingNotes(
            title: "Kickoff",
            tldr: "Lanzamos el viernes.",
            summary: "Acordamos alcance.",
            keyPoints: [KeyPoint(point: "Fecha firme", timestamp: "04:10", quote: "el viernes")],
            decisions: ["Sin beta pública"],
            actionItems: [ActionItem(task: "Cerrar copy", owner: "Ana", due: "jueves")],
            openQuestions: ["¿Quién revisa legal?"],
            risks: ["Dependemos de diseño"],
            nextSteps: ["Standup mañana"],
            topics: ["Lanzamiento"]
        )
        let markdown = MeetingMarkdown.export(
            title: "Kickoff",
            createdAt: .now,
            duration: 60,
            notes: "",
            document: notes,
            lines: []
        )
        #expect(markdown.contains("Lanzamos el viernes."))
        #expect(markdown.contains("- Fecha firme (04:10)"))
        #expect(markdown.contains("> el viernes"))
        #expect(markdown.contains("- [ ] Cerrar copy — Ana · jueves"))
        #expect(markdown.contains("¿Quién revisa legal?"))
    }
}
