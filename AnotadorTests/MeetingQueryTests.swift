import Foundation
import SwiftData
import Testing
@testable import Anotador

@MainActor
struct MeetingQueryTests {
    @Test func searchMatchesTitleAndNotesButNotTranscript() throws {
        let (context, container) = try inMemoryStore()
        _ = container
        let planning = Meeting(title: "Sprint planning", notes: "velocidad")
        planning.lines = [TranscriptLine(lane: .you, text: "secreto", startedAt: 1)]
        let oneOnOne = Meeting(title: "1:1 María", notes: "feedback")
        context.insert(planning)
        context.insert(oneOnOne)

        let byTitle = MeetingSearch.matching([planning, oneOnOne], query: "sprint")
        #expect(byTitle.map(\.title) == ["Sprint planning"])

        let byNotes = MeetingSearch.matching([planning, oneOnOne], query: "FEEDBACK")
        #expect(byNotes.map(\.title) == ["1:1 María"])

        let byTranscript = MeetingSearch.matching([planning, oneOnOne], query: "secreto")
        #expect(byTranscript.isEmpty)

        let blank = MeetingSearch.matching([planning, oneOnOne], query: "  ")
        #expect(blank.count == 2)
    }

    @Test func groupsMeetingsByDayNewestFirst() throws {
        let (context, container) = try inMemoryStore()
        _ = container
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 9))!
        let day1Later = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 18))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 9))!

        let first = Meeting(title: "Ayer mañana", createdAt: day1)
        let second = Meeting(title: "Ayer tarde", createdAt: day1Later)
        let third = Meeting(title: "Hoy", createdAt: day2)
        [first, second, third].forEach(context.insert)

        let groups = MeetingDayGroup.groups(from: [first, second, third], calendar: calendar)
        #expect(groups.map(\.id) == [
            calendar.startOfDay(for: day2),
            calendar.startOfDay(for: day1)
        ])
        #expect(groups[0].meetings.map(\.title) == ["Hoy"])
        #expect(Set(groups[1].meetings.map(\.title)) == ["Ayer mañana", "Ayer tarde"])
    }

    @Test func untitledFactoryUsesLocaleAndStyle() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let meeting = Meeting.untitled(now: now, localeIdentifier: "es-ES", style: .product)
        #expect(meeting.title.hasPrefix("Reunión "))
        #expect(meeting.localeIdentifier == "es-ES")
        #expect(meeting.style == .product)
        #expect(meeting.phase == .draft)
    }

    private func inMemoryStore() throws -> (ModelContext, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Meeting.self, configurations: config)
        return (container.mainContext, container)
    }
}
