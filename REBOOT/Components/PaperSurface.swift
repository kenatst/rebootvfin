import SwiftUI

/// The soft raised paper card: 28pt continuous radius, paper-raised fill,
/// soft (or lifted) two-layer shadow, optional padding.
struct PaperSurface<Content: View>: View {
    var shadow: ShadowLayers = .soft
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .appShadow(shadow)
    }
}
