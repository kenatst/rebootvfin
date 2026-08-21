import SwiftUI

extension Color {
    /// sRGB hex initializer, e.g. `Color(hex: 0xF9F7F1)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }
}

/// Central color tokens — exact sRGB conversions of the web app's oklch palette.
/// See DESIGN_MAPPING.md section 1.
enum AppColors {
    // Cinematic (onboarding)
    static let void = Color(hex: 0x000000)
    static let signal = Color(hex: 0xE60016)
    static let cineFG = Color(hex: 0xF9F8F5)
    static let cineMuted = Color(hex: 0xBCB6B1)

    // Product (diagnosis / report)
    static let paper = Color(hex: 0xF9F7F1)
    static let paperRaised = Color(hex: 0xFEFDFA)
    static let ink = Color(hex: 0x18130E)
    static let inkSoft = Color(hex: 0x5F5A54)
    static let inkFaint = Color(hex: 0x95928B)
    static let coral = Color(hex: 0xE54C4A)
    static let cyan = Color(hex: 0x4AB6C7)
    static let hairline = Color(hex: 0xE0DED8)

    /// Shadow tint — `oklch(0.3 0.02 70)` (#342C23).
    static let shadowTint = Color(hex: 0x342C23)

    /// Status card surface — `coral 8%` over paper-raised (#FFF0EC).
    static let statusTint = Color(hex: 0xFFF0EC)

    /// Absorption chip text — ink 90% / cyan 10% (oklab mix).
    static let absorptionText = Color(hex: 0x1F201E)

    // MARK: - Ambient atmospheric tints (never compete with the coral accent)

    static let ambientLavender = Color(hex: 0xE8E2F5)
    static let ambientIce = Color(hex: 0xE3F0F6)
    static let ambientBlush = Color(hex: 0xF7E2E4)
    static let ambientCoral = Color(hex: 0xFAE7DF)
    static let glassEdge = Color.white.opacity(0.55)
    static let glassHighlight = Color.white.opacity(0.28)
}
