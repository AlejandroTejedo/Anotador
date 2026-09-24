import SwiftData
import SwiftUI

struct SidebarView: View {
    let groups: [MeetingDayGroup]
    @Binding var selectedID: UUID?
    @Binding var search: String
    var onNew: () -> Void
    @Environment(AppModel.self) private var appModel

    var body: some View {
        List(selection: $selectedID) {
            sidebarSections
        }
        .listStyle(.sidebar)
        .searchable(text: $search, placement: .sidebar, prompt: "Buscar reuniones")
        .overlay {
            searchEmptyOverlay
        }
        .navigationTitle("Anotador")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nueva reunión", systemImage: "plus", action: onNew)
            }
        }
    }

    @ViewBuilder
    private var sidebarSections: some View {
        ForEach(groups) { group in
            Section(group.title) {
                ForEach(group.meetings, id: \.id) { meeting in
                    SidebarMeetingRow(
                        meeting: meeting,
                        canDelete: appModel.canDelete(meeting),
                        onDelete: { delete(meeting) }
                    )
                    .tag(meeting.id)
                }
            }
        }
    }

    @ViewBuilder
    private var searchEmptyOverlay: some View {
        if groups.isEmpty, !search.isEmpty {
            ContentUnavailableView.search(text: search)
        }
    }

    private func delete(_ meeting: Meeting) {
        guard appModel.canDelete(meeting) else { return }
        if selectedID == meeting.id {
            selectedID = nil
        }
        appModel.delete(meeting)
    }
}

private struct SidebarMeetingRow: View {
    let meeting: Meeting
    let canDelete: Bool
    var onDelete: () -> Void

    var body: some View {
        MeetingRow(meeting: meeting)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Eliminar", role: .destructive, action: onDelete)
                    .disabled(!canDelete)
            }
            .contextMenu {
                Button("Eliminar", role: .destructive, action: onDelete)
                    .disabled(!canDelete)
            }
    }
}

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if meeting.phase.isLive {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(Palette.rec)
                        .symbolEffect(.pulse)
                        .accessibilityHidden(true)
                }
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: 5) {
                Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                if meeting.duration > 0, !meeting.phase.isLive {
                    Text("·")
                    Text(meeting.durationDescription)
                }
                if meeting.phase != .ready, meeting.phase != .draft {
                    Text("·")
                    PhaseChip(phase: meeting.phase)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(meeting.phase.isLive ? .updatesFrequently : [])
    }

    private var accessibilityDescription: String {
        var parts = [meeting.title, meeting.phase.name]
        if meeting.duration > 0 {
            parts.append(meeting.durationDescription)
        }
        return parts.joined(separator: ", ")
    }
}
