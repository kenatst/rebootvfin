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

/// Typed namespace for experiment conditions. Existing string-backed IDs
/// remain the wire format; the domain gives comparison and conflict logic a
/// clean, extensible classification instead of keyword heuristics alone.
enum ExperimentConditionDomain: String, Codable, Equatable {
    case digital
    case environment
    case task
    case fuel
    case flow
    case custom

    /// Maps a stored condition ID (e.g. "phone.usual", "fuel.movement.walk_before")
    /// to its domain. Unknown prefixes stay `.custom`, preserving historical
    /// meaning instead of rejecting it.
    static func domain(forConditionID id: String) -> ExperimentConditionDomain {
        if id.hasPrefix("phone.") || id.hasPrefix("screen_time.") || id.hasPrefix("browser.") { return .digital }
        if id.hasPrefix("sound.") { return .environment }
        if id.hasPrefix("finish_line.") { return .task }
        if id.hasPrefix("fuel.") { return .fuel }
        if id.hasPrefix("flow.") { return .flow }
        return .custom
    }
}

/// Machine-readable matcher for observational comparison arms: the arm a
/// session belongs to is determined by naturally occurring context, never by
/// instruction. Daypart matchers resolve from the session timestamp; other
/// fields resolve from the session's Fuel snapshot.
enum ExperimentContextMatcherField: String, Codable, Equatable {
    case daypart
    case sleepQuality
    case mealTiming
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
    /// Observational arms only: which naturally occurring context selects this arm.
    var contextMatcher: ExperimentContextMatcher?

    var requiresManualConfirmation: Bool {
        expectedTruthSource == .userReported
    }

    var domain: ExperimentConditionDomain {
        ExperimentConditionDomain.domain(forConditionID: id)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, detail, timing, expectedTruthSource, requiresExplicitConsent, contextMatcher
    }

    init(
        id: String,
        title: String,
        detail: String,
        timing: ExperimentConditionTiming = .beforeSession,
        expectedTruthSource: ExperimentTruthSource = .userReported,
        requiresExplicitConsent: Bool = false,
        contextMatcher: ExperimentContextMatcher? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.timing = timing
        self.expectedTruthSource = expectedTruthSource
        self.requiresExplicitConsent = requiresExplicitConsent
        self.contextMatcher = contextMatcher
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        detail = try values.decode(String.self, forKey: .detail)
        timing = try values.decodeIfPresent(ExperimentConditionTiming.self, forKey: .timing) ?? .beforeSession
        expectedTruthSource = try values.decodeIfPresent(ExperimentTruthSource.self, forKey: .expectedTruthSource) ?? .userReported
        requiresExplicitConsent = try values.decodeIfPresent(Bool.self, forKey: .requiresExplicitConsent) ?? false
        // v6 conditions predate matchers; absent key must decode to nil.
        contextMatcher = try values.decodeIfPresent(ExperimentContextMatcher.self, forKey: .contextMatcher)
    }
}

/// Observational arm selector: the context value that decides which arm a
/// naturally occurring session belongs to.
struct ExperimentContextMatcher: Codable, Equatable, Hashable {
    var field: ExperimentContextMatcherField
    var value: String

    func matches(snapshot: FuelContextSnapshot?, sessionDate: Date) -> Bool {
        switch field {
        case .daypart:
            return FuelDaypart.derive(from: sessionDate).rawValue == value
        case .sleepQuality:
            return snapshot?.sleepQuality?.rawValue == value
        case .mealTiming:
            return snapshot?.mealTiming?.rawValue == value
        }
    }

