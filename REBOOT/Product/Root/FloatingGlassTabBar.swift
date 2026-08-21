import SwiftUI

/// Floating native Liquid Glass capsule above the bottom safe area.
/// Selected tab becomes a soft paper pill; icons are minimal and monochrome.
struct FloatingGlassTabBar: View {
    @Binding var selection: ProductTab

    var body: some View {
        GeometryReader { geo in
            LiquidCapsule {
                HStack(spacing: 4) {
                    ForEach(ProductTab.allCases) { tab in
                        tabButton(tab)
                    }
                }
                .padding(6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, max(10, geo.safeAreaInsets.bottom))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(true)
    }

    private func tabButton(_ tab: ProductTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.reboot(duration: 0.28)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppColors.ink : AppColors.inkFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppColors.paperRaised.opacity(0.92))
                        .appShadow(.soft)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}
