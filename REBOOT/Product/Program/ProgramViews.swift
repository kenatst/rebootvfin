import SwiftUI

struct ProgramTab: View {
    @ObservedObject var product: ProductStore

    private var phase: ProgramPhase { product.currentProgramPhase }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Program", color: AppColors.coral)
                        EditorialHeadline(
                            text: product.programStatus == .completed
                                ? "90 days complete."
                                : "90 days, built around you."
                        )
                        .padding(.top, 14)

                        phaseHero
                            .padding(.top, 26)

                        MetaLabel(text: "Current focus")
                            .padding(.top, 34)
                        currentFocus
                            .padding(.top, 12)

                        MetaLabel(text: "Your path")
                            .padding(.top, 38)
                        phasePath
                            .padding(.top, 18)

                        MetaLabel(text: "Recent learning")
                            .padding(.top, 36)
                        recentLearning
                            .padding(.top, 12)

                        MetaLabel(text: product.programStatus == .completed ? "Coming next" : "Next checkpoint")
                            .padding(.top, 34)
                        nextCheckpoint
                            .padding(.top, 12)

                        if !recentHistory.isEmpty {
                            MetaLabel(text: "Recent protocol days")
                                .padding(.top, 34)
                            history
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 160)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var phaseHero: some View {
        LiquidCard(radius: 30, padding: 22) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        MetaLabel(
                            text: product.isCalibrating
                                ? "Calibrating"
                                : "Phase \(phase.number)",
                            color: AppColors.coral
                        )
                        Text(phase.title, style: .reportTitle)
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    ProgressRing(progress: product.programProgress, size: 62, lineWidth: 5)
                        .accessibilityLabel("\(product.completedProtocolDays) of 90 program days completed")
                }

