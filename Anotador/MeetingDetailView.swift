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
        .toolbar(removing: .title)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Título", text: $meeting.title, axis: .vertical)
                        .layoutPriority(-1)
                        .textFieldStyle(.plain)
                        .font(.title.weight(.semibold))
                        .lineLimit(1...3)
                        .accessibilityLabel("Título de la reunión")
                    MeetingMetaLine(meeting: meeting, isLive: isLive)
                }
                Spacer(minLength: 12)
                if isLive {
                    ElapsedBadge()
                }
            }

            // Full labels when there's room; icon-only when the notes inspector squeezes us.
            ViewThatFits(in: .horizontal) {
                controls(compact: false)
                controls(compact: true)
            }
            .controlSize(.large)

            if meeting.style == .custom {
                TextField("Instrucciones para el modelo", text: $meeting.customInstructions, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            SessionStatusBanner(meeting: meeting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}

extension MeetingHeader {
    @ViewBuilder
    func controls(compact: Bool) -> some View {
        HStack(spacing: 10) {
            Picker("Captura", selection: $meeting.captureModeRaw) {
                ForEach(CaptureMode.allCases) { mode in
                    Group {
                        if compact {
                            Image(systemName: mode.systemImage)
                        } else {
                            Label(mode.name, systemImage: mode.systemImage)
                        }
                    }
                    .tag(mode.rawValue)
                    .help(mode.name)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(isLive)
            .labelsHidden()
            .help(meeting.captureMode.subtitle)
            .accessibilityLabel("Modo de captura")

            Menu {
                Picker("Estilo de notas", selection: $meeting.styleRaw) {
                    ForEach(SummaryStyle.allCases) { style in
                        Text(style.name).tag(style.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(compact ? meeting.style.name : "Notas: \(meeting.style.name)", systemImage: "text.alignleft")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .fixedSize()
            .disabled(isLive)
            .help("Estructura de las notas")
            .accessibilityLabel("Estilo de notas, \(meeting.style.name)")

            Spacer(minLength: 8)

            if isLive {
                Button(role: .destructive, action: onStop) {
                    Label("Detener y redactar", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.rec)
                .keyboardShortcut(.return, modifiers: [.command])
            } else {
                Button(action: onImport) {
                    Label("Subir audio", systemImage: "square.and.arrow.down")
                        .labelStyle(AdaptiveLabelStyle(compact: compact))
                }
                .buttonStyle(.bordered)
                .disabled(meeting.phase.isBusy)
                .help("Transcribe una grabación que ya tengas")

                Button(action: onStart) {
                    Label(meeting.lines.isEmpty ? "Transcribir" : "Continuar", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
                .help(meeting.lines.isEmpty ? "Empezar a transcribir (⌘⇧M)" : "Seguir transcribiendo esta reunión")
            }
        }
    }
}

private struct AdaptiveLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            Label(configuration).labelStyle(.iconOnly)
        } else {
            Label(configuration).labelStyle(.titleAndIcon)
        }
    }
}

private struct MeetingMetaLine: View {
    let meeting: Meeting
    let isLive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(meeting.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
            if !isLive, meeting.duration > 0 {
                Text("·")
                Text(meeting.durationDescription)
            }
            if !isLive, meeting.phase != .draft {
                Text("·")
                PhaseChip(phase: meeting.phase)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

struct PhaseChip: View {
    let phase: MeetingPhase

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phase.color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(phase.name)
        }
        .foregroundStyle(phase == .ready ? .secondary : phase.color)
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
                        .foregroundStyle(Palette.warning)
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
                        .foregroundStyle(Palette.warning)
                        .accessibilityHidden(true)
                    Text(message)
                        .textSelection(.enabled)
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
    @State private var jumpTarget: TimeInterval?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $tab) {
                ForEach(MeetingSection.allCases) { item in
                    Text(item.name).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.bottom, 8)
            .accessibilityLabel("Sección de la reunión")

            Divider()

            switch tab {
            case .summary:
                SummaryView(meeting: meeting) { time in
                    jumpTarget = time
                    tab = .transcript
                }
            case .transcript:
                LiveTranscriptView(
                    lines: meeting.lines,
                    volatile: [:],
                    jumpTarget: $jumpTarget,
                    followsLive: false
                )
            }
        }
    }
}

private struct NotesInspector: View {
    @Binding var text: String
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(isLive ? "Notas en vivo" : "Agenda y notas", systemImage: "square.and.pencil")
                .font(.headline)
            Text(isLive
                 ? "Escribe contexto o la agenda. El modelo lo tendrá en cuenta."
                 : "Estas notas se envían al modelo junto con la transcripción.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .paperCard()
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Agenda, nombres, contexto…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
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
