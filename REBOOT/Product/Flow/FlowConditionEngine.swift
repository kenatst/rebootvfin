import Foundation

enum FlowEngagementClassifier {
    static func classify(
        reflection: FlowBlockReflection,
        completed: Bool,
        endedEarly: Bool
    ) -> FlowEngagementSignal {
        guard reflection.isComplete,
              let absorption = reflection.absorption,
              let time = reflection.timePerception,
              let desire = reflection.desireToContinue else {
            return .insufficient
        }

        if absorption == .high, time == .faster, desire == .continue {
            return .strongerSignal
        }
        if absorption == .low,
           (time == .slower || time == .normal),
           desire == .stop {
            return .lowerSignal
        }
        return .mixed
    }
}

enum FlowConditionDimension: String, Codable, CaseIterable, Equatable, Identifiable {
    case finishLine
    case challengeSkill
    case feedback
    case duration
    case taskCategory
    case daypart
    case phoneSetup
    case screenTimeProtection
    case sound
    case energy
    case movement
    case breakState
    case sleep
    case mealContext

    var id: String { rawValue }

    var label: String {
        switch self {
        case .finishLine: return "Clear finish line"
        case .challengeSkill: return "Challenge"
        case .feedback: return "Feedback"
        case .duration: return "Block length"
        case .taskCategory: return "Task type"
        case .daypart: return "Time of day"
        case .phoneSetup: return "Phone setup"
        case .screenTimeProtection: return "Screen Time"
        case .sound: return "Sound"
        case .energy: return "Energy"
        case .movement: return "Movement"
        case .breakState: return "Break state"
        case .sleep: return "Sleep context"
        case .mealContext: return "Meal context"
        }
    }
}

enum FlowPatternMaturity: String, Codable, Equatable {
    case stillLearning
    case earlySignal
    case repeatedSignal
    case mixedRecently

    var label: String {
        switch self {
        case .stillLearning: return "Still learning"
        case .earlySignal: return "Early signal"
        case .repeatedSignal: return "Repeated signal"
        case .mixedRecently: return "Mixed recently"
        }
    }
}

struct FlowConditionPattern: Identifiable, Equatable {
    var dimension: FlowConditionDimension
    var value: String
    var maturity: FlowPatternMaturity
    var statement: String
    var strongerCount: Int
    var comparableCount: Int
    var supportingEvidenceIDs: [UUID]
    var contradictingEvidenceIDs: [UUID]
    var latestEvidenceDate: Date = .distantPast

    var id: String { "\(dimension.rawValue).\(value)" }

    var accessibilitySummary: String {
        "\(dimension.label). \(maturity.label). \(statement)"
    }
}

enum FlowComparabilityEngine {
    /// Qualitative comparability only. There is deliberately no match score.
    static func areComparable(
        _ lhs: FlowBlockEvidence,
        _ rhs: FlowBlockEvidence,
        state: FlowState
    ) -> Bool {
        guard (10...120).contains(lhs.actualDuration),
              (10...120).contains(rhs.actualDuration),
              let leftPlan = state.plan(id: lhs.planID),
              let rightPlan = state.plan(id: rhs.planID),
              leftPlan.baseMode == rightPlan.baseMode else { return false }

        if lhs.projectID == rhs.projectID {
            return abs(lhs.actualDuration - rhs.actualDuration) <= 20
        }

        let leftCategory = state.project(id: lhs.projectID)?.category
        let rightCategory = state.project(id: rhs.projectID)?.category
        return leftCategory != nil
            && leftCategory == rightCategory
            && abs(lhs.actualDuration - rhs.actualDuration) <= 15
    }

    /// Returns the strongest recent complete-linkage cohort. Every retained
    /// pair is comparable, so a bridge such as 10/30/50 minutes cannot turn
    /// incompatible outer blocks into one evidence set.
    static func strongestMutuallyComparableCohort(
        _ evidence: [FlowBlockEvidence],
        state: FlowState
    ) -> [FlowBlockEvidence] {
        let usable = evidence
            .filter {
                $0.engagementSignal != .insufficient
                    && (10...120).contains($0.actualDuration)
                    && state.plan(id: $0.planID) != nil
            }
            .sorted { $0.date < $1.date }
        let bounded = Array(usable.suffix(8))
        guard !bounded.isEmpty else { return [] }
        var best: [FlowBlockEvidence] = []

        for mask in 1..<(1 << bounded.count) {
            let cohort = bounded.indices.compactMap { index in
                mask & (1 << index) == 0 ? nil : bounded[index]
            }
            let mutuallyComparable = cohort.indices.allSatisfy { left in
                cohort.indices.dropFirst(left + 1).allSatisfy { right in
                    areComparable(cohort[left], cohort[right], state: state)
                }
            }
            guard mutuallyComparable else { continue }
            if cohortRanksAfter(cohort, best) { best = cohort }
        }
        return best
    }

