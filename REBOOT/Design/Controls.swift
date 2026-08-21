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
            }
            .foregroundStyle(AppColors.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .type(.smallLink)
                .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppColors.ink : AppColors.ink.opacity(0.05))
                .clipShape(Capsule())
                .animation(.easeOut(duration: AppMotion.selectMorph), value: isSelected)
        }
        .buttonStyle(PressScaleStyle())
    }
}
