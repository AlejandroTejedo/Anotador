import AppKit
import SwiftUI

enum Palette {
    static let terracotta = Color(light: .init(red: 0.78, green: 0.34, blue: 0.22, alpha: 1), dark: .init(red: 0.91, green: 0.50, blue: 0.36, alpha: 1))
    static let rec = Color(light: .init(red: 0.83, green: 0.18, blue: 0.18, alpha: 1), dark: .init(red: 0.96, green: 0.36, blue: 0.33, alpha: 1))
    /// Warm surface for cards and the notes editor. Adapts so text stays readable in dark mode.
    static let paper = Color(light: .init(red: 0.98, green: 0.96, blue: 0.93, alpha: 1), dark: .init(red: 0.17, green: 0.15, blue: 0.14, alpha: 1))
    static let ink = Color(light: .init(red: 0.16, green: 0.13, blue: 0.11, alpha: 1), dark: .init(red: 0.95, green: 0.93, blue: 0.90, alpha: 1))
    static let success = Color(light: .init(red: 0.22, green: 0.55, blue: 0.40, alpha: 1), dark: .init(red: 0.38, green: 0.75, blue: 0.56, alpha: 1))
    static let warning = Color(light: .init(red: 0.80, green: 0.55, blue: 0.10, alpha: 1), dark: .init(red: 0.96, green: 0.74, blue: 0.30, alpha: 1))
    static let question = Color(light: .init(red: 0.25, green: 0.45, blue: 0.62, alpha: 1), dark: .init(red: 0.48, green: 0.68, blue: 0.86, alpha: 1))
}

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
