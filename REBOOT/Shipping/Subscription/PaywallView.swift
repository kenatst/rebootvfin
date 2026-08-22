import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPeriod: SubscriptionPeriod = .yearly
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false

    enum SubscriptionPeriod: String, CaseIterable, Identifiable {
        case yearly
        case monthly

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        MetaLabel(text: "REBOOT ATTENTION SYSTEM", color: AppColors.coral)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                                .frame(width: 36, height: 36)
                                .background(AppColors.paperRaised)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 16)

                    // Hero Headline
                    EditorialHeadline(text: "90 Days to Rebuild Your Attention.")
                        .padding(.top, 24)

                    Text(
                        "A 90-day adaptive protocol that trains attention behaviors, learns your personal patterns from real sessions, and ends with an Operating Manual built from your own evidence.",
                        style: .todaySentence
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 12)

                    // Transformation Points
                    transformationList
                        .padding(.top, 28)

                    // Pricing Selection Cards
                    pricingSelectionSection
                        .padding(.top, 32)

                    // Error Message (if any)
                    if let error = subscriptionStore.errorMessage {
                        Text(error)
                            .type(.footnote)
                            .foregroundStyle(AppColors.coral)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                    }

                    // Primary CTA
                    PrimaryPillButton(
                        title: ctaTitle,
                        symbol: "sparkles",
                        isEnabled: !subscriptionStore.isPurchasing && subscriptionStore.isStoreKitAvailable
                    ) {
                        handlePurchase()
                    }
                    .padding(.top, 20)

                    // Secondary Actions & Restore
                    HStack(spacing: 20) {
                        Button("Restore Purchases") {
                            Task {
                                let restored = await subscriptionStore.restorePurchases()
                                if restored {
                                    dismiss()
                                }
                            }
                        }
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    // Legal & Terms Footer
                    footerLegalSection
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceView()
        }
    }

    // MARK: - 2. Paywall Copy

    private var transformationList: some View {
        VStack(alignment: .leading, spacing: 16) {
            transformationRow(
                tag: "UNDERSTAND",
                title: "What breaks your attention",
                detail: "Your sessions and honest self-reports surface the pulls that actually cost you focus."
            )
            transformationRow(
                tag: "TRAIN",
                title: "Staying, returning, recalling",
                detail: "One prescribed practice a day across five attention modes, calibrated to your measured window."
            )
            transformationRow(
                tag: "RESHAPE",
                title: "Your environment",
                detail: "Lighter friction first — phone distance, one-task browser, optional Screen Time protection."
            )
            transformationRow(
                tag: "LEARN",
                title: "The conditions that help you",
                detail: "Energy, time of day and setup — tested against your own comparable sessions, not averages."
            )
            transformationRow(
                tag: "LEAVE",
                title: "An Operating Manual that's yours",
                detail: "Day 90 ends with your evidence-backed manual. Own Mode keeps it useful without a program."
            )
        }
    }

    private func transformationRow(tag: String, title: String, detail: String) -> some View {
        PaperCard(radius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 6) {
                MetaLabel(text: tag, color: AppColors.coral)
                Text(title)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkSoft)
            }
        }
    }

    // MARK: - Pricing Selection

    private var pricingSelectionSection: some View {
        VStack(spacing: 14) {
            // Yearly Option (Visually Preferred)
            Button {
                selectedPeriod = .yearly
            } label: {
                PaperCard(radius: 22, padding: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Annual Membership")
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                                GlassPill(text: "Best Value", tint: AppColors.coral)
                            }
                            Text(yearlyPriceSubtitle)
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                        Image(systemName: selectedPeriod == .yearly ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedPeriod == .yearly ? AppColors.coral : AppColors.inkFaint)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(selectedPeriod == .yearly ? AppColors.coral : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(PressScaleStyle())

            // Monthly Option
            Button {
                selectedPeriod = .monthly
            } label: {
                PaperCard(radius: 22, padding: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Membership")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text(monthlyPriceSubtitle)
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                        Image(systemName: selectedPeriod == .monthly ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedPeriod == .monthly ? AppColors.coral : AppColors.inkFaint)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(selectedPeriod == .monthly ? AppColors.coral : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var yearlyPriceSubtitle: String {
        if let product = subscriptionStore.yearlyProduct {
            return "\(product.displayPrice)/year"
        }
        return "$79.99/year · about $6.67 a month"
    }

    private var monthlyPriceSubtitle: String {
        if let product = subscriptionStore.monthlyProduct {
            return "\(product.displayPrice)/month · Cancel anytime"
        }
        return "$14.99/month · Billed monthly"
    }

    /// Trial copy appears only when the StoreKit product actually carries an
    /// introductory offer. No invented discounts, no fake urgency.
    private var ctaTitle: String {
        if selectedPeriod == .yearly, trialConfigured {
            return "Start 7-Day Free Trial"
        }
        return "Continue the full program"
    }

    private var trialConfigured: Bool {
        guard let product = subscriptionStore.yearlyProduct else { return false }
        if #available(iOS 17.2, *) {
            return product.subscription?.introductoryOffer != nil
        }
        return product.subscription?.promotionalOffers.isEmpty == false
            || product.subscription?.introductoryOffer != nil
    }

    private func handlePurchase() {
        Task {
            let productToBuy = selectedPeriod == .yearly
                ? subscriptionStore.yearlyProduct
                : subscriptionStore.monthlyProduct

            if let product = productToBuy {
                let success = await subscriptionStore.purchase(product)
                if success {
                    dismiss()
                }
            } else {
                // In simulator testing without StoreKit configuration: simulate success for smooth flow
                #if DEBUG
                subscriptionStore.setMockStatus(.subscribed(productId: AppConfig.yearlyProductID, expiresAt: Date().addingTimeInterval(365 * 86400), isTrial: true))
                dismiss()
                #endif
            }
        }
    }

    // MARK: - Legal Footer

    private var footerLegalSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    showTermsSheet = true
                }
                Text("·")
                    .foregroundStyle(AppColors.inkFaint)
                Button("Privacy Policy") {
                    showPrivacySheet = true
                }
            }
            .type(.footnote)
            .foregroundStyle(AppColors.inkFaint)

            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current billing cycle in your Apple ID Account Settings.")
                .type(.footnote)
                .foregroundStyle(AppColors.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text(AppConfig.medicalDisclaimer)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.inkFaint.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
    }
}
