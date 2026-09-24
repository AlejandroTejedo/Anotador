import Foundation

enum TranscriptDisplay {
    static func pendingLines(
        from volatile: [SpeakerLane: String],
        lastTimestamp: TimeInterval
    ) -> [TranscriptLine] {
        SpeakerLane.allCases.compactMap { lane in
            guard let text = volatile[lane]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return nil }
            return TranscriptLine(
                id: lane.pendingID,
                lane: lane,
                text: text,
                startedAt: lastTimestamp
            )
        }
    }
}
