import SwiftUI
import StoreKit

/// Conversion surface. Above the fold: headline → value line → yearly plan →
/// CTA. Pillars and legal live below the purchase decision.
struct PaywallView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

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
                    // Top bar: brand eyebrow + close.
                    HStack {
                        MetaLabel(text: "REBOOT")
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                                .frame(width: 38, height: 38)
                                .background(AppColors.paperRaised)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, 16)

                    // The decision block sits above everything.
                    EditorialHeadline(text: "90 days to rebuild your attention.")
                        .padding(.top, 28)

                    Text(
                        "A 90-day protocol that trains attention behaviors, learns your patterns from real sessions, and ends with an Operating Manual built from your own evidence.",
                        style: .todaySentence
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                    pricingSelectionSection
                        .padding(.top, 28)

                    PrimaryPillButton(
                        title: ctaTitle,
                        isEnabled: !subscriptionStore.isPurchasing && subscriptionStore.isStoreKitAvailable
                    ) {
                        handlePurchase()
                    }
                    .padding(.top, 20)

                    Button {
                        Task {
                            let restored = await subscriptionStore.restorePurchases()
                            if restored { dismiss() }
                        }
                    } label: {
                        Text("Restore purchases")
                            .type(.smallLink)
                            .foregroundStyle(AppColors.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.top, 6)

                    if let error = subscriptionStore.errorMessage {
                        Text(error)
                            .type(.footnote)
                            .foregroundStyle(AppColors.coral)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }

                    // Supporting detail — quieter, below the fold decision.
                    Divider()
                        .overlay(AppColors.hairline)
                        .padding(.top, 36)

                    transformationList
                        .padding(.top, 32)

                    footerLegalSection
                        .padding(.top, 36)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceView()
        }
    }

    // MARK: - Pricing Selection

    private var pricingSelectionSection: some View {
        VStack(spacing: 12) {
            planRow(
                title: "Yearly",
                subtitle: yearlyPriceSubtitle,
                badge: trialConfigured ? "7-day free trial" : "Best value",
                isSelected: selectedPeriod == .yearly
            ) { selectedPeriod = .yearly }

            planRow(
                title: "Monthly",
                subtitle: monthlyPriceSubtitle,
                badge: nil,
                isSelected: selectedPeriod == .monthly
            ) { selectedPeriod = .monthly }
        }
    }

    private func planRow(
        title: String,
        subtitle: String,
        badge: String?,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(Font(AppTypography.plusJakarta(size: 17, weight: 700)))
                            .foregroundStyle(AppColors.ink)
                        if let badge {
                            Text(badge.uppercased())
                                .font(Font(AppTypography.plusJakarta(size: 10, weight: 700)))
                                .tracking(0.8)
                                .foregroundStyle(isSelected ? AppColors.paper : AppColors.coral)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isSelected ? AppColors.coral : AppColors.coral.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppColors.coral : AppColors.inkFaint)
            }
            .padding(18)
            .background(isSelected ? AppColors.paperRaised : AppColors.paperRaised.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous)
                    .strokeBorder(isSelected ? AppColors.coral : AppColors.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(title) plan. \(subtitle)\(badge.map { ". \($0)" } ?? "")")
    }

    // MARK: - Supporting Detail (below the fold)

    /// The five pillars as flat editorial rows — no cards, reduced weight.
    private var transformationList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(pillars.enumerated()), id: \.offset) { index, pillar in
                VStack(alignment: .leading, spacing: 4) {
                    Text(pillar.tag)
                        .font(Font(AppTypography.plusJakarta(size: 10, weight: 700)))
                        .tracking(1.5)
                        .foregroundStyle(AppColors.coral)
                    Text(pillar.title)
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pillar.detail)
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 14)

                if index < pillars.count - 1 {
                    Divider().overlay(AppColors.hairline)
                }
            }
        }
    }

    private struct Pillar {
        let tag: String
        let title: String
        let detail: String
    }

    private var pillars: [Pillar] {
        [
            Pillar(tag: "UNDERSTAND", title: "What breaks your attention",
                   detail: "Your sessions and honest self-reports surface the pulls that actually cost you focus."),
            Pillar(tag: "TRAIN", title: "Staying, returning, recalling",
                   detail: "One prescribed practice a day across five attention modes."),
            Pillar(tag: "RESHAPE", title: "Your environment",
                   detail: "Lighter friction first — distance, one-task browser, optional protection."),
            Pillar(tag: "LEARN", title: "The conditions that help you",
                   detail: "Tested against your own comparable sessions, not averages."),
            Pillar(tag: "LEAVE", title: "An Operating Manual that's yours",
                   detail: "Day 90 ends with your evidence-backed manual; Own Mode keeps it useful."),
        ]
    }

    // MARK: - Pricing Copy

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
