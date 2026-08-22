import Foundation

// MARK: - Personal Lab domain

enum ExperimentStatus: String, Codable, CaseIterable, Equatable {
    case draft
    case active
    case paused
    case completed
    case abandoned
}

enum ExperimentOrigin: String, Codable, Equatable {
    case builtIn
    case evidenceSuggestion
    case personalRuleRetest
    case userCreated
}

enum ExperimentArmKind: String, Codable, CaseIterable, Equatable, Hashable {
    case normal
    case test

    var displayLabel: String {
        switch self {
        case .normal: return "Normal"
        case .test: return "Test"
        }
    }
}

enum ExperimentTruthSource: String, Codable, Equatable {
    case userReported
    case systemConfirmed
    case notConfirmed

    var displayLabel: String {
        switch self {
        case .userReported: return "Self-reported"
        case .systemConfirmed: return "System-confirmed"
        case .notConfirmed: return "Not confirmed"
        }
    }
}

enum ExperimentConditionTiming: String, Codable, Equatable {
    case beforeSession
    case duringSession
    case afterSession
}

/// A string-backed condition keeps Lab open to future Fuel and Flow providers
/// without making the current public library pretend those inputs exist today.
struct ExperimentCondition: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var detail: String
    var timing: ExperimentConditionTiming = .beforeSession
    var expectedTruthSource: ExperimentTruthSource = .userReported
    var requiresExplicitConsent: Bool = false

    var requiresManualConfirmation: Bool {
        expectedTruthSource == .userReported
    }
}

struct ExperimentConditionSnapshot: Codable, Equatable {
    var requestedConditionID: String
    var requestedTitle: String
    var requestedDetail: String
    var actualDescription: String?
    var truthSource: ExperimentTruthSource
    var conditionFollowed: Bool
    var capturedAt: Date?

    static func pending(_ condition: ExperimentCondition) -> ExperimentConditionSnapshot {
        ExperimentConditionSnapshot(
            requestedConditionID: condition.id,
            requestedTitle: condition.title,
            requestedDetail: condition.detail,
            actualDescription: nil,
            truthSource: .notConfirmed,
            conditionFollowed: false,
            capturedAt: nil
        )
    }
}

/// String-backed outcome identity prevents the comparison engine from becoming
/// coupled to today's five public templates.
struct ExperimentOutcomeMetric: Codable, Hashable, Equatable {
    var key: String
    var displayName: String

    static let reportedSwitches = ExperimentOutcomeMetric(key: "reported_switches", displayName: "Reported switches")
    static let firstSwitchTiming = ExperimentOutcomeMetric(key: "first_switch_timing", displayName: "First-switch timing")
    static let startEase = ExperimentOutcomeMetric(key: "start_ease", displayName: "Starting felt easier")
    static let difficulty = ExperimentOutcomeMetric(key: "difficulty", displayName: "Difficulty")
    static let recallAssessment = ExperimentOutcomeMetric(key: "recall_assessment", displayName: "Recall self-assessment")
    static let explanationAssessment = ExperimentOutcomeMetric(key: "explanation_assessment", displayName: "Explanation self-assessment")
    static let earlyExit = ExperimentOutcomeMetric(key: "early_exit", displayName: "Early exit")
    static let completion = ExperimentOutcomeMetric(key: "completion", displayName: "Session completion")
}

enum ExperimentMetricValue: Codable, Equatable {
    case integer(Int)
    case boolean(Bool)
    case firstSwitch(FirstSwitchTiming)
    case recall(RecallSelfAssessment)
    case explanation(ExplanationSelfAssessment)
}

struct ExperimentArm: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ExperimentArmKind
    var condition: ExperimentCondition
}

struct ExperimentAssignmentSlot: Codable, Equatable {
    var pairIndex: Int
    var armKind: ExperimentArmKind
}

struct ExperimentPlan: Codable, Equatable {
    var targetPairs: Int
    var minimumPairs: Int
    var armOrder: [ExperimentAssignmentSlot]

    static func balanced(targetPairs: Int = 3, minimumPairs: Int = 2) -> ExperimentPlan {
        let pairOrders: [[ExperimentArmKind]] = [
            [.normal, .test],
            [.test, .normal],
            [.normal, .test],
        ]
        var slots: [ExperimentAssignmentSlot] = []
        for pairIndex in 1...max(1, targetPairs) {
            let order = pairOrders[(pairIndex - 1) % pairOrders.count]
            slots.append(contentsOf: order.map {
                ExperimentAssignmentSlot(pairIndex: pairIndex, armKind: $0)
            })
        }
        return ExperimentPlan(
            targetPairs: max(1, targetPairs),
            minimumPairs: min(max(1, minimumPairs), max(1, targetPairs)),
            armOrder: slots
        )
    }
}

struct ExperimentEligibilitySnapshot: Codable, Equatable {
    var eligible: Bool
    var reasons: [String]
    var mode: TrainingMode
    var targetMinutes: Int
    var recoveryProtected: Bool
    var ruleExceptionIDs: [UUID]
    var capturedAt = Date()
}

struct ExperimentParticipation: Codable, Equatable {
    var experimentID: UUID
    var armID: UUID
    var armKind: ExperimentArmKind
    var pairIndex: Int
    var conditionSnapshot: ExperimentConditionSnapshot
    var eligibilitySnapshot: ExperimentEligibilitySnapshot
    var assignmentReason: String
}

