import AppKit
import SwiftData
import SwiftUI

struct MenuBarPanel: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultLocale") private var defaultLocale = Locale.current.identifier
    @AppStorage("defaultStyle") private var defaultStyle = SummaryStyle.auto.rawValue

    private var live: Meeting? {
        appModel.isRecording ? appModel.activeMeeting : nil
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
                Text(live.title)
                    .font(.subheadline)
                    .lineLimit(2)
                LiveLinePreview()
                Button("Detener y redactar") {
                    Task { await appModel.stop(meeting: live) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.rec)
            } else {
                Text("Captura la reunión desde aquí. Transcripción local, notas con \(ProviderSettings.currentProvider().shortName).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Nueva reunión") {
                    createMeeting()
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()
            Button("Abrir Anotador") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func createMeeting() {
        let style = SummaryStyle(rawValue: defaultStyle) ?? .auto
        modelContext.insertUntitledMeeting(localeIdentifier: defaultLocale, style: style)
    }
}

private struct MenuBarElapsed: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Text(appModel.formattedElapsed)
            .monospacedDigit()
            .foregroundStyle(Palette.rec)
            .accessibilityLabel("En vivo, \(appModel.formattedElapsed)")
    }
}

private struct LiveLinePreview: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Text(appModel.liveLines.last?.text ?? "Escuchando…")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
    }
}
