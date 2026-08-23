import SwiftUI

/// Flat editorial choice row. Selected: warm tonal fill + coral check.
/// Unselected: quiet paper row, no shadow, hairline presence only.
/// Deliberately NOT a floating pill island.
struct ChoiceCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(label)
                    .type(.choiceLabel)
                    .foregroundStyle(isSelected ? AppColors.ink : AppColors.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppColors.coral : AppColors.hairline,
                            lineWidth: isSelected ? 1.6 : 1.2
                        )
                        .background(Circle().fill(isSelected ? AppColors.coral.opacity(0.08) : .clear))
                    if isSelected {
                        Circle()
                            .fill(AppColors.coral)
                            .frame(width: 9, height: 9)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(isSelected ? AppColors.statusTint : AppColors.paperRaised.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? AppColors.coral.opacity(0.35) : AppColors.hairline.opacity(0.6),
                                  lineWidth: isSelected ? 1.2 : 0.8)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.selectMorph), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
