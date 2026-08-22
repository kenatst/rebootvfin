import SwiftUI

private struct LabTemplateSelection: Identifiable {
    var id: String { "\(template.id).\(linkedRuleID?.uuidString ?? "new")" }
    var template: ExperimentTemplate
    var linkedRuleID: UUID?
}

private struct LabExperimentSelection: Identifiable {
    var id: UUID
}

// MARK: - Personal Lab home

struct PersonalLabView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var selectedTemplate: LabTemplateSelection?
    @State private var selectedExperiment: LabExperimentSelection?
    @State private var showLibrary = false
    @State private var showCustom = false

    private var suggestions: [ExperimentSuggestion] {
        product.labSuggestions(
            screenTimeAvailable: environmentStore.isConnected && environmentStore.selection != nil
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        MetaLabel(text: "Lab", color: AppColors.coral)
                            .padding(.top, 20)
                        EditorialHeadline(text: "Test what works.")
                            .padding(.top, 12)
                        Text("Compare a few real sessions. Keep only what earns its place.", style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 8)

                        if let active = product.activeExperiment {
                            activeSection(active)
                                .padding(.top, 30)
                        } else if let paused = product.pausedExperiment {
                            pausedSection(paused)
                                .padding(.top, 30)
                        }

                        worthTestingSection
                            .padding(.top, 34)

                        if !product.pastExperiments.isEmpty {
                            pastTestsSection
                                .padding(.top, 34)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(42, geo.safeAreaInsets.bottom) + 20)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedTemplate) { selection in
            ExperimentTemplateSheet(
                product: product,
                template: selection.template,
                linkedRuleID: selection.linkedRuleID,
                screenTimeAvailable: environmentStore.isConnected && environmentStore.selection != nil
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedExperiment) { selection in
            ExperimentDetailView(
                product: product,
                experimentID: selection.id
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLibrary) {
            ExperimentLibrarySheet(
                screenTimeAvailable: environmentStore.isConnected && environmentStore.selection != nil,
                observationalFuelAvailable: product.fuelState.promptsEnabled
            ) { template in
                showLibrary = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selectedTemplate = LabTemplateSelection(template: template)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCustom) {
            CustomExperimentSheet(product: product)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-qaOpenLabResult"),
               selectedExperiment == nil,
               let completed = product.pastExperiments.first(where: { $0.result != nil }) {
                selectedExperiment = LabExperimentSelection(id: completed.id)
            }
            if ProcessInfo.processInfo.arguments.contains("-qaOpenActiveLabDetail"),
               selectedExperiment == nil,
               let active = product.activeExperiment {
                selectedExperiment = LabExperimentSelection(id: active.id)
            }
#endif
        }
    }

    private var header: some View {
        HStack {
            Button { product.closePersonalLab() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 44, height: 44)
                    .background(AppColors.paperRaised.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Back to Profile")
            Spacer()
        }
    }

    private func activeSection(_ experiment: PersonalExperiment) -> some View {
        let canContinue = product.canPrepareStandaloneLabSession
        return VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Active test", color: AppColors.coral)
            PaperCard(radius: 28, padding: 22, shadow: .lift) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        GlassPill(text: progressText(experiment), tint: AppColors.coral)
                        Spacer()
                        Button {
                            selectedExperiment = LabExperimentSelection(id: experiment.id)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                                .frame(width: 38, height: 38)
                        }
                        .accessibilityLabel("Open test details")
                    }

                    Text(experiment.question, style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 18)

                    if experiment.comparisonKind == .observationalComparison {
                        MetaLabel(text: "How it fills")
                            .padding(.top, 18)
                        Text("You don't change anything. REBOOT pairs sessions that occur naturally.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 5)
                    } else if let assignment = PersonalLabEngine.nextAssignment(for: experiment) {
                        let arm = experiment.arm(for: assignment.armKind)
                        MetaLabel(text: "Current condition")
                            .padding(.top, 18)
                        Text("\(arm.kind.displayLabel) · \(arm.condition.title)", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 5)
                    }

                    if let waitReason = product.todayExperimentWaitReason(
                        activeRecurringProtection: environmentStore.hasActiveProtectionNow
                    ) {
                        Text(waitReason, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 14)
                    }

                    PrimaryPillButton(
                        title: canContinue ? "Continue test" : "Test waits today",
                        symbol: canContinue ? "play.fill" : "pause",
                        isEnabled: canContinue
                    ) {
                        product.prepareStandaloneLabSession()
                    }
                    .padding(.top, 22)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active experiment. \(experiment.question). \(experiment.completePairCount) of \(experiment.plan.targetPairs) comparisons complete.")
        }
    }

    private func pausedSection(_ experiment: PersonalExperiment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Paused test")
            PaperCard(radius: 24, padding: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(experiment.question, style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text("What we've learned is saved. Continue when it fits again.", style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                    HStack(spacing: 10) {
                        TonalPillButton(title: "Resume") {
                            _ = product.resumeExperiment(id: experiment.id)
                        }
                        Button {
                            selectedExperiment = LabExperimentSelection(id: experiment.id)
                        } label: {
                            GlassPill(text: "Details", symbol: "chevron.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    private var worthTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Worth testing")
            if suggestions.isEmpty {
                PaperCard(radius: 24, padding: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.sessions.count < 2
                            ? "A little evidence first."
                            : "Nothing urgent to test.", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(product.sessions.count < 2
                            ? "REBOOT needs a few real sessions before suggesting a useful comparison."
                            : "Your current evidence does not point to a clear unresolved question.", style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            selectedTemplate = LabTemplateSelection(
                                template: suggestion.template,
                                linkedRuleID: suggestion.linkedPersonalRuleID
                            )
                        } label: {
                            suggestionRow(suggestion)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }

            HStack(spacing: 10) {
                Button { showLibrary = true } label: {
                    GlassPill(text: "Browse tests", symbol: "rectangle.stack", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
                Button { showCustom = true } label: {
                    GlassPill(text: "Create your own", symbol: "plus", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.top, 2)
        }
    }

    private func suggestionRow(_ suggestion: ExperimentSuggestion) -> some View {
        PaperCard(radius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(suggestion.template.shortTitle, style: .heroMode)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.coral)
                }
                Text(suggestion.template.question, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.leading)
                Text(suggestion.reason, style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var pastTestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Past tests")
            VStack(spacing: 10) {
                ForEach(product.pastExperiments) { experiment in
                    Button {
                        selectedExperiment = LabExperimentSelection(id: experiment.id)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(experiment.templateID.flatMap(ExperimentTemplateLibrary.template)?.shortTitle ?? experiment.question, style: .heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                    .multilineTextAlignment(.leading)
                                Text(experiment.result.map { resultLabel($0.state) } ?? "Finished without a conclusion", style: .footnote)
                                    .foregroundStyle(AppColors.inkFaint)
                            }
                            Spacer()
                            resultIcon(experiment.result?.state)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.inkFaint)
                        }
                        .padding(18)
                        .background(AppColors.paperRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }
    }

    private func progressText(_ experiment: PersonalExperiment) -> String {
        "\(experiment.completePairCount) of \(experiment.plan.targetPairs) comparisons"
    }
}

// MARK: - Today integration

struct TodayExperimentCard: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var declinedToday = false

    var body: some View {
        if !declinedToday,
           let participation = product.todayExperimentParticipation(
                activeRecurringProtection: environmentStore.hasActiveProtectionNow
           ) {
            PaperCard(radius: 22, padding: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        MetaLabel(text: "Today's test", color: AppColors.coral)
                        Spacer()
                        GlassPill(text: participation.armKind.displayLabel, tint: AppColors.ink)
                    }
                    Text(participation.conditionSnapshot.requestedTitle, style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text("This session can count toward your current comparison.", style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                    HStack(spacing: 10) {
                        TonalPillButton(title: "Use test condition") {
                            product.prepareProtocolSession(
                                participatingInLab: true,
                                activeRecurringProtection: environmentStore.hasActiveProtectionNow
                            )
                        }
                        TonalPillButton(title: "Not today") {
                            declinedToday = true
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's test. \(participation.armKind.displayLabel) condition. \(participation.conditionSnapshot.requestedTitle).")
        }
    }
}

// MARK: - Template detail

private struct ExperimentTemplateSheet: View {
    @ObservedObject var product: ProductStore
    let template: ExperimentTemplate
    let linkedRuleID: UUID?
    let screenTimeAvailable: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showRuleException = false
    @State private var showActiveWarning = false

    private var capabilityAvailable: Bool {
        template.capabilityRequirement != .screenTimeSelection || screenTimeAvailable
    }

    var body: some View {
        LabSheetScaffold(close: { dismiss() }) {
            MetaLabel(text: template.shortTitle, color: AppColors.coral)
            EditorialHeadline(text: template.question)
                .padding(.top, 14)
            Text(template.rationale, style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 10)

            ConditionComparisonView(
                normal: template.normalCondition,
                test: template.testCondition
            )
            .padding(.top, 28)

            if template.comparisonKind == .observationalComparison {
                Text(
                    "Naturally occurring — you don't change anything. REBOOT pairs real sessions from both sides as they happen.",
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
                .padding(.top, 14)
            }

            VStack(alignment: .leading, spacing: 7) {
                MetaLabel(text: "What we're watching")
                Text(template.primaryOutcome.displayName, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                Text("We'll compare \(template.targetPairs) similar pairs. The primary outcome is fixed before the test begins.", style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .padding(.top, 26)

            if !capabilityAvailable {
                PaperCard(radius: 20, padding: 16) {
                    Text("Connect Screen Time and choose activities before using this test.", style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
                .padding(.top, 22)
            }

            PrimaryPillButton(title: "Start this test", symbol: "play.fill", isEnabled: capabilityAvailable) {
                start(allowingRuleExceptions: false)
            }
            .padding(.top, 28)
        }
        .confirmationDialog(
            "Temporary rule exception",
            isPresented: $showRuleException,
            titleVisibility: .visible
        ) {
            Button("Allow temporary test exception") {
                start(allowingRuleExceptions: true)
            }
            Button("Choose another test", role: .cancel) {}
        } message: {
            Text("This test needs a few sessions without one of your kept rules. The rule stays kept and is never retired automatically.")
        }
        .alert("One active test at a time", isPresented: $showActiveWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pause your current test before starting another.")
        }
    }

    private func start(allowingRuleExceptions: Bool) {
        let outcome = product.startExperiment(
            template: template,
            linkedRuleID: linkedRuleID,
            allowingRuleExceptions: allowingRuleExceptions
        )
        switch outcome {
        case .started:
            dismiss()
        case .needsRuleException:
            showRuleException = true
        case .activeExperimentExists:
            showActiveWarning = true
        case .unavailable:
            break
        }
    }
}

// MARK: - Active and result detail

struct ExperimentDetailView: View {
    @ObservedObject var product: ProductStore
    let experimentID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showStop = false
    @State private var showRepeatConflict = false
    @State private var showActiveWarning = false

    private var experiment: PersonalExperiment? { product.experiment(id: experimentID) }

    var body: some View {
        LabSheetScaffold(close: { dismiss() }) {
            if let experiment {
                if let result = experiment.result {
                    resultContent(experiment, result: result)
                } else {
                    activeContent(experiment)
                }
            } else {
                EditorialHeadline(text: "This test is no longer available.")
            }
        }
        .confirmationDialog("Finish this test?", isPresented: $showStop, titleVisibility: .visible) {
            Button("Finish without a conclusion", role: .destructive) {
                product.abandonExperiment(id: experimentID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Observations stay in your history. There is no penalty.")
        }
        .confirmationDialog("Temporary rule exception", isPresented: $showRepeatConflict, titleVisibility: .visible) {
            Button("Allow temporary test exception") {
                _ = product.repeatExperiment(id: experimentID, allowingRuleExceptions: true)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Normal condition conflicts with a kept rule. The rule will remain kept.")
        }
        .alert("One active test at a time", isPresented: $showActiveWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pause your current test before running another comparison.")
        }
    }

    @ViewBuilder
    private func activeContent(_ experiment: PersonalExperiment) -> some View {
        MetaLabel(text: experiment.status == .paused ? "Paused test" : "Active test", color: AppColors.coral)
        EditorialHeadline(text: experiment.question)
            .padding(.top, 14)
        Text(experiment.rationale, style: .todaySentence)
            .foregroundStyle(AppColors.inkSoft)
            .padding(.top, 10)

        ConditionComparisonView(
            normal: experiment.normalArm.condition,
            test: experiment.testArm.condition,
            pairs: experiment.pairs
        )
        .padding(.top, 28)

        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Comparison plan")
            ForEach(1...experiment.plan.targetPairs, id: \.self) { index in
                let pair = experiment.pairs.first { $0.pairIndex == index }
                HStack(spacing: 10) {
                    Image(systemName: pair?.isComplete == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(pair?.isComplete == true ? AppColors.coral : AppColors.inkFaint)
                    Text(pairStatus(index: index, experiment: experiment), style: .heroReason)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                }
            }
        }
        .padding(.top, 26)

        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: "What we're watching")
            Text(experiment.primaryOutcome.displayName, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
        }
        .padding(.top, 24)

        let confounded = experiment.observations.filter { $0.classification == .confounded }
        if !confounded.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MetaLabel(text: "Saved, not compared")
                Text("These sessions remain in your history but do not influence the comparison.", style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
                ForEach(confounded.prefix(3)) { observation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.coral)
                        Text(observation.classificationReason, style: .footnote)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }
            .padding(.top, 20)
        }

        if experiment.status == .active {
            let canContinue = product.canPrepareStandaloneLabSession
            PrimaryPillButton(
                title: canContinue ? "Continue test" : "Test waits today",
                symbol: canContinue ? "play.fill" : "pause",
                isEnabled: canContinue
            ) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    product.prepareStandaloneLabSession()
                }
            }
            .padding(.top, 28)

            if experiment.completePairCount >= experiment.plan.minimumPairs {
                Button {
                    _ = product.finalizeExperiment(id: experiment.id, allowEarly: true)
                } label: {
                    GlassPill(text: "Review early result", symbol: "checkmark.circle", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 12)
            }

            HStack(spacing: 12) {
                Button { product.pauseExperiment(id: experiment.id) } label: {
                    GlassPill(text: "Pause", symbol: "pause", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
                Button { showStop = true } label: {
                    GlassPill(text: "Stop", symbol: "stop", tint: AppColors.inkFaint)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.top, 12)
        } else if experiment.status == .paused {
            PrimaryPillButton(title: "Resume test", symbol: "play.fill") {
                _ = product.resumeExperiment(id: experiment.id)
            }
            .padding(.top, 28)
            Button { showStop = true } label: {
                GlassPill(text: "Finish without a conclusion", symbol: "stop", tint: AppColors.inkFaint)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 12)
        } else {
            Text("Finished without a conclusion. The observations remain in your history.", style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 28)
        }
    }

    @ViewBuilder
    private func resultContent(_ experiment: PersonalExperiment, result: ExperimentResult) -> some View {
        MetaLabel(text: "Lab result", color: AppColors.coral)
        HStack(spacing: 10) {
            resultIcon(result.state)
            Text(resultLabel(result.state), style: .heroMode)
                .foregroundStyle(AppColors.ink)
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Result: \(resultLabel(result.state)). Based on \(result.completedPairs) comparable pairs.")

        EditorialHeadline(text: result.headline)
            .padding(.top, 18)
        Text(result.summary, style: .todaySentence)
            .foregroundStyle(AppColors.inkSoft)
            .padding(.top, 12)

        ConditionComparisonView(
            normal: experiment.normalArm.condition,
            test: experiment.testArm.condition,
            pairs: result.pairResults
        )
        .padding(.top, 28)

        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "What we saw")
            Text("\(result.completedPairs) comparable pair\(result.completedPairs == 1 ? "" : "s")", style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            ForEach(result.pairResults) { pair in
                compactPairTrace(pair, experiment: experiment)
            }
            if !experiment.historicalResults.isEmpty {
                Text(
                    "Earlier result on this test: INCONCLUSIVE · kept as history, never counted twice.",
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
                .padding(.top, 4)
            }
        }
        .padding(.top, 26)

        Text("This is a pattern from your sessions, not proof of cause.", style: .footnote)
            .foregroundStyle(AppColors.inkFaint)
            .padding(.top, 22)

        resultActions(experiment, result: result)
            .padding(.top, 28)
    }

    @ViewBuilder
    private func resultActions(_ experiment: PersonalExperiment, result: ExperimentResult) -> some View {
        switch result.state {
        case .keep:
            if result.personalRuleID == nil, experiment.ruleDraft != nil {
                PrimaryPillButton(title: "Keep as a rule", symbol: "checkmark") {
                    _ = product.keepExperimentResultAsRule(experimentID: experiment.id)
                }
            } else if result.personalRuleID != nil {
                GlassPill(text: "Rule kept", symbol: "checkmark.circle.fill", tint: AppColors.coral)
            }
            HStack(spacing: 12) {
                repeatButton(experiment)
                Button { dismiss() } label: {
                    GlassPill(text: "Finish", symbol: "checkmark", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.top, 12)
        case .drop:
            if let linkedID = experiment.linkedPersonalRuleID,
               product.personalRules.contains(where: { $0.id == linkedID && $0.lifecycle == .kept }) {
                Text("This result challenges one of your current rules. You decide what happens to it.", style: .heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        GlassPill(text: "Keep rule", symbol: "checkmark", tint: AppColors.ink)
                    }
                    .buttonStyle(PressScaleStyle())
                    repeatButton(experiment)
                }
                Button {
                    product.retireRuleChallengedByExperiment(experimentID: experiment.id)
                    dismiss()
                } label: {
                    GlassPill(text: "Retire rule", symbol: "archivebox", tint: AppColors.inkFaint)
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 12)
            } else {
                HStack(spacing: 12) {
                    repeatButton(experiment)
                    Button { dismiss() } label: {
                        GlassPill(text: "Finish", symbol: "checkmark", tint: AppColors.ink)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        case .inconclusive:
            if experiment.status == .completed,
               experiment.plan.targetPairs < ExperimentPolicy.maxPairs,
               let result = experiment.result, result.state == .inconclusive {
                PrimaryPillButton(title: "Run one more comparison", symbol: "plus.circle") {
                    _ = product.extendInconclusiveExperiment(id: experiment.id)
                    dismiss()
                }
                Text(
                    "Adds one balanced pair to this same test. Earlier results are kept as history and never counted twice.",
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
                .padding(.top, 8)
            }
            HStack(spacing: 12) {
                repeatButton(experiment)
                Button { dismiss() } label: {
                    GlassPill(text: "Finish inconclusive", symbol: "checkmark", tint: AppColors.ink)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.top, 12)
        }
    }

    private func repeatButton(_ experiment: PersonalExperiment) -> some View {
        Button {
            let outcome = product.repeatExperiment(id: experiment.id)
            switch outcome {
            case .started:
                dismiss()
            case .needsRuleException:
                showRepeatConflict = true
            case .activeExperimentExists:
                showActiveWarning = true
            default:
                break
            }
        } label: {
            GlassPill(text: "Run another", symbol: "arrow.counterclockwise", tint: AppColors.ink)
        }
        .buttonStyle(PressScaleStyle())
    }

    /// Restrained trace: transparency, not a dashboard. Each pair shows both
    /// arms with the session day, mode, and the primary-outcome value.
    private func compactPairTrace(_ pair: ExperimentPair, experiment: PersonalExperiment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: pairSymbol(pair.comparison))
                    .foregroundStyle(AppColors.coral)
                Text("Pair \(pair.pairIndex)", style: .heroMode)
                    .foregroundStyle(AppColors.ink)
            }
            ForEach([ExperimentArmKind.normal, .test], id: \.self) { armKind in
                if let observationID = armKind == .normal ? pair.normalObservationID : pair.testObservationID,
                   let observation = experiment.observations.first(where: { $0.id == observationID }) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(armKind.displayLabel.uppercased(), style: .footnote)
                            .foregroundStyle(armKind == .test ? AppColors.coral : AppColors.inkFaint)
                            .frame(minWidth: 62, alignment: .leading)
                        Text(
                            "Day \(observationDateDay(observation)) · \(observation.mode.rawValue)\(primaryOutcomeText(observation, experiment: experiment))",
                            style: .footnote
                        )
                        .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }
            Text(pair.explanation, style: .footnote)
                .foregroundStyle(AppColors.inkFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pair \(pair.pairIndex). \(pair.explanation)")
    }

    private func observationDateDay(_ observation: ExperimentObservation) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: observation.date)
    }

    private func primaryOutcomeText(
        _ observation: ExperimentObservation,
        experiment: PersonalExperiment
    ) -> String {
        guard let value = observation.outcomes[experiment.primaryOutcome.key] else { return "" }
        let text: String
        switch value {
        case .integer(let int): text = "\(int)"
        case .boolean(let bool): text = bool ? "yes" : "no"
        case .firstSwitch(let timing): text = timing.label
        case .recall(let recall): text = recall == .little ? "a little" : (recall == .some ? "some" : "most")
        case .explanation(let explanation): text = explanation == .yes ? "yes" : (explanation == .partly ? "partly" : "not yet")
        }
        return " · \(experiment.primaryOutcome.displayName): \(text)"
    }

    private func pairStatus(index: Int, experiment: PersonalExperiment) -> String {
        if let pair = experiment.pairs.first(where: { $0.pairIndex == index }), pair.isComplete {
            return "Pair \(index) complete"
        }
        if let next = PersonalLabEngine.nextAssignment(for: experiment), next.pairIndex == index {
            return "Pair \(index) waiting for \(next.armKind.displayLabel)"
        }
        return "Pair \(index) upcoming"
    }
}

// MARK: - Library and custom creation

private struct ExperimentLibrarySheet: View {
    let screenTimeAvailable: Bool
    var observationalFuelAvailable: Bool = true
    let select: (ExperimentTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    private var templates: [ExperimentTemplate] {
        ExperimentTemplateLibrary.all.filter { template in
            if template.capabilityRequirement == .screenTimeSelection, !screenTimeAvailable { return false }
            // Sleep/meal observational comparisons need Fuel context answers;
            // without prompts they could never fill an arm.
            if template.comparisonKind == .observationalComparison,
               template.targetVariable == .sleepContext || template.targetVariable == .mealContext,
               !observationalFuelAvailable { return false }
            return true
        }
    }

    var body: some View {
        LabSheetScaffold(close: { dismiss() }) {
            MetaLabel(text: "Test library", color: AppColors.coral)
            EditorialHeadline(text: "A few useful questions.")
                .padding(.top, 14)
            Text("Small, executable comparisons using outcomes REBOOT already records.", style: .todaySentence)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 10)

            VStack(spacing: 10) {
                ForEach(templates) { template in
                    Button { select(template) } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(template.shortTitle, style: .heroMode)
                                    .foregroundStyle(AppColors.ink)
                                Text(template.question, style: .heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.coral)
                        }
                        .padding(18)
                        .background(AppColors.paperRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.top, 26)
        }
    }
}

private struct CustomExperimentSheet: View {
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var normal = ""
    @State private var test = ""
    @State private var mode: TrainingMode = .stay
    @State private var primaryOutcome: ExperimentOutcomeMetric = .reportedSwitches
    @State private var showActiveWarning = false

    private var compatibleMetrics: [ExperimentOutcomeMetric] {
        switch mode {
        case .stay: return [.reportedSwitches, .firstSwitchTiming, .startEase, .difficulty, .completion]
        case .recall: return [.recallAssessment, .difficulty, .startEase, .completion]
        case .explain: return [.explanationAssessment, .difficulty, .startEase, .completion]
        case .nothing: return [.difficulty, .completion, .earlyExit]
        case .observe: return [.reportedSwitches, .firstSwitchTiming, .difficulty, .completion]
        }
    }

    private var canStart: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !normal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !test.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        LabSheetScaffold(close: { dismiss() }) {
            MetaLabel(text: "Your test", color: AppColors.coral)
            EditorialHeadline(text: "Compare one real change.")
                .padding(.top, 14)

            experimentField("What do you want to test?", placeholder: "Does this setup help me stay with one task?", text: $question)
                .padding(.top, 26)
            experimentField("What stays normal?", placeholder: "My usual setup", text: $normal)
                .padding(.top, 18)
            experimentField("What changes?", placeholder: "One specific change", text: $test)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(text: "Session mode")
                Picker("Session mode", selection: $mode) {
                    ForEach(TrainingMode.allCases) { mode in
                        Text(mode.display).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.ink)
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(text: "What should we watch?")
                Picker("Primary outcome", selection: $primaryOutcome) {
                    ForEach(compatibleMetrics, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.ink)
            }
            .padding(.top, 20)
            .onChange(of: mode) { _, _ in
                if !compatibleMetrics.contains(primaryOutcome) {
                    primaryOutcome = compatibleMetrics[0]
                }
            }

            Text("Custom conditions are self-reported. REBOOT does not pretend to verify them.", style: .footnote)
                .foregroundStyle(AppColors.inkFaint)
                .padding(.top, 20)

            PrimaryPillButton(title: "Start this test", symbol: "play.fill", isEnabled: canStart) {
                let outcome = product.startCustomExperiment(
                    question: question,
                    normal: normal,
                    test: test,
                    mode: mode,
                    primaryOutcome: primaryOutcome
                )
                if case .started = outcome {
                    dismiss()
                } else if case .activeExperimentExists = outcome {
                    showActiveWarning = true
                }
            }
            .padding(.top, 28)
        }
        .alert("One active test at a time", isPresented: $showActiveWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pause your current test before starting another.")
        }
    }

    private func experimentField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: label)
            TextField(placeholder, text: text, axis: .vertical)
                .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                .padding(16)
                .background(AppColors.paperRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Signature comparison and shared presentation

private struct ConditionComparisonView: View {
    let normal: ExperimentCondition
    let test: ExperimentCondition
    var pairs: [ExperimentPair] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    conditionBlock(kind: .normal, condition: normal)
                    comparisonMarker
                    conditionBlock(kind: .test, condition: test)
                }
                VStack(spacing: 8) {
                    conditionBlock(kind: .normal, condition: normal)
                    comparisonMarker
                    conditionBlock(kind: .test, condition: test)
                }
            }

            if !pairs.isEmpty {
                HStack(spacing: 8) {
                    ForEach(pairs.sorted { $0.pairIndex < $1.pairIndex }) { pair in
                        HStack(spacing: 5) {
                            Image(systemName: pairSymbol(pair.comparison))
                            Text("P\(pair.pairIndex)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(pair.isComplete ? AppColors.coral : AppColors.inkFaint)
                        .accessibilityLabel("Pair \(pair.pairIndex). \(pair.explanation)")
                    }
                }
            }
        }
    }

    private func conditionBlock(kind: ExperimentArmKind, condition: ExperimentCondition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: kind.displayLabel, color: kind == .test ? AppColors.coral : AppColors.inkFaint)
            Text(condition.title, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            Text(condition.detail, style: .footnote)
                .foregroundStyle(AppColors.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind == .test ? AppColors.coral.opacity(0.07) : AppColors.ink.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.displayLabel) condition. \(condition.title). \(condition.detail)")
    }

    private var comparisonMarker: some View {
        Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.inkFaint)
            .frame(minWidth: 24, minHeight: 24)
            .accessibilityHidden(true)
    }
}

private struct LabSheetScaffold<Content: View>: View {
    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.paperRaised)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Close")
                        }
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(16, geo.safeAreaInsets.top))
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom) + 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
    }
}

private func resultLabel(_ state: ExperimentResultState) -> String {
    switch state {
    case .keep: return "KEEP"
    case .drop: return "DROP"
    case .inconclusive: return "INCONCLUSIVE"
    }
}

@ViewBuilder
private func resultIcon(_ state: ExperimentResultState?) -> some View {
    switch state {
    case .keep:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.coral)
    case .drop:
        Image(systemName: "minus.circle.fill").foregroundStyle(AppColors.inkSoft)
    case .inconclusive:
        Image(systemName: "questionmark.circle.fill").foregroundStyle(AppColors.inkSoft)
    case nil:
        Image(systemName: "circle.dashed").foregroundStyle(AppColors.inkFaint)
    }
}

private func pairSymbol(_ result: ExperimentPairResult) -> String {
    switch result {
    case .testBetter: return "arrow.up.right.circle.fill"
    case .baselineBetter: return "arrow.down.left.circle.fill"
    case .similar: return "equal.circle.fill"
    case .unusable: return "circle.dashed"
    }
}
