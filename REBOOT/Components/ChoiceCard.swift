import SwiftUI

/// Soft rounded choice card with check circle. Selected state morphs to the ink pill.
struct ChoiceCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(label)
                    .type(.choiceLabel)
                    .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.paper.opacity(0.22) : AppColors.ink.opacity(0.06))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(AppColors.paper)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 57.5, alignment: .leading)
            .background(isSelected ? AppColors.ink : AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .appShadow(isSelected ? .lift : .soft)
            .animation(.easeOut(duration: AppMotion.selectMorph), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}
