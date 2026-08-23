import SwiftUI

/// The first-value conversion moment: shown once, immediately after the free
/// Day-1 baseline completes, when REBOOT has just delivered its first genuine
/// insight. This is the only automatic paywall entry in the product.
struct Day1ContinuationView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    var onClose: () -> Void

    @State private var showPaywall = false

    private var firstInsight: String? {
        product.insights.first
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: L("DAY 1 COMPLETE"), color: AppColors.coral)

                    EditorialHeadline(text: L("Your baseline is set."))
                        .padding(.top, 18)

                    Text(
                        L("REBOOT now knows how today felt — and everything from here is measured against it. Each session teaches the program something new about how your attention actually works."),
                        style: .todaySentence
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                    if let insight = firstInsight {
                        VStack(alignment: .leading, spacing: 8) {
                            MetaLabel(text: L("FIRST INSIGHT"))
                            Text(insight)
                                .type(.heroGoal)
                                .foregroundStyle(AppColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.statusTint)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
                        .padding(.top, 28)
                    }

                    PrimaryPillButton(title: L("Continue the 90-day program")) {
                        showPaywall = true
                    }
                    .padding(.top, 32)

                    Button {
                        finish()
                    } label: {
                        Text(L("Not now"))
                            .type(.smallLink)
                            .foregroundStyle(AppColors.inkFaint)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.top, 6)

                    Text(L("The full program continues with a subscription. Your Day 1 session and insights stay yours either way."))
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionStore: subscriptionStore)
        }
        .onChange(of: subscriptionStore.status) { _, newStatus in
            // A completed purchase resolves this screen by itself.
            if newStatus.isPremium { finish() }
        }
    }

    /// Ends the first-value moment: starts the automatic-presentation cooldown
    /// and clears the pending flag so it can never fire twice.
    private func finish() {
        PaywallRules.recordAutomaticPresentation()
        product.pendingFirstValueMoment = false
        onClose()
    }
}
