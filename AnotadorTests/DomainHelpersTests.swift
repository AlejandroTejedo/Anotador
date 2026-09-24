import Testing
@testable import Anotador

struct DomainHelpersTests {
    @Test func speakerLaneExposesNameAndColor() {
        #expect(SpeakerLane.you.name == "Tú")
        #expect(SpeakerLane.others.name == "Participantes")
        #expect(SpeakerLane.you.color != SpeakerLane.others.color)
        #expect(SpeakerLane.you.pendingID != SpeakerLane.others.pendingID)
    }

    @Test func phaseExposesNameAndFlags() {
        #expect(MeetingPhase.draft.name == "Borrador")
        #expect(MeetingPhase.recording.name == "En vivo")
        #expect(MeetingPhase.ready.name == "Lista")
        #expect(MeetingPhase.failed.name == "Revisar")
        #expect(MeetingPhase.recording.isLive)
        #expect(MeetingPhase.processing.isBusy)
        #expect(MeetingPhase.summarizing.isBusy)
        #expect(!MeetingPhase.ready.isBusy)
        #expect(MeetingPhase.recording.color == Palette.rec)
    }

    @Test func captureModeExposesNameAndSystemAudio() {
        #expect(CaptureMode.meeting.name == "Reunión virtual")
        #expect(CaptureMode.inPerson.name == "Presencial")
        #expect(CaptureMode.meeting.capturesSystemAudio)
        #expect(!CaptureMode.inPerson.capturesSystemAudio)
    }

    @Test func summaryStylesHaveNameAndHint() {
        for style in SummaryStyle.allCases {
            #expect(!style.name.isEmpty)
            #expect(!style.promptHint.isEmpty)
        }
        #expect(SummaryStyle.sales.name == "Ventas")
    }

    @Test func meetingSectionNames() {
        #expect(MeetingSection.summary.name == "Resumen")
        #expect(MeetingSection.transcript.name == "Transcripción")
    }

    @Test func screenPermissionHeuristic() {
        #expect("Concede grabación de pantalla".suggestsScreenPermission)
        #expect("audio del sistema denegado".suggestsScreenPermission)
        #expect(!"Grok no tiene sesión".suggestsScreenPermission)
    }

    @Test func actionItemMarkdownIncludesOwnerAndDue() {
        let full = ActionItem(task: "Enviar acta", owner: "Eva", due: "mañana")
        #expect(full.markdownLine == "- [ ] Enviar acta — Eva · mañana")
        let bare = ActionItem(task: "Revisar")
        #expect(bare.markdownLine == "- [ ] Revisar")
    }
}
