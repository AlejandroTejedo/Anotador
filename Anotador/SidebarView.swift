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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if meeting.phase.isLive {
                    Circle()
                        .fill(meeting.phase.color)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: 8) {
                Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                if meeting.duration > 0 {
                    Text(meeting.formattedDuration)
                }
                Text(meeting.phase.name)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(meeting.phase.isLive ? .updatesFrequently : [])
    }

    private var accessibilityDescription: String {
        var parts = [meeting.title, meeting.phase.name]
        if meeting.duration > 0 {
            parts.append(meeting.formattedDuration)
        }
        return parts.joined(separator: ", ")
    }
}
