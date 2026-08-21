import SwiftUI

/// Full-width pill CTA. `.dark` = ink pill / paper text (product world),
/// `.light` = white pill / black text (cinematic world). 56pt tall, 0.985 press scale.
struct PrimaryButton: View {
    enum Tint {
        case dark
        case light
    }

    let title: String
    var tint: Tint = .dark
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .type(.buttonLabel)
                .foregroundStyle(tint == .dark ? AppColors.paper : AppColors.void)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(tint == .dark ? AppColors.ink : AppColors.cineFG)
                .clipShape(Capsule())
                .opacity(isEnabled ? 1 : 0.25)
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled)
    }
}

/// Scales to 0.985 with a 0.2s ease while pressed (web `active:scale-[0.985]`).
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: AppMotion.pressDuration), value: configuration.isPressed)
    }
}
