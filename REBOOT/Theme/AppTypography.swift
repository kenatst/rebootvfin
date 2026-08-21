import SwiftUI
import UIKit

/// Bundled font PostScript names (see DESIGN_MAPPING.md section 2).
enum BundledFont {
    static let plusJakarta = "PlusJakartaSans-Regular"
    static let instrument = "InstrumentSerif-Regular"
    static let instrumentItalic = "InstrumentSerif-Italic"
}

/// Builds fonts from the bundled variable/static TTFs.
/// Plus Jakarta Sans is variable along the `wght` axis; we set the axis directly
/// through `UIFontDescriptor` so every weight (300–800) matches the web exactly.
enum AppTypography {
    struct Style {
        let font: UIFont
        /// Target CSS line-height in points; `nil` lets the font decide.
        let lineHeight: CGFloat?
        let kerning: CGFloat

        var fontSwiftUI: Font { Font(font) }

        /// SwiftUI `.lineSpacing` delta to reach the target CSS line height.
        var lineSpacing: CGFloat {
            guard let lineHeight else { return 0 }
            return max(0, lineHeight - font.lineHeight)
        }
    }

    // MARK: - Font builders

    static func plusJakarta(size: CGFloat, weight: CGFloat = 400) -> UIFont {
        let name: String
        switch weight {
        case ..<450: name = BundledFont.plusJakarta
        case ..<550: name = "PlusJakartaSans-Medium"
        case ..<650: name = "PlusJakartaSans-SemiBold"
        default: name = "PlusJakartaSans-Bold"
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }

    static func instrument(size: CGFloat, italic: Bool = false) -> UIFont {
        UIFont(name: italic ? BundledFont.instrumentItalic : BundledFont.instrument, size: size)
            ?? UIFont.systemFont(ofSize: size)
    }
}

extension AppTypography.Style {
    // MARK: - Cinematic styles

    static let metaLabel = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 11, weight: 600),
        lineHeight: 16.5,
        kerning: 3.08
    )
    static let cineTitle = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 32.8, weight: 700),
        lineHeight: 33.456,
        kerning: -1.148
    )
    static let cineBody = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 17, weight: 400),
        lineHeight: 27.625,
        kerning: 0
    )
    static let cineSecondary = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 15, weight: 400),
        lineHeight: 24.4,
        kerning: 0
    )
    static let pillLabel = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 13, weight: 500),
        lineHeight: 19.5,
        kerning: 0
    )
    static let buttonLabel = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 16, weight: 600),
        lineHeight: 24,
        kerning: -0.4
    )
    static let smallLink = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 13, weight: 400),
        lineHeight: 19.5,
        kerning: 0
    )

    // MARK: - Product styles

    static let questionTitle = AppTypography.Style(
        font: AppTypography.instrument(size: 33.6),
        lineHeight: 36.288,
        kerning: -0.336
    )
    static let hint = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 15, weight: 400),
        lineHeight: 22.5,
        kerning: 0
    )
    static let choiceLabel = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 16, weight: 400),
        lineHeight: 24,
        kerning: 0
    )
    static let reportTitle = AppTypography.Style(
        font: AppTypography.instrument(size: 41.6),
        lineHeight: 42.848,
        kerning: -0.624
    )
    static let reportBody = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 15, weight: 400),
        lineHeight: 24.4,
        kerning: 0
    )
    static let cardTitle = AppTypography.Style(
        font: AppTypography.instrument(size: 32),
        lineHeight: 35.8,
        kerning: 0
    )
    static let clarity = AppTypography.Style(
        font: AppTypography.instrument(size: 28, italic: true),
        lineHeight: nil,
        kerning: 0
    )
    static let statValue = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 17, weight: 500),
        lineHeight: 23.4,
        kerning: -0.17
    )
    static let chipText = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 14, weight: 500),
        lineHeight: 21,
        kerning: 0
    )
    static let footnote = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 12, weight: 400),
        lineHeight: 19.5,
        kerning: 0
    )

    // MARK: - Product editorial styles

    static let todayHeadline = AppTypography.Style(
        font: AppTypography.instrument(size: 42),
        lineHeight: 46.2,
        kerning: -0.84
    )
    static let todaySentence = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 17, weight: 400),
        lineHeight: 27.6,
        kerning: 0
    )
    static let heroMode = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 18, weight: 600),
        lineHeight: 24,
        kerning: -0.3
    )
    static let heroDuration = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 40, weight: 600),
        lineHeight: 44,
        kerning: -1.2
    )
    static let heroGoal = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 17, weight: 400),
        lineHeight: 26,
        kerning: -0.1
    )
    static let heroReason = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 15, weight: 400),
        lineHeight: 23,
        kerning: 0
    )
    static let insightQuote = AppTypography.Style(
        font: AppTypography.instrument(size: 21, italic: true),
        lineHeight: 29,
        kerning: 0
    )
    static let calendarMeta = AppTypography.Style(
        font: AppTypography.plusJakarta(size: 13, weight: 500),
        lineHeight: 19.5,
        kerning: 0
    )
}

/// Applies a `AppTypography.Style` (font + line-height + kerning) to any view.
struct TypographyModifier: ViewModifier {
    let style: AppTypography.Style

    func body(content: Content) -> some View {
        content
            .font(style.fontSwiftUI)
            .kerning(style.kerning)
            .lineSpacing(style.lineSpacing)
    }
}

extension View {
    func type(_ style: AppTypography.Style) -> some View {
        modifier(TypographyModifier(style: style))
    }
}
