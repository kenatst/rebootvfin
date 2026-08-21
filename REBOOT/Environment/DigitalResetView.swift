import SwiftUI

/// Lightweight recovery micro-flow. No dopamine language, no detox, no claims.
struct DigitalResetView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @Environment(\.dismiss) private var dismiss
    @State private var protect = false
    @State private var nextAction: String?

    private let tinyActions = [
        "Open one document",
        "Write one sentence",
        "Walk for 5 minutes",
        "Read one page",
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "Reset", color: AppColors.coral)
                    EditorialHeadline(text: "Reset the environment.")
                        .padding(.top, 14)
                    Text(
                        "One small step is enough to restart. No streak, no judgement.",
                        style: .todaySentence
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 10)

                    if environmentStore.isConnected, environmentStore.selection != nil {
                        Toggle(isOn: $protect) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Protect for 10 minutes", style: .heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                Text("Shields your selected distractions briefly")
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                        }
                        .tint(AppColors.coral)
                        .padding(.top, 26)
                    }

                    Text("Choose ONE tiny next action", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 26)
                    FlowLayout(spacing: 8) {
                        ForEach(tinyActions, id: \.self) { action in
                            TonalPillButton(title: action, isSelected: nextAction == action) {
                                nextAction = action
                            }
                        }
                    }
                    .padding(.top, 12)

                    Spacer()

                    PrimaryPillButton(title: "Start 10 min", symbol: "play.fill") {
                        startReset()
                    }
                    .disabled(nextAction == nil)
                    .padding(.bottom, max(28, geo.safeAreaInsets.bottom) + 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, max(20, geo.safeAreaInsets.top) + 12)
            }
            .ignoresSafeArea()
        }
    }

    private func startReset() {
        var arm: SessionEnvironmentArm?
        if protect {
            let applied = environmentStore.applySessionProtection()
            arm = SessionEnvironmentArm(
                condition: .protected,
                manualIntervention: nil,
                protectedSelectionID: environmentStore.selection?.id,
                protectionOffered: true,
                protectionAccepted: true,
                protectionActivated: applied,
                phoneLocationSelfReport: nil
            )
        }
        dismiss()
        product.beginSession(environment: arm, minutesOverride: 10)
    }
}