    var truthSource: ExperimentTruthSource {
        switch field {
        case .daypart: return .systemConfirmed
        case .sleepQuality, .mealTiming: return .userReported
        }
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

    /// Appends one more balanced pair, continuing the rotation pattern.
    /// Caller enforces the max-pairs policy.
    mutating func extendByOnePair() {
        let nextIndex = targetPairs + 1
        let pairOrders: [[ExperimentArmKind]] = [
            [.normal, .test],
            [.test, .normal],
            [.normal, .test],
        ]
        let order = pairOrders[(nextIndex - 1) % pairOrders.count]
        armOrder.append(contentsOf: order.map {
            ExperimentAssignmentSlot(pairIndex: nextIndex, armKind: $0)
        })
        targetPairs = nextIndex
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
    /// Variable-aware comparability: the target variable did not differ between arms.
    case targetVariableDidNotDiffer
    /// Variable-aware comparability: a non-target context differed between arms.
    case contextMismatch
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
    /// Fuel context captured with the session — used by variable-aware
    /// comparability. Absent on all pre-Fuel observations, which stay valid.
    var fuelContext: FuelContextSnapshot?

    enum CodingKeys: String, CodingKey {
        case id, experimentID, sessionID, armID, armKind, pairIndex, requestedCondition
        case mode, targetMinutes, actualMinutes, completed, endedEarly, outcomes
        case classification, classificationReason, confounds, sourceEvidenceIDs, date, fuelContext
    }

    init(
        id: UUID = UUID(),
        experimentID: UUID,
        sessionID: UUID,
        armID: UUID,
        armKind: ExperimentArmKind,
        pairIndex: Int,
        requestedCondition: ExperimentConditionSnapshot,
        mode: TrainingMode,
        targetMinutes: Int,
        actualMinutes: Int,
        completed: Bool,
        endedEarly: Bool,
        outcomes: [String: ExperimentMetricValue],
        classification: ExperimentObservationClassification,
        classificationReason: String,
        confounds: [ExperimentConfound],
        sourceEvidenceIDs: [UUID],
        date: Date,
        fuelContext: FuelContextSnapshot? = nil
    ) {
        self.id = id
        self.experimentID = experimentID
        self.sessionID = sessionID
        self.armID = armID
        self.armKind = armKind
        self.pairIndex = pairIndex
        self.requestedCondition = requestedCondition
        self.mode = mode
        self.targetMinutes = targetMinutes
        self.actualMinutes = actualMinutes
        self.completed = completed
        self.endedEarly = endedEarly
        self.outcomes = outcomes
        self.classification = classification
        self.classificationReason = classificationReason
        self.confounds = confounds
        self.sourceEvidenceIDs = sourceEvidenceIDs
        self.date = date
        self.fuelContext = fuelContext
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        experimentID = try values.decode(UUID.self, forKey: .experimentID)
        sessionID = try values.decode(UUID.self, forKey: .sessionID)
        armID = try values.decode(UUID.self, forKey: .armID)
        armKind = try values.decode(ExperimentArmKind.self, forKey: .armKind)
        pairIndex = try values.decode(Int.self, forKey: .pairIndex)
        requestedCondition = try values.decode(ExperimentConditionSnapshot.self, forKey: .requestedCondition)
        mode = try values.decode(TrainingMode.self, forKey: .mode)
        targetMinutes = try values.decode(Int.self, forKey: .targetMinutes)
        actualMinutes = try values.decode(Int.self, forKey: .actualMinutes)
        completed = try values.decode(Bool.self, forKey: .completed)
        endedEarly = try values.decode(Bool.self, forKey: .endedEarly)
        outcomes = try values.decodeIfPresent([String: ExperimentMetricValue].self, forKey: .outcomes) ?? [:]
        classification = try values.decode(ExperimentObservationClassification.self, forKey: .classification)
        classificationReason = try values.decode(String.self, forKey: .classificationReason)
        confounds = try values.decodeIfPresent([ExperimentConfound].self, forKey: .confounds) ?? []
        sourceEvidenceIDs = try values.decodeIfPresent([UUID].self, forKey: .sourceEvidenceIDs) ?? []
        date = try values.decode(Date.self, forKey: .date)
        fuelContext = try values.decodeIfPresent(FuelContextSnapshot.self, forKey: .fuelContext)
    }
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

/// The two conceptual comparison types Personal Lab supports.
/// - interventionTest: the user deliberately changes one condition.
/// - observationalComparison: REBOOT compares naturally occurring contexts
///   (e.g. morning vs afternoon). The user never manipulates the variable.
enum ExperimentComparisonKind: String, Codable, Equatable {
    case interventionTest
    case observationalComparison

    var displayLabel: String {
        switch self {
        case .interventionTest: return "Deliberate test"
        case .observationalComparison: return "Naturally occurring"
        }
    }
}

/// The variable an experiment deliberately varies. Variable-aware
/// comparability allows the target variable to differ between arms while
/// other contexts remain matched. Mirrors the typed condition namespace.
enum ExperimentTargetVariable: String, Codable, Equatable {
    case phoneDistance
    case screenProtection
    case browserScope
    case sound
    case finishLine
    case movement
    case breakStyle
    case daypart
    case sleepContext
    case mealContext
    case caffeineContext
}

/// Conservative pair policy: default 3 balanced pairs, at most 5 total when
/// an INCONCLUSIVE result earns one more comparison.
enum ExperimentPolicy {
    static let defaultTargetPairs = 3
    static let maxPairs = 5
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
    /// Optional provenance when Flow Lab surfaced the question. The Lab still
    /// owns the comparison and result semantics.
    var sourceFlowPatternID: String? = nil
    var discoveryEvidenceIDs: [UUID] = []
    var comparisonKind: ExperimentComparisonKind = .interventionTest
    var targetVariable: ExperimentTargetVariable? = nil
    var observations: [ExperimentObservation] = []
    var pairs: [ExperimentPair] = []
    var result: ExperimentResult?
    /// Results superseded by an INCONCLUSIVE extension. Never double-counted:
    /// the active result always reflects all completed pairs.
    var historicalResults: [ExperimentResult] = []
    var approvedRuleExceptionIDs: [UUID] = []
    var linkedPersonalRuleID: UUID?
    var ruleDraft: ExperimentRuleDraft?
    var createdAt = Date()
    var updatedAt = Date()
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        templateID: String?,
        version: Int = 1,
        question: String,
        rationale: String,
        normalArm: ExperimentArm,
        testArm: ExperimentArm,
        eligibleModes: [TrainingMode],
        preferredDuration: Int,
        primaryOutcome: ExperimentOutcomeMetric,
        secondaryOutcomes: [ExperimentOutcomeMetric],
        plan: ExperimentPlan,
        status: ExperimentStatus,
        origin: ExperimentOrigin,
        sourceFlowPatternID: String? = nil,
        discoveryEvidenceIDs: [UUID] = [],
        comparisonKind: ExperimentComparisonKind = .interventionTest,
        targetVariable: ExperimentTargetVariable? = nil,
        observations: [ExperimentObservation] = [],
        pairs: [ExperimentPair] = [],
        result: ExperimentResult? = nil,
        historicalResults: [ExperimentResult] = [],
        approvedRuleExceptionIDs: [UUID] = [],
        linkedPersonalRuleID: UUID? = nil,
        ruleDraft: ExperimentRuleDraft? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.version = version
        self.question = question
        self.rationale = rationale
        self.normalArm = normalArm
        self.testArm = testArm
        self.eligibleModes = eligibleModes
        self.preferredDuration = preferredDuration
        self.primaryOutcome = primaryOutcome
        self.secondaryOutcomes = secondaryOutcomes
        self.plan = plan
        self.status = status
        self.origin = origin
        self.sourceFlowPatternID = sourceFlowPatternID
        self.discoveryEvidenceIDs = discoveryEvidenceIDs
        self.comparisonKind = comparisonKind
        self.targetVariable = targetVariable
        self.observations = observations
        self.pairs = pairs
        self.result = result
        self.historicalResults = historicalResults
        self.approvedRuleExceptionIDs = approvedRuleExceptionIDs
        self.linkedPersonalRuleID = linkedPersonalRuleID
        self.ruleDraft = ruleDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, templateID, version, question, rationale, normalArm, testArm
        case eligibleModes, preferredDuration, primaryOutcome, secondaryOutcomes
        case plan, status, origin, sourceFlowPatternID, discoveryEvidenceIDs
        case comparisonKind, targetVariable
        case observations, pairs, result, historicalResults
        case approvedRuleExceptionIDs, linkedPersonalRuleID, ruleDraft
        case createdAt, updatedAt, completedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        templateID = try values.decodeIfPresent(String.self, forKey: .templateID)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        question = try values.decode(String.self, forKey: .question)
        rationale = try values.decode(String.self, forKey: .rationale)
        normalArm = try values.decode(ExperimentArm.self, forKey: .normalArm)
        testArm = try values.decode(ExperimentArm.self, forKey: .testArm)
        eligibleModes = try values.decode([TrainingMode].self, forKey: .eligibleModes)
        preferredDuration = try values.decode(Int.self, forKey: .preferredDuration)
        primaryOutcome = try values.decode(ExperimentOutcomeMetric.self, forKey: .primaryOutcome)
        secondaryOutcomes = try values.decodeIfPresent([ExperimentOutcomeMetric].self, forKey: .secondaryOutcomes) ?? []
        plan = try values.decode(ExperimentPlan.self, forKey: .plan)
        status = try values.decode(ExperimentStatus.self, forKey: .status)
        origin = try values.decode(ExperimentOrigin.self, forKey: .origin)
        sourceFlowPatternID = try? values.decodeIfPresent(String.self, forKey: .sourceFlowPatternID)
        discoveryEvidenceIDs = (try? values.decodeIfPresent(
            [UUID].self,
            forKey: .discoveryEvidenceIDs
        )) ?? []
        // v6 experiments predate Fuel: absent keys decode to safe defaults.
        comparisonKind = try values.decodeIfPresent(ExperimentComparisonKind.self, forKey: .comparisonKind) ?? .interventionTest
        targetVariable = try values.decodeIfPresent(ExperimentTargetVariable.self, forKey: .targetVariable)
        observations = try values.decodeIfPresent([ExperimentObservation].self, forKey: .observations) ?? []
        pairs = try values.decodeIfPresent([ExperimentPair].self, forKey: .pairs) ?? []
        result = try values.decodeIfPresent(ExperimentResult.self, forKey: .result)
        historicalResults = try values.decodeIfPresent([ExperimentResult].self, forKey: .historicalResults) ?? []
        approvedRuleExceptionIDs = try values.decodeIfPresent([UUID].self, forKey: .approvedRuleExceptionIDs) ?? []
        linkedPersonalRuleID = try values.decodeIfPresent(UUID.self, forKey: .linkedPersonalRuleID)
        ruleDraft = try values.decodeIfPresent(ExperimentRuleDraft.self, forKey: .ruleDraft)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    func arm(for kind: ExperimentArmKind) -> ExperimentArm {
        kind == .normal ? normalArm : testArm
    }

    var completePairCount: Int {
        pairs.filter(\.isComplete).count
    }

    /// Extends an INCONCLUSIVE experiment with exactly one more balanced pair.
    /// The experiment ID, question, conditions, and primary metric are
    /// unchanged; the previous result is preserved as history; the status
    /// becomes active again. Returns false when extension is not allowed.
    mutating func extendForAdditionalComparison(now: Date = Date()) -> Bool {
        guard let currentResult = result,
              currentResult.state == .inconclusive,
              status == .completed,
              plan.targetPairs < ExperimentPolicy.maxPairs else { return false }
        historicalResults.append(currentResult)
        result = nil
        status = .active
        completedAt = nil
        plan.extendByOnePair()
        updatedAt = now
        return true
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
    var comparisonKind: ExperimentComparisonKind = .interventionTest
    var targetVariable: ExperimentTargetVariable? = nil
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
        shortWalkBeforeFocus,
        noInputBreak,
        morningFocus,
        sleepQualityComparison,
        mealTimingComparison,
    ]

    /// Deliberate Fuel tests — safe intentional setups run through Personal Lab.
    static let fuelInterventionTemplates: [ExperimentTemplate] = [
        shortWalkBeforeFocus,
        noInputBreak,
    ]

    /// Observational comparisons of naturally occurring contexts. The user
    /// never manipulates the variable; arms are selected by real context.
    static let fuelObservationalTemplates: [ExperimentTemplate] = [
        morningFocus,
        sleepQualityComparison,
        mealTimingComparison,
    ]

    static func template(id: String) -> ExperimentTemplate? {
        all.first { $0.id == id }
    }

    // MARK: Fuel — deliberate safe setups (intervention tests)

    /// "Does a short comfortable walk before focused work change how starting feels?"
    /// No intensity, no duration target, self-reported truth. Always optional.
    static let shortWalkBeforeFocus = ExperimentTemplate(
        id: "fuel_walk_before_focus",
        shortTitle: "Short walk before focus",
        question: "Does a short comfortable walk before focused work change how starting feels?",
        rationale: "Movement is worth one fair comparison — only when it feels suitable for you.",
        normalCondition: ExperimentCondition(
            id: "fuel.movement.usual",
            title: "Start normally",
            detail: "Begin the session the way you usually would."
        ),
        testCondition: ExperimentCondition(
            id: "fuel.movement.walk_before",
            title: "Short comfortable walk first",
            detail: "Take a short, comfortable walk before starting. Stop if it doesn't suit you."
        ),
        eligibleModes: [.stay],
        preferredDuration: 15,
        primaryOutcome: .startEase,
        secondaryOutcomes: [.difficulty, .reportedSwitches],
        comparisonKind: .interventionTest,
        targetVariable: .movement,
        ruleDraft: ExperimentRuleDraft(
            title: "When practical, take a short walk before difficult focus",
            detail: "A short comfortable walk before starting focused work is worth trying when it fits.",
            category: .timing,
            contexts: [.stay, .deepWork]
        )
    )

    /// "Does taking a short no-input break make returning easier than your usual break?"
    static let noInputBreak = ExperimentTemplate(
        id: "fuel_no_input_break",
        shortTitle: "No-input break",
        question: "Does taking a short no-input break make returning easier than your usual break?",
        rationale: "What you do during a break may matter as much as taking one. A fair comparison settles it for you.",
        normalCondition: ExperimentCondition(
            id: "fuel.break.usual",
            title: "Your usual break",
            detail: "Take the kind of break you normally would."
        ),
        testCondition: ExperimentCondition(
            id: "fuel.break.no_input",
            title: "Break without new input",
            detail: "A short break with no feeds, no scrolling, no new input."
        ),
        eligibleModes: [.stay, .recall],
        preferredDuration: 15,
        primaryOutcome: .startEase,
        secondaryOutcomes: [.difficulty, .completion],
        comparisonKind: .interventionTest,
        targetVariable: .breakStyle,
        ruleDraft: ExperimentRuleDraft(
            title: "A short no-input break is worth trying before restarting",
            detail: "After a long work block, a short break without new input may make returning easier.",
            category: .environment,
            contexts: [.stay, .recall, .deepWork]
        )
    )

    // MARK: Fuel — observational comparisons (naturally occurring)

    /// Morning vs afternoon. Daypart arms are system-derived from the session
    /// timestamp: the user is never told to change when they work.
    static let morningFocus = ExperimentTemplate(
        id: "fuel_morning_vs_afternoon",
        shortTitle: "Morning vs afternoon",
        question: "Do your demanding sessions feel steadier before noon or later in the day?",
        rationale: "You already work at different times. REBOOT can compare the sessions that occur naturally.",
        normalCondition: ExperimentCondition(
            id: "fuel.daypart.afternoon",
            title: "Afternoon sessions",
            detail: "Sessions that begin between noon and 5pm.",
            expectedTruthSource: .systemConfirmed,
            contextMatcher: ExperimentContextMatcher(field: .daypart, value: FuelDaypart.afternoon.rawValue)
        ),
        testCondition: ExperimentCondition(
            id: "fuel.daypart.morning",
            title: "Morning sessions",
            detail: "Sessions that begin before noon.",
            expectedTruthSource: .systemConfirmed,
            contextMatcher: ExperimentContextMatcher(field: .daypart, value: FuelDaypart.morning.rawValue)
        ),
        eligibleModes: [.stay, .recall],
        preferredDuration: 15,
        primaryOutcome: .difficulty,
        secondaryOutcomes: [.reportedSwitches, .firstSwitchTiming],
        minimumPairs: 2,
        targetPairs: 3,
        comparisonKind: .observationalComparison,
        targetVariable: .daypart,
        ruleDraft: ExperimentRuleDraft(
            title: "When possible, schedule demanding work earlier",
            detail: "Morning has looked more reliable for demanding work in your comparable sessions.",
            category: .timing,
            contexts: [.stay, .recall, .deepWork]
        )
    )

    /// Naturally occurring sleep reports — rough vs good. Never a manipulation.
    static let sleepQualityComparison = ExperimentTemplate(
        id: "fuel_sleep_quality_context",
        shortTitle: "Sleep context",
        question: "Do sessions after rough-reported sleep feel different from sessions after good-reported sleep?",
        rationale: "Your sleep varies on its own. This only compares sessions you already have.",
        normalCondition: ExperimentCondition(
            id: "fuel.sleep.rough",
            title: "After rough-reported sleep",
            detail: "Sessions started after a night you described as rough.",
            contextMatcher: ExperimentContextMatcher(field: .sleepQuality, value: FuelSleepQuality.rough.rawValue)
        ),
        testCondition: ExperimentCondition(
            id: "fuel.sleep.good",
            title: "After good-reported sleep",
            detail: "Sessions started after a night you described as good.",
            contextMatcher: ExperimentContextMatcher(field: .sleepQuality, value: FuelSleepQuality.good.rawValue)
        ),
        eligibleModes: [.stay, .recall, .explain],
        preferredDuration: 15,
        primaryOutcome: .difficulty,
        secondaryOutcomes: [.reportedSwitches, .completion],
        comparisonKind: .observationalComparison,
        targetVariable: .sleepContext
    )

    /// Naturally occurring meal timing — recently ate vs between meals.
    /// Pure context; no dietary instruction of any kind.
    static let mealTimingComparison = ExperimentTemplate(
        id: "fuel_meal_timing_context",
        shortTitle: "Meal timing context",
        question: "Do sessions right after eating feel different from sessions between meals?",
        rationale: "Meal timing varies naturally across your week. This only observes what already happens.",
        normalCondition: ExperimentCondition(
            id: "fuel.meal.between",
            title: "Between meals",
            detail: "Sessions started between meals.",
            contextMatcher: ExperimentContextMatcher(field: .mealTiming, value: FuelMealTiming.betweenMeals.rawValue)
        ),
        testCondition: ExperimentCondition(
            id: "fuel.meal.recently_ate",
            title: "Recently ate",
            detail: "Sessions started soon after a meal.",
            contextMatcher: ExperimentContextMatcher(field: .mealTiming, value: FuelMealTiming.recentlyAte.rawValue)
        ),
        eligibleModes: [.stay, .recall, .explain],
        preferredDuration: 15,
        primaryOutcome: .difficulty,
        secondaryOutcomes: [.reportedSwitches, .completion],
        comparisonKind: .observationalComparison,
        targetVariable: .mealContext
    )
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

            // Variable-aware comparability: only when both arms captured Fuel
            // context. Missing context stays missing — it never confounds.
            if let variable = experiment.targetVariable,
               let contextConfound = evaluateVariableAwareMatch(
                normal: normal,
                test: test,
                targetVariable: variable
               ) {
                confoundLaterObservation(
                    normalIndex: normalIndex,
                    testIndex: testIndex,
                    kind: contextConfound.kind,
                    explanation: contextConfound.explanation,
                    experiment: &experiment
                )
                rebuiltPairs.append(unusablePair(pairIndex, reason: contextConfound.explanation))
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

    /// Variable-aware matching. The experiment's target variable is ALLOWED
    /// (indeed required) to differ between arms; other contexts should match.
    /// Fuel-era contexts only: absent context never confounds.
    private static func evaluateVariableAwareMatch(
        normal: ExperimentObservation,
        test: ExperimentObservation,
        targetVariable: ExperimentTargetVariable
    ) -> (kind: ExperimentConfoundKind, explanation: String)? {
        if targetVariable == .daypart {
            let normalDaypart = FuelDaypart.derive(from: normal.date)
            let testDaypart = FuelDaypart.derive(from: test.date)
            if normalDaypart == testDaypart {
                return (.targetVariableDidNotDiffer, "Both sessions happened in the same part of the day.")
            }
        } else {
            let normalDaypart = FuelDaypart.derive(from: normal.date)
            let testDaypart = FuelDaypart.derive(from: test.date)
            if normalDaypart != testDaypart {
                return (.contextMismatch, "The sessions happened at different times of day.")
            }
        }
        if let normalTask = normal.fuelContext?.taskContext,
           let testTask = test.fuelContext?.taskContext,
           normalTask != testTask {
            return (.contextMismatch, "The task types were different.")
        }
        return nil
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

// MARK: - Opportunity-aware surfacing

enum ExperimentOpportunity: Equatable {
    /// The current session genuinely counts toward the test.
    case eligibleNow(message: String)
    /// The session is comparable, but a kept-rule exception needs explicit approval.
    case eligibleWithConfirmation(message: String)
    /// Today's real session cannot support a fair comparison.
    case notComparable(reasons: [String])
    /// The test itself cannot run (Day 1, recovery, paused, finished).
    case blocked(reasons: [String])
}

/// Deterministic eligibility for surfacing experiment opportunities. Lab
/// surfaces only when a genuinely compatible session exists — this reduces
/// "Continue test" noise on days that can never count.
enum ExperimentOpportunityEngine {
    static func evaluate(
        request: TrainingSessionRequest,
        experiment: PersonalExperiment,
        isRecovery: Bool,
        activeRecurringProtection: Bool = false,
        rules: [PersonalRule] = [],
        fuel: FuelContextSnapshot? = nil,
        sessionDate: Date = Date()
    ) -> ExperimentOpportunity {
        var blockedReasons: [String] = []
        if experiment.status != .active {
            blockedReasons.append("This test is not active.")
        }
        if request.origin == .protocol, request.programDay == 1 {
            blockedReasons.append("Day 1 protects your natural baseline.")
        }
        if isRecovery {
            blockedReasons.append("Recovery sessions keep their original intent.")
        }
        if !blockedReasons.isEmpty {
            return .blocked(reasons: blockedReasons)
        }

        var reasons: [String] = []
        if !experiment.eligibleModes.contains(request.mode) {
            reasons.append("This training mode is not comparable for the current question.")
        }
        if request.origin == .protocol,
           !PersonalLabEligibilityEngine.durationCompatible(request.targetMinutes, experiment.preferredDuration) {
            reasons.append("Today's session length is not comparable for this test.")
        }

        if experiment.comparisonKind == .observationalComparison {
            // The session's real context must select an open arm.
            if PersonalLabEngine.observationalAssignment(
                for: experiment,
                fuel: fuel,
                sessionDate: sessionDate
            ) == nil {
                let needed = PersonalLabEngine.fuelFieldNeeded(by: experiment)
                if let needed {
                    reasons.append("This test needs to know your \(needed.label.lowercased()) first.")
                } else {
                    reasons.append("Today's context does not fill the next comparison slot.")
                }
            }
        } else if let assignment = PersonalLabEngine.nextAssignment(for: experiment),
                  assignment.armKind == .normal,
                  experiment.normalArm.condition.id == "screen_time.unprotected",
                  activeRecurringProtection {
            reasons.append("A protected window is already active.")
        }

        if !reasons.isEmpty {
            return .notComparable(reasons: reasons)
        }

        if experiment.comparisonKind == .interventionTest {
            let conflicts = PersonalLabEngine.conflictingRuleIDs(for: experiment, rules: rules)
            if !conflicts.isEmpty && !experiment.approvedRuleExceptionIDs.contains(conflicts[0]) {
                return .eligibleWithConfirmation(
                    message: "This test needs a temporary exception to one of your kept rules. The rule stays kept."
                )
            }
        }
        return .eligibleNow(message: "Today can count toward your current test.")
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
            comparisonKind: template.comparisonKind,
            targetVariable: template.targetVariable,
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
        let normalCondition = experiment.normalArm.condition
        return rules.filter { rule in
            guard rule.lifecycle == .kept else { return false }
            let copy = "\(rule.title) \(rule.detail)".lowercased()
            switch normalCondition.domain {
            case .digital:
                // Legacy keyword heuristics kept byte-for-byte: the digital
                // conflict behavior is verified by existing regression tests.
                if normalCondition.id == "phone.usual" {
                    return copy.contains("phone") && (copy.contains("reach") || copy.contains("room") || copy.contains("away"))
                }
                if normalCondition.id == "screen_time.unprotected" {
                    return copy.contains("protect") || copy.contains("screen time")
                }
                if normalCondition.id == "browser.usual" {
                    return copy.contains("tab") || copy.contains("browser")
                }
                return false
            case .task:
                if normalCondition.id == "finish_line.usual" {
                    return copy.contains("done") || copy.contains("finish")
                }
                return false
            case .fuel:
                // Conservative: only same-dimension fuel rules can conflict.
                switch experiment.targetVariable {
                case .movement:
                    return copy.contains("walk")
                case .breakStyle:
                    return copy.contains("break")
                default:
                    return false
                }
            case .environment, .flow, .custom:
                return false
            }
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

    /// For observational comparisons, the arm is chosen by the naturally
    /// occurring context — never by instruction. Returns the open pair and
    /// the arm this real context can fill, or nil when nothing matches.
    static func observationalAssignment(
        for experiment: PersonalExperiment,
        fuel: FuelContextSnapshot?,
        sessionDate: Date
    ) -> (slot: ExperimentAssignmentSlot, arm: ExperimentArm)? {
        guard experiment.comparisonKind == .observationalComparison,
              experiment.status == .active else { return nil }
        func hasUsable(_ pairIndex: Int, _ armKind: ExperimentArmKind) -> Bool {
            experiment.observations.contains { observation in
                observation.pairIndex == pairIndex
                    && observation.armKind == armKind
                    && observation.requestedCondition.conditionFollowed
                    && (observation.classification == .comparable
                        || observation.classification == .usableButUnmatched)
            }
        }
        for pairIndex in 1...experiment.plan.targetPairs {
            let normalFilled = hasUsable(pairIndex, .normal)
            let testFilled = hasUsable(pairIndex, .test)
            if normalFilled && testFilled { continue }
            if !normalFilled,
               experiment.normalArm.condition.contextMatcher?.matches(snapshot: fuel, sessionDate: sessionDate) == true {
                return (
                    ExperimentAssignmentSlot(pairIndex: pairIndex, armKind: .normal),
                    experiment.normalArm
                )
            }
            if !testFilled,
               experiment.testArm.condition.contextMatcher?.matches(snapshot: fuel, sessionDate: sessionDate) == true {
                return (
                    ExperimentAssignmentSlot(pairIndex: pairIndex, armKind: .test),
                    experiment.testArm
                )
            }
            // This pair is open but today's context does not fill it; later
            // pairs stay closed until earlier ones complete.
            return nil
        }
        return nil
    }

    /// The Fuel field an active observational experiment still needs, if any.
    /// Daypart experiments need nothing (derived from the timestamp).
    static func fuelFieldNeeded(by experiment: PersonalExperiment) -> FuelContextField? {
        guard experiment.status == .active,
              experiment.comparisonKind == .observationalComparison else { return nil }
        switch experiment.targetVariable {
        case .sleepContext: return .sleepQuality
        case .mealContext: return .mealTiming
        default: return nil
        }
    }

    /// True while an active deliberate Fuel test (walk, no-input break) owns
    /// the user's one deliberate variable — generic sampling stays silent.
    static func hasActiveFuelConditionTest(_ experiment: PersonalExperiment?) -> Bool {
        guard let experiment, experiment.status == .active else { return false }
        return experiment.comparisonKind == .interventionTest
            && experiment.normalArm.condition.domain == .fuel
    }

    static func participation(
        for experiment: PersonalExperiment,
        request: TrainingSessionRequest,
        eligibility: ExperimentEligibilitySnapshot,
        fuel: FuelContextSnapshot? = nil,
        sessionDate: Date = Date()
    ) -> ExperimentParticipation? {
        guard eligibility.eligible else { return nil }
        if experiment.comparisonKind == .observationalComparison {
            guard let assignment = observationalAssignment(
                for: experiment,
                fuel: fuel,
                sessionDate: sessionDate
            ) else { return nil }
            // The context itself selects the arm: the condition is followed
            // by definition, with the honest truth source for that context.
            var snapshot = ExperimentConditionSnapshot.pending(assignment.arm.condition)
            snapshot.actualDescription = assignment.arm.condition.detail
            snapshot.truthSource = assignment.arm.condition.contextMatcher?.truthSource ?? .userReported
            snapshot.conditionFollowed = true
            snapshot.capturedAt = sessionDate
            return ExperimentParticipation(
                experimentID: experiment.id,
                armID: assignment.arm.id,
                armKind: assignment.arm.kind,
                pairIndex: assignment.slot.pairIndex,
                conditionSnapshot: snapshot,
                eligibilitySnapshot: eligibility,
                assignmentReason: "Filled by your naturally occurring context (pair \(assignment.slot.pairIndex))."
            )
        }
        guard let assignment = nextAssignment(for: experiment) else { return nil }
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
            date: session.date,
            fuelContext: session.fuelContext
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

        // Fuel observational opportunities: real context data already exists
        // on both sides, so a fair comparison is genuinely executable.
        let withFuel = sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
        if withFuel.count >= 4 {
            let morningStay = withFuel.filter { $0.mode == .stay && $0.fuelContext?.daypart == .morning }
            let afternoonStay = withFuel.filter { $0.mode == .stay && $0.fuelContext?.daypart == .afternoon }
            if morningStay.count >= 2 && afternoonStay.count >= 2 {
                add(ExperimentTemplateLibrary.morningFocus, reason: "You already have morning and afternoon sessions worth comparing.")
            }
            let goodSleep = withFuel.filter { $0.fuelContext?.sleepQuality == .good }
            let roughSleep = withFuel.filter { $0.fuelContext?.sleepQuality == .rough }
            if goodSleep.count >= 2 && roughSleep.count >= 2 {
                add(ExperimentTemplateLibrary.sleepQualityComparison, reason: "You've reported both good and rough nights recently.")
            }
            let recentlyAte = withFuel.filter { $0.fuelContext?.mealTiming == .recentlyAte }
            let betweenMeals = withFuel.filter { $0.fuelContext?.mealTiming == .betweenMeals }
            if recentlyAte.count >= 2 && betweenMeals.count >= 2 {
                add(ExperimentTemplateLibrary.mealTimingComparison, reason: "Meal timing varies naturally across your sessions.")
            }
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
