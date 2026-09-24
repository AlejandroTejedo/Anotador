import AppKit
import SwiftUI
import Testing
@testable import Anotador

/// Regression: long AI-generated topics made FlowLayout report a huge ideal
/// width, which pushed the sidebar and notes inspector out of the window.
@MainActor
struct SummaryLayoutTests {
    private let longTopics = [
        "Migración del sistema de facturas (API, webhooks, conciliación manual)",
        "Plan de lanzamiento (beta, precios, canal de soporte)",
        "Cambios en el onboarding de nuevos clientes"
    ]

    private func size(_ view: some View, width: CGFloat) -> CGSize {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private var chips: some View {
        FlowLayout(spacing: 6) {
            ForEach(longTopics, id: \.self) { Text($0).padding(.horizontal, 10) }
        }
    }

    @Test func flowLayoutNeverExceedsProposedWidth() {
        for width in [120.0, 240, 400] {
            #expect(size(chips, width: width).width <= width + 0.5)
        }
    }

    @Test func flowLayoutWrapsInsteadOfWidening() {
        let narrow = size(chips, width: 240)
        let wide = size(chips, width: 2_000)
        #expect(narrow.height > wide.height)
    }

    @Test func summaryStaysNarrowWithLongContent() {
        let meeting = Meeting()
        meeting.notesDocument = MeetingNotes(
            tldr: String(repeating: "palabra ", count: 60),
            actionItems: [ActionItem(task: "tarea", owner: "Participante", due: "Antes del cierre del trimestre (sin fecha exacta)")],
            topics: longTopics
        )
        let minimum = size(SummaryView(meeting: meeting).frame(height: 800), width: 0).width
        #expect(minimum < 320)
    }
}
