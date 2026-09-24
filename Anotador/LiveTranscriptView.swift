import SwiftUI

struct LiveTranscriptView: View {
    let lines: [TranscriptLine]
    let volatile: [SpeakerLane: String]
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
                LazyVStack(alignment: .leading, spacing: 14) {
                    if lines.isEmpty && pendingLines.isEmpty {
                        ContentUnavailableView(
                            "La transcripción aparece aquí",
                            systemImage: "text.bubble",
                            description: Text("Micrófono = Tú. Audio del sistema = Participantes.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    }

                    ForEach(lines) { line in
                        TranscriptBubble(line: line, pending: false)
                    }

                    ForEach(pendingLines) { line in
                        TranscriptBubble(line: line, pending: true)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: lines.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: pendingLines.map(\.text)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

struct TranscriptBubble: View {
    let line: TranscriptLine
    let pending: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(line.lane.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(line.lane.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(line.lane.color)
                    Text(line.timestampLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(line.text)
                    .foregroundStyle(pending ? .secondary : .primary)
                    .italic(pending)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lane.name), \(line.timestampLabel), \(line.text)")
    }
}
