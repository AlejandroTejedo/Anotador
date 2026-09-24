import Testing
@testable import Anotador

struct TranscriptClockTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(TranscriptLine.clock(0) == "00:00")
        #expect(TranscriptLine.clock(5) == "00:05")
        #expect(TranscriptLine.clock(75) == "01:15")
        #expect(TranscriptLine.clock(3599) == "59:59")
    }

    @Test func formatsHours() {
        #expect(TranscriptLine.clock(3600) == "1:00:00")
        #expect(TranscriptLine.clock(3661) == "1:01:01")
    }

    @Test func clampsNegativeValues() {
        #expect(TranscriptLine.clock(-12) == "00:00")
    }

    @Test func timestampLabelUsesStart() {
        let line = TranscriptLine(lane: .you, text: "Hola", startedAt: 90)
        #expect(line.timestampLabel == "01:30")
        #expect(line.markdownLine == "[01:30] **Tú:** Hola")
    }
}
