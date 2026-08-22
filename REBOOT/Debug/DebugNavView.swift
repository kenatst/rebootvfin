import SwiftUI

/// DEBUG navigation: jump to every onboarding / diagnosis / report state.
/// Opened by long-pressing the header meta label (or the debug button in DEBUG
/// builds). Only available in builds compiled with the `DEBUG` flag.
struct DebugNavView: View {
    @ObservedObject var state: AppState
    @ObservedObject var product: ProductStore
    @Environment(\.dismiss) private var dismiss

    /// Answer seed used to reach any diagnosis question (same branch as QA flow).
    static let seedAnswers: Answers = [
        "goals": ["deep_work", "scroll_less", "study_better", "remember_more"],
        "primary": ["focus_better"],
        "hardest": ["starting"],
        "breaker": ["notifications"],
        "focus_window": ["15_30"],
        "switch_response": ["check_phone"],
        "return_ability": ["effortful_return"],
        "use_case": ["building"],
        "best_time": ["early"],
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Onboarding") {
                    ForEach(CinematicContent.screens) { screen in
                        Button(screen.meta) {
                            jump(phase: .cinematic, screen: screen.id - 1, step: 0, answers: [:])
                        }
                    }
                    Button("Dissolve") {
                        jump(phase: .dissolve, screen: 5, step: 0, answers: [:])
                    }
                }

                Section("Diagnosis") {
                    ForEach(debugDiagnosisEntries) { entry in
                        Button(entry.label) {
                            jump(
                                phase: .diagnosis,
                                screen: 0,
                                step: entry.step,
                                answers: entry.answers
                            )
                        }
                    }
                }

                Section("Report") {
                    Button("Your starting point (full answers)") {
                        jump(phase: .report, screen: 0, step: 0, answers: Self.seedAnswers)
                    }
                    Button("Your starting point (unknowns)") {
                        jump(phase: .report, screen: 0, step: 0, answers: [:])
                    }
                }

                Section("Product (Today / session)") {
                    Button("Today — Day 1 baseline (OBSERVE)") {
                        product.apply(QASeeds.day1)
                        state.patch(phase: .today)
                        dismiss()
                    }
                    Button("Today — STAY after hard sessions") {
                        product.apply(QASeeds.stay)
                        state.patch(phase: .today)
                        dismiss()
                    }
                    Button("Today — RECALL (memory goal)") {
                        product.apply(QASeeds.recall)
                        state.patch(phase: .today)
                        dismiss()
                    }
                    Button("Today — REST after difficulty") {
                        product.apply(QASeeds.rest)
                        state.patch(phase: .today)
                        dismiss()
                    }
                    Button("Session — running timer") {
                        product.apply(QASeeds.running)
                        state.patch(phase: .today)
                        dismiss()
                    }
                    Button("Session — done transition") {
                        product.apply(QASeeds.done)
                        state.patch(phase: .today)
                        dismiss()
                    }
                }

                Section {
                    Button("Reset to first onboarding screen", role: .destructive) {
                        state.reset()
                        dismiss()
                    }
                }
            }
            .navigationTitle("DEBUG Navigation")
        }
    }

    private struct Entry: Identifiable {
        let id: String
        let label: String
        let step: Int
        let answers: Answers
    }

    private var debugDiagnosisEntries: [Entry] {
        let questions = DiagnosisModels.visibleQuestions(Self.seedAnswers)
        var entries: [Entry] = []

        // First question, empty state
        entries.append(.init(id: "goals", label: "1. What would feel different? (empty)", step: 0, answers: [:]))
        // goals pre-selected (multi selected state)
        entries.append(.init(
            id: "goals-selected",
            label: "1. What would feel different? (selected)",
            step: 0,
            answers: ["goals": ["deep_work", "scroll_less", "study_better", "remember_more"]]
        ))

        for (i, q) in questions.enumerated() {
            let step = i
            let answers = Self.seedAnswers
            entries.append(.init(id: q.id, label: "\(i + 1). \(q.title)", step: step, answers: answers))
        }
        return entries
    }

    private func jump(phase: AppState.Phase, screen: Int, step: Int, answers: Answers) {
        state.patch(phase: phase, screen: screen, step: step, answers: answers)
        dismiss()
    }
}
