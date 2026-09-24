import SwiftUI

struct LiveTranscriptView: View {
    let lines: [TranscriptLine]
    let volatile: [SpeakerLane: String]
    /// Set from the summary's timestamp chips; the view scrolls there and highlights it.
    var jumpTarget: Binding<TimeInterval?> = .constant(nil)
    var followsLive = true
    @State private var highlighted: UUID?
    private let bottomID = "transcript-bottom"

    private var pendingLines: [TranscriptLine] {
        TranscriptDisplay.pendingLines(
            from: volatile,
            lastTimestamp: lines.last?.startedAt ?? 0
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if lines.isEmpty && pendingLines.isEmpty {
                        ContentUnavailableView(
                            followsLive ? "Escuchando…" : "Sin transcripción",
                            systemImage: followsLive ? "waveform" : "text.bubble",
                            description: Text("Tu micrófono aparece como Tú. El audio del sistema, como Participantes.")
                        )
                        .symbolEffect(.variableColor.iterative, isActive: followsLive)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        TranscriptBubble(
                            line: line,
                            pending: false,
                            showsHeader: index == 0 || lines[index - 1].lane != line.lane,
                            highlighted: highlighted == line.id
                        )
                        .id(line.id)
                    }

                    ForEach(pendingLines) { line in
                        TranscriptBubble(
                            line: line,
                            pending: true,
                            showsHeader: lines.last?.lane != line.lane,
                            highlighted: false
                        )
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: lines.count) {
                guard followsLive else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: pendingLines.map(\.text)) {
                guard followsLive else { return }
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
            .onChange(of: jumpTarget.wrappedValue, initial: true) { _, target in
                guard let target, let index = TranscriptLine.index(nearest: target, in: lines) else { return }
                let id = lines[index].id
                withAnimation(.snappy) {
                    proxy.scrollTo(id, anchor: .center)
                    highlighted = id
                }
                jumpTarget.wrappedValue = nil
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.6)) {
                        if highlighted == id { highlighted = nil }
                    }
                }
            }
        }
    }
}

struct TranscriptBubble: View {
    let line: TranscriptLine
    let pending: Bool
    var showsHeader = true
    var highlighted = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(line.timestampLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .trailing)
                .padding(.top, 2)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(line.lane.color.opacity(pending ? 0.4 : 0.9))
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if showsHeader {
                    Text(line.lane.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(line.lane.color)
                }
                Text(line.text)
                    .foregroundStyle(pending ? .secondary : .primary)
                    .italic(pending)
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, showsHeader ? 14 : 4)
        .padding(.bottom, 2)
        .padding(.horizontal, 6)
        .background(
            highlighted ? Palette.terracotta.opacity(0.14) : .clear,
            in: .rect(cornerRadius: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lane.name), \(line.timestampLabel), \(line.text)")
    }
}
