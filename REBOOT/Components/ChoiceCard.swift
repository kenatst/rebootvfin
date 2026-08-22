import SwiftUI

/// Soft editorial choice row with a check circle. Selected state morphs to the
/// ink pill. Lighter than a card: tonal fill, secondary radius, minimal shadow.
struct ChoiceCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(label)
                    .type(.choiceLabel)
                    .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.paper.opacity(0.22) : AppColors.ink.opacity(0.05))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(AppColors.paper)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(isSelected ? AppColors.ink : AppColors.paperRaised.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .appShadow(isSelected ? .lift : .soft)
            .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.selectMorph), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
