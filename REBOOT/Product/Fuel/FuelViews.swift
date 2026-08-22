import SwiftUI

// MARK: - Fuel destination (entered from Profile, never a fifth tab)

/// "What your attention runs on." Observations, not a health dashboard:
/// only real known context, evidence-backed patterns, honest unknowns.
struct FuelView: View {
    @ObservedObject var product: ProductStore
    @State private var selectedPattern: FuelPattern?

    private var analysis: (patterns: [FuelPattern], openQuestions: [FuelOpenQuestion]) {
        product.fuelAnalysis
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        MetaLabel(text: "FUEL")
                            .padding(.top, 20)
                        EditorialHeadline(text: "What your attention runs on.")
                            .padding(.top, 12)
                        Text(
                            "Quiet observations about the conditions around your sessions. Not advice, not scores.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 8)

                        rightNow
                            .padding(.top, 30)
                        noticing
                            .padding(.top, 34)
                        stillLearning
                            .padding(.top, 34)
                        worthTesting
                            .padding(.top, 34)
                        if !product.fuelLinkedSessions.isEmpty {
                            recentSessions
                                .padding(.top, 34)
                        }
                        promptSetting
                            .padding(.top, 34)
                        Text("Fuel stays on this device. Nothing here is sent anywhere.", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(42, geo.safeAreaInsets.bottom) + 20)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedPattern) { pattern in
            FuelPatternDetailSheet(pattern: pattern, product: product)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button { product.closeFuel() } label: {
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

    // MARK: Right now — only actual known current context

    private var rightNow: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Right now")
            if let latest = product.latestFuelContext {
                PaperCard(radius: 26, padding: 20, shadow: .lift) {
                    VStack(alignment: .leading, spacing: 10) {
                        let daypart = FuelDaypart.derive(from: latest.capturedAt)
                        GlassPill(text: daypart.label, tint: AppColors.coral)
                        ForEach(latest.summaryLines, id: \.self) { line in
                            Text(line, style: .heroReason)
                                .foregroundStyle(AppColors.ink)
                        }
                        if latest.summaryLines.isEmpty {
                            Text("Not much captured yet — that's fine.", style: .heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Text("Self-reported · from your most recent session", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Right now. \(latest.summaryLines.joined(separator: ". ")). Self-reported.")
            } else {
                PaperCard(radius: 26, padding: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing captured yet.", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(
                            "Occasionally, before a session, REBOOT asks one optional question. Skip it any time.",
                            style: .heroReason
                        )
                        .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }
        }
    }

    // MARK: What REBOOT is noticing

    private var noticing: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "What REBOOT is noticing", color: AppColors.coral)
            let patterns = analysis.patterns
            if patterns.isEmpty {
                PaperCard(radius: 24, padding: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Still learning.", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(
                            product.fuelLinkedSessions.count < 2
                                ? "A few context-linked sessions come first."
                                : "No stable pattern yet — that is an honest result.",
                            style: .heroReason
                        )
                        .foregroundStyle(AppColors.inkSoft)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(patterns.prefix(4)) { pattern in
                        Button { selectedPattern = pattern } label: {
                            patternRow(pattern)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    private func patternRow(_ pattern: FuelPattern) -> some View {
        PaperCard(radius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pattern.maturity.label, style: .heroMode)
                        .foregroundStyle(pattern.maturity == .mixed ? AppColors.inkSoft : AppColors.coral)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.inkFaint)
                }
                Text(pattern.statement, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.leading)
                Text(
                    "From \(pattern.supportingSessions + pattern.contradictingSessions) comparable session\(pattern.supportingSessions + pattern.contradictingSessions == 1 ? "" : "s")",
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pattern.dimensionLabel). \(pattern.maturity.label). \(pattern.statement)")
    }

    // MARK: Still learning

    private var stillLearning: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Still learning")
            VStack(spacing: 10) {
                ForEach(analysis.openQuestions) { question in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 3)
                        Text(question.question, style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    // MARK: Worth testing — only genuinely executable Personal Lab tests

    private var worthTesting: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Worth testing")
            let suggestions = fuelTestSuggestions
            if let suggestion = suggestions.first {
                PaperCard(radius: 22, padding: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.template.shortTitle, style: .heroMode)
                            .foregroundStyle(AppColors.coral)
                        Text(suggestion.template.question, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                            .multilineTextAlignment(.leading)
                        Text(suggestion.reason, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                        Button { product.openPersonalLab() } label: {
                            GlassPill(text: "Test this in Lab", symbol: "arrow.left.arrow.right", tint: AppColors.ink)
                        }
                        .buttonStyle(PressScaleStyle())
                        .padding(.top, 4)
                    }
                }
            } else {
                Text(
                    "Nothing to test right now. Tests appear only when your sessions can genuinely answer them.",
                    style: .heroReason
                )
                .foregroundStyle(AppColors.inkSoft)
            }
        }
    }

    private var fuelTestSuggestions: [ExperimentSuggestion] {
        product.labSuggestions(screenTimeAvailable: false)
            .filter { $0.template.id.hasPrefix("fuel_") }
    }

    // MARK: Recent context-linked sessions (restrained)

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Recent context-linked sessions")
            VStack(spacing: 8) {
                ForEach(product.fuelLinkedSessions.prefix(5)) { session in
                    HStack(spacing: 12) {
                        Text("Day \(session.day) · \(session.mode.rawValue)", style: .heroReason)
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                        Text(contextSummary(session), style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Day \(session.day), \(session.mode.display). \(contextSummary(session)).")
                }
            }
        }
    }

    private func contextSummary(_ session: SessionRecord) -> String {
        guard let fuel = session.fuelContext else { return "" }
        let daypart = FuelDaypart.derive(from: session.date)
        var parts = [daypart.label]
        if let sleep = fuel.sleepQuality { parts.append("\(sleep.label.lowercased())-reported sleep") }
        if let meal = fuel.mealTiming { parts.append(meal.label.lowercased()) }
        if let energy = fuel.energy { parts.append("energy \(energy.label.lowercased())") }
        if let movement = fuel.movement { parts.append(movement.label.lowercased()) }
        return parts.joined(separator: " · ")
    }

    // MARK: Prompt setting

    private var promptSetting: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Context prompts")
            PaperCard(radius: 22, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        product.fuelState.promptsEnabled
                            ? "One optional question occasionally, before a session."
                            : "Context prompts are paused. Everything else keeps working.",
                        style: .heroReason
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    Button {
                        product.setFuelPromptsEnabled(!product.fuelState.promptsEnabled)
                    } label: {
                        GlassPill(
                            text: product.fuelState.promptsEnabled ? "Pause prompts" : "Resume prompts",
                            symbol: product.fuelState.promptsEnabled ? "pause" : "play",
                            tint: AppColors.ink
                        )
                    }
                    .buttonStyle(PressScaleStyle())
                    Text("Your existing evidence stays exactly as it is.", style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
        }
    }
}

// MARK: - Pattern detail (what REBOOT has seen, honestly)

private struct FuelPatternDetailSheet: View {
    let pattern: FuelPattern
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.paperRaised)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Close")
                        }
                        MetaLabel(text: pattern.dimensionLabel, color: AppColors.coral)
                        EditorialHeadline(text: pattern.maturity.label)
                            .padding(.top, 12)
                        Text(pattern.statement, style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 10)

                        VStack(alignment: .leading, spacing: 10) {
                            MetaLabel(text: "What REBOOT has seen")
                                .padding(.top, 26)
                            HStack(spacing: 16) {
                                microStat(value: "\(pattern.supportingSessions)", label: "supporting")
                                microStat(value: "\(pattern.contradictingSessions)", label: "contradicting")
                                microStat(value: "\(pattern.knownSessions)", label: "with this context known")
                            }
                        }

                        Text(
                            "This is an association from your recent sessions, not proof of cause. Contradictions lower confidence; unknowns stay unknown.",
                            style: .footnote
                        )
                        .foregroundStyle(AppColors.inkFaint)
                        .padding(.top, 22)

                        if let templateID = pattern.suggestsTestTemplateID,
                           let template = ExperimentTemplateLibrary.template(id: templateID),
                           product.activeExperiment == nil {
                            VStack(alignment: .leading, spacing: 10) {
                                MetaLabel(text: "Worth testing", color: AppColors.coral)
                                    .padding(.top, 24)
                                Text(template.question, style: .heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                Button {
                                    dismiss()
                                    product.openPersonalLab()
                                } label: {
                                    GlassPill(text: "Open Personal Lab", symbol: "arrow.left.arrow.right", tint: AppColors.ink)
                                }
                                .buttonStyle(PressScaleStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(16, geo.safeAreaInsets.top))
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom) + 16)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func microStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .type(.calendarMeta)
                .foregroundStyle(AppColors.ink)
            Text(label, style: .footnote)
                .foregroundStyle(AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Today's single optional Fuel prompt

/// ONE compact optional question before a session. Skippable, never repeated
/// within the same day, never shown on Day 1 or recovery days.
struct FuelPromptCard: View {
    @ObservedObject var product: ProductStore
    let prompt: FuelSamplePrompt

    var body: some View {
        PaperCard(radius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(text: "Before you start")
                Text(prompt.question, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                FlowOptionRow(
                    options: prompt.options.map { option in
                        FlowOption(label: option.label) {
                            product.answerFuelPrompt(prompt, rawValue: option.rawValue)
                        }
                    }
                )
                Button {
                    product.skipFuelPrompt(prompt)
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.inkFaint)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Skip this question")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fuel context question. \(prompt.question)")
    }
}

private struct FlowOption: Identifiable {
    var id: String { label }
    var label: String
    var action: () -> Void
}

private struct FlowOptionRow: View {
    let options: [FlowOption]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { optionButtons }
            VStack(alignment: .leading, spacing: 8) { optionButtons }
        }
    }

    @ViewBuilder
    private var optionButtons: some View {
        ForEach(options) { option in
            Button(action: option.action) {
                Text(option.label)
                    .font(Font(AppTypography.plusJakarta(size: 14, weight: 600)))
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppColors.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(option.label)
        }
    }
}
