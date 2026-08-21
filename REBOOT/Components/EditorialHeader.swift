import SwiftUI

/// Top chrome shared by the flow.
///
/// - Cinematic: meta label left, "Skip" (and optional debug access) right.
/// - Diagnosis: Back · progress track + ink fill · step counter.
struct EditorialHeader: View {
    enum Variant {
        case cinema(meta: String, showsSkip: Bool, onSkip: () -> Void)
        case diagnosis(backEnabled: Bool, progress: CGFloat, counter: String, onBack: () -> Void)
    }

    let variant: Variant
    var safeTop: CGFloat = 0
    var onDebug: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.headerGap) {
            switch variant {
            case .cinema(let meta, let showsSkip, let onSkip):
                MetaLabel(text: meta, color: AppColors.cineMuted.opacity(0.7))
                Spacer()
                if showsSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .type(.metaLabel)
                            .foregroundStyle(AppColors.cineMuted.opacity(0.6))
                    }
                }
                debugButton
            case .diagnosis(let backEnabled, let progress, let counter, let onBack):
                Button(action: onBack) {
                    Text("Back")
                        .type(.smallLink)
                        .foregroundStyle(AppColors.inkFaint)
                }
                .disabled(!backEnabled)
                .opacity(backEnabled ? 1 : 0)

                ProgressBar(progress: progress)
                    .frame(maxWidth: .infinity)

                Text(counter)
                    .type(.metaLabel)
                    .foregroundStyle(AppColors.inkFaint)
                debugButton
            }
        }
        .padding(.top, max(AppSpacing.safeTopMin, safeTop))
    }

    @ViewBuilder
    private var debugButton: some View {
        if let onDebug {
            Button(action: onDebug) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.cineMuted.opacity(0.5))
            }
            .accessibilityLabel("Debug navigation")
        }
    }
}

/// 3pt pill progress track with ink fill (web: `h-[3px] rounded-full bg-hairline`).
struct ProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.hairline)
                Capsule()
                    .fill(AppColors.ink)
                    .frame(width: max(6, min(geo.size.width, progress * geo.size.width)))
                    .animation(.reboot(duration: AppMotion.progressDuration), value: progress)
            }
        }
        .frame(height: 3)
    }
}
