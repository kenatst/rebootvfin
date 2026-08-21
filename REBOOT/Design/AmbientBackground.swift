import SwiftUI

/// Warm paper base with large, heavily diffused ambient light blooms.
/// Reads as light entering the room, never as a gradient wallpaper.
struct AmbientBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppColors.paper

                bloom(color: AppColors.ambientCoral, size: geo.size.width * 0.9, x: geo.size.width * 0.86, y: geo.size.height * 0.10, opacity: 0.75)
                bloom(color: AppColors.ambientLavender, size: geo.size.width * 1.0, x: geo.size.width * 0.10, y: geo.size.height * 0.78, opacity: 0.7)
                bloom(color: AppColors.ambientIce, size: geo.size.width * 0.7, x: geo.size.width * 0.78, y: geo.size.height * 0.88, opacity: 0.55)
                bloom(color: AppColors.ambientBlush, size: geo.size.width * 0.55, x: geo.size.width * 0.18, y: geo.size.height * 0.18, opacity: 0.5)
            }
            .ignoresSafeArea()
        }
    }

    private func bloom(color: Color, size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .blur(radius: 34)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}
