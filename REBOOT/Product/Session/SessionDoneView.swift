import SwiftUI

struct SessionDoneView: View {
    @ObservedObject var product: ProductStore
    @State private var stage = 0
    @State private var difficulty: Int?
    @State private var energy: Int?
    @State private var distraction: String?
    @State private var switches: Int?
    @State private var firstSwitchTiming: FirstSwitchTiming?
    @State private var recallAssessment: RecallSelfAssessment?
    @State private var missedIdea = ""
    @State private var explanationAssessment: ExplanationSelfAssessment?
    @State private var explanationBreakdown = ""
    @State private var nothingDifficulty: NothingDifficulty?
    @State private var skippedNothingQuestion = false
    @State private var observation = ""
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
                        case 0: completionIntro
                        case 1: questions
                        default: learned
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 16)
                    .padding(.bottom, max(40, geo.safeAreaInsets.bottom) + 20)
                    .animation(.reboot(duration: 0.35), value: stage)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
    }

    private var completionIntro: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: record?.completed == true ? "Session complete" : "Session ended", color: AppColors.coral)
            EditorialHeadline(text: record?.completed == true ? "Done." : "That still tells us something.")
                .padding(.top, 16)
            Text(introCopy, style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 14)
            PrimaryPillButton(title: "Continue") {
                withAnimation(.reboot(duration: 0.35)) { stage = 1 }
            }
            .padding(.top, 30)
        }
    }

    private var introCopy: String {
        guard let record else { return "A truthful record is useful." }
        if record.endedEarly {
            return "You stopped early. The program stays on the same day, and this attempt remains useful evidence."
        }
        switch record.mode {
        case .recall: return "Now describe what came back. This is your assessment, not an automated score."
        case .explain: return "Look at what you could teach, without pretending fluency is a number."
        case .nothing: return "No score. Just notice what made adding nothing difficult."
        case .observe: return record.day == 1 ? "That is your natural baseline. Nothing was optimized first." : "You noticed before trying to change it."
        case .stay: return "The session is now evidence. A few honest details make it useful."
        }
    }

    @ViewBuilder
    private var questions: some View {
        if let record {
            VStack(alignment: .leading, spacing: 0) {
                EditorialHeadline(text: questionTitle(for: record.mode))
                modeQuestions(for: record)
                    .padding(.top, 24)
                environmentQuestions(for: record)
                PrimaryPillButton(title: "Continue", isEnabled: canContinue(record)) {
                    withAnimation(.reboot(duration: 0.35)) { stage = 2 }
                }
                .padding(.top, 32)
            }
        }
    }

    private func questionTitle(for mode: TrainingMode) -> String {
        switch mode {
        case .stay: return "What happened when attention moved?"
        case .recall: return "What came back?"
        case .explain: return "Could you explain the main idea?"
        case .nothing: return "What was hardest?"
        case .observe: return "What did you notice?"
        }
    }

    @ViewBuilder
    private func modeQuestions(for record: SessionRecord) -> some View {
        switch record.mode {
        case .stay:
            attentionQuestions(record: record)
            universalQuestions
        case .observe:
            attentionQuestions(record: record)
            VStack(alignment: .leading, spacing: 10) {
                questionLabel("One observation (optional)")
                TextField("What happened just before the switch?", text: $observation, axis: .vertical)
                    .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                    .padding(18)
                    .background(AppColors.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.top, 24)
            universalQuestions
        case .recall:
            choiceGroup(
                label: "Your honest assessment",
                items: [
                    ("Little came back", RecallSelfAssessment.little),
                    ("Some came back", .some),
                    ("Most came back", .most),
                ],
                selection: $recallAssessment
            )
            optionalField("What did you miss? (optional)", text: $missedIdea)
                .padding(.top, 24)
            universalQuestions
        case .explain:
            choiceGroup(
                label: "Could I explain the main idea?",
                items: [
                    ("Yes", ExplanationSelfAssessment.yes),
                    ("Partly", .partly),
                    ("Not yet", .notYet),
                ],
                selection: $explanationAssessment
            )
            optionalField("What broke down? (optional)", text: $explanationBreakdown)
                .padding(.top, 24)
            universalQuestions
        case .nothing:
            choiceGroup(
                label: "Choose one, or skip",
                items: [
                    ("Urge to check", NothingDifficulty.urgeToCheck),
                    ("Restlessness", .restlessness),
                    ("Thoughts", .thoughts),
                    ("Nothing in particular", .nothingInParticular),
                ],
                selection: $nothingDifficulty
            )
            TonalPillButton(title: "Skip", isSelected: skippedNothingQuestion) {
                skippedNothingQuestion = true
                nothingDifficulty = nil
            }
            .padding(.top, 12)
        }
    }

    private func attentionQuestions(record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            choiceGroup(
                label: "What pulled you away first?",
                items: [
                    ("Notifications", "notifications"),
                    ("Social", "social"),
                    ("My own tabs", "tabs"),
                    ("People or noise", "people"),
                    ("Nothing pulled me", "none"),
                    ("I don't remember", "forgot"),
                ],
                selection: $distraction
            )
            choiceGroup(
                label: "About how many switches?",
                items: [("0–1", 1), ("2–3", 2), ("4–6", 4), ("7+", 7)],
                selection: $switches
            )
            if record.firstSwitchTiming == nil, switches != nil, switches != 0 {
                choiceGroup(
                    label: "When was the first switch?",
                    items: FirstSwitchTiming.allCases.map { ($0.label, $0) },
                    selection: $firstSwitchTiming
                )
            }
        }
    }

    private var universalQuestions: some View {
        VStack(alignment: .leading, spacing: 24) {
            choiceGroup(
                label: "Difficulty",
                items: [("1 · easy", 1), ("2", 2), ("3", 3), ("4", 4), ("5 · hard", 5)],
                selection: $difficulty
            )
            choiceGroup(
                label: "Energy (optional)",
                items: [("1", 1), ("2", 2), ("3", 3), ("4", 4), ("5", 5)],
                selection: $energy
            )
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func environmentQuestions(for record: SessionRecord) -> some View {
        if record.environment?.protectionActivated == true {
            VStack(alignment: .leading, spacing: 24) {
                choiceGroup(
                    label: "Did protection make starting easier?",
                    items: [("Yes", true), ("Not really", false)],
                    selection: $startedEasier
                )
                if record.endedEarly {
                    choiceGroup(
                        label: "Why did protection end?",
                        items: [
                            ("Needed for the task", "task"),
                            ("Needed to communicate", "communicate"),
                            ("Too restrictive", "restrictive"),
                            ("Changed my mind", "mind"),
                        ],
                        selection: $protectionExitReason
                    )
                }
            }
            .padding(.top, 24)
        }
    }

    private func canContinue(_ record: SessionRecord) -> Bool {
        switch record.mode {
        case .stay, .observe:
            return distraction != nil && switches != nil && difficulty != nil
        case .recall:
            return recallAssessment != nil && difficulty != nil
        case .explain:
            return explanationAssessment != nil && difficulty != nil
        case .nothing:
            return nothingDifficulty != nil || skippedNothingQuestion
        }
    }

    private var learned: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: "Evidence saved honestly", color: AppColors.coral)
            EditorialHeadline(text: record?.completed == true ? "What happens next can change." : "The same day waits for you.")
                .padding(.top, 16)
            Text(learnedCopy, style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 16)
            PrimaryPillButton(title: record?.origin == .freeTraining ? "Back to Train" : "Back to Today") {
                save()
            }
            .padding(.top, 32)
        }
    }

    private var learnedCopy: String {
        guard let record else { return "Unknown stays unknown." }
        if !record.completed { return "This attempt is saved, but it does not advance the 90-day program." }
        if record.origin == .freeTraining { return "This practice can inform your profile, but your program day does not move." }
        return "This completed protocol session advances the program by exactly one day."
    }

    private func save() {
        let inferredDifficulty: Int
        if let difficulty {
            inferredDifficulty = difficulty
        } else {
            switch nothingDifficulty {
            case .urgeToCheck, .restlessness: inferredDifficulty = 4
            case .thoughts: inferredDifficulty = 3
            case .nothingInParticular, nil: inferredDifficulty = 2
            }
        }
        product.saveDoneSession(
            SessionReflection(
                difficulty: inferredDifficulty,
                energy: energy,
                firstDistraction: distraction,
                switches: switches,
                firstSwitchTiming: firstSwitchTiming,
                startedEasier: startedEasier,
                protectionExitReason: protectionExitReason,
                recallAssessment: recallAssessment,
                missedIdea: missedIdea.nilIfBlank,
                explanationAssessment: explanationAssessment,
                explanationBreakdown: explanationBreakdown.nilIfBlank,
                nothingDifficulty: nothingDifficulty,
                observation: observation.nilIfBlank
            )
        )
    }

    private func questionLabel(_ text: String) -> some View {
        Text(text, style: .heroGoal)
            .foregroundStyle(AppColors.ink)
    }

    private func choiceGroup<Value: Hashable>(
        label: String,
        items: [(String, Value)],
        selection: Binding<Value?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            questionLabel(label)
            FlowLayout(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    TonalPillButton(title: item.0, isSelected: selection.wrappedValue == item.1) {
                        selection.wrappedValue = item.1
                    }
                }
            }
        }
    }

    private func optionalField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            questionLabel(label)
            TextField("A short note", text: text, axis: .vertical)
                .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                .padding(18)
                .background(AppColors.paperRaised)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
