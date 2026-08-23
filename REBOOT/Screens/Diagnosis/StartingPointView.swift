import SwiftUI

/// "Your starting point" — the editorial close of the diagnosis.
///
/// Structure: WHAT YOU WANT → STARTING HYPOTHESES → WHAT REBOOT WILL MEASURE
/// → Start day one. No stat grids, no duplicate "what you told us" table,
/// no raw internal identifiers. Every value renders through localized labels.
struct StartingPointView: View {
    @ObservedObject var state: AppState
    var product: ProductStore? = nil

    private var answers: Answers { state.answers }

    // MARK: - Prior extraction (always display-labeled, never raw values)

    /// The one direction everything adapts around. Falls back to the single
    /// chosen goal when the conditional primary question never appeared.
    private var wantLabel: String? {
        if let labeled = DiagnosisModels.answerLabels("primary", answers).first, !labeled.isEmpty {
            return labeled
        }
        if DiagnosisModels.isUnknown("primary", answers),
           let only = answers["goals"]?.first, answers["goals"]?.count == 1 {
            return DiagnosisModels.goalLabel[only]
        }
        return nil
    }

    private var extraGoalLabels: [String] {
        guard let goals = answers["goals"], goals.count > 1 else { return [] }
        return DiagnosisModels.answerLabels("goals", answers).filter { $0 != wantLabel }
    }

    private struct Hypothesis: Identifiable {
        let id: String
        let text: String
    }

    /// Honest priors as sentences. Unknowns become "Day 1 will test this."
    /// instead of a mechanical "Unmeasured" row.
    private var hypotheses: [Hypothesis] {
        var rows: [Hypothesis] = []
        if let hardest = firstLabel("hardest") {
            rows.append(Hypothesis(id: "hardest", text: String(format: L("%@ may be the hardest part right now."), hardest)))
        }
        if let breaker = firstLabel("breaker") {
            rows.append(Hypothesis(id: "breaker", text: String(format: L("%@ are a possible breaker."), breaker)))
        } else {
            rows.append(Hypothesis(id: "breaker", text: L("What pulls your attention is still unclear — Day 1 watches for it.")))
        }
        if let window = windowSentence {
            rows.append(Hypothesis(id: "window", text: window))
        }
        if let returning = firstLabel("return_ability") {
            rows.append(Hypothesis(id: "return", text: String(format: L("After a distraction, returning %@"), returning)))
        } else {
            rows.append(Hypothesis(id: "return", text: L("How you return after distraction isn't measured yet — Day 1 will test it.")))
        }
        return rows
    }

    private func firstLabel(_ questionID: String) -> String? {
        let label = DiagnosisModels.answerLabels(questionID, answers).first ?? ""
        return label.isEmpty ? nil : label
    }

    private var windowSentence: String? {
        guard !DiagnosisModels.isUnknown("focus_window", answers) else { return nil }
        switch answers["focus_window"]?.first ?? "" {
        case "lt5": return L("Focus usually holds under 5 minutes before something pulls.")
        case "5_15": return L("Focus usually holds 5–15 minutes before something pulls.")
        case "15_30": return L("You usually expect 15–30 minutes before feeling pulled away.")
        case "30_60": return L("Focus usually holds 30–60 minutes before something pulls.")
        default: return L("You usually stay past an hour before feeling pulled away.")
        }
    }

    private var willMeasure: [String] {
        [
            L("Your actual focus window."),
            L("What really pulls you away."),
            L("How you return."),
            L("Which conditions consistently help."),
        ]
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    whatYouWant
                        .padding(.top, 34)
                    hypothesesSection
                        .padding(.top, 36)
                    willMeasureSection
                        .padding(.top, 36)
                    actions
                        .padding(.top, 40)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, max(AppSpacing.safeTopMin, geo.safeAreaInsets.top) + 8)
                .padding(.bottom, max(AppSpacing.safeBottomMin, geo.safeAreaInsets.bottom) + 12)
                .frame(maxWidth: AppSpacing.contentMaxWidth + 2 * AppSpacing.screenPadding)
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea()
        }
        .background(AppColors.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: L("Reboot / Calibration"))
            Text(L("Your starting point."), style: .reportTitle)
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.sm)
            Text(
                L("This is not a verdict. It is where REBOOT starts — and the first week begins replacing these answers with what actually happens."),
                style: .reportBody
            )
            .foregroundStyle(AppColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppSpacing.xs)
        }
    }

    private var whatYouWant: some View {
        Reveal(delay: 0.06) {
            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(text: L("WHAT YOU WANT"), color: AppColors.coral)
                Text(wantLabel ?? L("Still choosing"), style: .cardTitle)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !extraGoalLabels.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(extraGoalLabels, id: \.self) { label in
                            Pill.goal(label)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(AppColors.statusTint)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
        }
    }

    private var hypothesesSection: some View {
        Reveal(delay: 0.16) {
            VStack(alignment: .leading, spacing: 0) {
                MetaLabel(text: L("STARTING HYPOTHESES"))
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(hypotheses) { hypothesis in
                        Text(hypothesis.text, style: .reportBody)
                            .foregroundStyle(AppColors.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var willMeasureSection: some View {
        Reveal(delay: 0.26) {
            VStack(alignment: .leading, spacing: 0) {
                MetaLabel(text: L("WHAT REBOOT WILL MEASURE"))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(willMeasure.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(AppColors.coral.opacity(0.7))
                                .frame(width: 5, height: 5)
                            Text(line, style: .hint)
                                .foregroundStyle(AppColors.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 14)
                Text(L("Observed evidence outweighs every answer above."), style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 18)
            }
        }
    }

    private var actions: some View {
        Reveal(delay: 0.36) {
            VStack(spacing: 12) {
                PrimaryButton(title: L("Start day one")) {
                    // Canonical program initialization: installs the diagnosis
                    // priors and guarantees Day 1 of an active program
                    // regardless of any stale persisted state.
                    product?.applyDiagnosis(state.answers)
                    state.patch(phase: .today)
                }
                    .frame(maxWidth: AppSpacing.contentMaxWidth)

                Button(action: {
                    // Clear any stale program/evidence state BEFORE the user
                    // retakes the questions; the rebuilt profile is created
                    // from the new answers when they finish.
                    product?.rebuildFromDiagnosis()
                    state.patch(phase: .diagnosis)
                }) {
                    Text(L("Retake the diagnosis"), style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)
                        .padding(.vertical, 8)
                }

                Text(
                    L("REBOOT trains attention behaviors. It doesn't diagnose anything or measure your brain."),
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
