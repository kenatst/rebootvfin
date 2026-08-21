import SwiftUI

// MARK: - Train

/// Elegant empty shell. No fake product features.
struct TrainTab: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        MetaLabel(text: "Train", color: AppColors.coral)
                        EditorialHeadline(text: "Practice lives here.")
                            .padding(.top, 6)
                        Text(
                            "The full training library arrives in the next step. " +
                            "For now, today's prescription is the practice.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        EditorialIllustrationContainer {
                            AttentionBloomMark()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Program

struct ProgramTab: View {
    let product: ProductStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        MetaLabel(text: "Program", color: AppColors.coral)
                        EditorialHeadline(text: "90 days, built around you.")
                            .padding(.top, 6)
                        Text(
                            "Every session updates what comes next. The program map arrives with the next step.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)

                        HStack(spacing: 16) {
                            ProgressRing(progress: Double(product.day) / 90.0, size: 54, lineWidth: 4)
                            MicroMetric(label: "Day", value: String(format: "%03d / 090", product.day))
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Profile

/// Real profile data only — unknowns stay unknown, every fact keeps its source.
struct ProfileTab: View {
    let product: ProductStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        MetaLabel(text: "Profile", color: AppColors.coral)
                        EditorialHeadline(text: "What reboot knows.")
                            .padding(.top, 6)
                        Text(
                            "Only what you've told us and what sessions have shown. Unknown stays unknown.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)

                        profileCard("Primary goal", value: profileText(product.profile.primaryGoal.value))
                        profileCard("Main distractors", value: profileList(product.profile.distractors.value))
                        profileCard("Attention stability", value: levelText(product.profile.attentionStability))
                        profileCard("Return after distraction", value: levelText(product.profile.returnAfterDistraction))
                        profileCard("Recall", value: levelText(product.profile.recall))
                        profileCard("Focus window", value: product.profile.focusWindowMinutes.map { "\($0) minutes" } ?? "Unmeasured")

                        Text("Sessions: \(product.sessions.count) · Evidence is only ever self-reported, observed, or from a session.")
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func profileCard(_ label: String, value: String) -> some View {
        PaperCard(radius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 6) {
                MetaLabel(text: label, color: AppColors.inkFaint)
                Text(value)
                    .type(.calendarMeta)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }

    private func profileText(_ value: String?) -> String {
        guard let value else { return "Unknown" }
        return DiagnosisModels.goalLabel[value] ?? value
    }

    private func profileList(_ values: [String]?) -> String {
        guard let values, !values.isEmpty else { return "Unknown" }
        return values.map { value in
            switch value {
            case Distractor.phone: return "Phone"
            case Distractor.social: return "Social apps"
            case Distractor.notifications: return "Notifications"
            case Distractor.tabs: return "Open tabs"
            case Distractor.people: return "People & noise"
            case Distractor.internalRestlessness: return "Internal restlessness"
            default: return value
            }
        }
        .joined(separator: ", ")
    }

    private func levelText(_ knowledge: Knowledge<StabilityLevel>) -> String {
        guard let level = knowledge.value else { return "Unknown" }
        return level.rawValue.capitalized
    }

    private func levelText(_ knowledge: Knowledge<ReturnLevel>) -> String {
        guard let level = knowledge.value else { return "Unknown" }
        return level.rawValue.capitalized
    }

    private func levelText(_ knowledge: Knowledge<RecallLevel>) -> String {
        guard let level = knowledge.value else { return "Unknown" }
        return level.rawValue.capitalized
    }
}
