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
                        "An adaptive, evidence-backed protocol to retrain focus, protect your cognitive boundaries, and graduate with a personalized Operating Manual.",
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

    // MARK: - Transformation List

    private var transformationList: some View {
        VStack(alignment: .leading, spacing: 16) {
            transformationRow(
                tag: "UNDERSTAND",
                title: "What Breaks Your Attention",
                detail: "Isolate your primary digital pulls, reflex habits, and fatigue triggers with honest on-device sampling."
            )
            transformationRow(
                tag: "TRAIN",
                title: "Stability, Recall & Depth",
                detail: "Progress daily through 5 distinct attention modes calibrated to your expanding focus window."
            )
            transformationRow(
                tag: "RESHAPE",
                title: "Your Digital Environment",
                detail: "Deploy adaptive friction boundaries and automated Screen Time shields before task-switching starts."
            )
            transformationRow(
                tag: "LEARN",
                title: "Your Optimal Working Context",
                detail: "Discover the exact sleep, daypart, and energy conditions that maximize your deep-work output."
            )
            transformationRow(
                tag: "LEAVE",
                title: "Your Attention Operating Manual",
                detail: "Graduate on Day 90 with a synthesized 11-dimension operating guide for self-directed Own Mode."
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
            return "\(product.displayPrice)/year · Includes 7-day free trial"
        }
        return "$79.99/year · $6.67/month (7-day free trial)"
    }

    private var monthlyPriceSubtitle: String {
        if let product = subscriptionStore.monthlyProduct {
            return "\(product.displayPrice)/month · Cancel anytime"
        }
        return "$14.99/month · Billed monthly"
    }

    private var ctaTitle: String {
        if selectedPeriod == .yearly {
            return "Start 7-Day Free Trial"
        } else {
            return "Unlock Full Program"
        }
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
