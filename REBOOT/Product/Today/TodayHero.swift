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
                    GlassPill(text: prescription.mode.display.uppercased(), tint: AppColors.ink)
                }

                Text("\(prescription.minutes) min", style: .heroDuration)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 18)

                Text(prescription.goal, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 6)

                Text(prescription.reason, style: .heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 8)

                PrimaryPillButton(title: "Start \(prescription.minutes) min", symbol: "play.fill") {
                    product.beginSession()
                }
                .padding(.top, 22)
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
