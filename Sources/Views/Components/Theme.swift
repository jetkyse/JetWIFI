import SwiftUI

/// JetWIFI visual language: deep navy/black canvas, electric blue + cyan accents.
enum Theme {
    static let bg = Color(red: 0.03, green: 0.04, blue: 0.08)         // near-black navy
    static let bgElevated = Color(red: 0.07, green: 0.09, blue: 0.16) // card base
    static let card = Color(red: 0.09, green: 0.12, blue: 0.20)
    static let cardStroke = Color.white.opacity(0.06)

    static let accent = Color(red: 0.16, green: 0.52, blue: 1.0)      // electric blue
    static let cyan = Color(red: 0.20, green: 0.85, blue: 0.98)
    static let danger = Color(red: 1.0, green: 0.30, blue: 0.38)
    static let success = Color(red: 0.26, green: 0.86, blue: 0.56)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.30)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static let accentGradient = LinearGradient(
        colors: [accent, cyan],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let glowGradient = LinearGradient(
        colors: [accent.opacity(0.35), cyan.opacity(0.08)],
        startPoint: .top, endPoint: .bottom
    )
}

/// Reusable rounded card container.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

/// A status pill (Allowed / Restricted / Offline).
struct StatusPill: View {
    let text: String
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(filled ? Color.black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.15)))
            )
    }
}
