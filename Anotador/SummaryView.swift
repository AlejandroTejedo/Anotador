import SwiftUI

struct SummaryView: View {
    let meeting: Meeting

    var body: some View {
        if let notes = meeting.notesDocument {
            ScrollView {
                SummaryDocumentView(notes: notes)
                    .padding(24)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        } else if meeting.phase.isBusy {
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text("Ordenando lo que no puede quedar en el aire…")
            }
        } else if meeting.lines.isEmpty {
            ContentUnavailableView(
                "Todavía no hay resumen",
                systemImage: "text.page",
                description: Text("Transcribe o sube un audio para generar el resumen.")
            )
        } else {
            ContentUnavailableView(
                "Hay transcripción, pero todavía no hay notas",
                systemImage: "text.page",
                description: Text("Pulsa Regenerar para redactarlas.")
            )
        }
    }
}

private struct SummaryDocumentView: View {
    let notes: MeetingNotes

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SummarySection(title: "En una frase") {
                Text(notes.tldr)
                    .font(.title3)
                    .textSelection(.enabled)
            }

            SummarySection(title: "Resumen") {
                Text(notes.summary)
                    .textSelection(.enabled)
            }

            if !notes.keyPoints.isEmpty {
                SummarySection(title: "Puntos clave") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(notes.keyPoints) { point in
                            KeyPointRow(point: point)
                        }
                    }
                }
            }

            BulletList(title: "Decisiones", items: notes.decisions)
            ActionList(items: notes.actionItems)
            BulletList(title: "Preguntas abiertas", items: notes.openQuestions)
            BulletList(title: "Riesgos", items: notes.risks)
            BulletList(title: "Próximos pasos", items: notes.nextSteps)

            if !notes.topics.isEmpty {
                SummarySection(title: "Temas") {
                    Text(notes.topics.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SummarySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionEyebrow()
            content
        }
    }
}

private struct KeyPointRow: View {
    let point: KeyPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(point.point)
                    .textSelection(.enabled)
                Spacer()
                if let timestamp = point.timestamp, !timestamp.isEmpty {
                    Text(timestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let quote = point.quote, !quote.isEmpty {
                Text("“\(quote)”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BulletList: View {
    let title: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            SummarySection(title: title) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        BulletRow(text: item)
                    }
                }
            }
        }
    }
}

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .accessibilityHidden(true)
            Text(text)
                .textSelection(.enabled)
        }
    }
}

private struct ActionList: View {
    let items: [ActionItem]

    var body: some View {
        if !items.isEmpty {
            SummarySection(title: "Acciones") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        ActionRow(item: item)
                    }
                }
            }
        }
    }
}

private struct ActionRow: View {
    let item: ActionItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Palette.terracotta)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.task)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    if let owner = item.owner, !owner.isEmpty {
                        Text(owner)
                    }
                    if let due = item.due, !due.isEmpty {
                        Text(due)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = [item.task]
        if let owner = item.owner, !owner.isEmpty { parts.append(owner) }
        if let due = item.due, !due.isEmpty { parts.append(due) }
        return parts.joined(separator: ", ")
    }
}
