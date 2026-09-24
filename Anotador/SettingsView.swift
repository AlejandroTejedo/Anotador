import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Modelo", systemImage: "sparkles") {
                ProviderSettingsView()
            }
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage("defaultLocale") private var defaultLocale = Locale.current.identifier
    @AppStorage("defaultStyle") private var defaultStyle = SummaryStyle.auto.rawValue

    private static let locales = ["es-ES", "es-MX", "en-US", "en-GB", "fr-FR", "pt-BR", "de-DE", "it-IT"]

    private var localeOptions: [String] {
        let current = Locale.current.identifier(.bcp47)
        return Self.locales.contains(current) ? Self.locales : [current] + Self.locales
    }

    var body: some View {
        Form {
            Section("Preferencias") {
                Picker("Idioma de transcripción", selection: $defaultLocale) {
                    ForEach(localeOptions, id: \.self) { id in
                        Text(Locale.current.localizedString(forIdentifier: id) ?? id).tag(id)
                    }
                    if !localeOptions.contains(defaultLocale) {
                        Text(defaultLocale).tag(defaultLocale)
                    }
                }
                Picker("Estilo de notas", selection: $defaultStyle) {
                    ForEach(SummaryStyle.allCases) { style in
                        Text(style.name).tag(style.rawValue)
                    }
                }
            }

            Section("Privacidad") {
                LabeledContent("Transcripción") {
                    Text("On-device con SpeechAnalyzer. El audio no sale del Mac.")
                }
                LabeledContent("Audio guardado") {
                    Text("~/Library/Application Support/Anotador/Meetings")
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            Section("Permisos") {
                Text("Micrófono para tu voz. Grabación de pantalla para el audio del sistema de Zoom, Meet, Teams o FaceTime. Reconocimiento de voz para el modelo on-device.")
                    .foregroundStyle(.secondary)
                Button("Abrir privacidad de captura de pantalla") {
                    appModel.openScreenPrivacySettings()
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProviderSettingsView: View {
    @AppStorage(ProviderSettings.providerKey) private var providerRaw = AIProvider.grokCLI.rawValue

    private var provider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .grokCLI
    }

    var body: some View {
        Form {
            Section {
                ProviderPicker(selection: $providerRaw)
            } footer: {
                Text(provider.privacyNote)
                    .foregroundStyle(.secondary)
            }

            ProviderDetailSection(provider: provider)
                .id(provider)
        }
        .formStyle(.grouped)
    }
}

struct ProviderPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("Proveedor", selection: $selection) {
            ForEach(AIProvider.Group.allCases) { group in
                Section(group.title) {
                    ForEach(group.providers) { item in
                        Text(item.name).tag(item.rawValue)
                    }
                }
            }
        }
    }
}

/// Recreated per provider (`.id`) so each keeps its own model, URL and key.
struct ProviderDetailSection: View {
    let provider: AIProvider
    @AppStorage private var model: String
    @AppStorage private var baseURL: String
    @State private var apiKey = ""
    @State private var models: [String] = []
    @State private var testState: TestState = .idle

    enum TestState: Equatable {
        case idle
        case running
        case ok(String)
        case failed(String)
    }

    init(provider: AIProvider) {
        self.provider = provider
        _model = AppStorage(wrappedValue: provider.defaultModel, ProviderSettings.modelKey(provider))
        _baseURL = AppStorage(wrappedValue: provider.defaultBaseURL, ProviderSettings.baseURLKey(provider))
    }

    private var config: ProviderConfig {
        ProviderConfig(provider: provider, model: model, baseURL: baseURL, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        Section(provider.shortName) {
            if provider == .grokCLI {
                LabeledContent("Binario") {
                    Text(GrokClient.resolveBinary()?.path ?? String(localized: "No encontrado. Instala Grok CLI y ejecuta `grok login`."))
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            if provider.editableBaseURL {
                TextField("URL del servidor", text: $baseURL, prompt: Text(verbatim: provider.defaultBaseURL))
                    .autocorrectionDisabled()
            }

            if provider.acceptsAPIKey {
                SecureField(provider.requiresAPIKey ? LocalizedStringKey("API key") : LocalizedStringKey("API key (opcional)"), text: $apiKey)
                    .onSubmit(saveKey)
                    .onChange(of: apiKey) { saveKey() }
                if let url = provider.keyHelpURL {
                    Link("Conseguir una API key", destination: url)
                        .font(.caption)
                }
            }

            if provider.usesModel {
                HStack {
                    TextField("Modelo", text: $model, prompt: Text(verbatim: provider.defaultModel.isEmpty ? "model-name" : provider.defaultModel))
                        .autocorrectionDisabled()
                    if !models.isEmpty {
                        Menu("Elegir") {
                            ForEach(models, id: \.self) { name in
                                Button(name) { model = name }
                            }
                        }
                        .fixedSize()
                    }
                }
            }

            HStack {
                Button(provider.usesModel ? LocalizedStringKey("Probar y cargar modelos") : LocalizedStringKey("Comprobar")) {
                    Task { await test() }
                }
                .disabled(testState == .running)
                Spacer()
                switch testState {
                case .idle:
                    EmptyView()
                case .running:
                    ProgressView().controlSize(.small)
                case .ok(let text):
                    Label(text, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .lineLimit(2)
                case .failed(let text):
                    Label(text, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                }
            }
            .font(.callout)
        }
        .onAppear {
            apiKey = Keychain.read(account: ProviderSettings.keychainAccount(provider)) ?? ""
        }
    }

    private func saveKey() {
        guard provider.acceptsAPIKey else { return }
        Keychain.save(apiKey, account: ProviderSettings.keychainAccount(provider))
    }

    private func test() async {
        saveKey()
        testState = .running
        if provider == .grokCLI {
            testState = GrokClient.resolveBinary() == nil
                ? .failed(AnotadorError.grokMissing.errorDescription ?? "")
                : .ok(String(localized: "Grok CLI encontrado"))
            return
        }
        var probe = config
        if probe.apiKey.isEmpty, let env = ProviderSettings.envAPIKey(for: provider) {
            probe.apiKey = env
        }
        do {
            let found = try await LLMClient.listModels(config: probe)
            models = found
            if found.isEmpty {
                testState = .ok(String(localized: "Conectado"))
            } else if !model.isEmpty, !found.contains(model) {
                testState = .failed(String(localized: "Conectado, pero “\(model)” no aparece en la lista. Elige uno."))
            } else {
                if model.isEmpty, let first = found.first { model = first }
                testState = .ok(String(localized: "Conectado · \(found.count) modelos"))
            }
        } catch {
            testState = .failed(AppModel.message(for: error))
        }
    }
}
