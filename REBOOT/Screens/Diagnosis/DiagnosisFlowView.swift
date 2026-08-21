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
                            counter: "\(index + 1)/\(questions.count)",
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
                            .padding(.top, AppSpacing.xl)
                            .padding(.bottom, AppSpacing.choicesBottom)
                            .animation(.reboot(duration: AppMotion.questionDuration), value: question.id)
                        }
                        .onChange(of: question.id, initial: false) { _, _ in
                            proxy.scrollTo(question.id, anchor: .top)
                        }
                    }
                }

                if question.kind == .multi {
                    bottomBar(safeBottom: geo.safeAreaInsets.bottom)
                }
            }
            .ignoresSafeArea()
        }
        .background(AppColors.paper)
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

            VStack(spacing: AppSpacing.choicesGap) {
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
            .padding(.top, AppSpacing.lg)
        }
    }

    private var options: [QuestionOption] {
        DiagnosisModels.optionsFor(question, state.answers)
    }

    // MARK: - Bottom bar (multi questions)

    private func bottomBar(safeBottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            PrimaryButton(title: "Continue", isEnabled: canContinue) {
                advance()
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth)
        }
        .padding(.top, AppSpacing.twoXL)
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
