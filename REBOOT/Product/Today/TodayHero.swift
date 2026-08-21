import SwiftUI

/// One large premium hero surface — Today's prescription.
/// Warm paper with a restrained glass sheen; nothing dashboard-like inside.
struct TodayHero: View {
    @ObservedObject var product: ProductStore

    private var prescription: DailyPrescription { product.prescription }

    var body: some View {
        PaperCard(radius: 34, padding: 24, shadow: .lift) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    MetaLabel(text: "Today", color: AppColors.coral)
                    Spacer()
                    GlassPill(
                        text: product.programStatus == .completed
                            ? "PROGRAM COMPLETE"
                            : prescription.mode.display.uppercased(),
                        tint: product.programStatus == .completed ? AppColors.coral : AppColors.ink
                    )
                }

                Text(
                    product.programStatus == .completed ? "90 days" : "\(prescription.minutes) min",
                    style: .heroDuration
                )
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 18)

                Text(
                    product.programStatus == .completed
                        ? "The protocol is complete. Your practice library stays open."
                        : prescription.goal,
                    style: .heroGoal
                )
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 6)

                Text(
                    product.programStatus == .completed
                        ? "No Day 91 is generated."
                        : prescription.reason,
                    style: .heroReason
                )
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 8)

                if product.programStatus == .completed {
                    PrimaryPillButton(title: "Open Program", symbol: "checkmark.circle") {
                        product.tab = .program
                    }
                    .padding(.top, 22)
                } else if product.hasCompletedCurrentProtocol {
                    GlassPill(text: "Protocol day complete", symbol: "checkmark", tint: AppColors.coral)
                        .padding(.top, 22)
                } else {
                    PrimaryPillButton(title: "Start \(prescription.minutes) min", symbol: "play.fill") {
                        product.prepareProtocolSession()
                    }
                    .padding(.top, 22)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            AttentionBloomMark(accent: AppColors.coral.opacity(0.55))
                .padding(18)
                .allowsHitTesting(false)
        }
    }
}
