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
    var suggestsScreenPermission: Bool {
        localizedCaseInsensitiveContains("grabación de pantalla")
            || localizedCaseInsensitiveContains("audio del sistema")
    }

    var suggestsProviderSettings: Bool {
        localizedCaseInsensitiveContains("Ajustes → Modelo")
            || localizedCaseInsensitiveContains("otro proveedor")
    }

    func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self, forType: .string)
    }
}
