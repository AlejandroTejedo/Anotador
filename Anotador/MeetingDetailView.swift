import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting
    @Environment(AppModel.self) private var appModel
    @State private var tab: MeetingSection = .summary
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument = MarkdownFile()
    @State private var showNotesInspector = true

    private var isLive: Bool {
        appModel.isActive(meeting)
    }

    /// Another meeting is recording, or this one is busy: don't offer to start.
    private var canStart: Bool {
        !appModel.isRecording && !appModel.installingAssets && !meeting.phase.isBusy
    }

    var body: some View {
        VStack(spacing: 0) {
            MeetingHeader(
                meeting: meeting,
                isLive: isLive,
                canStart: canStart,
                onStart: { appModel.requestStart(meeting) },
                onStop: { Task { await appModel.stop(meeting: meeting) } },
                onImport: { importing = true }
            )
            Divider()
            if isLive {
                LiveTranscriptHost()
            } else {
                FinishedMeetingBody(meeting: meeting, tab: $tab)
            }
        }
        .background(.background)
        .navigationTitle(meeting.title)
        .inspector(isPresented: $showNotesInspector) {
            NotesInspector(text: $meeting.notes, isLive: isLive)
                .inspectorColumnWidth(min: 240, ideal: 300, max: 480)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Copiar", systemImage: "doc.on.doc") {
                    meeting.markdownExport().copyToPasteboard()
                }
                .help("Copiar notas en Markdown")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Exportar", systemImage: "square.and.arrow.up") {
                    exportDocument = MarkdownFile(text: meeting.markdownExport())
                    exporting = true
                }
            }
            if !isLive, meeting.phase == .ready || meeting.phase == .failed, !meeting.lines.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Regenerar") {
                        Task { await appModel.summarize(meeting) }
                    }
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .primaryAction) {
                Button("Notas", systemImage: "sidebar.trailing") {
                    showNotesInspector.toggle()
                }
                .help("Mostrar u ocultar notas")
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.audio, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let access = url.startAccessingSecurityScopedResource()
                Task {
                    await appModel.importAudio(url: url, into: meeting)
                    if access { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
        .fileDialogMessage("Elige un audio para transcribirlo en este Mac.")
        .fileDialogConfirmationLabel("Transcribir")
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .markdownText,
            defaultFilename: meeting.exportFilename
        ) { _ in }
        .fileExporterFilenameLabel("Exportar notas")
        .onChange(of: meeting.phase) { _, phase in
            if phase == .ready { tab = .summary }
            if phase.isLive { tab = .transcript }
        }
    }
}

private struct MeetingHeader: View {
    @Bindable var meeting: Meeting
    let isLive: Bool
    let canStart: Bool
    var onStart: () -> Void
    var onStop: () -> Void
    var onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Título", text: $meeting.title)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                Spacer()
                if isLive {
                    ElapsedBadge()
                } else if meeting.duration > 0 {
                    Text(meeting.formattedDuration)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 10) {
                Picker("Captura", selection: $meeting.captureModeRaw) {
                    ForEach(CaptureMode.allCases) { mode in
                        Text(mode.name).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .disabled(isLive)
                .labelsHidden()
                .accessibilityLabel("Modo de captura")

                Picker("Notas", selection: $meeting.styleRaw) {
                    ForEach(SummaryStyle.allCases) { style in
                        Text(style.name).tag(style.rawValue)
                    }
                }
                .frame(maxWidth: 160)
                .disabled(isLive)
                .labelsHidden()
                .accessibilityLabel("Estilo de notas")

                Spacer()

                if isLive {
                    Button("Detener", role: .destructive, action: onStop)
                        .keyboardShortcut(.return, modifiers: [.command])
                } else {
                    Button("Transcribir", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canStart)
                    Button("Subir audio", action: onImport)
                        .disabled(meeting.phase.isBusy)
                }
            }

            if meeting.style == .custom {
                TextField("Instrucciones para el modelo", text: $meeting.customInstructions, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            SessionStatusBanner(meeting: meeting)
        }
        .padding(20)
    }
}

private struct ElapsedBadge: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        LiveBadge(elapsed: appModel.formattedElapsed)
    }
}

private struct SessionStatusBanner: View {
    @Environment(AppModel.self) private var appModel
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let status = appModel.status(for: meeting)
            if !status.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(status)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if appModel.isActive(meeting), !appModel.liveWarning.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(appModel.liveWarning)
                    Spacer()
                }
                .warningBanner()
                .accessibilityElement(children: .combine)
            }

            let message = meeting.grokError
            if !message.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(message)
                    Spacer()
                    if message.suggestsScreenPermission {
                        Button("Ajustes") { appModel.openScreenPrivacySettings() }
                    }
                    if message.suggestsProviderSettings {
                        SettingsLink { Text("Ajustes") }
                    }
                    if meeting.phase == .failed, !meeting.lines.isEmpty {
                        Button("Reintentar") {
                            Task { await appModel.summarize(meeting) }
                        }
                    }
                }
                .warningBanner()
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct LiveTranscriptHost: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        LiveTranscriptView(lines: appModel.liveLines, volatile: appModel.volatile)
    }
}

private struct FinishedMeetingBody: View {
    let meeting: Meeting
    @Binding var tab: MeetingSection

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $tab) {
                ForEach(MeetingSection.allCases) { item in
                    Text(item.name).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityLabel("Sección de la reunión")

            switch tab {
            case .summary:
                SummaryView(meeting: meeting)
            case .transcript:
                LiveTranscriptView(lines: meeting.lines, volatile: [:])
            }
        }
    }
}

private struct NotesInspector: View {
    @Binding var text: String
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isLive ? "Notas en vivo" : "Agenda y notas")
                .font(.headline)
            Text(isLive
                 ? "Escribe contexto o la agenda. El modelo lo tendrá en cuenta."
                 : "Estas notas se envían al modelo junto con la transcripción.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .paperCard()
        }
        .padding(16)
    }
}

struct LiveBadge: View {
    let elapsed: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.rec)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("EN VIVO")
                .font(.caption.weight(.bold))
            Text(elapsed)
                .monospacedDigit()
        }
        .liveCapsule()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("En vivo, \(elapsed)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    LiveBadge(elapsed: "03:12")
        .padding()
}