                Text(String(format: "DAY %03d / 090", product.day))
                    .type(.calendarMeta)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 20)

                Text(
                    product.programStatus == .completed
                        ? "The program is complete. Train remains available whenever a specific skill needs practice."
                        : phase.description,
                    style: .heroReason
                )
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 8)

                Text("\(product.completedProtocolDays) protocol days completed")
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 14)
            }
        }
    }

    private var currentFocus: some View {
        PaperCard(radius: 26, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(phase.priorities.prefix(3)), id: \.self) { priority in
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: priority))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.coral)
                            .frame(width: 22)
                        Text(priority.title, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
    }

    private var phasePath: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ProgramPhase.all.enumerated()), id: \.element.id) { index, item in
                let state = visualState(for: item)
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(state == .current ? AppColors.coral : AppColors.paperRaised)
                                .frame(width: 28, height: 28)
                            if state == .completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppColors.coral)
                            } else {
                                Text("\(item.number)")
                                    .type(.footnote)
                                    .foregroundStyle(state == .current ? AppColors.paper : AppColors.inkFaint)
                            }
                        }
                        if index < ProgramPhase.all.count - 1 {
                            Rectangle()
                                .fill(state == .completed ? AppColors.coral.opacity(0.35) : AppColors.hairline)
                                .frame(width: 1, height: 72)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title, style: .heroGoal)
                                .foregroundStyle(state == .upcoming ? AppColors.inkSoft : AppColors.ink)
                            Spacer()
                            Text(state.label.uppercased())
                                .type(.footnote)
                                .foregroundStyle(state == .current ? AppColors.coral : AppColors.inkFaint)
                        }
                        Text(item.description, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 24)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Phase \(item.number), \(item.title), \(state.label)")
            }
        }
    }

    @ViewBuilder
    private var recentLearning: some View {
        if product.programInsights.isEmpty {
            Text("REBOOT is still learning which patterns repeat.", style: .heroReason)
                .foregroundStyle(AppColors.inkSoft)
        } else {
            VStack(spacing: 10) {
                ForEach(product.programInsights.prefix(2)) { insight in
                    PaperCard(radius: 22, padding: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            MetaLabel(
                                text: insight.confidence == .earlySignal ? "Early signal" : "Repeated signal",
                                color: AppColors.coral
                            )
                            Text(insight.text, style: .insightQuote)
                                .foregroundStyle(AppColors.ink)
                        }
                    }
                }
            }
        }
    }

    private var nextCheckpoint: some View {
        LiquidCard(radius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 7) {
                if product.programStatus == .completed {
                    Text("Your Attention Operating Manual", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text("Coming next. The history and self-reports needed for it are preserved.", style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                } else if let remaining = product.sessionsUntilNextCheckpoint,
                          let checkpoint = product.nextCheckpointDay {
                    Text(checkpoint == 7 ? "Your first review" : "Review after Day \(checkpoint)", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text(checkpointCopy(remaining), style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                } else {
                    Text("Final synthesis", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text("\(max(0, 90 - product.completedProtocolDays)) protocol sessions remain. Ready when you are.", style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
        }
    }

    private var history: some View {
        VStack(spacing: 0) {
            ForEach(Array(recentHistory.enumerated()), id: \.element.id) { index, session in
                HStack(spacing: 12) {
                    Text(String(format: "Day %02d", session.day))
                        .type(.calendarMeta)
                        .foregroundStyle(AppColors.ink)
                    Text(session.mode.rawValue)
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkFaint)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.coral)
                }
                .padding(.vertical, 12)
                if index < recentHistory.count - 1 {
                    Divider().overlay(AppColors.hairline)
                }
            }
        }
    }

    private var recentHistory: [SessionRecord] {
        var seen: Set<Int> = []
        return product.completedProtocolSessions
            .sorted { $0.day > $1.day }
            .filter { seen.insert($0.day).inserted }
            .prefix(5)
            .map { $0 }
    }

    private func checkpointCopy(_ remaining: Int) -> String {
        if remaining == 1 { return "One protocol session until a short review. No deadline." }
        return "\(remaining) protocol sessions until a short review. No deadline."
    }

    private func visualState(for item: ProgramPhase) -> PhaseVisualState {
        if product.programStatus == .completed || item.number < phase.number { return .completed }
        if item.id == phase.id { return .current }
        return .upcoming
    }

    private func symbol(for priority: ProgramSkillPriority) -> String {
        switch priority {
        case .notice: return "eye"
        case .stay: return "scope"
        case .returnToTask: return "arrow.uturn.backward"
        case .reduceInput: return "rectangle.compress.vertical"
        case .recall: return "text.book.closed"
        case .explain: return "quote.bubble"
        case .tolerateStillness: return "circle.dotted"
        case .depth: return "arrow.down.to.line"
        case .conditions: return "slider.horizontal.3"
        case .independentSetup: return "checkmark.circle"
        }
    }
}

private enum PhaseVisualState {
    case completed
    case current
    case upcoming

    var label: String {
        switch self {
        case .completed: return "completed"
        case .current: return "current"
        case .upcoming: return "upcoming"
        }
    }
}

struct WeeklyReviewView: View {
    @ObservedObject var product: ProductStore
    let checkpointDay: Int
    @State private var helpedMost = ""
    @State private var stillBreaks = ""
    @State private var nextTest = ""

    private var insights: [ProgramInsight] {
        ProgramInsightEngine.insights(
            from: product.protocolSessions.filter { $0.day <= checkpointDay }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Program review", color: AppColors.coral)
                        EditorialHeadline(text: checkpointDay == 7 ? "Your first week." : "A short review.")
                            .padding(.top, 16)
                        Text("This review belongs to Day \(checkpointDay). It never adds another program day.", style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 12)

                        MetaLabel(text: "What changed?")
                            .padding(.top, 30)
                        reviewInsights
                            .padding(.top, 12)

                        reviewQuestions
                            .padding(.top, 30)

                        PrimaryPillButton(title: "Save review", symbol: "checkmark") {
                            product.saveWeeklyReview(answers)
                        }
                        .padding(.top, 30)

                        Button("Skip questions") {
                            product.skipWeeklyReviewQuestions()
                        }
                        .type(.smallLink)
                        .foregroundStyle(AppColors.inkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 16)
                    .padding(.bottom, max(40, geo.safeAreaInsets.bottom) + 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var reviewInsights: some View {
        if insights.isEmpty {
            Text("We're still learning which changes matter most.", style: .insightQuote)
                .foregroundStyle(AppColors.ink)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights.prefix(2)) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppColors.coral)
                            .frame(width: 6, height: 6)
                            .padding(.top, 9)
                        Text(insight.text, style: .heroReason)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
    }

    private var reviewQuestions: some View {
        VStack(alignment: .leading, spacing: 22) {
            switch (checkpointDay / 7) % 3 {
            case 1:
                reviewField("What helped most?", placeholder: "Optional", text: $helpedMost)
                reviewField("What still gets in the way?", placeholder: "Optional", text: $stillBreaks)
            case 2:
                reviewField("What helped most?", placeholder: "Optional", text: $helpedMost)
                reviewField("What should REBOOT test next?", placeholder: "Optional", text: $nextTest)
            default:
                reviewField("What still gets in the way?", placeholder: "Optional", text: $stillBreaks)
                reviewField("What should REBOOT test next?", placeholder: "Optional", text: $nextTest)
            }
        }
    }

    private func reviewField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            TextField(placeholder, text: text, axis: .vertical)
                .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                .padding(18)
                .background(AppColors.paperRaised)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var answers: WeeklyReviewAnswers {
        WeeklyReviewAnswers(
            helpedMost: helpedMost.nilIfBlank,
            stillBreaksAttention: stillBreaks.nilIfBlank,
            nextTestPreference: nextTest.nilIfBlank
        )
    }
}

struct ProgramPhaseTransitionView: View {
    @ObservedObject var product: ProductStore
    let phaseID: ProgramPhaseID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase: ProgramPhase { ProgramPhase.all.first { $0.id == phaseID } ?? ProgramPhase.all[0] }

    var body: some View {
        GeometryReader { geo in
            let topPadding = max(20, geo.safeAreaInsets.top) + 24
            let bottomPadding = max(28, geo.safeAreaInsets.bottom) + 12
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Phase \(phase.number)", color: AppColors.coral)
                        EditorialHeadline(text: phase.title)
                            .padding(.top, 18)
                        Text(transitionCopy, style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 16)

                        PaperCard(radius: 24, padding: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                MetaLabel(text: "What the evidence says")
                                Text(learningCopy, style: .insightQuote)
                                    .foregroundStyle(AppColors.ink)
                            }
                        }
                        .padding(.top, 28)

                        Spacer(minLength: 30)
                        PrimaryPillButton(title: "Continue", symbol: "arrow.right") {
                            product.acknowledgePhaseTransition()
                        }
                    }
                    .frame(
                        minHeight: max(0, geo.size.height - topPadding - bottomPadding),
                        alignment: .top
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .ignoresSafeArea()
        }
    }

    private var transitionCopy: String {
        switch phaseID {
        case .controlInput:
            return "You've spent seven protocol sessions noticing what pulls you away. Now we start changing the environment — gently."
        case .buildStability:
            return "You have made more space. Now the work is continuity: staying, noticing, and returning."
        case .deepen:
            return "Staying is only the beginning. This phase uses attention to understand and remember more deeply."
        case .findConditions:
            return "Now we look for conditions associated with deeper absorption, without promising or scoring flow."
        case .ownSystem:
            return "The direction becomes lighter. Choose what works, test what remains weak, and make the setup your own."
        case .calibrate:
            return phase.description
        }
    }

    private var learningCopy: String {
        product.programInsights.first?.text
            ?? "We're still learning which changes matter most."
    }
}

struct ProgramCompletionView: View {
    @ObservedObject var product: ProductStore

    var body: some View {
        GeometryReader { geo in
            let topPadding = max(20, geo.safeAreaInsets.top) + 24
            let bottomPadding = max(28, geo.safeAreaInsets.bottom) + 12
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Program complete", color: AppColors.coral)
                        EditorialHeadline(text: "90 days complete.")
                            .padding(.top, 18)
                        Text(
                            "The program stops here. Train remains available, and the evidence stays ready for what comes next.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 16)

                        PaperCard(radius: 26, padding: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                MetaLabel(text: "Coming next")
                                Text("Your Attention Operating Manual", style: .cardTitle)
                                    .foregroundStyle(AppColors.ink)
                                Text("No report is invented here. The next pass can build it from your real protocol history and reviews.", style: .heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                        }
                        .padding(.top, 30)

                        Spacer(minLength: 30)
                        PrimaryPillButton(title: "Continue", symbol: "checkmark") {
                            product.acknowledgeProgramCompletion()
                        }
                    }
                    .frame(
                        minHeight: max(0, geo.size.height - topPadding - bottomPadding),
                        alignment: .top
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
