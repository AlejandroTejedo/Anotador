import SwiftUI

struct SummaryView: View {
    let meeting: Meeting
    var onJump: (TimeInterval) -> Void = { _ in }

    var body: some View {
        if let notes = meeting.notesDocument {
            ScrollView {
                SummaryDocumentView(
                    notes: notes,
                    onToggle: toggle,
                    onJump: onJump
                )
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        } else if meeting.phase.isBusy {
            ContentUnavailableView {
                ProgressView()
                    .controlSize(.large)
            } description: {
                Text("Ordenando lo que no puede quedar en el aire…")
            }
        } else if meeting.lines.isEmpty {
            ContentUnavailableView(
                "Todavía no hay resumen",
                systemImage: "text.page",
                description: Text("Pulsa Transcribir durante la reunión o sube un audio.")
            )
        } else {
            ContentUnavailableView(
                "Hay transcripción, pero todavía no hay notas",
                systemImage: "text.page",
                description: Text("Pulsa Regenerar para redactarlas.")
            )
        }
    }

    private func toggle(_ item: ActionItem) {
        guard var notes = meeting.notesDocument,
              let index = notes.actionItems.firstIndex(where: { $0.id == item.id }) else { return }
        notes.actionItems[index].done.toggle()
        meeting.notesDocument = notes
    }
}

private struct SummaryDocumentView: View {
    let notes: MeetingNotes
    var onToggle: (ActionItem) -> Void
    var onJump: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                TLDRCard(text: notes.tldr)
                StatsStrip(notes: notes)
            }

            if !notes.actionItems.isEmpty {
                ActionList(items: notes.actionItems, onToggle: onToggle)
            }

            IconList(
                title: "Decisiones",
                systemImage: "checkmark.seal.fill",
                tint: Palette.success,
                items: notes.decisions
            )

            if !notes.summary.isEmpty {
                SummarySection(title: "Resumen") {
                    Text(notes.summary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }

            if !notes.keyPoints.isEmpty {
                SummarySection(title: "Puntos clave") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(notes.keyPoints) { point in
                            KeyPointRow(point: point, onJump: onJump)
                        }
                    }
                }
            }

            IconList(
                title: "Preguntas abiertas",
                systemImage: "questionmark.circle.fill",
                tint: Palette.question,
                items: notes.openQuestions
            )
            IconList(
                title: "Riesgos",
                systemImage: "exclamationmark.triangle.fill",
                tint: Palette.warning,
                items: notes.risks
            )
            IconList(
                title: "Próximos pasos",
                systemImage: "arrow.right.circle.fill",
                tint: Palette.terracotta,
                items: notes.nextSteps
            )

            if !notes.topics.isEmpty {
                SummarySection(title: "Temas") {
                    FlowLayout(spacing: 6) {
                        ForEach(notes.topics, id: \.self) { topic in
                            Text(topic)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

private struct TLDRCard: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.terracotta)
                    .frame(width: 4)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("En una frase")
                        .sectionEyebrow()
                    Text(text)
                        .font(.title3.weight(.medium))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}

private struct StatsStrip: View {
    let notes: MeetingNotes

    private var stats: [(String, String, Color)] {
        var result: [(String, String, Color)] = []
        func add(_ count: Int, _ singular: String, _ plural: String, _ icon: String, _ tint: Color) {
            guard count > 0 else { return }
            result.append(("\(count) \(count == 1 ? singular : plural)", icon, tint))
        }
        add(notes.actionItems.count, "acción", "acciones", "checklist", Palette.terracotta)
        add(notes.decisions.count, "decisión", "decisiones", "checkmark.seal", Palette.success)
        add(notes.openQuestions.count, "pregunta abierta", "preguntas abiertas", "questionmark.circle", Palette.question)
        add(notes.risks.count, "riesgo", "riesgos", "exclamationmark.triangle", Palette.warning)
        return result
    }

    var body: some View {
        if !stats.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(stats, id: \.0) { stat in
                    Label(stat.0, systemImage: stat.1)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(stat.2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(stat.2.opacity(0.12), in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct SummarySection<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if let trailing {
                    Text(trailing)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            content
        }
    }
}

private struct KeyPointRow: View {
    let point: KeyPoint
    var onJump: (TimeInterval) -> Void

    private var time: TimeInterval? {
        point.timestamp.flatMap(TranscriptLine.parseClock)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(point.point)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                if let time, let label = point.timestamp {
                    Button {
                        onJump(time)
                    } label: {
                        Label(label, systemImage: "play.fill")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Ir a este momento de la transcripción")
                    .accessibilityLabel("Ir al minuto \(label)")
                }
            }
            if let quote = point.quote, !quote.isEmpty {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.tertiary)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                    Text("“\(quote)”")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                        .textSelection(.enabled)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct IconList: View {
    let title: String
    let systemImage: String
    let tint: Color
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            SummarySection(title: title) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: systemImage)
                                .foregroundStyle(tint)
                                .accessibilityHidden(true)
                            Text(item)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

private struct ActionList: View {
    let items: [ActionItem]
    var onToggle: (ActionItem) -> Void

    var body: some View {
        let done = items.filter(\.done).count
        SummarySection(title: "Acciones", trailing: "\(done)/\(items.count)") {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    ActionRow(item: item) { onToggle(item) }
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(Palette.paper, in: .rect(cornerRadius: 12))
        }
    }
}

private struct ActionRow: View {
    let item: ActionItem
    var onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.done ? Palette.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Marcar como pendiente" : "Marcar como hecha")

            VStack(alignment: .leading, spacing: 6) {
                Text(item.task)
                    .strikethrough(item.done, color: .secondary)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .textSelection(.enabled)
                if hasMeta {
                    HStack(spacing: 6) {
                        if let owner = item.owner, !owner.isEmpty {
                            MetaChip(text: owner, systemImage: "person")
                        }
                        if let due = item.due, !due.isEmpty {
                            MetaChip(text: due, systemImage: "calendar")
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.snappy, value: item.done)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(item.done ? "Hecha" : "Pendiente")
        .accessibilityAction(named: item.done ? "Marcar como pendiente" : "Marcar como hecha", onToggle)
    }

    private var hasMeta: Bool {
        !(item.owner ?? "").isEmpty || !(item.due ?? "").isEmpty
    }

    private var label: String {
        var parts = [item.task]
        if let owner = item.owner, !owner.isEmpty { parts.append(owner) }
        if let due = item.due, !due.isEmpty { parts.append(due) }
        return parts.joined(separator: ", ")
    }
}

private struct MetaChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.7), in: Capsule())
    }
}

/// Wraps children onto new lines, left-aligned. For chips and tags.
///
/// Follows the `Layout` contract: `.unspecified` → ideal (one row),
/// `.zero` → minimum, finite width → wrap. An item wider than the proposal
/// is offered the full width so its text wraps instead of forcing the whole
/// column wider (long AI-generated topics would otherwise push the split view
/// past the window).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    /// Below this, chips wrap their own text rather than shrinking to nothing.
    var minItemWidth: CGFloat = 80

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Item {
        var index: Int
        var size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width proposed: CGFloat?, subviews: Subviews) -> [Row] {
        let limit = proposed.map { max($0, minItemWidth) } ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > limit {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: limit, height: nil))
            }
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > limit, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(Item(index: index, size: size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
