import SwiftData
import SwiftUI

@main
struct AnotadorApp: App {
    @State private var appModel = AppModel()
    private let container = try! ModelContainer(for: Meeting.self)

    var body: some Scene {
        WindowGroup("Anotador", id: "main") {
            ContentView()
                .environment(appModel)
                .tint(Palette.terracotta)
        }
        .defaultSize(width: 1180, height: 760)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .modelContainer(container)
        .commands {
            InspectorCommands()
            MeetingCommands()
        }

        MenuBarExtra("Anotador", systemImage: appModel.isRecording ? "record.circle" : "waveform") {
            MenuBarPanel()
                .environment(appModel)
                .tint(Palette.terracotta)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Settings {
            SettingsView()
                .environment(appModel)
                .tint(Palette.terracotta)
        }
        .modelContainer(container)
    }
}

struct AnotadorSceneActions {
    var createMeeting: () -> Void
    var startTranscription: () -> Void
    var stopTranscription: () -> Void
    var isRecording: Bool
    var hasSelection: Bool
}

extension FocusedValues {
    @Entry var anotadorActions: AnotadorSceneActions?
}

private struct MeetingCommands: Commands {
    @FocusedValue(\.anotadorActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Nueva reunión") {
                actions?.createMeeting()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu("Reunión") {
            Button("Empezar a transcribir") {
                actions?.startTranscription()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(actions?.hasSelection != true || actions?.isRecording == true)

            Button("Detener") {
                actions?.stopTranscription()
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(actions?.isRecording != true)
        }
    }
}
