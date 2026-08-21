import SwiftUI

// MARK: - PaperCard

/// Warm, opaque paper surface for important content. Keeps hierarchy obvious
/// against the glass interaction layer.
struct PaperCard<Content: View>: View {
    var radius: CGFloat = 28
    var padding: CGFloat = 22
    var shadow: ShadowLayers = .soft
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .appShadow(shadow)
    }
}

// MARK: - LiquidCard

/// Restrained native Liquid Glass surface. Falls back to a soft translucent
/// material on iOS 17–18 so the visual language survives older runtimes.
struct LiquidCard<Content: View>: View {
    var radius: CGFloat = 26
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(AppColors.glassEdge.opacity(0.5), lineWidth: 0.5)
                        )
                }
            }
            .appShadow(.soft)
    }
}

// MARK: - GlassPill

/// Compact translucent glass capsule for chips, disclosures and metadata.
struct GlassPill: View {
    let text: String
    var symbol: String?
    var tint: Color = AppColors.ink
    var paddingH: CGFloat = 14
    var paddingV: CGFloat = 8

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .type(.smallLink)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, paddingH)
        .padding(.vertical, paddingV)
        .background {
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(Capsule().strokeBorder(AppColors.glassEdge.opacity(0.5), lineWidth: 0.5))
    }
}

// MARK: - LiquidCapsule

/// Larger glass capsule used by the floating tab bar.
struct LiquidCapsule<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(Capsule().strokeBorder(AppColors.glassEdge.opacity(0.55), lineWidth: 0.5))
            .appShadow(.soft)
    }
}