enum ExperimentObservationClassification: String, Codable, Equatable {
    case comparable
    case usableButUnmatched
    case confounded
    case insufficient
}

enum ExperimentConfoundKind: String, Codable, Equatable {
    case differentMode
    case durationMismatch
    case recoverySession
    case conditionNotFollowed
    case screenTimeInterference
    case activeRuleConflict
    case missingPrimaryOutcome
    case endedTooEarly
    case conflictingEnvironmentOverride
}

struct ExperimentConfound: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ExperimentConfoundKind
    var explanation: String
}

struct ExperimentObservation: Codable, Identifiable, Equatable {
    var id = UUID()
    var experimentID: UUID
    var sessionID: UUID
    var armID: UUID
    var armKind: ExperimentArmKind
    var pairIndex: Int
    var requestedCondition: ExperimentConditionSnapshot
    var mode: TrainingMode
    var targetMinutes: Int
    var actualMinutes: Int
    var completed: Bool
    var endedEarly: Bool
    var outcomes: [String: ExperimentMetricValue]
    var classification: ExperimentObservationClassification
    var classificationReason: String
    var confounds: [ExperimentConfound]
    var sourceEvidenceIDs: [UUID]
    var date: Date
}

enum ExperimentPairResult: String, Codable, Equatable {
    case testBetter
    case baselineBetter
    case similar
    case unusable
}

struct ExperimentPair: Codable, Identifiable, Equatable {
    var id = UUID()
    var pairIndex: Int
    var normalObservationID: UUID?
    var testObservationID: UUID?
    var comparison: ExperimentPairResult
    var explanation: String

    var isComplete: Bool {
        normalObservationID != nil && testObservationID != nil && comparison != .unusable
    }
}

struct ExperimentResult: Codable, Identifiable, Equatable {
    var id = UUID()
    var state: ExperimentResultState
    var primaryOutcome: ExperimentOutcomeMetric
    var completedPairs: Int
    var pairResults: [ExperimentPair]
    var headline: String
    var summary: String
    var sourceObservationIDs: [UUID]
    var sourceEvidenceIDs: [UUID]
    var finalizedAt = Date()
    var personalRuleID: UUID?
}

struct ExperimentRuleDraft: Codable, Equatable {
    var title: String
    var detail: String
    var category: RuleCategory
    var contexts: [RuleContext]
}

struct PersonalExperiment: Codable, Identifiable, Equatable {
    var id = UUID()
    var templateID: String?
    var version: Int = 1
    var question: String
    var rationale: String
    var normalArm: ExperimentArm
    var testArm: ExperimentArm
    var eligibleModes: [TrainingMode]
    var preferredDuration: Int
    var primaryOutcome: ExperimentOutcomeMetric
    var secondaryOutcomes: [ExperimentOutcomeMetric]
    var plan: ExperimentPlan
    var status: ExperimentStatus
    var origin: ExperimentOrigin
    var observations: [ExperimentObservation] = []
    var pairs: [ExperimentPair] = []
    var result: ExperimentResult?
    var approvedRuleExceptionIDs: [UUID] = []
    var linkedPersonalRuleID: UUID?
    var ruleDraft: ExperimentRuleDraft?
    var createdAt = Date()
    var updatedAt = Date()
    var completedAt: Date?

    func arm(for kind: ExperimentArmKind) -> ExperimentArm {
        kind == .normal ? normalArm : testArm
    }

    var completePairCount: Int {
        pairs.filter(\.isComplete).count
    }
}

struct PersonalLabState: Codable, Equatable {
    var experiments: [PersonalExperiment] = []
    var pendingParticipation: ExperimentParticipation?

    var activeExperiment: PersonalExperiment? {
        experiments.first { $0.status == .active }
    }

    var pausedExperiment: PersonalExperiment? {
        experiments.first { $0.status == .paused }
    }

