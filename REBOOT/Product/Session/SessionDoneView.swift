import SwiftUI

/// Lightweight post-session transition — "Done.", one reflection, 1–3 questions,
/// then a concise adaptive insight. No stats dashboard.
struct SessionDoneView: View {
    @ObservedObject var product: ProductStore
    @State private var stage = 0
    @State private var difficultyText: String?
    @State private var distraction: String?
    @State private var switchesText: String?
    @State private var energyText: String?
    @State private var startedEasier: Bool?
    @State private var protectionExitReason: String?

    private var record: SessionRecord? {
        if case .done(let record) = product.phase { return record }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch stage {
                        case 0: doneStage
                        case 1: questionsStage
                        default: insightStage
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 16)
                    .padding(.bottom, 60)
                    .animation(.reboot(duration: 0.35), value: stage)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Stage 0: Done.

    private var doneStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: "Session complete", color: AppColors.coral)
            EditorialHeadline(text: "Done.")
                .padding(.top, 16)
            Text(reflection, style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 12)
            Text("Three honest answers are worth more than a perfect score.")
                .type(.heroReason)
                .foregroundStyle(AppColors.inkFaint)
                .padding(.top, 18)

            PrimaryPillButton(title: "Continue") {
                withAnimation(.reboot(duration: 0.35)) { stage = 1 }
            }
            .padding(.top, 30)
        }
    }

    private var reflection: String {
        guard let record else { return "You showed up for yourself." }
        if record.endedEarly {
            return "You gave it a real attempt — that still teaches us something."
        }
        if record.mode == .observe {
            return "That's your baseline. It's the most honest number we have."
        }
        return "That block is now evidence — it will shape tomorrow."
    }

    // MARK: - Stage 1: Questions

    private var questionsStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialHeadline(text: "How did it feel?")

            questionLabel("Difficulty")
            pillRow(items: ["1 · easy", "2", "3", "4", "5 · hard"], selected: difficultyText) { value in
                difficultyText = value
            }
            .padding(.top, 14)

            questionLabel("What pulled you away first?")
                .padding(.top, 28)
            wrapChips(items: [
                ("Notifications", "notifications"),
                ("Social", "social"),
                ("My own tabs", "tabs"),
                ("People or noise", "people"),
                ("Nothing pulled me", "none"),
                ("I don't remember", "forgot"),
            ], selected: distraction) { value in
                distraction = value
            }
            .padding(.top, 14)

            questionLabel("About how many switches?")
                .padding(.top, 28)
            pillRow(items: ["0–1", "2–3", "4–6", "7+"], selected: switchesText) { value in
                switchesText = value
            }
            .padding(.top, 14)

            questionLabel("Energy (optional)")
                .padding(.top, 28)
            pillRow(items: ["Skip", "1", "2", "3", "4", "5"], selected: energyText) { value in
                energyText = value == "Skip" ? nil : value
            }
            .padding(.top, 14)

            if record?.environment?.protectionActivated == true {
                questionLabel("Did protecting these apps make starting easier?")
                    .padding(.top, 28)
                pillRow(items: ["Yes", "Not really", "Not sure"], selected: startedEasierText) { value in
                    startedEasier = value == "Yes" ? true : (value == "Not really" ? false : nil)
                }
                .padding(.top, 14)

                if record?.endedEarly == true {
                    questionLabel("Why did you stop protection?")
                        .padding(.top, 28)
                    wrapChips(items: [
                        ("Needed for the task", "task"),
                        ("Needed to communicate", "communicate"),
                        ("Too restrictive", "restrictive"),
                        ("Changed my mind", "mind"),
                        ("Other", "other"),
                        ("Skip", "skip"),
                    ], selected: protectionExitReason) { value in
                        protectionExitReason = value == "skip" ? nil : value
                    }
                    .padding(.top, 14)
                }
            }

            PrimaryPillButton(
                title: "Continue",
                isEnabled: difficultyText != nil && distraction != nil && switchesText != nil
            ) {
                withAnimation(.reboot(duration: 0.35)) { stage = 2 }
            }
            .padding(.top, 32)
        }
    }

    private func questionLabel(_ text: String) -> some View {
        Text(text, style: .heroGoal)
            .foregroundStyle(AppColors.ink)
    }

    private func pillRow(items: [String], selected: String?, onSelect: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                TonalPillButton(
                    title: item,
                    isSelected: selected == item
                ) {
                    onSelect(item)
                }
            }
        }
    }

    private func wrapChips(items: [(String, String)], selected: String?, onSelect: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.1) { item in
                TonalPillButton(title: item.0, isSelected: selected == item.1) {
                    onSelect(item.1)
                }
            }
        }
    }

    // MARK: - Stage 2: Learned something

    private var insightStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: "What reboot learned", color: AppColors.coral)
            EditorialHeadline(text: "REBOOT learned something.")
                .padding(.top, 16)

            Text(insightText, style: .insightQuote)
                .foregroundStyle(AppColors.ink)
                .padding(.top, 18)

            PrimaryPillButton(title: "Back to Today") {
                saveAndReturn()
            }
            .padding(.top, 32)
        }
    }

    private var insightText: String {
        guard let record else { return "Every session counts." }
        var sessions = product.sessions
        sessions.append(record)
        return InsightEngine.insights(profile: product.profile, sessions: sessions).first
            ?? "Not enough evidence yet — but every session makes the next one smarter."
    }

    private func saveAndReturn() {
        let difficulty = Int((difficultyText ?? "3").prefix(1)) ?? 3
        let switches: Int? = switch switchesText {
        case "0–1": 1
        case "2–3": 2
        case "4–6": 4
        case "7+": 7
        default: nil
        }
        product.saveDoneSession(
            difficulty: difficulty,
            firstDistraction: distraction,
            switches: switches,
            firstSwitchMinute: nil,
            energy: energyText.flatMap(Int.init),
            environmentActionDone: nil,
            startedEasier: startedEasier,
            protectionExitReason: protectionExitReason
        )
    }

    private var startedEasierText: String? {
        guard let startedEasier else { return nil }
        return startedEasier ? "Yes" : "Not really"
    }
}
