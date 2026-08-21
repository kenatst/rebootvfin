import SwiftUI

// MARK: - EditorialHeadline

/// Large serif editorial statement.
struct EditorialHeadline: View {
    let text: String
    var style: AppTypography.Style = .todayHeadline
    var color: Color = AppColors.ink

    var body: some View {
        Text(text, style: style)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - InsightCard

/// One small editorial insight, shown only when real evidence supports it.
struct InsightCard: View {
    let insight: String

    var body: some View {
        PaperCard(radius: 24, padding: 20) {
            VStack(alignment: .leading, spacing: 8) {
                MetaLabel(text: "What reboot learned", color: AppColors.coral)
                Text(insight, style: .insightQuote)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }
}

// MARK: - EditorialIllustration

/// Container for tiny 2D editorial marks — abstract attention metaphors only.
struct EditorialIllustrationContainer<Content: View>: View {
    var size: CGFloat = 56
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(AppColors.paperRaised)
                    .appShadow(.soft)
            )
    }
}

/// Abstract "attention bloom": concentric arcs around a small dot.
struct AttentionBloomMark: View {
    var accent: Color = AppColors.coral

    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.35), lineWidth: 1.5)
                .frame(width: 34, height: 34)
            Circle().stroke(accent.opacity(0.55), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            Circle().fill(accent)
                .frame(width: 7, height: 7)
        }
    }
}
