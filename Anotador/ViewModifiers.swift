import AppKit
import SwiftUI

struct PaperCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Palette.paper.opacity(0.6), in: .rect(cornerRadius: 12))
    }
}

struct WarningBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout)
            .padding(10)
            .background(.yellow.opacity(0.12), in: .rect(cornerRadius: 8))
    }
}

struct LiveCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Palette.rec)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.rec.opacity(0.12), in: Capsule())
    }
}

struct SectionEyebrowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .textCase(.uppercase)
    }
}

extension View {
    func paperCard() -> some View {
        modifier(PaperCardModifier())
    }

    func warningBanner() -> some View {
        modifier(WarningBannerModifier())
    }

    func liveCapsule() -> some View {
        modifier(LiveCapsuleModifier())
    }

    func sectionEyebrow() -> some View {
        modifier(SectionEyebrowModifier())
    }
}

extension String {
    /// Error texts are persisted as strings, so these match the localized
    /// fragments the errors are built from (see `AnotadorError`).
    var suggestsScreenPermission: Bool {
        [String(localized: "grabación de pantalla"), String(localized: "audio del sistema"), "grabación de pantalla", "audio del sistema"]
            .contains { localizedCaseInsensitiveContains($0) }
    }

    var suggestsProviderSettings: Bool {
        [String(localized: "Ajustes → Modelo"), String(localized: "otro proveedor"), "Ajustes → Modelo", "otro proveedor"]
            .contains { localizedCaseInsensitiveContains($0) }
    }

    func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self, forType: .string)
    }
}
