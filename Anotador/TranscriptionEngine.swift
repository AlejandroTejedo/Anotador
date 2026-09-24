import AVFoundation
import CoreMedia
import Foundation
import Speech

struct TranscriptUpdate: Sendable {
    let lane: SpeakerLane
    let text: String
    let isFinal: Bool
    let timestamp: TimeInterval
}

enum EngineEvent: Sendable {
    case transcript(TranscriptUpdate)
    case warning(String)
    /// 0…1 loudness per lane, throttled, so the UI can show audio is arriving.
    case level(SpeakerLane, Float)
}

enum AudioLevel {
    static let emitInterval: CFAbsoluteTime = 1.0 / 12

    /// RMS mapped from -60…0 dBFS to 0…1.
    static func normalized(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let samples = UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength))
        return normalized(samples)
    }

    static func normalized<C: Collection>(_ samples: C) -> Float where C.Element == Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        let rms = meanSquare.squareRoot()
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(max((db + 60) / 60, 0), 1)
    }
}

/// Wall-clock origin shared by both lanes and the UI timer. Set right before
/// audio starts flowing so transcript timestamps match the elapsed clock.
final class SessionClock: @unchecked Sendable {
    private let lock = NSLock()
    private var origin = Date()

    func reset(to date: Date = Date()) {
        lock.withLock { origin = date }
    }

    var start: Date { lock.withLock { origin } }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        max(0, date.timeIntervalSince(start))
    }
}

enum SpeechLocale {
    static func resolve(_ locale: Locale) async throws -> Locale {
        let fallbacks = [locale, Locale.current, Locale(identifier: "es-ES"), Locale(identifier: "en-US")]
        for candidate in fallbacks {
            if let match = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return match
            }
        }
        throw AnotadorError.unsupportedLocale
    }

    static func installAssets(for transcriber: SpeechTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
}

/// One SpeechAnalyzer per audio lane (mic = you, system = others).
/// `ingest` is called from audio threads, `finish` from the engine; a lock
/// keeps them from racing.
final class LaneTranscriber: @unchecked Sendable {
    private let lock = NSLock()
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: BufferConverter?
    private var converterInputFormat: AVAudioFormat?
    private var analyzerFormat: AVAudioFormat?
    private var resultsTask: Task<Void, Never>?
    private let lane: SpeakerLane
    private let clock: SessionClock
    private let onUpdate: @Sendable (TranscriptUpdate) -> Void

    init(lane: SpeakerLane, clock: SessionClock, onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void) {
        self.lane = lane
        self.clock = clock
        self.onUpdate = onUpdate
    }

    func start(locale: Locale) async throws {
        _ = await Permissions.requestSpeech()

        let resolved = try await SpeechLocale.resolve(locale)
        let transcriber = SpeechTranscriber(
            locale: resolved,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        try await SpeechLocale.installAssets(for: transcriber)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AnotadorError.conversionFailed
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        lock.withLock {
            self.analyzer = analyzer
            self.inputBuilder = continuation
            self.analyzerFormat = format
        }

        resultsTask = Task { [lane, clock, onUpdate] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    // Finals arrive after the phrase ends; back-date to when it started.
                    let spoken = result.range.duration.seconds.isFinite ? result.range.duration.seconds : 0
                    let timestamp = max(0, clock.elapsed() - spoken)
                    onUpdate(
                        TranscriptUpdate(
                            lane: lane,
                            text: text,
                            isFinal: result.isFinal,
                            timestamp: timestamp
                        )
                    )
                }
            } catch {
                // The session finishes by cancelling the stream.
            }
        }

        try await analyzer.start(inputSequence: inputSequence)
    }

    func ingest(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let analyzerFormat, let inputBuilder else { return }
        // Recreate when the *input* changes too (e.g. switching to AirPods).
        if converter == nil || converterInputFormat != buffer.format {
            converter = BufferConverter(from: buffer.format, to: analyzerFormat)
            converterInputFormat = buffer.format
        }
        guard let converter else { return }
        do {
            let converted = try converter.convert(buffer)
            guard converted.frameLength > 0 else { return }
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        } catch {
            // Drop a bad buffer rather than killing the session.
        }
    }

    func finish() async {
        let analyzer: SpeechAnalyzer? = lock.withLock {
            inputBuilder?.finish()
            inputBuilder = nil
            converter = nil
            let current = self.analyzer
            self.analyzer = nil
            return current
        }
        if let analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                await analyzer.cancelAndFinishNow()
            }
        }
        // Let the last final results drain, but never hang "Cerrando…" on it.
        if let resultsTask {
            let drained = Task { await resultsTask.value }
            let watchdog = Task {
                try? await Task.sleep(for: .seconds(8))
                resultsTask.cancel()
            }
            await drained.value
            watchdog.cancel()
        }
        resultsTask = nil
    }
}

