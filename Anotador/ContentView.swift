import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]
    @State private var selectedID: UUID?
    @State private var search = ""
    @AppStorage("defaultLocale") private var defaultLocale = Locale.current.identifier
    @AppStorage("defaultStyle") private var defaultStyle = SummaryStyle.auto.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    private var filtered: [Meeting] {
        MeetingSearch.matching(meetings, query: search)
    }

    private var groups: [MeetingDayGroup] {
        MeetingDayGroup.groups(from: filtered)
    }

    private var selected: Meeting? {
        meetings.first(where: { $0.id == selectedID }) ?? filtered.first
    }

    var body: some View {
        ZStack {
            if hasOnboarded {
                main
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) { hasOnboarded = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            appModel.attach(context: modelContext)
        }
    }

    private var main: some View {
        @Bindable var appModel = appModel
        return NavigationSplitView {
            SidebarView(
                groups: groups,
                selectedID: $selectedID,
                search: $search,
                onNew: createMeeting
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            if let meeting = selected {
                MeetingDetailView(meeting: meeting)
            } else if !search.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                EmptyMeetingsView(onNew: createMeeting)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: appModel.requestedSelection) { _, id in
            guard let id else { return }
            search = ""
            selectedID = id
            appModel.requestedSelection = nil
        }
        .onAppear {
            if let id = appModel.requestedSelection {
                selectedID = id
                appModel.requestedSelection = nil
            }
            if selectedID == nil {
                selectedID = meetings.first?.id
            }
        }
        .focusedSceneValue(
            \.anotadorActions,
            AnotadorSceneActions(
                createMeeting: createMeeting,
                startTranscription: {
                    if let meeting = selected { appModel.requestStart(meeting) }
                },
                stopTranscription: {
                    Task { await appModel.stopActive() }
                },
                isRecording: appModel.isRecording,
                hasSelection: selected != nil && selected?.phase.isBusy != true
            )
        )
        .alert("Antes de transcribir", isPresented: $appModel.showConsent) {
            Button("Cancelar", role: .cancel) {
                appModel.pendingStart = nil
            }
            Button("Empezar") {
                appModel.confirmStart()
            }
        } message: {
            Text("Al transcribir confirmas que las personas en la reunión lo saben y están de acuerdo. El audio y la transcripción se quedan en este Mac. \(ProviderSettings.currentProvider().privacyNote)")
        }
    }

    private func createMeeting() {
        let style = SummaryStyle(rawValue: defaultStyle) ?? .auto
        selectedID = modelContext.insertUntitledMeeting(
            localeIdentifier: defaultLocale,
            style: style
        ).id
    }
}

struct EmptyMeetingsView: View {
    var onNew: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Nada se queda en el aire", systemImage: "waveform.badge.mic")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Palette.terracotta)
        } description: {
            Text("Captura Zoom, Meet, Teams o una sala. Anotador transcribe en el Mac y el modelo que elijas redacta puntos clave, decisiones y acciones.")
        } actions: {
            Button("Nueva reunión", systemImage: "plus", action: onNew)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

#Preview {
    EmptyMeetingsView(onNew: {})
        .frame(width: 640, height: 420)
}
