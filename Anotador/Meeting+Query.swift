import Foundation
import SwiftData

enum MeetingSearch {
    static func matching(_ meetings: [Meeting], query: String) -> [Meeting] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return meetings }
        return meetings.filter { $0.matches(trimmed) }
    }
}

extension Meeting {
    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
    }

    static func untitled(
        now: Date = .now,
        localeIdentifier: String,
        style: SummaryStyle
    ) -> Meeting {
        let meeting = Meeting(
            title: Self.defaultTitle(now: now),
            createdAt: now,
            localeIdentifier: localeIdentifier
        )
        meeting.style = style
        return meeting
    }

    /// True while the title is still the one we generated, so the AI title may
    /// replace it. A user-typed "Reunión con Ana" is left alone.
    var hasPlaceholderTitle: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders = ["Nueva reunión", String(localized: "Nueva reunión"), Self.defaultTitle(now: createdAt), "Reunión \(createdAt.formatted(date: .abbreviated, time: .shortened))"]
        return trimmed.isEmpty || placeholders.contains(trimmed)
    }

    static func defaultTitle(now: Date = .now) -> String {
        String(localized: "Reunión \(now.formatted(date: .abbreviated, time: .shortened))")
    }
}

struct MeetingDayGroup: Identifiable, Equatable {
    let id: Date
    let title: String
    let meetings: [Meeting]

    static func == (lhs: MeetingDayGroup, rhs: MeetingDayGroup) -> Bool {
        lhs.id == rhs.id && lhs.meetings.map(\.id) == rhs.meetings.map(\.id)
    }

    static func groups(from meetings: [Meeting], calendar: Calendar = .current) -> [MeetingDayGroup] {
        let grouped = Dictionary(grouping: meetings) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            MeetingDayGroup(
                id: day,
                title: day.formatted(date: .long, time: .omitted),
                meetings: grouped[day] ?? []
            )
        }
    }
}

extension ModelContext {
    @discardableResult
    func insertUntitledMeeting(localeIdentifier: String, style: SummaryStyle, now: Date = .now) -> Meeting {
        let meeting = Meeting.untitled(now: now, localeIdentifier: localeIdentifier, style: style)
        insert(meeting)
        try? save()
        return meeting
    }
}
