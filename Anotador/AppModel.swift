import AppKit
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AppModel {
    var isRecording = false
    var elapsed: TimeInterval = 0
    var liveLines: [TranscriptLine] = []
    var volatile: [SpeakerLane: String] = [:]
    var showConsent = false
    var pendingStart: Meeting?
    var installingAssets = false
    /// Progress text per meeting, so a summary running for A never shows on B.
    var statusByMeeting: [UUID: String] = [:]
    /// Non-fatal issues during capture (e.g. system audio dropped).
    var liveWarning = ""
    /// Smoothed 0…1 input level per lane while recording.
    var levels: [SpeakerLane: Float] = [:]
    private(set) var activeMeeting: Meeting?
    /// Set from outside the main window (menu bar) to select a meeting there.
    var requestedSelection: UUID?
    private(set) var summarizingIDs: Set<UUID> = []

    @ObservationIgnored var modelContext: ModelContext?

    private var engine = TranscriptionEngine()
    private var clockTask: Task<Void, Never>?
    private var startedAt: Date?
    /// Resumed meetings continue their timeline instead of restarting at 00:00.
    private var timeOffset: TimeInterval = 0
    private var lastPersist = Date.distantPast
    private static let persistInterval: TimeInterval = 15

    var formattedElapsed: String {
        TranscriptLine.clock(elapsed)
    }

    var activeID: UUID? { activeMeeting?.id }

    func status(for meeting: Meeting) -> String {
        statusByMeeting[meeting.id] ?? ""
    }

    func isActive(_ meeting: Meeting) -> Bool {
        isRecording && activeMeeting?.id == meeting.id
    }

    func attach(context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        recoverInterruptedMeetings()
    }

    /// A crash or force-quit mid-meeting leaves phases stuck at recording /
    /// summarizing forever. Put them somewhere the user can act on.
    private func recoverInterruptedMeetings() {
        guard let modelContext else { return }
        let stuck = (try? modelContext.fetch(FetchDescriptor<Meeting>()))?
            .filter { $0.phase == .recording || $0.phase.isBusy } ?? []
        guard !stuck.isEmpty else { return }
        for meeting in stuck {
            if meeting.endedAt == nil {
                meeting.endedAt = meeting.lines.last.map { line in
                    (meeting.startedAt ?? meeting.createdAt).addingTimeInterval(line.startedAt)
                } ?? meeting.startedAt
            }
            if meeting.notesDocument != nil {
                meeting.phase = .ready
            } else {
                meeting.phase = .failed
                meeting.grokError = meeting.lines.isEmpty
                    ? String(localized: "La sesión se interrumpió antes de guardar la transcripción.")
                    : String(localized: "La sesión se interrumpió. La transcripción guardada está a salvo: pulsa Reintentar para redactar las notas.")
            }
        }
        try? modelContext.save()
    }

    // MARK: - Recording

    func requestStart(_ meeting: Meeting) {
        guard !isRecording, !meeting.phase.isBusy else { return }
        pendingStart = meeting
        showConsent = true
    }

    func confirmStart() {
        showConsent = false
        guard let meeting = pendingStart else { return }
        pendingStart = nil
        Task { await start(meeting) }
    }

    func start(_ meeting: Meeting) async {
        guard !isRecording, !installingAssets else { return }
        meeting.grokError = ""
        liveWarning = ""
        statusByMeeting[meeting.id] = String(localized: "Preparando transcripción on-device…")
        installingAssets = true

        let previous = meeting.lines
        let offset = previous.isEmpty ? 0 : meeting.duration

        let locale = Locale(identifier: meeting.localeIdentifier)
        do {
            let result = try await engine.start(
                meetingID: meeting.id,
                locale: locale,
                mode: meeting.captureMode
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }

            timeOffset = offset
            startedAt = result.startedAt
            meeting.startedAt = result.startedAt.addingTimeInterval(-offset)
            meeting.endedAt = nil
            meeting.phase = .recording
            meeting.audioMicPath = result.micURL?.path ?? ""
            meeting.audioSystemPath = result.systemURL?.path ?? ""
            try? modelContext?.save()

            activeMeeting = meeting
            liveLines = previous
            volatile = [:]
            elapsed = offset
            isRecording = true
            installingAssets = false
            lastPersist = Date()
            statusByMeeting[meeting.id] = meeting.captureMode.capturesSystemAudio
                ? String(localized: "Capturando micrófono y audio del sistema")
                : String(localized: "Capturando micrófono")
            startClock()
        } catch {
            installingAssets = false
            isRecording = false
            statusByMeeting[meeting.id] = nil
            meeting.phase = previous.isEmpty ? .failed : (meeting.notesDocument == nil ? .failed : .ready)
            meeting.grokError = Self.message(for: error)
            try? modelContext?.save()
        }
    }

    func stopActive() async {
        guard let activeMeeting else { return }
        await stop(meeting: activeMeeting)
    }

    func stop(meeting: Meeting) async {
        guard isRecording, activeMeeting?.id == meeting.id else { return }
        isRecording = false
        clockTask?.cancel()
        clockTask = nil
        statusByMeeting[meeting.id] = String(localized: "Cerrando transcripción…")
        meeting.phase = .processing
        meeting.endedAt = Date()
        meeting.lines = liveLines
        try? modelContext?.save()

        await engine.stop()

        // Final results that arrived while finishing.
        meeting.lines = liveLines
        volatile = [:]
        levels = [:]
        activeMeeting = nil
        liveWarning = ""
        try? modelContext?.save()

        await summarize(meeting)
    }

    // MARK: - Summaries

    func summarize(_ meeting: Meeting) async {
        guard !summarizingIDs.contains(meeting.id) else { return }
        summarizingIDs.insert(meeting.id)
        defer { summarizingIDs.remove(meeting.id) }

        let config = ProviderSettings.current()
        meeting.phase = .summarizing
        meeting.grokError = ""
        statusByMeeting[meeting.id] = String(localized: "\(config.provider.shortName) está redactando las notas…")
        try? modelContext?.save()

        do {
            let notes = try await Summarizer.summarize(
                transcript: meeting.lines,
                notes: meeting.notes,
                style: meeting.style,
                customInstructions: meeting.customInstructions,
                config: config
            )
            meeting.notesDocument = notes
            if meeting.hasPlaceholderTitle, !notes.title.trimmingCharacters(in: .whitespaces).isEmpty {
                meeting.title = notes.title
            }
            meeting.phase = .ready
            meeting.grokError = ""
        } catch {
            meeting.phase = .failed
            meeting.grokError = Self.message(for: error)
        }
        statusByMeeting[meeting.id] = nil
        try? modelContext?.save()
    }

    func importAudio(url: URL, into meeting: Meeting) async {
        guard !isActive(meeting), !meeting.phase.isBusy else { return }
        meeting.grokError = ""
        statusByMeeting[meeting.id] = String(localized: "Transcribiendo archivo en el Mac…")
        meeting.phase = .processing
        try? modelContext?.save()

        do {
            let collector = LineCollector()
            try await FileTranscriber.transcribe(
                url: url,
                locale: Locale(identifier: meeting.localeIdentifier)
            ) { update in
                guard update.isFinal else { return }
                collector.add(
                    TranscriptLine(
                        lane: .others,
                        text: update.text,
                        startedAt: update.timestamp
                    )
                )
            }
            let imported = collector.snapshot().sorted { $0.startedAt < $1.startedAt }
            meeting.lines = imported
            let now = Date()
            let length = imported.last?.startedAt ?? 0
            meeting.startedAt = now.addingTimeInterval(-length)
            meeting.endedAt = now
            try? modelContext?.save()
            await summarize(meeting)
        } catch {
            meeting.phase = .failed
            meeting.grokError = Self.message(for: error)
            statusByMeeting[meeting.id] = nil
            try? modelContext?.save()
        }
    }

    // MARK: - Deleting

    func canDelete(_ meeting: Meeting) -> Bool {
        !isActive(meeting) && !meeting.phase.isBusy && pendingStart?.id != meeting.id
    }

    /// Removes the record *and* the audio on disk.
    func delete(_ meeting: Meeting) {
        guard canDelete(meeting), let modelContext else { return }
        let id = meeting.id
        statusByMeeting[id] = nil
        modelContext.delete(meeting)
        try? modelContext.save()
        AudioSupport.removeFolder(for: id)
    }

    // MARK: - Misc

    func openScreenPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ]
        for item in urls {
            if let url = URL(string: item), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func handle(_ event: EngineEvent) {
        switch event {
        case .transcript(let update):
            apply(update)
        case .warning(let message):
            liveWarning = message
        case .level(let lane, let value):
            guard isRecording else { return }
            // Fast attack, slow release: reads like a real meter.
            let previous = levels[lane] ?? 0
            levels[lane] = value > previous ? value : previous * 0.6 + value * 0.4
        }
    }

    private func apply(_ update: TranscriptUpdate) {
        guard activeMeeting != nil else { return }
        if update.isFinal {
            liveLines.append(
                TranscriptLine(
                    lane: update.lane,
                    text: update.text,
                    startedAt: update.timestamp + timeOffset
                )
            )
            volatile[update.lane] = nil
        } else {
            volatile[update.lane] = update.text
        }
    }

    /// Writes the transcript so far, so a crash loses seconds, not the meeting.
    private func persistLiveLinesIfNeeded() {
        guard isRecording, let activeMeeting, Date().timeIntervalSince(lastPersist) >= Self.persistInterval else { return }
        lastPersist = Date()
        if activeMeeting.lines.count != liveLines.count {
            activeMeeting.lines = liveLines
            try? modelContext?.save()
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRecording {
                if let startedAt = self.startedAt {
                    let next = self.timeOffset + Date().timeIntervalSince(startedAt)
                    if Int(next) != Int(self.elapsed) {
                        self.elapsed = next
                    }
                }
                self.persistLiveLinesIfNeeded()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}

final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [TranscriptLine] = []

    func add(_ line: TranscriptLine) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func snapshot() -> [TranscriptLine] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}
