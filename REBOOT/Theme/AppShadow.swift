import SwiftUI

/// Two-layer shadows matching the CSS values in DESIGN_MAPPING.md section 1.
struct ShadowLayers {
    static let soft = ShadowLayers(
        near: (color: AppColors.shadowTint.opacity(0.04), radius: 1, y: 1),
        far: (color: AppColors.shadowTint.opacity(0.06), radius: 12, y: 8)
    )
    static let lift = ShadowLayers(
        near: (color: AppColors.shadowTint.opacity(0.05), radius: 2, y: 2),
        far: (color: AppColors.shadowTint.opacity(0.10), radius: 22, y: 18)
    )
    var near: (color: Color, radius: CGFloat, y: CGFloat)
    var far: (color: Color, radius: CGFloat, y: CGFloat)
}

struct ShadowModifier: ViewModifier {
    let layers: ShadowLayers

    func body(content: Content) -> some View {
        content
            .shadow(color: layers.far.color, radius: layers.far.radius, x: 0, y: layers.far.y)
            .shadow(color: layers.near.color, radius: layers.near.radius, x: 0, y: layers.near.y)
    }
}

extension View {
    func appShadow(_ shadow: ShadowLayers) -> some View {
        modifier(ShadowModifier(layers: shadow))
    }
}
