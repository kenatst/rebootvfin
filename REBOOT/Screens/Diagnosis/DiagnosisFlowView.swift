import SwiftUI

/// Port of `DiagnosisFlow.tsx`: one large serif question per screen, soft choice
/// cards, branching via `DiagnosisModels`, fixed Continue bar for multi questions.
struct DiagnosisFlowView: View {
    @ObservedObject var state: AppState
    var onDebug: () -> Void

    private var questions: [Question] { DiagnosisModels.visibleQuestions(state.answers) }
    private var index: Int { min(state.step, max(0, questions.count - 1)) }
    private var question: Question { questions[index] }
    private var selected: [String] { state.answers[question.id] ?? [] }
    private var canContinue: Bool { !selected.isEmpty }
    private var progress: CGFloat {
        CGFloat(index + (canContinue ? 1 : 0)) / CGFloat(max(1, questions.count))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                AppColors.paper

                VStack(spacing: 0) {
                    EditorialHeader(
                        variant: .diagnosis(
                            backEnabled: index > 0,
                            progress: progress,
                            counter: counterText,
                            onBack: { state.patch(step: max(0, index - 1)) }
                        ),
                        safeTop: geo.safeAreaInsets.top,
                        onDebug: onDebug
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            ZStack(alignment: .top) {
                                questionBlock
                                    .id(question.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 14)),
                                        removal: .opacity.combined(with: .offset(y: -10))
                                    ))
                            }
                            .padding(.horizontal, AppSpacing.screenPadding)
                            .padding(.top, AppSpacing.lg)
                            .padding(.bottom, question.kind == .multi ? AppSpacing.choicesBottom : AppSpacing.choicesBottom * 0.55)
                            .animation(.reboot(duration: AppMotion.questionDuration), value: question.id)
                        }
                        .onChange(of: question.id, initial: false) { _, _ in
                            proxy.scrollTo(question.id, anchor: .top)
                        }
                    }
                }

                if question.kind == .multi {
                    bottomBar(safeBottom: geo.safeAreaInsets.bottom, hasSelection: canContinue)
                }
            }
            .ignoresSafeArea()
        }
        .background(AppColors.paper)
    }

    /// Canonical counter derived from the SAME visible-question array the flow
    /// walks. The conditional "primary" question only enters the list after
    /// goals are chosen, so both bar and number always agree.
    private var counterText: String {
        String(format: NSLocalizedString("%d of %d", comment: "Diagnosis step counter"),
               index + 1, questions.count)
    }

    // MARK: - Question block

    private var questionBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(question.title, style: .questionTitle)
                .foregroundStyle(AppColors.ink)

            if let hint = question.hint {
                Text(hint, style: .hint)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, AppSpacing.xs)
            }

            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.element.id) { i, option in
                    Reveal(
                        offset: 8,
                        delay: AppMotion.choiceStaggerBase + Double(i) * AppMotion.choiceStagger,
                        duration: AppMotion.choiceDuration
                    ) {
                        ChoiceCard(label: option.label, isSelected: selected.contains(option.value)) {
                            choose(option.value)
                        }
                    }
                }
            }
            .padding(.top, 22)
        }
    }

    private var options: [QuestionOption] {
        DiagnosisModels.optionsFor(question, state.answers)
    }

    // MARK: - Bottom bar (multi questions)

    private func bottomBar(safeBottom: CGFloat, hasSelection: Bool) -> some View {
        Group {
            if hasSelection {
                PrimaryButton(title: L("Continue")) {
                    advance()
                }
                .frame(maxWidth: AppSpacing.contentMaxWidth)
            } else {
                // No giant disabled pill: a quiet hint keeps the screen open
                // until the user actually selects something.
                Text(L("Select to continue"))
                    .type(.smallLink)
                    .foregroundStyle(AppColors.inkFaint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.bottom, max(AppSpacing.safeBottomMin, safeBottom))
        .background(
            LinearGradient(
                stops: [
                    .init(color: AppColors.paper.opacity(0), location: 0),
                    .init(color: AppColors.paper.opacity(0.85), location: 0.35),
                    .init(color: AppColors.paper, location: 0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeOut(duration: 0.2), value: hasSelection)
    }

    // MARK: - Actions

    private func choose(_ value: String) {
        if question.kind == .multi {
            var next = selected
            if next.contains(value) {
                next.removeAll { $0 == value }
            } else {
                next.append(value)
            }
            var answers = state.answers
            answers[question.id] = next
            state.patch(answers: answers)
            return
        }

        var cleared = state.answers
        cleared[question.id] = [value]
        state.patch(answers: cleared)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.singleAdvanceSettle) {
            advance(state: cleared)
        }
    }

    private func advance(state answers: Answers? = nil) {
        let list = DiagnosisModels.visibleQuestions(answers ?? state.answers)
        let position = list.firstIndex { $0.id == question.id } ?? 0
        if position >= list.count - 1 {
            state.patch(phase: .report)
        } else {
            state.patch(step: position + 1)
        }
    }
}
