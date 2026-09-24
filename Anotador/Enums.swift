import Foundation
import SwiftUI

enum SpeakerLane: String, Codable, CaseIterable, Identifiable, Sendable {
    case you
    case others

    var id: String { rawValue }

    var name: String {
        switch self {
        case .you: "Tú"
        case .others: "Participantes"
        }
    }

    var color: Color {
        switch self {
        case .you: Color(red: 0.78, green: 0.34, blue: 0.22)
        case .others: Color(red: 0.25, green: 0.45, blue: 0.62)
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
        case .draft: "Borrador"
        case .recording: "En vivo"
        case .processing: "Cerrando"
        case .summarizing: "Redactando"
        case .ready: "Lista"
        case .failed: "Revisar"
        }
    }

    var color: Color {
        switch self {
        case .draft: .secondary
        case .recording: Palette.rec
        case .processing, .summarizing: Palette.terracotta
        case .ready: Color(red: 0.22, green: 0.55, blue: 0.40)
        case .failed: .yellow
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
        case .auto: "Auto"
        case .standup: "Standup"
        case .oneOnOne: "1:1"
        case .sales: "Ventas"
        case .product: "Producto"
        case .interview: "Entrevista"
        case .custom: "Personalizado"
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
        case .meeting: "Reunión virtual"
        case .inPerson: "Presencial"
        }
    }

    var subtitle: String {
        switch self {
        case .meeting: "Micrófono + audio del sistema (Zoom, Meet, Teams, FaceTime)"
        case .inPerson: "Solo micrófono, para una sala o una llamada en altavoz"
        }
    }

    var capturesSystemAudio: Bool { self == .meeting }
}

enum MeetingSection: String, CaseIterable, Identifiable {
    case summary
    case transcript

    var id: String { rawValue }

    var name: String {
        switch self {
        case .summary: "Resumen"
        case .transcript: "Transcripción"
        }
    }
}
