import SwiftUI

/// The ONE environment card on Today. Manual actions keep the existing gentle UI;
/// Screen Time actions offer connection, selection or session protection —
/// never a dashboard, never punishment.
struct RealWorldActionCard: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var showFallback = false
    @State private var resolved = false
    @State private var showConnect = false
    @State private var showPicker = false

    private var prescription: DailyPrescription { product.prescription }
    private var envAction: EnvironmentAction? { prescription.environmentAction }
    private var wantsProtection: Bool {
        (envAction?.level ?? 0) >= FrictionLadder.protectSession
    }

    var body: some View {
        Group {
            if wantsProtection {
                protectionCard
            } else {
                manualCard
            }
        }
        .sheet(isPresented: $showConnect) {
            ScreenTimeExplainerSheet(environmentStore: environmentStore, onStateChanged: syncDeviceFacts)
        }
        .sheet(isPresented: $showPicker) {
            ActivitySelectionSheet(environmentStore: environmentStore, onStateChanged: syncDeviceFacts)
        }
    }

    // MARK: - Manual friction (unchanged gentle behaviour)

    private var manualCard: some View {
        PaperCard(radius: 24, padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                MetaLabel(text: "Before you start")

                Text(resolved ? "Set. You're ready." : prescription.action, style: .heroGoal)
                    .foregroundStyle(resolved ? AppColors.coral : AppColors.ink)
                    .padding(.top, 10)

                if showFallback, !resolved {
                    Text(prescription.actionFallback, style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 8)
                }

                if !resolved {
                    HStack(spacing: 10) {
                        TonalPillButton(title: "Done", isSelected: resolved) {
                            product.setEnvironmentActionDone(true)
                            withAnimation(.easeOut(duration: 0.25)) { resolved = true }
                        }
                        if !showFallback {
                            TonalPillButton(title: "I can't do this") {
                                withAnimation(.easeOut(duration: 0.25)) { showFallback = true }
                            }
                        } else {
                            TonalPillButton(title: "Use the fallback", isSelected: resolved) {
                                product.setEnvironmentActionDone(true)
                                withAnimation(.easeOut(duration: 0.25)) { resolved = true }
                            }
                        }
                    }
                    .padding(.top, 14)
                }

                if connectSuggestionVisible {
                    Button {
                        showConnect = true
                    } label: {
                        GlassPill(text: "Connect Screen Time", symbol: "clock.badge.checkmark", tint: AppColors.coral)
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.top, 14)
                }
            }
        }
    }

    private var connectSuggestionVisible: Bool {
        product.day > 1 &&
            environmentStore.capability == .notRequested &&
            FrictionLadder.wantsSessionProtection(env: product.profile.environmentEvidence)
    }

    // MARK: - Session protection

    private var protectionCard: some View {
        PaperCard(radius: 24, padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                MetaLabel(text: "Before you start")

                if !environmentStore.isConnected {
                    Text("Protect the apps you usually reach for during this session.", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 10)
                    Button {
                        showConnect = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Connect Screen Time")
                                .type(.buttonLabel)
                        }
                        .foregroundStyle(AppColors.paper)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(AppColors.ink)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.top, 16)
                } else if environmentStore.selection == nil {
                    Text("Choose what can wait while you work.", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 10)
                    PrimaryPillButton(title: "Choose activities", symbol: "square.grid.2x2") {
                        showPicker = true
                    }
                    .padding(.top, 16)
                } else {
                    Text(
                        resolved
                            ? "Environment protected · \(prescription.minutes) min"
                            : (envAction?.detail ?? ""),
                        style: .heroGoal
                    )
                    .foregroundStyle(resolved ? AppColors.coral : AppColors.ink)
                    .padding(.top, 10)
                    if !resolved {
                        PrimaryPillButton(title: "Enable protection", symbol: "shield.lefthalf.filled") {
                            enableProtection()
                        }
                        .padding(.top, 16)
                    }
                }
            }
        }
    }

    private func enableProtection() {
        let applied = environmentStore.applySessionProtection()
        let arm = SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: environmentStore.selection?.id,
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: applied,
            phoneLocationSelfReport: nil
        )
        withAnimation(.easeOut(duration: 0.25)) { resolved = true }
        product.beginSession(environment: arm)
    }

    private func syncDeviceFacts() {
        product.updateEnvironmentDeviceFacts(
            screenTimeConnected: environmentStore.isConnected,
            hasSelection: environmentStore.selection != nil,
            hasApprovedWindows: !environmentStore.windows.isEmpty,
            thresholdApproved: environmentStore.thresholdApproved
        )
    }
}
