import SwiftUI

/// Capsule chip with configurable surface — used for cine stages, goal chips,
/// absorption chips and small labels.
struct Pill: View {
    let text: String
    var background: Color
    var foreground: Color
    var font: AppTypography.Style = .pillLabel
    var verticalPadding: CGFloat = 6
    var horizontalPadding: CGFloat = 14

    var body: some View {
        Text(text)
            .type(font)
            .foregroundStyle(foreground)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(background)
            .clipShape(Capsule())
    }
}

extension Pill {
    /// Cinematic stage chip: white 10% surface, white 85% text.
    static func stage(_ text: String) -> Pill {
        Pill(
            text: text,
            background: AppColors.cineFG.opacity(0.10),
            foreground: AppColors.cineFG.opacity(0.85)
        )
    }

    /// Goal chip in the report: ink 5% surface, ink-soft text, 13px.
    static func goal(_ text: String) -> Pill {
        Pill(
            text: text,
            background: AppColors.ink.opacity(0.05),
            foreground: AppColors.inkSoft,
            font: .smallLink
        )
    }

    /// Absorption chip: cyan 14% surface, ink/cyan-blended text, 14px.
    static func absorption(_ text: String) -> Pill {
        Pill(
            text: text,
            background: AppColors.cyan.opacity(0.14),
            foreground: AppColors.absorptionText,
            font: .chipText,
            verticalPadding: 8,
            horizontalPadding: 14
        )
    }
}
