import AppKit
import SwiftData
import SwiftUI

struct MenuBarPanel: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]
    @AppStorage("defaultLocale") private var defaultLocale = Locale.current.identifier
    @AppStorage("defaultStyle") private var defaultStyle = SummaryStyle.auto.rawValue

    private var live: Meeting? {
        appModel.isRecording ? appModel.activeMeeting : nil
    }

    private var recent: [Meeting] {
        Array(meetings.filter { $0.id != live?.id }.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(Palette.terracotta)
                    .accessibilityHidden(true)
                Text("Anotador")
                    .font(.headline)
                Spacer()
                if appModel.isRecording {
                    MenuBarElapsed()
                }
            }

            if let live {
                LiveSection(meeting: live)
            } else {
                Button {
                    let meeting = createMeeting()
                    show(meeting)
                } label: {
                    Label("Nueva reunión", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recientes")
                        .sectionEyebrow()
                        .padding(.bottom, 4)
                    ForEach(recent) { meeting in
                        RecentRow(meeting: meeting, status: appModel.status(for: meeting)) {
                            show(meeting)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Abrir Anotador") { show(nil) }
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Ajustes")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Salir de Anotador")
                .disabled(appModel.isRecording)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
    }

    private func show(_ meeting: Meeting?) {
        if let meeting { appModel.requestedSelection = meeting.id }
        NSApp.activate()
        openWindow(id: "main")
    }

    private func createMeeting() -> Meeting {
        let style = SummaryStyle(rawValue: defaultStyle) ?? .auto
        return modelContext.insertUntitledMeeting(localeIdentifier: defaultLocale, style: style)
    }
}

private struct LiveSection: View {
    @Environment(AppModel.self) private var appModel
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meeting.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            LevelMeters(lanes: meeting.captureMode.capturesSystemAudio ? [.you, .others] : [.you])
            Text(appModel.liveLines.last?.text ?? String(localized: "Escuchando…"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
            Button {
                Task { await appModel.stop(meeting: meeting) }
            } label: {
                Label("Detener y redactar", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.rec)
            .controlSize(.large)
        }
    }
}

private struct RecentRow: View {
    let meeting: Meeting
    let status: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title)
                        .lineLimit(1)
                    if status.isEmpty {
                        Text(meeting.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(Palette.terracotta)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if meeting.phase.isBusy {
                    ProgressView().controlSize(.mini)
                } else if meeting.phase == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warning)
                        .accessibilityLabel(meeting.phase.name)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre la reunión")
    }
}

private struct MenuBarElapsed: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        LiveBadge(elapsed: appModel.formattedElapsed)
            .font(.caption)
    }
}
