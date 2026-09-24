import Foundation
import SwiftData

struct TranscriptLine: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var lane: SpeakerLane
    var text: String
    var startedAt: TimeInterval
    var endedAt: TimeInterval?

    init(
        id: UUID = UUID(),
        lane: SpeakerLane,
        text: String,
        startedAt: TimeInterval,
        endedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.lane = lane
        self.text = text
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var timestampLabel: String {
        Self.clock(startedAt)
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Inverse of `clock`: "04:10" or "1:02:03" → seconds. Tolerates "[04:10]".
    static func parseClock(_ text: String) -> TimeInterval? {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "[]() ").union(.whitespaces))
        let parts = cleaned.split(separator: ":").map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        return TimeInterval(parts.reduce(0) { $0 * 60 + $1! })
    }

    /// Index of the line closest to (and not after) `time`.
    static func index(nearest time: TimeInterval, in lines: [TranscriptLine]) -> Int? {
        guard !lines.isEmpty else { return nil }
        return lines.lastIndex { $0.startedAt <= time + 0.5 } ?? 0
    }
}

struct KeyPoint: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var point: String
    var timestamp: String?
    var quote: String?

    enum CodingKeys: String, CodingKey {
        case id, point, timestamp, quote
    }

    init(id: UUID = UUID(), point: String, timestamp: String? = nil, quote: String? = nil) {
        self.id = id
        self.point = point
        self.timestamp = timestamp
        self.quote = quote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        point = try container.decode(String.self, forKey: .point)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        quote = try container.decodeIfPresent(String.self, forKey: .quote)
    }
}

struct ActionItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var task: String
    var owner: String?
    var due: String?
    /// Ticked by the user in the summary; never produced by the model.
    var done: Bool

    enum CodingKeys: String, CodingKey {
        case id, task, owner, due, done
    }

    init(id: UUID = UUID(), task: String, owner: String? = nil, due: String? = nil, done: Bool = false) {
        self.id = id
        self.task = task
        self.owner = owner
        self.due = due
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        task = try container.decode(String.self, forKey: .task)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        due = try container.decodeIfPresent(String.self, forKey: .due)
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct MeetingNotes: Codable, Hashable, Sendable {
    var title: String
    var tldr: String
    var summary: String
    var keyPoints: [KeyPoint]
    var decisions: [String]
    var actionItems: [ActionItem]
    var openQuestions: [String]
    var risks: [String]
    var nextSteps: [String]
    var topics: [String]

    enum CodingKeys: String, CodingKey {
        case title, tldr, summary
        case keyPoints = "key_points"
        case decisions
        case actionItems = "action_items"
        case openQuestions = "open_questions"
        case risks
        case nextSteps = "next_steps"
        case topics
    }

    init(
        title: String = "",
        tldr: String = "",
        summary: String = "",
        keyPoints: [KeyPoint] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [String] = [],
        risks: [String] = [],
        nextSteps: [String] = [],
        topics: [String] = []
    ) {
        self.title = title
        self.tldr = tldr
        self.summary = summary
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.risks = risks
        self.nextSteps = nextSteps
        self.topics = topics
    }

    /// Lenient: models without strict structured outputs (local ones, mostly)
    /// sometimes drop empty sections. A missing list is an empty list, not a failure.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        tldr = (try? c.decodeIfPresent(String.self, forKey: .tldr)) ?? ""
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        keyPoints = (try? c.decodeIfPresent([KeyPoint].self, forKey: .keyPoints)) ?? []
        decisions = (try? c.decodeIfPresent([String].self, forKey: .decisions)) ?? []
        actionItems = (try? c.decodeIfPresent([ActionItem].self, forKey: .actionItems)) ?? []
        openQuestions = (try? c.decodeIfPresent([String].self, forKey: .openQuestions)) ?? []
        risks = (try? c.decodeIfPresent([String].self, forKey: .risks)) ?? []
        nextSteps = (try? c.decodeIfPresent([String].self, forKey: .nextSteps)) ?? []
        topics = (try? c.decodeIfPresent([String].self, forKey: .topics)) ?? []
    }

    var isEmpty: Bool {
        tldr.isEmpty && summary.isEmpty && keyPoints.isEmpty && decisions.isEmpty && actionItems.isEmpty
    }
}

