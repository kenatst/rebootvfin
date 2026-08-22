import SwiftUI

/// Large soft pill button — the primary interaction accent.
struct PrimaryPillButton: View {
    let title: String
    var symbol: String?
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .type(.buttonLabel)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(AppColors.paper)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .padding(.vertical, 2)
            .background(AppColors.ink)
            .clipShape(Capsule())
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled)
    }
}

/// Quiet tonal pill for secondary choices (question options, fallback buttons).
struct TonalPillButton: View {
    let title: String
    var isSelected: Bool = false
    var showsSelectionIndicator: Bool = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsSelectionIndicator {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(isSelected ? 1 : 0)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .type(.smallLink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppColors.ink : AppColors.ink.opacity(0.05))
                .clipShape(Capsule())
                .animation(
                    reduceMotion ? nil : .easeOut(duration: AppMotion.selectMorph),
                    value: isSelected
                )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
