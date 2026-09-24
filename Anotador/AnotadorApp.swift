import SwiftData
import SwiftUI

@main
struct AnotadorApp: App {
    @State private var appModel = AppModel()
    private let container = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        #if DEBUG
        if DemoData.isEnabled { return DemoData.makeContainer() }
        #endif
        do {
            return try ModelContainer(for: Meeting.self)
        } catch {
            fatalError("No se pudo abrir la base de datos de Anotador: \(error)")
        }
    }

    /// `-forceAppearance light|dark` for screenshots and design review (DEBUG only).
    private static var forcedColorScheme: ColorScheme? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "forceAppearance") {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }

    var body: some Scene {
        WindowGroup("Anotador", id: "main") {
            ContentView()
                .environment(appModel)
                .tint(Palette.terracotta)
                .preferredColorScheme(Self.forcedColorScheme)
        }
        .defaultSize(width: 1180, height: 760)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .modelContainer(container)
        .commands {
            InspectorCommands()
            MeetingCommands()
            HelpCommands()
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

private struct HelpCommands: Commands {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Commands {
        CommandGroup(before: .help) {
            Button("Guía de bienvenida") { hasOnboarded = false }
        }
    }
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