    var completedExperiments: [PersonalExperiment] {
        experiments
            .filter { $0.status == .completed || $0.status == .abandoned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static let empty = PersonalLabState()
}

enum ExperimentCapabilityRequirement: String, Codable, Equatable {
    case screenTimeSelection
}

struct ExperimentTemplate: Identifiable, Equatable {
    var id: String
    var shortTitle: String
    var question: String
    var rationale: String
    var normalCondition: ExperimentCondition
    var testCondition: ExperimentCondition
    var eligibleModes: [TrainingMode]
    var preferredDuration: Int
    var primaryOutcome: ExperimentOutcomeMetric
    var secondaryOutcomes: [ExperimentOutcomeMetric]
    var minimumPairs: Int = 2
    var targetPairs: Int = 3
    var capabilityRequirement: ExperimentCapabilityRequirement?
    var ruleDraft: ExperimentRuleDraft?
}

struct ExperimentSuggestion: Identifiable, Equatable {
    var id: String { template.id }
    var template: ExperimentTemplate
    var reason: String
    var linkedPersonalRuleID: UUID?
}

enum ExperimentTemplateLibrary {
    static let phoneDistance = ExperimentTemplate(
        id: "phone_distance",
        shortTitle: "Phone distance",
        question: "Does keeping your phone outside reach help you stay with one task?",
        rationale: "Phone-related switching appears relevant, but distance still needs a fair comparison.",
        normalCondition: ExperimentCondition(
            id: "phone.usual",
            title: "Usual phone placement",
            detail: "Keep your phone where you usually do."
        ),
        testCondition: ExperimentCondition(
            id: "phone.outside_reach",
            title: "Phone outside reach",
            detail: "Keep your phone outside reach."
        ),
        eligibleModes: [.stay],
        preferredDuration: 15,
        primaryOutcome: .reportedSwitches,
        secondaryOutcomes: [.firstSwitchTiming, .startEase, .difficulty],
        ruleDraft: ExperimentRuleDraft(
            title: "Keep phone outside reach during focused work",
            detail: "When starting focused work, keep the phone outside reach.",
            category: .environment,
            contexts: [.stay, .deepWork, .highDistraction]
        )
    )

    static let sessionProtection = ExperimentTemplate(
        id: "session_protection",
        shortTitle: "Session protection",
        question: "Does protecting selected distractions make staying easier?",
        rationale: "Protection is available, but its usefulness should come from comparable sessions.",
        normalCondition: ExperimentCondition(
            id: "screen_time.unprotected",
            title: "No session protection",
            detail: "Use your usual setup without session protection.",
            expectedTruthSource: .systemConfirmed
        ),
        testCondition: ExperimentCondition(
            id: "screen_time.protected",
            title: "Selected distractions protected",
            detail: "Protect the activities you already selected.",
            expectedTruthSource: .systemConfirmed,
            requiresExplicitConsent: true
        ),
        eligibleModes: [.stay],
        preferredDuration: 15,
        primaryOutcome: .reportedSwitches,
        secondaryOutcomes: [.startEase, .earlyExit, .difficulty],
        capabilityRequirement: .screenTimeSelection,
        ruleDraft: ExperimentRuleDraft(
            title: "Protect selected distractions during focused work",
            detail: "Use session protection for matching focused work.",
            category: .environment,
            contexts: [.stay, .deepWork, .highDistraction]
        )
    )

    static let oneBrowserTask = ExperimentTemplate(
        id: "one_browser_task",
        shortTitle: "One browser task",
        question: "Does reducing open browser work make switching less likely?",
        rationale: "Open tabs appear as a switch trigger, but the setup has not been compared yet.",
        normalCondition: ExperimentCondition(
            id: "browser.usual",
            title: "Usual browser setup",
            detail: "Keep your browser setup as usual."
        ),
        testCondition: ExperimentCondition(
            id: "browser.single_task",
            title: "One active browser task",
            detail: "Keep only the task you are using active."
        ),
        eligibleModes: [.stay],
        preferredDuration: 15,
        primaryOutcome: .reportedSwitches,
        secondaryOutcomes: [.firstSwitchTiming, .difficulty],
        ruleDraft: ExperimentRuleDraft(
            title: "Keep one browser task active",
            detail: "Close unrelated browser work before a focused block.",
            category: .taskSetup,
            contexts: [.stay, .deepWork]
        )
    )

    static let sound = ExperimentTemplate(
        id: "sound",
        shortTitle: "Sound",
        question: "Do you work more steadily in silence or with your usual background sound?",
        rationale: "Your sound environment is worth comparing without assuming one setup is universally better.",
        normalCondition: ExperimentCondition(
            id: "sound.usual",
            title: "Usual background sound",
            detail: "Use the sound setup you normally choose."
        ),
        testCondition: ExperimentCondition(
            id: "sound.silence",
            title: "Silence",
            detail: "Use as quiet a setup as is reasonably available."
        ),
        eligibleModes: [.stay, .recall, .explain],
        preferredDuration: 15,
        primaryOutcome: .difficulty,
        secondaryOutcomes: [.completion, .reportedSwitches]
    )

    static let clearFinishLine = ExperimentTemplate(
        id: "clear_finish_line",
        shortTitle: "Clear finish line",
        question: "Does defining what 'done' means make starting easier?",
        rationale: "Task clarity may matter for starting, but it needs a direct comparison.",
        normalCondition: ExperimentCondition(
            id: "finish_line.usual",
            title: "Start normally",
            detail: "Begin with your usual task setup."
        ),
        testCondition: ExperimentCondition(
            id: "finish_line.clear",
            title: "Define done first",
            detail: "Write one clear definition of done before the session."
        ),
        eligibleModes: [.stay],
        preferredDuration: 15,
        primaryOutcome: .startEase,
        secondaryOutcomes: [.difficulty, .reportedSwitches, .completion],
        ruleDraft: ExperimentRuleDraft(
            title: "Define done before focused work",
            detail: "Write one clear finish line before starting a focused block.",
            category: .taskSetup,
            contexts: [.stay, .deepWork]
        )
    )

    static let all: [ExperimentTemplate] = [
        phoneDistance,
        sessionProtection,
        oneBrowserTask,
        sound,
        clearFinishLine,
    ]

    static func template(id: String) -> ExperimentTemplate? {
        all.first { $0.id == id }
    }
}

// MARK: - Eligibility and assignment

enum PersonalLabEligibilityEngine {
    static func evaluate(
        request: TrainingSessionRequest,
        experiment: PersonalExperiment,
        isRecovery: Bool,
        activeRecurringProtection: Bool = false
    ) -> ExperimentEligibilitySnapshot {
        var reasons: [String] = []
        if experiment.status != .active {
            reasons.append("This test is not active.")
        }
        if request.origin == .protocol, request.programDay == 1 {
            reasons.append("Day 1 protects your natural baseline.")
        }
        if isRecovery {
            reasons.append("Recovery sessions keep their original intent.")
        }
        if !experiment.eligibleModes.contains(request.mode) {
            reasons.append("This training mode is not comparable for the current question.")
        }
        if let assignment = PersonalLabEngine.nextAssignment(for: experiment),
           assignment.armKind == .normal,
           experiment.normalArm.condition.id == "screen_time.unprotected",
           activeRecurringProtection {
            reasons.append("A protected window is already active.")
        }
        return ExperimentEligibilitySnapshot(
            eligible: reasons.isEmpty,
            reasons: reasons,
            mode: request.mode,
            targetMinutes: request.targetMinutes,
            recoveryProtected: isRecovery,
            ruleExceptionIDs: experiment.approvedRuleExceptionIDs
        )
    }

    static func durationCompatible(_ lhs: Int, _ rhs: Int) -> Bool {
        abs(lhs - rhs) <= 5
    }
}

// MARK: - Comparability and deterministic result engine

enum ExperimentComparisonEngine {
    static func updateComparability(_ experiment: inout PersonalExperiment) {
        for index in experiment.observations.indices where
            experiment.observations[index].classification == .comparable {
            experiment.observations[index].classification = .usableButUnmatched
            experiment.observations[index].classificationReason = "Waiting for the matching condition."
        }

        var rebuiltPairs: [ExperimentPair] = []
        for pairIndex in 1...experiment.plan.targetPairs {
            let normalIndices = candidateIndices(in: experiment, pairIndex: pairIndex, armKind: .normal)
            let testIndices = candidateIndices(in: experiment, pairIndex: pairIndex, armKind: .test)
            guard let normalIndex = normalIndices.first, let testIndex = testIndices.first else {
                rebuiltPairs.append(ExperimentPair(
                    pairIndex: pairIndex,
                    normalObservationID: normalIndices.first.map { experiment.observations[$0].id },
                    testObservationID: testIndices.first.map { experiment.observations[$0].id },
                    comparison: .unusable,
                    explanation: "We need another similar session."
                ))
                continue
            }

            let normal = experiment.observations[normalIndex]
            let test = experiment.observations[testIndex]
            if normal.mode != test.mode {
                confoundLaterObservation(
                    normalIndex: normalIndex,
                    testIndex: testIndex,
                    kind: .differentMode,
                    explanation: "The sessions used different training modes.",
                    experiment: &experiment
                )
                rebuiltPairs.append(unusablePair(pairIndex, reason: "Different modes are not comparable."))
                continue
            }
            if !PersonalLabEligibilityEngine.durationCompatible(normal.targetMinutes, test.targetMinutes) {
                confoundLaterObservation(
                    normalIndex: normalIndex,
                    testIndex: testIndex,
                    kind: .durationMismatch,
                    explanation: "The target durations were too different.",
                    experiment: &experiment
                )
                rebuiltPairs.append(unusablePair(pairIndex, reason: "The session durations were very different."))
                continue
            }

            let comparison = compare(
                normal: normal,
                test: test,
                metric: experiment.primaryOutcome
            )
            guard comparison != .unusable else {
                experiment.observations[normalIndex].classification = .insufficient
                experiment.observations[normalIndex].classificationReason = "The primary outcome was missing."
                experiment.observations[testIndex].classification = .insufficient
                experiment.observations[testIndex].classificationReason = "The primary outcome was missing."
                rebuiltPairs.append(unusablePair(pairIndex, reason: "The primary outcome was missing."))
                continue
            }

            experiment.observations[normalIndex].classification = .comparable
            experiment.observations[normalIndex].classificationReason = "Matched with a similar Test session."
            experiment.observations[testIndex].classification = .comparable
            experiment.observations[testIndex].classificationReason = "Matched with a similar Normal session."
            rebuiltPairs.append(ExperimentPair(
                pairIndex: pairIndex,
                normalObservationID: normal.id,
                testObservationID: test.id,
                comparison: comparison,
                explanation: explanation(for: comparison, metric: experiment.primaryOutcome)
            ))
        }
        experiment.pairs = rebuiltPairs
        experiment.updatedAt = Date()
    }

    static func compare(
        normal: ExperimentObservation,
        test: ExperimentObservation,
        metric: ExperimentOutcomeMetric
    ) -> ExperimentPairResult {
        guard let normalValue = normal.outcomes[metric.key],
              let testValue = test.outcomes[metric.key] else { return .unusable }

        switch metric.key {
        case ExperimentOutcomeMetric.reportedSwitches.key,
             ExperimentOutcomeMetric.difficulty.key:
            guard case .integer(let normalInt) = normalValue,
                  case .integer(let testInt) = testValue else { return .unusable }
            if testInt < normalInt { return .testBetter }
            if normalInt < testInt { return .baselineBetter }
            return .similar
        case ExperimentOutcomeMetric.firstSwitchTiming.key:
            guard case .firstSwitch(let normalTiming) = normalValue,
                  case .firstSwitch(let testTiming) = testValue,
                  let normalRank = firstSwitchRank(normalTiming),
                  let testRank = firstSwitchRank(testTiming) else { return .unusable }
            if testRank > normalRank { return .testBetter }
            if normalRank > testRank { return .baselineBetter }
            return .similar
        case ExperimentOutcomeMetric.startEase.key,
             ExperimentOutcomeMetric.completion.key:
            guard case .boolean(let normalBool) = normalValue,
                  case .boolean(let testBool) = testValue else { return .unusable }
            if testBool && !normalBool { return .testBetter }
            if normalBool && !testBool { return .baselineBetter }
            return .similar
        case ExperimentOutcomeMetric.earlyExit.key:
            guard case .boolean(let normalExited) = normalValue,
                  case .boolean(let testExited) = testValue else { return .unusable }
            if !testExited && normalExited { return .testBetter }
            if !normalExited && testExited { return .baselineBetter }
            return .similar
        case ExperimentOutcomeMetric.recallAssessment.key:
            guard case .recall(let normalAssessment) = normalValue,
                  case .recall(let testAssessment) = testValue else { return .unusable }
            return rankedComparison(normal: recallRank(normalAssessment), test: recallRank(testAssessment))
        case ExperimentOutcomeMetric.explanationAssessment.key:
            guard case .explanation(let normalAssessment) = normalValue,
                  case .explanation(let testAssessment) = testValue else { return .unusable }
            return rankedComparison(normal: explanationRank(normalAssessment), test: explanationRank(testAssessment))
        default:
            return .unusable
        }
    }

    private static func candidateIndices(
        in experiment: PersonalExperiment,
        pairIndex: Int,
        armKind: ExperimentArmKind
    ) -> [Int] {
        experiment.observations.indices.filter { index in
            let observation = experiment.observations[index]
            return observation.pairIndex == pairIndex
                && observation.armKind == armKind
                && observation.requestedCondition.conditionFollowed
                && observation.classification != .confounded
                && observation.classification != .insufficient
        }
        .sorted { experiment.observations[$0].date < experiment.observations[$1].date }
    }

    private static func confoundLaterObservation(
        normalIndex: Int,
        testIndex: Int,
        kind: ExperimentConfoundKind,
        explanation: String,
        experiment: inout PersonalExperiment
    ) {
        let laterIndex = experiment.observations[normalIndex].date >= experiment.observations[testIndex].date
            ? normalIndex
            : testIndex
        experiment.observations[laterIndex].classification = .confounded
        experiment.observations[laterIndex].classificationReason = explanation
        if !experiment.observations[laterIndex].confounds.contains(where: { $0.kind == kind }) {
            experiment.observations[laterIndex].confounds.append(
                ExperimentConfound(kind: kind, explanation: explanation)
            )
        }
    }

    private static func unusablePair(_ pairIndex: Int, reason: String) -> ExperimentPair {
        ExperimentPair(
            pairIndex: pairIndex,
            normalObservationID: nil,
            testObservationID: nil,
            comparison: .unusable,
            explanation: reason
        )
    }

    private static func explanation(
        for result: ExperimentPairResult,
        metric: ExperimentOutcomeMetric
    ) -> String {
        switch result {
        case .testBetter: return "The Test condition looked more useful for \(metric.displayName.lowercased())."
        case .baselineBetter: return "The Normal condition looked more useful for \(metric.displayName.lowercased())."
        case .similar: return "The two conditions looked similar for \(metric.displayName.lowercased())."
        case .unusable: return "This pair could not be compared."
        }
    }

    private static func firstSwitchRank(_ value: FirstSwitchTiming) -> Int? {
        switch value {
        case .underFive: return 0
        case .fiveToTen: return 1
        case .tenToTwenty: return 2
        case .twentyPlus: return 3
        case .notSure: return nil
        }
    }

    private static func recallRank(_ value: RecallSelfAssessment) -> Int {
        switch value {
        case .little: return 0
        case .some: return 1
        case .most: return 2
        }
    }

    private static func explanationRank(_ value: ExplanationSelfAssessment) -> Int {
        switch value {
        case .notYet: return 0
        case .partly: return 1
        case .yes: return 2
        }
    }

    private static func rankedComparison(normal: Int, test: Int) -> ExperimentPairResult {
        if test > normal { return .testBetter }
        if normal > test { return .baselineBetter }
        return .similar
    }
}

enum ExperimentResultEngine {
    static func finalize(_ experiment: inout PersonalExperiment, allowEarly: Bool = false) -> ExperimentResult? {
        if let result = experiment.result { return result }
        let completedPairs = experiment.pairs.filter(\.isComplete)
        let minimum = allowEarly ? experiment.plan.minimumPairs : experiment.plan.targetPairs
        guard completedPairs.count >= minimum else { return nil }

        let testBetter = completedPairs.filter { $0.comparison == .testBetter }.count
        let baselineBetter = completedPairs.filter { $0.comparison == .baselineBetter }.count
        let confoundedCount = experiment.observations.filter { $0.classification == .confounded }.count
        let state: ExperimentResultState
        if confoundedCount > completedPairs.count {
            state = .inconclusive
        } else if completedPairs.count == 2 {
            if testBetter == 2 {
                state = .keep
            } else if baselineBetter == 2 {
                state = .drop
            } else {
                state = .inconclusive
            }
        } else if testBetter >= 2 && baselineBetter == 0 {
            state = .keep
        } else if baselineBetter >= 2 {
            state = .drop
        } else {
            state = .inconclusive
        }

        let comparableIDs = Set(completedPairs.flatMap { pair in
            [pair.normalObservationID, pair.testObservationID].compactMap { $0 }
        })
        let sourceObservations = experiment.observations.filter { comparableIDs.contains($0.id) }
        let result = ExperimentResult(
            state: state,
            primaryOutcome: experiment.primaryOutcome,
            completedPairs: completedPairs.count,
            pairResults: completedPairs,
            headline: headline(for: state),
            summary: summary(for: state, experiment: experiment, testBetter: testBetter, baselineBetter: baselineBetter),
            sourceObservationIDs: sourceObservations.map(\.id),
            sourceEvidenceIDs: Array(Set(sourceObservations.flatMap(\.sourceEvidenceIDs)))
        )
        experiment.result = result
        experiment.status = .completed
        experiment.completedAt = result.finalizedAt
        experiment.updatedAt = result.finalizedAt
        return result
    }

    private static func headline(for state: ExperimentResultState) -> String {
        switch state {
        case .keep: return "Worth keeping."
        case .drop: return "Not useful enough to keep."
        case .inconclusive: return "No clear pattern yet."
        }
    }

    private static func summary(
        for state: ExperimentResultState,
        experiment: PersonalExperiment,
        testBetter: Int,
        baselineBetter: Int
    ) -> String {
        switch state {
        case .keep:
            return "\(experiment.testArm.condition.title) looked more useful in these recent comparable sessions."
        case .drop:
            return "\(experiment.testArm.condition.title) has not looked useful enough to keep in these recent comparisons."
        case .inconclusive:
            if testBetter > 0 || baselineBetter > 0 {
                return "The recent comparable sessions pointed in different directions."
            }
            return "We don't have a clear enough pattern yet."
        }
    }
}

// MARK: - Lab coordination engine

enum ExperimentStartOutcome: Equatable {
    case started(UUID)
    case needsRuleException([UUID])
    case activeExperimentExists(UUID)
    case unavailable
}

enum PersonalLabEngine {
    static func makeExperiment(
        template: ExperimentTemplate,
        origin: ExperimentOrigin = .builtIn,
        linkedRuleID: UUID? = nil,
        now: Date = Date()
    ) -> PersonalExperiment {
        PersonalExperiment(
            templateID: template.id,
            question: template.question,
            rationale: template.rationale,
            normalArm: ExperimentArm(kind: .normal, condition: template.normalCondition),
            testArm: ExperimentArm(kind: .test, condition: template.testCondition),
            eligibleModes: template.eligibleModes,
            preferredDuration: template.preferredDuration,
            primaryOutcome: template.primaryOutcome,
            secondaryOutcomes: template.secondaryOutcomes,
            plan: .balanced(targetPairs: template.targetPairs, minimumPairs: template.minimumPairs),
            status: .draft,
            origin: origin,
            linkedPersonalRuleID: linkedRuleID,
            ruleDraft: template.ruleDraft,
            createdAt: now,
            updatedAt: now
        )
    }

    static func makeCustomExperiment(
        question: String,
        normal: String,
        test: String,
        mode: TrainingMode,
        primaryOutcome: ExperimentOutcomeMetric,
        now: Date = Date()
    ) -> PersonalExperiment {
        let template = ExperimentTemplate(
            id: "custom.\(UUID().uuidString)",
            shortTitle: "Your test",
            question: question,
            rationale: "You chose to test this.",
            normalCondition: ExperimentCondition(
                id: "custom.normal.\(UUID().uuidString)",
                title: "Normal",
                detail: normal
            ),
            testCondition: ExperimentCondition(
                id: "custom.test.\(UUID().uuidString)",
                title: "Test",
                detail: test
            ),
            eligibleModes: [mode],
            preferredDuration: mode.freeDurations.first ?? 10,
            primaryOutcome: primaryOutcome,
            secondaryOutcomes: []
        )
        return makeExperiment(template: template, origin: .userCreated, now: now)
    }

    static func conflictingRuleIDs(
        for experiment: PersonalExperiment,
        rules: [PersonalRule]
    ) -> [UUID] {
        let normalKey = experiment.normalArm.condition.id
        return rules.filter { rule in
            guard rule.lifecycle == .kept else { return false }
            let copy = "\(rule.title) \(rule.detail)".lowercased()
            if normalKey == "phone.usual" {
                return copy.contains("phone") && (copy.contains("reach") || copy.contains("room") || copy.contains("away"))
            }
            if normalKey == "screen_time.unprotected" {
                return copy.contains("protect") || copy.contains("screen time")
            }
            if normalKey == "browser.usual" {
                return copy.contains("tab") || copy.contains("browser")
            }
            if normalKey == "finish_line.usual" {
                return copy.contains("done") || copy.contains("finish")
            }
            return false
        }
        .map(\.id)
    }

    static func start(
        _ experiment: PersonalExperiment,
        in state: inout PersonalLabState,
        rules: [PersonalRule],
        allowingRuleExceptions: Bool = false,
        now: Date = Date()
    ) -> ExperimentStartOutcome {
        if let active = state.activeExperiment, active.id != experiment.id {
            return .activeExperimentExists(active.id)
        }
        let conflicts = conflictingRuleIDs(for: experiment, rules: rules)
        if !conflicts.isEmpty && !allowingRuleExceptions {
            return .needsRuleException(conflicts)
        }
        var started = experiment
        started.status = .active
        started.approvedRuleExceptionIDs = allowingRuleExceptions ? conflicts : []
        started.updatedAt = now
        if let index = state.experiments.firstIndex(where: { $0.id == started.id }) {
            state.experiments[index] = started
        } else {
            state.experiments.append(started)
        }
        return .started(started.id)
    }

    static func nextAssignment(for experiment: PersonalExperiment) -> ExperimentAssignmentSlot? {
        guard experiment.status == .active else { return nil }
        return experiment.plan.armOrder.first { slot in
            !experiment.observations.contains { observation in
                observation.pairIndex == slot.pairIndex
                    && observation.armKind == slot.armKind
                    && observation.requestedCondition.conditionFollowed
                    && (observation.classification == .comparable
                        || observation.classification == .usableButUnmatched)
            }
        }
    }

    static func participation(
        for experiment: PersonalExperiment,
        request: TrainingSessionRequest,
        eligibility: ExperimentEligibilitySnapshot
    ) -> ExperimentParticipation? {
        guard eligibility.eligible,
              let assignment = nextAssignment(for: experiment) else { return nil }
        let arm = experiment.arm(for: assignment.armKind)
        return ExperimentParticipation(
            experimentID: experiment.id,
            armID: arm.id,
            armKind: arm.kind,
            pairIndex: assignment.pairIndex,
            conditionSnapshot: .pending(arm.condition),
            eligibilitySnapshot: eligibility,
            assignmentReason: "Balanced order for comparison \(assignment.pairIndex)."
        )
    }

    static func record(
        session: SessionRecord,
        sourceEvidenceIDs: [UUID],
        in state: inout PersonalLabState
    ) {
        guard let participation = session.experimentParticipation,
              let experimentIndex = state.experiments.firstIndex(where: { $0.id == participation.experimentID }) else { return }
        guard !state.experiments[experimentIndex].observations.contains(where: { $0.sessionID == session.id }) else {
            state.pendingParticipation = nil
            return
        }

        let experiment = state.experiments[experimentIndex]
        var confounds: [ExperimentConfound] = []
        if participation.eligibilitySnapshot.recoveryProtected {
            confounds.append(ExperimentConfound(
                kind: .recoverySession,
                explanation: "Recovery kept its original intent."
            ))
        }
        let screenTimeInterference = participation.conditionSnapshot.requestedConditionID == "screen_time.unprotected"
            && session.environment?.protectionActivated == true
        if screenTimeInterference {
            confounds.append(ExperimentConfound(
                kind: .screenTimeInterference,
                explanation: "A protected window was already active during the Normal condition."
            ))
        }
        if !participation.conditionSnapshot.conditionFollowed && !screenTimeInterference {
            confounds.append(ExperimentConfound(
                kind: .conditionNotFollowed,
                explanation: "The requested condition was not confirmed."
            ))
        }
        if session.endedEarly && experiment.primaryOutcome != .earlyExit {
            confounds.append(ExperimentConfound(
                kind: .endedTooEarly,
                explanation: "The session ended too early for this outcome."
            ))
        }
        let outcomes = outcomes(from: session)
        let primaryAvailable = outcomes[experiment.primaryOutcome.key] != nil
        if !primaryAvailable {
            confounds.append(ExperimentConfound(
                kind: .missingPrimaryOutcome,
                explanation: "The declared primary outcome was not available."
            ))
        }
        let classification: ExperimentObservationClassification
        let reason: String
        let substantiveConfounds = confounds.filter { $0.kind != .missingPrimaryOutcome }
        if let firstConfound = substantiveConfounds.first {
            classification = .confounded
            reason = firstConfound.explanation
        } else if !primaryAvailable {
            classification = .insufficient
            reason = "The primary outcome was missing."
        } else {
            classification = .usableButUnmatched
            reason = "Waiting for the matching condition."
        }

        let observation = ExperimentObservation(
            experimentID: experiment.id,
            sessionID: session.id,
            armID: participation.armID,
            armKind: participation.armKind,
            pairIndex: participation.pairIndex,
            requestedCondition: participation.conditionSnapshot,
            mode: session.mode,
            targetMinutes: session.targetMinutes,
            actualMinutes: session.actualMinutes,
            completed: session.completed,
            endedEarly: session.endedEarly,
            outcomes: outcomes,
            classification: classification,
            classificationReason: reason,
            confounds: confounds,
            sourceEvidenceIDs: sourceEvidenceIDs,
            date: session.date
        )
        state.experiments[experimentIndex].observations.append(observation)
        ExperimentComparisonEngine.updateComparability(&state.experiments[experimentIndex])
        if state.experiments[experimentIndex].completePairCount >= state.experiments[experimentIndex].plan.targetPairs {
            _ = ExperimentResultEngine.finalize(&state.experiments[experimentIndex])
        }
        state.pendingParticipation = nil
    }

    static func pause(id: UUID, in state: inout PersonalLabState, now: Date = Date()) {
        guard let index = state.experiments.firstIndex(where: { $0.id == id && $0.status == .active }) else { return }
        state.experiments[index].status = .paused
        state.experiments[index].updatedAt = now
        state.pendingParticipation = nil
    }

    static func resume(id: UUID, in state: inout PersonalLabState, now: Date = Date()) -> Bool {
        guard state.activeExperiment == nil,
              let index = state.experiments.firstIndex(where: { $0.id == id && $0.status == .paused }) else { return false }
        state.experiments[index].status = .active
        state.experiments[index].updatedAt = now
        return true
    }

    static func abandon(id: UUID, in state: inout PersonalLabState, now: Date = Date()) {
        guard let index = state.experiments.firstIndex(where: { $0.id == id }),
              state.experiments[index].status == .active || state.experiments[index].status == .paused else { return }
        state.experiments[index].status = .abandoned
        state.experiments[index].updatedAt = now
        state.experiments[index].completedAt = now
        state.pendingParticipation = nil
    }

    static func finalize(id: UUID, in state: inout PersonalLabState, allowEarly: Bool) -> ExperimentResult? {
        guard let index = state.experiments.firstIndex(where: { $0.id == id }) else { return nil }
        return ExperimentResultEngine.finalize(&state.experiments[index], allowEarly: allowEarly)
    }

    static func suggestions(
        profile: AttentionProfile,
        sessions: [SessionRecord],
        rules: [PersonalRule],
        state: PersonalLabState,
        screenTimeAvailable: Bool
    ) -> [ExperimentSuggestion] {
        let unavailableTemplateIDs = Set(state.experiments.compactMap { experiment -> String? in
            guard experiment.status == .active || experiment.status == .paused || experiment.status == .completed else { return nil }
            return experiment.templateID
        })
        var suggestions: [ExperimentSuggestion] = []

        for rule in rules where rule.lifecycle == .candidate || rule.confidence == .needsReview || rule.recencyStatus == .older || rule.recencyStatus == .repeatedOlder {
            let copy = "\(rule.title) \(rule.detail)".lowercased()
            let template: ExperimentTemplate?
            if copy.contains("phone") {
                template = .some(ExperimentTemplateLibrary.phoneDistance)
            } else if copy.contains("tab") || copy.contains("browser") {
                template = .some(ExperimentTemplateLibrary.oneBrowserTask)
            } else if copy.contains("done") || copy.contains("finish") {
                template = .some(ExperimentTemplateLibrary.clearFinishLine)
            } else {
                template = nil
            }
            if let template, !unavailableTemplateIDs.contains(template.id) {
                suggestions.append(ExperimentSuggestion(
                    template: template,
                    reason: rule.confidence == .needsReview
                        ? "One of your rules has mixed recent evidence."
                        : "This candidate rule still needs a fair comparison.",
                    linkedPersonalRuleID: rule.id
                ))
            }
        }

        let reportedDistractors = profile.distractors.value ?? []
        let recentBreakers = sessions.suffix(12).compactMap(\.firstDistraction)
        func add(_ template: ExperimentTemplate, reason: String) {
            guard !unavailableTemplateIDs.contains(template.id),
                  !suggestions.contains(where: { $0.template.id == template.id }) else { return }
            suggestions.append(ExperimentSuggestion(template: template, reason: reason))
        }

        let phoneSignals = recentBreakers.filter { $0 == Distractor.phone || $0 == Distractor.social }.count
        if phoneSignals >= 2 || reportedDistractors.contains(Distractor.phone) || reportedDistractors.contains(Distractor.social) {
            add(ExperimentTemplateLibrary.phoneDistance, reason: "Phone-related switching appears often, but distance has not been compared.")
        }
        let tabSignals = recentBreakers.filter { $0 == Distractor.tabs }.count
        if tabSignals >= 2 || reportedDistractors.contains(Distractor.tabs) {
            add(ExperimentTemplateLibrary.oneBrowserTask, reason: "Browser switching appears repeatedly, but a one-task setup is still untested.")
        }
        if screenTimeAvailable && (phoneSignals >= 2 || profile.environmentEvidence?.protectionEarlyExits ?? 0 > 0) {
            add(ExperimentTemplateLibrary.sessionProtection, reason: "Protection is available, and recent sessions leave its usefulness uncertain.")
        }

        let goal = profile.primaryGoal.value ?? ""
        if suggestions.isEmpty, sessions.count >= 2,
           goal.contains("deep") || goal.contains("study") || goal.contains("focus") {
            add(ExperimentTemplateLibrary.clearFinishLine, reason: "Task clarity is relevant to your goal and has not been compared yet.")
        }
        if suggestions.isEmpty, sessions.count >= 3,
           reportedDistractors.contains(Distractor.people) {
            add(ExperimentTemplateLibrary.sound, reason: "Your sound environment appears relevant, but the evidence is still mixed.")
        }
        return Array(suggestions.prefix(3))
    }

    private static func outcomes(from session: SessionRecord) -> [String: ExperimentMetricValue] {
        var outcomes: [String: ExperimentMetricValue] = [:]
        if let switches = session.switches {
            outcomes[ExperimentOutcomeMetric.reportedSwitches.key] = .integer(switches)
        }
        if let timing = session.firstSwitchTiming {
            outcomes[ExperimentOutcomeMetric.firstSwitchTiming.key] = .firstSwitch(timing)
        }
        if let startedEasier = session.startedEasierSelfReport ?? session.environment?.startedEasierSelfReport {
            outcomes[ExperimentOutcomeMetric.startEase.key] = .boolean(startedEasier)
        }
        if let difficulty = session.difficulty {
            outcomes[ExperimentOutcomeMetric.difficulty.key] = .integer(difficulty)
        }
        if let recall = session.evidence?.recall?.selfAssessment {
            outcomes[ExperimentOutcomeMetric.recallAssessment.key] = .recall(recall)
        }
        if let explanation = session.evidence?.explain?.selfAssessment {
            outcomes[ExperimentOutcomeMetric.explanationAssessment.key] = .explanation(explanation)
        }
        outcomes[ExperimentOutcomeMetric.earlyExit.key] = .boolean(session.endedEarly)
        outcomes[ExperimentOutcomeMetric.completion.key] = .boolean(session.completed)
        return outcomes
    }
}
