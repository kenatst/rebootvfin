import SwiftUI

/// Compact glass-backed sheet explaining why today is what it is.
/// Honest about evidence; never pretends causality from weak data.
struct AdaptiveDisclosureSheet: View {
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss

    private var prescription: DailyPrescription { product.prescription }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            MetaLabel(text: "Why this?", color: AppColors.coral)
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.inkFaint)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(AppColors.ink.opacity(0.05)))
                            }
                        }

                        EditorialHeadline(text: prescription.headline)
                            .padding(.top, 18)

                        sectionLabel("What REBOOT noticed")
                        Text(prescription.reason, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                            .padding(.top, 8)

                        sectionLabel("Why we're testing this today")
                            .padding(.top, 22)
                        Text(prescription.sentence, style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 8)

                        if let envNote = environmentNote {
                            sectionLabel("Environment")
                                .padding(.top, 22)
                            Text(envNote, style: .heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                                .padding(.top, 8)
                        }

                        GlassPill(text: evidenceSummary, symbol: "checkmark.seal", tint: AppColors.ink)
                            .padding(.top, 22)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 12)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        MetaLabel(text: text)
            .padding(.top, 10)
    }

    private var evidenceSummary: String {
        let sessionWord = product.sessions.count == 1 ? "1 session" : "\(product.sessions.count) sessions"
        if product.profile.environmentEvidence?.evidenceCount ?? 0 > 0 {
            return "Self-report + environment evidence · \(sessionWord)"
        }
        return "Based on self-report · \(sessionWord)"
    }

    private var environmentNote: String? {
        let env = product.profile.environmentEvidence
        let distractor = product.profile.distractors.value?.first.map {
            switch $0 {
            case Distractor.phone: return "phone"
            case Distractor.social: return "social apps"
            case Distractor.notifications: return "notifications"
            case Distractor.tabs: return "open tabs"
            case Distractor.people: return "people and noise"
            default: return "distractions"
            }
        }
        return EnvironmentInsight.whyToday(env, distractor: distractor)
    }
}
