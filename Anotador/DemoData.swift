#if DEBUG
import Foundation
import SwiftData

/// Fictional meetings for screenshots and design review. Launch with `-demo YES`
/// (optionally `-demoTab transcript`). Uses an in-memory store: real data is never touched.
enum DemoData {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "demo")
    }

    static var initialTab: MeetingSection? {
        UserDefaults.standard.string(forKey: "demoTab").flatMap(MeetingSection.init(rawValue:))
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: Meeting.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let english = Locale.current.language.languageCode?.identifier == "en"
        for meeting in english ? englishMeetings() : spanishMeetings() {
            container.mainContext.insert(meeting)
        }
        try? container.mainContext.save()
        return container
    }

    private static func meeting(
        title: String,
        daysAgo: Int,
        hour: Int,
        minutes: Int,
        phase: MeetingPhase,
        notes: String = "",
        lines: [TranscriptLine] = [],
        document: MeetingNotes? = nil
    ) -> Meeting {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
        let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let meeting = Meeting(title: title, createdAt: start, notes: notes)
        if phase != .draft {
            meeting.startedAt = start
            meeting.endedAt = start.addingTimeInterval(TimeInterval(minutes * 60))
        }
        meeting.lines = lines
        meeting.notesDocument = document
        meeting.phase = phase
        return meeting
    }

    private static func lines(_ items: [(SpeakerLane, Int, String)]) -> [TranscriptLine] {
        items.map { TranscriptLine(lane: $0.0, text: $0.2, startedAt: TimeInterval($0.1)) }
    }

    // MARK: - Español

    private static func spanishMeetings() -> [Meeting] {
        let transcript = lines([
            (.you, 4, "Vale, empezamos. La idea es cerrar hoy la fecha de la beta de Reservas."),
            (.others, 12, "Por diseño estamos listos. Faltan los estados vacíos del calendario, pero son dos días."),
            (.others, 31, "Backend tiene el cobro con tarjeta funcionando en staging desde ayer."),
            (.you, 48, "¿Y las notificaciones push? En la última demo fallaban en Android."),
            (.others, 63, "Lo arreglamos el martes. Falta probarlo con más dispositivos."),
            (.you, 95, "Entonces propongo beta cerrada el lunes 14 con cincuenta clientes."),
            (.others, 110, "Me parece bien, pero necesitamos el aviso de privacidad revisado por legal antes."),
            (.you, 128, "Marta, ¿puedes pedírselo a legal hoy?"),
            (.others, 134, "Sí, lo mando esta tarde y te digo el jueves."),
            (.others, 170, "Otra cosa: el precio de la suscripción aún no está decidido. ¿Cinco o siete euros?"),
            (.you, 186, "Lo dejamos abierto hasta ver los datos de la beta."),
            (.others, 214, "El riesgo es que el soporte se sature si entra mucha gente a la vez."),
            (.you, 230, "Por eso cincuenta. Javier, prepara una guía rápida para soporte antes del viernes."),
            (.others, 247, "Hecho. También puedo montar un canal de Slack para la beta.")
        ])
        let notes = MeetingNotes(
            title: "Beta de Reservas: fecha y lanzamiento",
            tldr: "La beta cerrada de Reservas arranca el lunes 14 con 50 clientes, siempre que legal apruebe el aviso de privacidad esta semana; el precio se decidirá con los datos de la beta.",
            summary: "El equipo revisó el estado de la app de Reservas para fijar la beta. Diseño está casi listo (faltan los estados vacíos del calendario) y el cobro con tarjeta funciona en staging. Las notificaciones push en Android se corrigieron el martes, pero hay que probarlas en más dispositivos.\n\nSe acordó una beta cerrada con 50 clientes para controlar la carga de soporte. La condición es tener el aviso de privacidad revisado por legal antes del lanzamiento.",
            keyPoints: [
                KeyPoint(point: "Diseño listo salvo los estados vacíos del calendario (unos dos días).", timestamp: "00:12", quote: "Faltan los estados vacíos del calendario, pero son dos días."),
                KeyPoint(point: "El cobro con tarjeta ya funciona en staging.", timestamp: "00:31", quote: "Backend tiene el cobro con tarjeta funcionando en staging desde ayer."),
                KeyPoint(point: "Push en Android corregido, pendiente de probar en más dispositivos.", timestamp: "01:03", quote: "Lo arreglamos el martes. Falta probarlo con más dispositivos.")
            ],
            decisions: [
                "Beta cerrada el lunes 14 con 50 clientes.",
                "El precio de la suscripción se decide con los datos de la beta."
            ],
            actionItems: [
                ActionItem(task: "Pedir a legal la revisión del aviso de privacidad", owner: "Marta", due: "Hoy", done: true),
                ActionItem(task: "Confirmar la aprobación de legal", owner: "Marta", due: "Jueves"),
                ActionItem(task: "Preparar una guía rápida para soporte", owner: "Javier", due: "Viernes"),
                ActionItem(task: "Terminar los estados vacíos del calendario", owner: "Diseño", due: "Miércoles"),
                ActionItem(task: "Probar las push de Android en al menos 5 dispositivos", owner: "QA")
            ],
            openQuestions: [
                "¿Suscripción a 5 € o a 7 € al mes?",
                "¿Quién selecciona a los 50 clientes de la beta?"
            ],
            risks: [
                "Si legal no aprueba el aviso esta semana, la beta se retrasa.",
                "El soporte puede saturarse si la beta crece demasiado rápido."
            ],
            nextSteps: [
                "Abrir un canal de Slack para la beta.",
                "Revisar métricas de la beta a las dos semanas."
            ],
            topics: ["Fecha de la beta", "Cobros", "Notificaciones push", "Privacidad", "Precio", "Soporte"]
        )
        return [
            meeting(title: notes.title, daysAgo: 0, hour: 10, minutes: 34, phase: .ready,
                    notes: "Agenda:\n1. Estado de diseño y backend\n2. Fecha de la beta\n3. Precio",
                    lines: transcript, document: notes),
            meeting(title: "1:1 con Laura", daysAgo: 0, hour: 8, minutes: 0, phase: .draft),
            meeting(title: "Entrevista: diseñador de producto", daysAgo: 1, hour: 12, minutes: 48, phase: .ready,
                    lines: transcript, document: MeetingNotes(title: "Entrevista", tldr: "Buen perfil de sistemas de diseño.")),
            meeting(title: "Standup de plataforma", daysAgo: 1, hour: 9, minutes: 14, phase: .ready,
                    lines: transcript, document: MeetingNotes(title: "Standup", tldr: "Sin bloqueos."))
        ]
    }

    // MARK: - English

    private static func englishMeetings() -> [Meeting] {
        let transcript = lines([
            (.you, 4, "Okay, let's start. The goal today is to lock the date for the Bookings beta."),
            (.others, 12, "Design is ready. The empty states for the calendar are missing, but that's two days."),
            (.others, 31, "Backend has card payments working in staging since yesterday."),
            (.you, 48, "What about push notifications? They were failing on Android in the last demo."),
            (.others, 63, "We fixed it on Tuesday. It still needs testing on more devices."),
            (.you, 95, "Then I propose a closed beta on Monday the 14th with fifty customers."),
            (.others, 110, "Sounds good, but we need the privacy notice reviewed by legal first."),
            (.you, 128, "Marta, can you ask legal today?"),
            (.others, 134, "Yes, I'll send it this afternoon and get back to you on Thursday."),
            (.others, 170, "One more thing: subscription pricing isn't decided yet. Five or seven euros?"),
            (.you, 186, "Let's leave it open until we see the beta data."),
            (.others, 214, "The risk is support getting swamped if many people join at once."),
            (.you, 230, "That's why fifty. Javier, prepare a quick guide for support before Friday."),
            (.others, 247, "Done. I can also set up a Slack channel for the beta.")
        ])
        let notes = MeetingNotes(
            title: "Bookings beta: date and launch",
            tldr: "The closed Bookings beta starts Monday the 14th with 50 customers, provided legal approves the privacy notice this week; pricing will be decided from beta data.",
            summary: "The team reviewed the Bookings app to set the beta date. Design is nearly done (calendar empty states remain) and card payments work in staging. Android push notifications were fixed on Tuesday but need testing on more devices.\n\nThey agreed on a closed beta with 50 customers to keep support load under control. The condition is having the privacy notice reviewed by legal before launch.",
            keyPoints: [
                KeyPoint(point: "Design is ready except for the calendar empty states (about two days).", timestamp: "00:12", quote: "The empty states for the calendar are missing, but that's two days."),
                KeyPoint(point: "Card payments already work in staging.", timestamp: "00:31", quote: "Backend has card payments working in staging since yesterday."),
                KeyPoint(point: "Android push fixed, still to be tested on more devices.", timestamp: "01:03", quote: "We fixed it on Tuesday. It still needs testing on more devices.")
            ],
            decisions: [
                "Closed beta on Monday the 14th with 50 customers.",
                "Subscription price will be decided from beta data."
            ],
            actionItems: [
                ActionItem(task: "Ask legal to review the privacy notice", owner: "Marta", due: "Today", done: true),
                ActionItem(task: "Confirm legal approval", owner: "Marta", due: "Thursday"),
                ActionItem(task: "Prepare a quick guide for support", owner: "Javier", due: "Friday"),
                ActionItem(task: "Finish the calendar empty states", owner: "Design", due: "Wednesday"),
                ActionItem(task: "Test Android push on at least 5 devices", owner: "QA")
            ],
            openQuestions: [
                "Subscription at €5 or €7 per month?",
                "Who picks the 50 beta customers?"
            ],
            risks: [
                "If legal doesn't approve the notice this week, the beta slips.",
                "Support may get swamped if the beta grows too fast."
            ],
            nextSteps: [
                "Open a Slack channel for the beta.",
                "Review beta metrics after two weeks."
            ],
            topics: ["Beta date", "Payments", "Push notifications", "Privacy", "Pricing", "Support"]
        )
        return [
            meeting(title: notes.title, daysAgo: 0, hour: 10, minutes: 34, phase: .ready,
                    notes: "Agenda:\n1. Design and backend status\n2. Beta date\n3. Pricing",
                    lines: transcript, document: notes),
            meeting(title: "1:1 with Laura", daysAgo: 0, hour: 8, minutes: 0, phase: .draft),
            meeting(title: "Interview: product designer", daysAgo: 1, hour: 12, minutes: 48, phase: .ready,
                    lines: transcript, document: MeetingNotes(title: "Interview", tldr: "Strong design systems profile.")),
            meeting(title: "Platform standup", daysAgo: 1, hour: 9, minutes: 14, phase: .ready,
                    lines: transcript, document: MeetingNotes(title: "Standup", tldr: "No blockers."))
        ]
    }
}
#endif