final class TranscriptionEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var mic: LaneTranscriber?
    private var system: LaneTranscriber?
    private let capture = CaptureService()
    private var micWriter: LaneWriter?
    private var systemWriter: LaneWriter?
    private var onEvent: (@Sendable (EngineEvent) -> Void)?
    private var lastLevelEmit: [SpeakerLane: CFAbsoluteTime] = [:]
    let clock = SessionClock()

    func start(
        meetingID: UUID,
        locale: Locale,
        mode: CaptureMode,
        onEvent: @escaping @Sendable (EngineEvent) -> Void
    ) async throws -> (micURL: URL?, systemURL: URL?, startedAt: Date) {
        let folder = try AudioSupport.folder(for: meetingID)
        let stamp = Int(Date().timeIntervalSince1970)
        let micURL = folder.appendingPathComponent("mic-\(stamp).caf")
        let systemURL = folder.appendingPathComponent("system-\(stamp).caf")
        let onUpdate: @Sendable (TranscriptUpdate) -> Void = { onEvent(.transcript($0)) }
        lock.withLock {
            self.onEvent = onEvent
            lastLevelEmit = [:]
        }

        do {
            let micLane = LaneTranscriber(lane: .you, clock: clock, onUpdate: onUpdate)
            lock.withLock { mic = micLane }
            try await micLane.start(locale: locale)

            if mode.capturesSystemAudio {
                let lane = LaneTranscriber(lane: .others, clock: clock, onUpdate: onUpdate)
                lock.withLock { system = lane }
                try await lane.start(locale: locale)
            }

            let writerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
            if let writerFormat {
                let micOut = try LaneWriter(url: micURL, format: writerFormat)
                let sysOut = mode.capturesSystemAudio ? try LaneWriter(url: systemURL, format: writerFormat) : nil
                lock.withLock {
                    micWriter = micOut
                    systemWriter = sysOut
                }
            }

            capture.onMicBuffer = { [weak self] buffer in
                self?.handle(buffer, lane: .you)
            }
            capture.onSystemBuffer = { [weak self] buffer in
                self?.handle(buffer, lane: .others)
            }
            capture.onError = { error in
                onEvent(.warning(String(localized: "Se cortó el audio del sistema (\(error.localizedDescription)). Sigo con el micrófono.")))
            }

            clock.reset()
            try await capture.start(mode: mode)
        } catch {
            await stop()
            throw error
        }

        return (micURL, mode.capturesSystemAudio ? systemURL : nil, clock.start)
    }

    func stop() async {
        capture.stop()
        let (micLane, systemLane): (LaneTranscriber?, LaneTranscriber?) = lock.withLock {
            let lanes = (mic, system)
            mic = nil
            system = nil
            micWriter = nil
            systemWriter = nil
            onEvent = nil
            return lanes
        }
        await micLane?.finish()
        await systemLane?.finish()
    }

    private func handle(_ buffer: AVAudioPCMBuffer, lane: SpeakerLane) {
        let now = CFAbsoluteTimeGetCurrent()
        let (transcriber, writer, emit): (LaneTranscriber?, LaneWriter?, (@Sendable (EngineEvent) -> Void)?) = lock.withLock {
            var emit: (@Sendable (EngineEvent) -> Void)?
            if now - (lastLevelEmit[lane] ?? 0) >= AudioLevel.emitInterval {
                lastLevelEmit[lane] = now
                emit = onEvent
            }
            return lane == .you ? (mic, micWriter, emit) : (system, systemWriter, emit)
        }
        transcriber?.ingest(buffer)
        writer?.write(buffer)
        emit?(.level(lane, AudioLevel.normalized(buffer)))
    }
}

/// Converts to 16 kHz mono and appends to a CAF file. Owned by one audio
/// thread at a time; its own lock covers the brief overlap during device changes.
final class LaneWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let file: CAFWriter
    private let format: AVAudioFormat
    private var converter: BufferConverter?
    private var converterInputFormat: AVAudioFormat?

    init(url: URL, format: AVAudioFormat) throws {
        self.file = try CAFWriter(url: url, format: format)
        self.format = format
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        if converter == nil || converterInputFormat != buffer.format {
            converter = BufferConverter(from: buffer.format, to: format)
            converterInputFormat = buffer.format
        }
        guard let converter, let converted = try? converter.convert(buffer) else { return }
        // Keep transcribing even if disk write fails.
        try? file.write(converted)
    }
}

enum FileTranscriber {
    @concurrent
    static func transcribe(url: URL, locale: Locale, onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void) async throws {
        let resolved = try await SpeechLocale.resolve(locale)
        let transcriber = SpeechTranscriber(
            locale: resolved,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        try await SpeechLocale.installAssets(for: transcriber)

        let file = try AVAudioFile(forReading: url)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let resultsTask = Task {
            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                // Position in the file, not wall-clock: a 1 h file transcribes in minutes.
                let start = result.range.start.seconds
                onUpdate(
                    TranscriptUpdate(
                        lane: .others,
                        text: text,
                        isFinal: result.isFinal,
                        timestamp: start.isFinite ? max(0, start) : 0
                    )
                )
            }
        }

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            resultsTask.cancel()
            throw error
        }
        try await resultsTask.value
    }
}
