import SwiftUI

/// First-run guide: what Anotador does, the three permissions, and which
/// model writes the notes. Reopenable from Ayuda → Guía de bienvenida.
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var step: Step = .initial
    @State private var forward = true

    enum Step: Int, CaseIterable {
        case welcome, permissions, model, ready

        static var initial: Step {
            #if DEBUG
            // `-onboardingStep 2` jumps straight to a step for design review.
            if let forced = Step(rawValue: UserDefaults.standard.integer(forKey: "onboardingStep")) { return forced }
            #endif
            return .welcome
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: 720, maxHeight: 640)
        .background(.background)
        .tint(Palette.terracotta)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep()
        case .permissions: PermissionsStep()
        case .model: ModelStep()
        case .ready: ReadyStep()
        }
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Atrás") { go(-1) }
                    .keyboardShortcut(.cancelAction)
            } else {
                Button("Omitir", action: onFinish)
                    .buttonStyle(.link)
            }
            Spacer()
            StepDots(current: step.rawValue, count: Step.allCases.count)
            Spacer()
            Button(step == .ready ? LocalizedStringKey("Empezar") : LocalizedStringKey("Continuar")) {
                step == .ready ? onFinish() : go(1)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        forward = delta > 0
        withAnimation(.snappy(duration: 0.35)) { step = next }
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.terracotta : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Paso \(current + 1) de \(count)")
    }
}

private struct StepHeader: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Palette.terracotta)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                systemImage: "waveform.badge.mic",
                title: "Nada se queda en el aire",
                subtitle: "Anotador escucha tus reuniones, las transcribe en este Mac y deja por escrito decisiones, acciones y dudas."
            )
            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    systemImage: "lock.shield",
                    title: "Privado por diseño",
                    detail: "El audio y la transcripción nunca salen del Mac."
                )
                FeatureRow(
                    systemImage: "person.2.wave.2",
                    title: "Tú y los demás, separados",
                    detail: "Tu micrófono y el audio de Zoom, Meet o Teams van por carriles distintos."
                )
                FeatureRow(
                    systemImage: "checklist",
                    title: "Notas que se pueden usar",
                    detail: "Resumen, puntos clave con citas, decisiones y acciones con responsable y fecha."
                )
            }
            .frame(maxWidth: 440)
        }
        .padding(32)
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Palette.terracotta)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionsStep: View {
    @State private var mic = Permissions.microphone
    @State private var speech = Permissions.speech
    @State private var screen = Permissions.screen
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                systemImage: "hand.raised",
                title: "Permisos",
                subtitle: "macOS te los pedirá una vez. Puedes concederlos ahora o al grabar por primera vez."
            )
            VStack(spacing: 10) {
                PermissionRow(
                    systemImage: "mic",
                    title: "Micrófono",
                    detail: "Para transcribir tu voz.",
                    state: mic
                ) {
                    Task {
                        _ = await Permissions.requestMicrophone()
                        mic = Permissions.microphone
                    }
                }
                PermissionRow(
                    systemImage: "text.bubble",
                    title: "Reconocimiento de voz",
                    detail: "El modelo de Apple que transcribe en el Mac.",
                    state: speech
                ) {
                    Task {
                        _ = await Permissions.requestSpeech()
                        speech = Permissions.speech
                    }
                }
                PermissionRow(
                    systemImage: "rectangle.dashed.badge.record",
                    title: "Grabación de pantalla y audio",
                    detail: "Solo para oír a los demás en reuniones virtuales. No se graba vídeo.",
                    state: screen,
                    optional: true
                ) {
                    Permissions.requestScreen()
                    appModel.openScreenPrivacySettings()
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(32)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            mic = Permissions.microphone
            speech = Permissions.speech
            screen = Permissions.screen
        }
    }
}

private struct PermissionRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let state: PermissionState
    var optional = false
    var request: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Palette.terracotta)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    if optional {
                        Text("Reuniones virtuales")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            switch state {
            case .granted:
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Palette.success)
            case .denied:
                Button("Abrir Ajustes", action: request)
            case .notDetermined:
                Button("Conceder", action: request)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Palette.paper, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

private struct ModelStep: View {
    @AppStorage(ProviderSettings.providerKey) private var providerRaw = AIProvider.grokCLI.rawValue

    private var provider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .grokCLI
    }

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                systemImage: "sparkles",
                title: "¿Quién redacta las notas?",
                subtitle: "La transcripción es siempre local. Elige qué modelo convierte el texto en notas."
            )
            HStack(spacing: 10) {
                ForEach(AIProvider.Group.allCases) { group in
                    GroupCard(group: group, isSelected: provider.group == group) {
                        if provider.group != group, let first = group.providers.first {
                            providerRaw = first.rawValue
                        }
                    }
                }
            }
            .frame(maxWidth: 600)

            Form {
                Section {
                    ProviderPicker(selection: $providerRaw)
                } footer: {
                    Text(provider.privacyNote).foregroundStyle(.secondary)
                }
                ProviderDetailSection(provider: provider)
                    .id(provider)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 600)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }
}

private struct GroupCard: View {
    let group: AIProvider.Group
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: group.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Palette.terracotta : .secondary)
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(group.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Palette.paper, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Palette.terracotta : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ReadyStep: View {
    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                systemImage: "checkmark.seal",
                title: "Todo listo",
                subtitle: "Crea una reunión, pulsa Transcribir y céntrate en la conversación."
            )
            VStack(alignment: .leading, spacing: 12) {
                ShortcutRow(keys: "⌘N", action: "Nueva reunión")
                ShortcutRow(keys: "⌘⇧M", action: "Empezar a transcribir")
                ShortcutRow(keys: "⌘⇧.", action: "Detener y redactar las notas")
                ShortcutRow(keys: "⌘,", action: "Cambiar de modelo o idioma")
            }
            .frame(maxWidth: 380)

            Label("Avisa siempre a los demás de que estás transcribiendo.", systemImage: "person.wave.2")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let action: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: keys)
                .font(.body.monospaced().weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: .rect(cornerRadius: 6))
                .frame(width: 72, alignment: .leading)
            Text(action)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environment(AppModel())
}