@Model
final class Meeting {
    var id: UUID
    var title: String
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var notes: String
    var localeIdentifier: String
    var phaseRaw: String
    var styleRaw: String
    var customInstructions: String
    var captureModeRaw: String
    var transcriptJSON: String
    var summaryJSON: String
    var grokError: String
    var audioMicPath: String
    var audioSystemPath: String

    init(
        id: UUID = UUID(),
        title: String = "Nueva reunión",
        createdAt: Date = .now,
        notes: String = "",
        localeIdentifier: String = Locale.current.identifier
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.startedAt = nil
        self.endedAt = nil
        self.notes = notes
        self.localeIdentifier = localeIdentifier
        self.phaseRaw = MeetingPhase.draft.rawValue
        self.styleRaw = SummaryStyle.auto.rawValue
        self.customInstructions = ""
        self.captureModeRaw = CaptureMode.meeting.rawValue
        self.transcriptJSON = "[]"
        self.summaryJSON = ""
        self.grokError = ""
        self.audioMicPath = ""
        self.audioSystemPath = ""
    }

    var phase: MeetingPhase {
        get { MeetingPhase(rawValue: phaseRaw) ?? .draft }
        set { phaseRaw = newValue.rawValue }
    }

    var style: SummaryStyle {
        get { SummaryStyle(rawValue: styleRaw) ?? .auto }
        set { styleRaw = newValue.rawValue }
    }

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: captureModeRaw) ?? .meeting }
        set { captureModeRaw = newValue.rawValue }
    }

    var lines: [TranscriptLine] {
        get {
            guard let data = transcriptJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([TranscriptLine].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            transcriptJSON = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    var notesDocument: MeetingNotes? {
        get {
            guard let data = summaryJSON.data(using: .utf8), !summaryJSON.isEmpty else { return nil }
            return try? JSONDecoder().decode(MeetingNotes.self, from: data)
        }
        set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value),
                  let text = String(data: data, encoding: .utf8) else {
                summaryJSON = ""
                return
            }
            summaryJSON = text
        }
    }

    var duration: TimeInterval {
        guard let start = startedAt else { return 0 }
        return (endedAt ?? Date()).timeIntervalSince(start)
    }

    var formattedDuration: String {
        TranscriptLine.clock(duration)
    }

    /// "45 min", "1 h 12 min", "30 s": readable where "16:29" is ambiguous.
    var durationDescription: String {
        let units: Set<Duration.UnitsFormatStyle.Unit> = duration >= 60 ? [.hours, .minutes] : [.seconds]
        return Duration.seconds(duration.rounded()).formatted(.units(allowed: units, width: .abbreviated))
    }
}

enum AnotadorError: LocalizedError, Equatable {
    case microphoneDenied
    case speechDenied
    case screenDenied
    case grokMissing
    case summaryFailed(String)
    case missingAPIKey(String)
    case missingModel(String)
    case invalidEndpoint
    case noSpeech
    case conversionFailed
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Anotador necesita el micrófono para capturar tu voz."
        case .speechDenied:
            "Habilita reconocimiento de voz para transcribir en el Mac."
        case .screenDenied:
            "Para oír a los demás en Zoom, Meet o Teams, concede grabación de pantalla / audio del sistema."
        case .grokMissing:
            "No encuentro el CLI de Grok. Instálalo e inicia sesión con `grok login`, o elige otro proveedor en Ajustes."
        case .summaryFailed(let message):
            message
        case .missingAPIKey(let provider):
            "Falta la API key de \(provider). Añádela en Ajustes → Modelo."
        case .missingModel(let provider):
            "Elige un modelo para \(provider) en Ajustes → Modelo."
        case .invalidEndpoint:
            "La URL del servidor no es válida. Revísala en Ajustes → Modelo."
        case .noSpeech:
            "No hay suficiente conversación para redactar notas. Habla al menos un minuto."
        case .conversionFailed:
            "No pude convertir el audio para transcribirlo."
        case .unsupportedLocale:
            "Este idioma no está disponible para transcripción en el dispositivo."
        }
    }
}
