import Foundation
import SwiftUI

enum SpeakerLane: String, Codable, CaseIterable, Identifiable, Sendable {
    case you
    case others

    var id: String { rawValue }

    var name: String {
        switch self {
        case .you: String(localized: "Tú")
        case .others: String(localized: "Participantes")
        }
    }

    var color: Color {
        switch self {
        case .you: Palette.terracotta
        case .others: Palette.question
        }
    }

    var pendingID: UUID {
        switch self {
        case .you: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .others: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        }
    }
}

enum MeetingPhase: String, Codable, CaseIterable, Sendable {
    case draft
    case recording
    case processing
    case summarizing
    case ready
    case failed

    var name: String {
        switch self {
        case .draft: String(localized: "Borrador")
        case .recording: String(localized: "En vivo")
        case .processing: String(localized: "Cerrando")
        case .summarizing: String(localized: "Redactando")
        case .ready: String(localized: "Lista")
        case .failed: String(localized: "Revisar")
        }
    }

    var color: Color {
        switch self {
        case .draft: .secondary
        case .recording: Palette.rec
        case .processing, .summarizing: Palette.terracotta
        case .ready: Palette.success
        case .failed: Palette.warning
        }
    }

    var isLive: Bool { self == .recording }
    var isBusy: Bool { self == .processing || self == .summarizing }
}

enum SummaryStyle: String, CaseIterable, Identifiable, Codable {
    case auto
    case standup
    case oneOnOne
    case sales
    case product
    case interview
    case custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .standup: String(localized: "Standup")
        case .oneOnOne: String(localized: "1:1")
        case .sales: String(localized: "Ventas")
        case .product: String(localized: "Producto")
        case .interview: String(localized: "Entrevista")
        case .custom: String(localized: "Personalizado")
        }
    }

    var promptHint: String {
        switch self {
        case .auto:
            "Elige la estructura que mejor encaje con la conversación."
        case .standup:
            "Estructura tipo standup: ayer, hoy, bloqueos, ayudas pedidas."
        case .oneOnOne:
            "Estructura 1:1: contexto, feedback, acuerdos, desarrollo, seguimiento."
        case .sales:
            "Estructura comercial: necesidades, objeciones, próximos pasos, presupuesto, decisión."
        case .product:
            "Estructura de producto: problema, decisiones, alcance, riesgos, owners."
        case .interview:
            "Estructura de entrevista: perfil, señales fuertes, dudas, siguiente paso."
        case .custom:
            "Usa las instrucciones personalizadas del usuario."
        }
    }
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case meeting
    case inPerson

    var id: String { rawValue }

    var name: String {
        switch self {
        case .meeting: String(localized: "Reunión virtual")
        case .inPerson: String(localized: "Presencial")
        }
    }

    var subtitle: String {
        switch self {
        case .meeting: String(localized: "Micrófono + audio del sistema (Zoom, Meet, Teams, FaceTime)")
        case .inPerson: String(localized: "Solo micrófono, para una sala o una llamada en altavoz")
        }
    }

    var capturesSystemAudio: Bool { self == .meeting }

    var systemImage: String {
        switch self {
        case .meeting: "video"
        case .inPerson: "person.2"
        }
    }
}

enum MeetingSection: String, CaseIterable, Identifiable {
    case summary
    case transcript

    var id: String { rawValue }

    var name: String {
        switch self {
        case .summary: String(localized: "Resumen")
        case .transcript: String(localized: "Transcripción")
        }
    }
}
