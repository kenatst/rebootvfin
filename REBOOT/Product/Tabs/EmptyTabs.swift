import SwiftUI

// MARK: - Train

struct TrainTab: View {
    @ObservedObject var product: ProductStore
    @State private var selectedMode: TrainingMode?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Train", color: AppColors.coral)
                        EditorialHeadline(text: "Train what attention needs.")
                            .padding(.top, 14)
                        Text(
                            "Practice a specific skill without moving your 90-day program forward.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)

                        MetaLabel(text: "Today's practice")
                            .padding(.top, 34)
                        todayPractice
                            .padding(.top, 12)

                        MetaLabel(text: "Practice library")
                            .padding(.top, 34)
                        practiceLibrary
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 160)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedMode) { mode in
            ModeIntroductionSheet(mode: mode) {
                selectedMode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    product.prepareFreeTraining(mode)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var todayPractice: some View {
        PaperCard(radius: 30, padding: 22, shadow: .lift) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    GlassPill(text: product.prescription.mode.rawValue, tint: AppColors.coral)
                    Spacer()
                    Text("\(product.prescription.minutes) min", style: .heroMode)
                        .foregroundStyle(AppColors.ink)
                }
                Text(product.prescription.goal, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 18)
                Text(product.prescription.reason, style: .heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 8)
                if product.hasCompletedCurrentProtocol {
                    GlassPill(text: "Today complete", symbol: "checkmark", tint: AppColors.coral)
                        .padding(.top, 20)
                } else {
                    PrimaryPillButton(title: "Do today's session", symbol: "play.fill") {
                        product.prepareProtocolSession()
                    }
                    .padding(.top, 20)
                }
            }
        }
    }

    private var practiceLibrary: some View {
        VStack(spacing: 12) {
            practiceTile(.stay, tint: AppColors.coral.opacity(0.12), minHeight: 168)
            HStack(alignment: .top, spacing: 12) {
                practiceTile(.recall, tint: Color.blue.opacity(0.09), minHeight: 190)
                practiceTile(.explain, tint: Color.purple.opacity(0.07), minHeight: 190)
            }
            HStack(alignment: .top, spacing: 12) {
                practiceTile(.nothing, tint: Color.mint.opacity(0.09), minHeight: 168)
                practiceTile(.observe, tint: Color.orange.opacity(0.08), minHeight: 168)
            }
        }
    }

    private func practiceTile(_ mode: TrainingMode, tint: Color, minHeight: CGFloat) -> some View {
        Button { selectedMode = mode } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(mode.rawValue, style: .heroMode)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Image(systemName: symbol(for: mode))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.coral)
                }
                Spacer(minLength: 24)
                Text(mode.libraryDescription, style: .heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.leading)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(AppColors.paperRaised.opacity(0.88))
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .appShadow(.soft)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(mode.display). \(mode.libraryDescription)")
    }

    private func symbol(for mode: TrainingMode) -> String {
        switch mode {
        case .stay: return "scope"
        case .recall: return "text.book.closed"
        case .explain: return "quote.bubble"
        case .nothing: return "circle.dotted"
        case .observe: return "eye"
        }
    }
}

private struct ModeIntroductionSheet: View {
    let mode: TrainingMode
    let start: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MetaLabel(text: mode.rawValue, color: AppColors.coral)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 44, height: 44)
                            .background(AppColors.paperRaised)
                            .clipShape(Circle())
                    }
                }
                EditorialHeadline(text: mode.libraryDescription)
                    .padding(.top, 20)
                Text(mode.trains, style: .todaySentence)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 14)
                PaperCard(radius: 26, padding: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        MetaLabel(text: "How it works")
                        Text(howItWorks, style: .heroReason)
                            .foregroundStyle(AppColors.ink)
                    }
                }
                .padding(.top, 28)
                Text("Suggested: \(mode.freeDurations.first ?? 10) min", style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 16)
                Spacer()
                PrimaryPillButton(title: "Start practice", symbol: "play.fill", action: start)
            }
            .padding(24)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
    }

    private var howItWorks: String {
        switch mode {
        case .stay: return "Name one task, define a stopping point, then return whenever you notice a switch."
        case .recall: return "Read your own material, hide it completely, reconstruct it, then compare."
        case .explain: return "Review your material, hide it, teach the idea aloud or in writing, then look back."
        case .nothing: return "Sit, stand or walk slowly for a short period without adding new input."
        case .observe: return "Choose one moment to notice. Observe it without turning the mission into a score."
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