    private static func cohortRanksAfter(
        _ lhs: [FlowBlockEvidence],
        _ rhs: [FlowBlockEvidence]
    ) -> Bool {
        let leftStronger = lhs.lazy.filter { $0.engagementSignal == .strongerSignal }.count
        let rightStronger = rhs.lazy.filter { $0.engagementSignal == .strongerSignal }.count
        if leftStronger != rightStronger { return leftStronger > rightStronger }
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        let leftLatest = lhs.map(\.date).max() ?? .distantPast
        let rightLatest = rhs.map(\.date).max() ?? .distantPast
        if leftLatest != rightLatest { return leftLatest > rightLatest }
        return lhs.map { $0.id.uuidString }.sorted().joined()
            < rhs.map { $0.id.uuidString }.sorted().joined()
    }
}

enum FlowConditionEngine {
    static func evaluate(
        state: FlowState,
        projectID: UUID? = nil
    ) -> [FlowConditionPattern] {
        let allUsable = state.evidence
            .filter { projectID == nil || $0.projectID == projectID }
            .filter {
                $0.engagementSignal != .insufficient
                    && (10...120).contains($0.actualDuration)
            }
            .sorted { $0.date < $1.date }
        // Conditions describe the recent picture. A bounded window lets newer
        // contradictory evidence replace an old pattern instead of fixing an
        // identity forever.
        let usable = Array(allUsable.suffix(8))

        guard usable.count >= 3 else { return [] }

        var patterns: [FlowConditionPattern] = []
        for dimension in FlowConditionDimension.allCases {
            let values = Dictionary(grouping: usable.compactMap { evidence -> LabeledEvidence? in
                guard let value = value(for: dimension, evidence: evidence, state: state) else { return nil }
                return LabeledEvidence(value: value, evidence: evidence)
            }, by: \.value)

            let candidates = values.compactMap { value, labeled -> FlowConditionPattern? in
                let cohort = FlowComparabilityEngine.strongestMutuallyComparableCohort(
                    labeled.map(\.evidence),
                    state: state
                )
                guard cohort.count >= 3 else { return nil }
                let stronger = cohort.filter { $0.engagementSignal == .strongerSignal }
                let contradictions = cohort.filter { $0.engagementSignal == .lowerSignal }
                let mixed = cohort.filter { $0.engagementSignal == .mixed }
                guard stronger.count >= 3 else { return nil }

                let competingStrongValues = values.filter { otherValue, other in
                    guard otherValue != value else { return false }
                    let otherCohort = FlowComparabilityEngine.strongestMutuallyComparableCohort(
                        other.map(\.evidence),
                        state: state
                    )
                    let cohortsOverlap = cohort.contains { candidate in
                        otherCohort.contains { other in
                            FlowComparabilityEngine.areComparable(candidate, other, state: state)
                        }
                    }
                    return cohortsOverlap && otherCohort.filter {
                        $0.engagementSignal == .strongerSignal
                    }.count >= 3
                }
                let maturity: FlowPatternMaturity
                let unresolvedCount = contradictions.count + mixed.count
                if !competingStrongValues.isEmpty || unresolvedCount >= stronger.count {
                    maturity = .mixedRecently
                } else if stronger.count >= 4, stronger.count > unresolvedCount * 2 {
                    maturity = .repeatedSignal
                } else {
                    maturity = .earlySignal
                }

                return FlowConditionPattern(
                    dimension: dimension,
                    value: value,
                    maturity: maturity,
                    statement: statement(
                        dimension: dimension,
                        value: value,
                        maturity: maturity,
                        strongerCount: stronger.count,
                        comparableCount: cohort.count
                    ),
                    strongerCount: stronger.count,
                    comparableCount: cohort.count,
                    supportingEvidenceIDs: stronger.map(\.id),
                    contradictingEvidenceIDs: contradictions.map(\.id),
                    latestEvidenceDate: cohort.map(\.date).max() ?? .distantPast
                )
            }

            if let best = candidates.sorted(by: patternRanksBefore).first {
                patterns.append(best)
            }
        }
        return patterns.sorted(by: patternRanksBefore)
    }

