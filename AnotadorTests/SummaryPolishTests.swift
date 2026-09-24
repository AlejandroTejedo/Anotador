import Foundation
import Testing
@testable import Anotador

struct SummaryPolishTests {
    @Test func parsesClockStrings() {
        #expect(TranscriptLine.parseClock("04:10") == 250)
        #expect(TranscriptLine.parseClock("[1:02:03]") == 3723)
        #expect(TranscriptLine.parseClock(" 00:05 ") == 5)
        #expect(TranscriptLine.parseClock("mañana") == nil)
        #expect(TranscriptLine.parseClock("12") == nil)
        #expect(TranscriptLine.parseClock("1:2:3:4") == nil)
    }

    @Test func clockRoundTrips() {
        for seconds in [0.0, 59, 61, 3599, 3723] {
            #expect(TranscriptLine.parseClock(TranscriptLine.clock(seconds)) == seconds)
        }
    }

    @Test func findsNearestLineForJump() {
        let lines = [0.0, 30, 95, 200].map { TranscriptLine(lane: .you, text: "x", startedAt: $0) }
        #expect(TranscriptLine.index(nearest: 100, in: lines) == 2)
        #expect(TranscriptLine.index(nearest: 95, in: lines) == 2)
        #expect(TranscriptLine.index(nearest: 5, in: lines) == 0)
        #expect(TranscriptLine.index(nearest: 999, in: lines) == 3)
        #expect(TranscriptLine.index(nearest: 10, in: []) == nil)
    }

    @Test func actionDoneStateDefaultsAndPersists() throws {
        let fromModel = try JSONDecoder().decode(ActionItem.self, from: Data(#"{"task":"a"}"#.utf8))
        #expect(!fromModel.done)

        var item = ActionItem(task: "b")
        item.done = true
        let roundTrip = try JSONDecoder().decode(ActionItem.self, from: JSONEncoder().encode(item))
        #expect(roundTrip.done)
        #expect(roundTrip.markdownLine == "- [x] b")
    }

    @Test func togglingActionUpdatesStoredNotes() {
        let meeting = Meeting()
        meeting.notesDocument = MeetingNotes(tldr: "t", actionItems: [ActionItem(task: "a")])
        var notes = meeting.notesDocument!
        notes.actionItems[0].done = true
        meeting.notesDocument = notes
        #expect(meeting.notesDocument?.actionItems.first?.done == true)
    }

    @Test func readableDuration() {
        let meeting = Meeting()
        meeting.startedAt = Date(timeIntervalSince1970: 0)
        meeting.endedAt = Date(timeIntervalSince1970: 45 * 60 + 20)
        #expect(meeting.durationDescription.contains("45"))
        meeting.endedAt = Date(timeIntervalSince1970: 30)
        #expect(meeting.durationDescription.contains("30"))
    }

    @Test func providerGroupsCoverEveryProvider() {
        let grouped = AIProvider.Group.allCases.flatMap(\.providers)
        #expect(Set(grouped) == Set(AIProvider.allCases))
        #expect(grouped.count == AIProvider.allCases.count)
    }
}

struct AudioLevelTests {
    @Test func silenceIsZeroAndFullScaleIsOne() {
        #expect(AudioLevel.normalized([Float](repeating: 0, count: 256)) == 0)
        #expect(AudioLevel.normalized([Float](repeating: 1, count: 256)) == 1)
        #expect(AudioLevel.normalized([Float]()) == 0)
    }

    @Test func quietSpeechLandsMidScale() {
        // -30 dBFS ≈ 0.0316 RMS → halfway on a -60…0 scale.
        let level = AudioLevel.normalized([Float](repeating: 0.0316, count: 512))
        #expect(abs(level - 0.5) < 0.02)
    }
}
