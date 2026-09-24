import Testing
@testable import Anotador

struct TranscriptDisplayTests {
    @Test func ignoresEmptyVolatileLanes() {
        let lines = TranscriptDisplay.pendingLines(
            from: [.you: "  ", .others: ""],
            lastTimestamp: 12
        )
        #expect(lines.isEmpty)
    }

    @Test func keepsStableIDsPerLane() {
        let first = TranscriptDisplay.pendingLines(
            from: [.you: "uno", .others: "dos"],
            lastTimestamp: 4
        )
        let second = TranscriptDisplay.pendingLines(
            from: [.you: "tres", .others: "cuatro"],
            lastTimestamp: 9
        )
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.id) == [
            SpeakerLane.you.pendingID,
            SpeakerLane.others.pendingID
        ])
    }

    @Test func usesLastTimestamp() {
        let lines = TranscriptDisplay.pendingLines(from: [.you: "ok"], lastTimestamp: 42)
        #expect(lines.count == 1)
        #expect(lines[0].startedAt == 42)
        #expect(lines[0].lane == .you)
    }
}
