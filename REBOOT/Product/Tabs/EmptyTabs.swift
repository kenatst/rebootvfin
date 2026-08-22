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
            ModeIntroductionSheet(
                mode: mode,
                experimentCondition: product.nextExperimentCondition(for: mode),
                start: {
                    selectedMode = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        product.prepareFreeTraining(mode)
                    }
                },
                startExperiment: product.canAttachActiveExperiment(to: mode) ? {
                    selectedMode = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        product.prepareFreeTraining(mode, participatingInLab: true)
                    }
                } : nil
            )
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
    let experimentCondition: String?
    let start: () -> Void
    let startExperiment: (() -> Void)?
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
                if let experimentCondition, let startExperiment {
                    VStack(alignment: .leading, spacing: 10) {
                        MetaLabel(text: "Active Personal Lab test", color: AppColors.coral)
                        Text(experimentCondition, style: .footnote)
                            .foregroundStyle(AppColors.inkSoft)
                        Button(action: startExperiment) {
                            GlassPill(text: "Use test condition", symbol: "arrow.left.arrow.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                    .padding(.top, 14)
                }
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

// MARK: - Profile & Attention Map

/// Real profile data only — unknowns stay unknown, every fact keeps its source.
struct ProfileTab: View {
    @ObservedObject var product: ProductStore
    @State private var selectedRule: PersonalRule?
    @State private var showAddRule = false
    @State private var selectedLabExperiment: PersonalExperiment?

    private var profile: AttentionProfile { product.profile }
    private var isSparse: Bool { product.sessions.count < 3 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(text: "Attention Map", color: AppColors.coral)
                        EditorialHeadline(text: "What reboot knows.")
                            .padding(.top, 14)
                        Text(
                            "Only what you've told us and what sessions have shown. Unknown stays unknown.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 8)

                        // Hero summary card
                        overviewCard
                            .padding(.top, 24)

                        personalLabSection
                            .padding(.top, 32)

                        energyContextSection
                            .padding(.top, 32)

                        // Personal Rules Section
                        personalRulesSection
                            .padding(.top, 32)

                        // Focus Span & Stability Section
                        focusSpanSection
                            .padding(.top, 32)

                        // Distraction & Friction Section
                        distractionSection
                            .padding(.top, 32)

                        // Digital Environment Dynamics Section
                        environmentDynamicsSection
                            .padding(.top, 32)

                        footerNote
                            .padding(.top, 28)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, 160)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedRule) { rule in
            WhyThisRuleSheet(rule: rule, product: product)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddRule) {
            AddCustomRuleSheet(product: product)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedLabExperiment) { experiment in
            ExperimentDetailView(product: product, experimentID: experiment.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.valueAfter("-qaSeed") == "rulesWhyThisRule",
               selectedRule == nil {
                selectedRule = product.personalRules.first
            }
        }
    }

    // MARK: - Personal Lab

    private var personalLabSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel(text: "Still learning · Personal Lab", color: AppColors.coral)
                Spacer()
                Button { product.openPersonalLab() } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Open Personal Lab")
            }

            if let active = product.activeExperiment {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassPill(
                            text: "\(active.completePairCount) of \(active.plan.targetPairs) comparisons",
                            tint: AppColors.coral
                        )
                        Text(active.question, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Button { product.openPersonalLab() } label: {
                            GlassPill(text: "Continue test", symbol: "chevron.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            } else if let useful = product.pastExperiments.first(where: { $0.result?.state == .keep }) {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        MetaLabel(text: "What seems to help")
                        Text(useful.testArm.condition.title, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text("Repeated experiment signal", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                        Button { selectedLabExperiment = useful } label: {
                            GlassPill(text: "View test", symbol: "chevron.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            } else if let suggestion = profileLabSuggestions.first {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.template.question, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(suggestion.reason, style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                        Button { product.openPersonalLab() } label: {
                            GlassPill(text: "Test this", symbol: "arrow.right", tint: AppColors.coral)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            } else {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isSparse ? "A little evidence first." : "Nothing urgent to test.", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(isSparse
                            ? "Useful comparisons appear after a few real sessions."
                            : "Open Lab whenever you want to browse or create a test.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }
        }
    }

    private var profileLabSuggestions: [ExperimentSuggestion] {
        let environment = profile.environmentEvidence
        return product.labSuggestions(
            screenTimeAvailable: environment?.screenTimeConnected == true && environment?.hasSelection == true
        )
    }

    // MARK: - Energy & Context (Fuel)

    private var energyContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel(text: "Energy & Context", color: AppColors.coral)
                Spacer()
                Button { product.openFuel() } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Open Fuel")
            }

            let analysis = product.fuelAnalysis
            if let pattern = analysis.patterns.first(where: { $0.dimension == .energy }) ?? analysis.patterns.first {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassPill(text: pattern.maturity.label, tint: AppColors.coral)
                        Text(pattern.statement, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Button { product.openFuel() } label: {
                            GlassPill(text: "Open Fuel", symbol: "chevron.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Energy context. \(pattern.maturity.label). \(pattern.statement)")
            } else {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            product.fuelLinkedSessions.isEmpty
                                ? "REBOOT is still learning how daily context interacts with your sessions."
                                : "No stable context pattern yet — that is an honest result.",
                            style: .heroReason
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        Button { product.openFuel() } label: {
                            GlassPill(text: "Open Fuel", symbol: "chevron.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    // MARK: - Overview card

    private var overviewCard: some View {
        LiquidCard(radius: 28, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        MetaLabel(text: "Primary Goal", color: AppColors.coral)
                        Text(profileText(profile.primaryGoal.value))
                            .type(.calendarMeta)
                            .foregroundStyle(AppColors.ink)
                    }
                    Spacer()
                    GlassPill(
                        text: isSparse ? "Learning baseline" : "\(product.sessions.count) sessions",
                        tint: isSparse ? AppColors.coral : AppColors.ink
                    )
                }

                Divider().overlay(AppColors.hairline)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        MetaLabel(text: "Window")
                        Text(profile.focusWindowMinutes.map { "\($0) min" } ?? "Measuring...")
                            .type(.calendarMeta)
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        MetaLabel(text: "Stability")
                        Text(levelText(profile.attentionStability))
                            .type(.calendarMeta)
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        MetaLabel(text: "Return")
                        Text(levelText(profile.returnAfterDistraction))
                            .type(.calendarMeta)
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Personal Rules Section

    private var personalRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel(text: "Personal Rules", color: AppColors.coral)
                Spacer()
                Button {
                    showAddRule = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add rule")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.coral)
                }
            }

            if product.personalRules.isEmpty {
                PaperCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No rules active yet", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(
                            isSparse
                                ? "As sessions repeat, reboot discovers friction and conditions that support your focus."
                                : "Add custom rules or test suggestions that appear from your sessions.",
                            style: .heroReason
                        )
                        .foregroundStyle(AppColors.inkSoft)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(product.personalRules) { rule in
                        Button {
                            selectedRule = rule
                        } label: {
                            ruleRow(rule)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: PersonalRule) -> some View {
        PaperCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GlassPill(
                        text: rule.lifecycle.displayLabel,
                        tint: rule.lifecycle == .kept ? AppColors.coral : (rule.lifecycle == .testing ? AppColors.ink : AppColors.inkFaint)
                    )
                    Spacer()
                    Text(rule.recencyStatus.humanLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.inkFaint)
                }

                Text(rule.title, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(rule.sourceType.displayLabel)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.inkFaint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Focus Span & Stability

    private var focusSpanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Focus Span & Stability")

            if isSparse {
                PaperCard(radius: 22, padding: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        MetaLabel(text: "Awaiting baseline evidence", color: AppColors.inkFaint)
                        Text("Initial protocol sessions measure how long focus stays before an urge or task switch occurs.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    dimensionCard(
                        title: "Observed Focus Window",
                        value: profile.focusWindowMinutes.map { "\($0) minutes max continuous block" } ?? "Unknown",
                        source: "Observed from sessions"
                    )
                    dimensionCard(
                        title: "Switch Pattern",
                        value: switchPatternDescription,
                        source: "Measured across protocol days"
                    )
                    dimensionCard(
                        title: "Attention Stability",
                        value: levelText(profile.attentionStability),
                        source: profile.attentionStability.source?.label ?? "Self-reported"
                    )
                    dimensionCard(
                        title: "Return After Distraction",
                        value: levelText(profile.returnAfterDistraction),
                        source: profile.returnAfterDistraction.source?.label ?? "Self-reported"
                    )
                    Button { product.openFuel() } label: {
                        dimensionCard(
                            title: "Energy Context",
                            value: energyContextValue,
                            source: "From Fuel observations"
                        )
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("Energy context. \(energyContextValue). Opens Fuel.")
                }
            }
        }
    }

    // MARK: - Distraction & Triggers

    private var distractionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Distraction & Friction")

            VStack(spacing: 10) {
                dimensionCard(
                    title: "Reported Distractors",
                    value: profileList(profile.distractors.value),
                    source: profile.distractors.source?.label ?? "Self-reported"
                )
                if !isSparse {
                    dimensionCard(
                        title: "Observed Switch Triggers",
                        value: observedDistractorSummary,
                        source: "Session logs"
                    )
                }
            }
        }
    }

    // MARK: - Digital Environment Dynamics

    private var environmentDynamicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Digital Environment")

            let env = profile.environmentEvidence
            let isConnected = env?.screenTimeConnected == true

            PaperCard(radius: 22, padding: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        MetaLabel(text: "Screen Time Intervention", color: isConnected ? AppColors.coral : AppColors.inkFaint)
                        Spacer()
                        GlassPill(
                            text: isConnected ? "System-confirmed" : "Unconnected",
                            tint: isConnected ? AppColors.coral : AppColors.inkFaint
                        )
                    }

                    if isConnected {
                        Text("Active app protection and scheduled windows are supported by device policies.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    } else {
                        Text("Physical friction (phone outside reach) operates via self-reported manual verification.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("Sessions: \(product.sessions.count) · Evidence is strictly self-reported, observed, or from a session. No artificial scores.")
            .type(.footnote)
            .foregroundStyle(AppColors.inkFaint)
    }

    // MARK: - Helpers

    private func dimensionCard(title: String, value: String, source: String) -> some View {
        PaperCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    MetaLabel(text: title, color: AppColors.inkFaint)
                    Spacer()
                    Text(source)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppColors.inkFaint)
                }
                Text(value)
                    .type(.calendarMeta)
                    .foregroundStyle(AppColors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var switchPatternDescription: String {
        let early = product.sessions.filter { $0.firstSwitchTiming == .underFive }.count
        let mid = product.sessions.filter { $0.firstSwitchTiming == .fiveToTen || $0.firstSwitchTiming == .tenToTwenty }.count
        if early > mid && early >= 2 {
            return "Switches typically occur early (< 5 min)"
        } else if mid >= 2 {
            return "Initial focus holds 10–20 min before switching"
        }
        return "Steady return pattern across sessions"
    }

    /// Attention Map Energy Context: meaningful only when Fuel evidence
    /// exists; otherwise honestly unknown.
    private var energyContextValue: String {
        let analysis = product.fuelAnalysis
        if let pattern = analysis.patterns.first(where: { $0.dimension == .energy }) {
            return "\(pattern.maturity.label) — \(pattern.statement)"
        }
        if product.fuelLinkedSessions.isEmpty {
            return "Still learning"
        }
        return "No stable pattern yet"
    }

    private var observedDistractorSummary: String {
        let distractors = product.sessions.compactMap(\.firstDistraction).filter { $0 != "none" }
        if distractors.isEmpty { return "None observed repeatedly" }
        let counts = Dictionary(grouping: distractors, by: { $0 }).mapValues(\.count)
        let sorted = counts.sorted { $0.value > $1.value }
        return sorted.prefix(2).map { "\($0.key.capitalized) (\($0.value) sessions)" }.joined(separator: ", ")
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

// MARK: - Why This Rule? Editorial Sheet

struct WhyThisRuleSheet: View {
    let rule: PersonalRule
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRuleException = false
    @State private var showActiveWarning = false
    @State private var showLinkedExperiment = false

    private var explanation: WhyThisRuleExplanation { rule.whyRebootSuggested }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            MetaLabel(text: rule.category.rawValue, color: AppColors.coral)
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

                        EditorialHeadline(text: rule.title)
                            .padding(.top, 14)

                        Text(rule.detail, style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 8)

                        // Section 1: Why Reboot Suggested This / Created by you
                        VStack(alignment: .leading, spacing: 10) {
                            MetaLabel(text: explanation.sourceDescription)
                                .padding(.top, 24)

                            if rule.sourceType == .userCreated {
                                Text("This rule was created directly by you. It is applied when matching session contexts occur.", style: .heroReason)
                                    .foregroundStyle(AppColors.ink)
                            } else {
                                ForEach(explanation.supportingPoints, id: \.self) { point in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppColors.coral)
                                            .padding(.top, 3)
                                        Text(point, style: .heroReason)
                                            .foregroundStyle(AppColors.ink)
                                    }
                                }
                            }
                        }

                        // Section 2: Contradiction if present
                        if let contradiction = explanation.contradictionPoint {
                            VStack(alignment: .leading, spacing: 8) {
                                MetaLabel(text: "Mixed Evidence", color: AppColors.coral)
                                    .padding(.top, 20)
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppColors.coral)
                                        .padding(.top, 3)
                                    Text(contradiction, style: .heroReason)
                                        .foregroundStyle(AppColors.inkSoft)
                                }
                            }
                        }

                        // Section 3: Maturity & Recency
                        VStack(alignment: .leading, spacing: 6) {
                            MetaLabel(text: "Evidence & Recency")
                                .padding(.top, 20)
                            Text(explanation.maturityAndRecency, style: .footnote)
                                .foregroundStyle(AppColors.ink)
                        }

                        // Section 4: Disclaimer
                        Text(explanation.disclaimer, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 18)

                        if let experimentID = rule.experimentID,
                           product.experiment(id: experimentID) != nil {
                            Button { showLinkedExperiment = true } label: {
                                GlassPill(text: "View test", symbol: "arrow.up.right", tint: AppColors.ink)
                            }
                            .buttonStyle(PressScaleStyle())
                            .padding(.top, 18)
                        }

                        // Actions
                        VStack(spacing: 12) {
                            if rule.lifecycle == .candidate || rule.lifecycle == .testing {
                                PrimaryPillButton(title: "Keep this rule", symbol: "checkmark") {
                                    product.keepPersonalRule(id: rule.id)
                                    dismiss()
                                }
                                if rule.lifecycle == .candidate {
                                    Button {
                                        startRuleTest(allowingRuleExceptions: false)
                                    } label: {
                                        GlassPill(text: "Test in Personal Lab", symbol: "play.circle", tint: AppColors.ink)
                                    }
                                }
                                Button {
                                    product.rejectPersonalRule(id: rule.id)
                                    dismiss()
                                } label: {
                                    Text("Dismiss suggestion")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppColors.inkFaint)
                                }
                                .padding(.top, 4)
                            } else if rule.lifecycle == .kept {
                                HStack(spacing: 12) {
                                    Button {
                                        startRuleTest(allowingRuleExceptions: false)
                                    } label: {
                                        GlassPill(text: "Test again", symbol: "arrow.counterclockwise", tint: AppColors.ink)
                                    }
                                    Button {
                                        product.retirePersonalRule(id: rule.id)
                                        dismiss()
                                    } label: {
                                        GlassPill(text: "Retire rule", symbol: "archivebox", tint: AppColors.inkFaint)
                                    }
                                }
                            } else if rule.lifecycle == .retired {
                                PrimaryPillButton(title: "Re-activate rule", symbol: "arrow.counterclockwise") {
                                    product.keepPersonalRule(id: rule.id)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.top, 28)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 10)
                    .padding(.bottom, 36)
                }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Temporary rule exception", isPresented: $showRuleException, titleVisibility: .visible) {
            Button("Allow temporary test exception") {
                startRuleTest(allowingRuleExceptions: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Normal condition needs a few sessions without this kept rule. The rule remains kept.")
        }
        .alert("One active test at a time", isPresented: $showActiveWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pause your current test before starting another.")
        }
        .sheet(isPresented: $showLinkedExperiment) {
            if let experimentID = rule.experimentID {
                ExperimentDetailView(product: product, experimentID: experimentID)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func startRuleTest(allowingRuleExceptions: Bool) {
        let outcome = product.startExperimentForRule(
            id: rule.id,
            allowingRuleExceptions: allowingRuleExceptions
        )
        switch outcome {
        case .started:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                product.openPersonalLab()
            }
        case .needsRuleException:
            showRuleException = true
        case .activeExperimentExists:
            showActiveWarning = true
        case .unavailable:
            product.testPersonalRule(id: rule.id)
            dismiss()
        }
    }
}

// MARK: - Add Custom Rule Sheet

struct AddCustomRuleSheet: View {
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var category: RuleCategory = .environment
    @State private var selectedContext: RuleContext = .stay

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            MetaLabel(text: "New Personal Rule", color: AppColors.coral)
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.inkFaint)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(AppColors.ink.opacity(0.05)))
                            }
                        }

                        EditorialHeadline(text: "Create a rule.")
                            .padding(.top, 14)

                        MetaLabel(text: "Rule title")
                            .padding(.top, 20)
                        TextField("e.g. Leave phone outside room during Stay", text: $title)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(AppColors.paperRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 6)

                        MetaLabel(text: "Detail / intention")
                            .padding(.top, 16)
                        TextField("e.g. Physical distance prevents reaching for feeds.", text: $detail)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(AppColors.paperRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 6)

                        MetaLabel(text: "Category")
                            .padding(.top, 16)
                        Picker("Category", selection: $category) {
                            ForEach(RuleCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 6)

                        MetaLabel(text: "Applies to")
                            .padding(.top, 16)
                        Picker("Context", selection: $selectedContext) {
                            Text("Stay sessions").tag(RuleContext.stay)
                            Text("Recall sessions").tag(RuleContext.recall)
                            Text("Deep work").tag(RuleContext.deepWork)
                            Text("All sessions").tag(RuleContext.general)
                        }
                        .pickerStyle(.menu)
                        .padding(.top, 6)

                        PrimaryPillButton(title: "Save rule", symbol: "checkmark") {
                            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            product.addCustomPersonalRule(
                                title: title.trimmingCharacters(in: .whitespaces),
                                detail: detail.isEmpty ? title : detail,
                                category: category,
                                contexts: [selectedContext]
                            )
                            dismiss()
                        }
                        .padding(.top, 28)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 10)
                    .padding(.bottom, 36)
                }
            }
            .ignoresSafeArea()
        }
    }
}