    private struct LabeledEvidence {
        let value: String
        let evidence: FlowBlockEvidence
    }

    private static func value(
        for dimension: FlowConditionDimension,
        evidence: FlowBlockEvidence,
        state: FlowState
    ) -> String? {
        guard let plan = state.plan(id: evidence.planID) else { return nil }
        switch dimension {
        case .finishLine:
            return plan.definitionOfDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : "Clear"
        case .challengeSkill: return plan.challengeSkillRelation.label
        case .feedback: return plan.feedbackLabel
        case .duration: return durationBand(for: evidence.actualDuration)
        case .taskCategory: return state.project(id: evidence.projectID)?.category.label
        case .daypart: return FuelDaypart.derive(from: evidence.date).label
        case .phoneSetup:
            if plan.environmentPlan.phoneSetup == .screenTimeProtected {
                guard screenTimeWasConfirmed(plan: plan, evidence: evidence) else { return nil }
                return "Protected with Screen Time"
            }
            return plan.environmentPlan.phoneSetup.label
        case .screenTimeProtection:
            guard screenTimeWasConfirmed(plan: plan, evidence: evidence) else { return nil }
            return "Protection active"
        case .sound: return plan.environmentPlan.soundContext.label
        case .energy: return evidence.fuelContext?.energy?.label
        case .movement: return evidence.fuelContext?.movement?.label
        case .breakState: return evidence.fuelContext?.breakState?.label
        case .sleep: return evidence.fuelContext?.sleepQuality?.label
        case .mealContext: return evidence.fuelContext?.mealTiming?.label
        }
    }

    private static func screenTimeWasConfirmed(
        plan: FlowBlockPlan,
        evidence: FlowBlockEvidence
    ) -> Bool {
        guard plan.environmentPlan.phoneSetup == .screenTimeProtected,
              plan.environmentPlan.protectionActivated,
              plan.environmentPlan.verification == .screenTimeIntervention
                || plan.environmentPlan.verification == .systemConfirmed,
              let environment = evidence.environment else { return false }
        return environment.protectionOffered
            && environment.protectionAccepted
            && environment.protectionActivated
            && environment.protectedSelectionID != nil
            && environment.environmentCondition == EnvironmentCondition.protected.rawValue
    }

    private static func durationBand(for minutes: Int) -> String {
        let safeMinutes = min(max(minutes, 10), 120)
        let nearest = [10, 15, 20, 25, 30, 35, 45, 60, 90, 120].min {
            abs($0 - safeMinutes) < abs($1 - safeMinutes)
        } ?? 25
        return "About \(nearest) min"
    }

    private static func patternRanksBefore(
        _ lhs: FlowConditionPattern,
        _ rhs: FlowConditionPattern
    ) -> Bool {
        let rank: [FlowPatternMaturity: Int] = [
            .repeatedSignal: 0,
            .earlySignal: 1,
            .mixedRecently: 2,
            .stillLearning: 3,
        ]
        if rank[lhs.maturity] != rank[rhs.maturity] {
            return (rank[lhs.maturity] ?? 4) < (rank[rhs.maturity] ?? 4)
        }
        if lhs.strongerCount != rhs.strongerCount { return lhs.strongerCount > rhs.strongerCount }
        if lhs.latestEvidenceDate != rhs.latestEvidenceDate {
            return lhs.latestEvidenceDate > rhs.latestEvidenceDate
        }
        if lhs.value != rhs.value { return lhs.value < rhs.value }
        return lhs.dimension.rawValue < rhs.dimension.rawValue
    }

    private static func statement(
        dimension: FlowConditionDimension,
        value: String,
        maturity: FlowPatternMaturity,
        strongerCount: Int,
        comparableCount: Int
    ) -> String {
        if maturity == .mixedRecently {
            return "\(dimension.label) has been mixed recently. Keep observing before changing your setup."
        }

        switch dimension {
        case .finishLine:
            return "A clear finish line was present in \(strongerCount) stronger blocks among \(comparableCount) comparable recent blocks."
        case .challengeSkill:
            return "\(value) has appeared often in your stronger comparable blocks."
        case .duration:
            return "\(value) has appeared often in stronger blocks, but longer is not automatically better."
        case .phoneSetup, .screenTimeProtection:
            return "\(value) appears often in stronger comparable blocks; this is an association, not a requirement."
        case .energy, .movement, .breakState, .sleep, .mealContext:
            return "\(value) appeared in several stronger comparable blocks. The context remains observational."
        default:
            return "\(value) has appeared often in stronger comparable blocks."
        }
    }
}
