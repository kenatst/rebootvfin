import Foundation

// MARK: - Evidence

/// Where a piece of profile knowledge comes from. Unknown stays unknown.
enum EvidenceSource: String, Codable, Equatable {
    case selfReport
    case observed
    case session
    case repeated

    var label: String {
        switch self {
        case .selfReport: return "self-reported"
        case .observed: return "observed"
        case .session: return "from a session"
        case .repeated: return "repeated evidence"
        }
    }
}

/// A profile dimension that is either honestly unknown or backed by a source.
enum Knowledge<Value: Codable & Equatable>: Codable, Equatable {
    case unknown
    case known(Value, source: EvidenceSource)

    var value: Value? {
        if case .known(let value, _) = self { return value }
        return nil
    }

    var source: EvidenceSource? {
        if case .known(_, let source) = self { return source }
        return nil
    }

    var isKnown: Bool { value != nil }
}

// MARK: - Levels

enum ReflexLevel: String, Codable, Equatable { case low, medium, high }
enum StabilityLevel: String, Codable, Equatable { case low, medium, high }
enum ReturnLevel: String, Codable, Equatable { case weak, fair, strong }
enum RecallLevel: String, Codable, Equatable { case weak, fair, strong }
enum DepthLevel: String, Codable, Equatable { case shallow, fair, deep }

// MARK: - Recency & Evidence Labels

enum RecencyStatus: String, Codable, CaseIterable, Equatable {
    case recent = "recent"
    case current = "current"
    case older = "older"
    case mixedRecently = "mixedRecently"
    case repeatedRecent = "repeatedRecent"
    case repeatedOlder = "repeatedOlder"

    var humanLabel: String {
        switch self {
        case .recent: return "Recent"
        case .current: return "Still current"
        case .older: return "Older evidence"
        case .mixedRecently: return "Mixed recently"
        case .repeatedRecent: return "Repeated signal · recent"
        case .repeatedOlder: return "Repeated signal · older evidence"
        }
    }
}

enum RuleCategory: String, Codable, CaseIterable, Equatable {
    case environment = "Environment"
    case friction = "Friction"
    case timing = "Timing"
    case taskSetup = "Task Setup"
}

enum RuleContext: String, Codable, CaseIterable, Equatable {
    case stay = "STAY"
    case recall = "RECALL"
    case explain = "EXPLAIN"
    case rest = "NOTHING"
    case observe = "OBSERVE"
    case deepWork = "deep_work"
    case highDistraction = "high_distraction"
    case general = "general"
}

enum RuleLifecycle: String, Codable, CaseIterable, Equatable {
    case candidate = "candidate"
    case testing = "testing"
    case kept = "kept"
    case rejected = "rejected"
    case retired = "retired"

    var displayLabel: String {
        switch self {
        case .candidate: return "Suggested rule"
        case .testing: return "Testing"
        case .kept: return "Kept"
        case .rejected: return "Dismissed"
        case .retired: return "Retired"
        }
    }
}

enum RuleSourceType: String, Codable, CaseIterable, Equatable {
    case discoveredFromEvidence = "discovered"
    case userCreated = "userCreated"
    case experiment = "experiment"

    var displayLabel: String {
        switch self {
        case .discoveredFromEvidence: return "Discovered from your sessions"
        case .userCreated: return "Created by you"
        case .experiment: return "Kept from a Personal Lab test"
        }
    }
}

enum RuleConfidence: String, Codable, CaseIterable, Equatable {
    case emerging = "emerging"
    case moderate = "moderate"
    case strong = "strong"
    case needsReview = "needsReview"

    var displayLabel: String {
        switch self {
        case .emerging: return "Early pattern"
        case .moderate: return "Consistent signal"
        case .strong: return "Strong pattern"
        case .needsReview: return "Needs another look"
        }
    }
}

enum EnvironmentVerificationState: String, Codable, CaseIterable, Equatable {
    case userReported = "userReported"
    case systemConfirmed = "systemConfirmed"
    case screenTimeIntervention = "screenTimeIntervention"
    case unknown = "unknown"

    var displayLabel: String {
        switch self {
        case .userReported: return "Self-reported"
        case .systemConfirmed: return "System-confirmed"
        case .screenTimeIntervention: return "Screen Time shield"
        case .unknown: return "Unverified"
        }
    }
}

struct EvidenceObservation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sessionID: UUID?
    var day: Int
    var mode: TrainingMode
    var date: Date = Date()
    var source: EvidenceSource
    var verificationState: EnvironmentVerificationState
    var finding: String
    var sentiment: String // "positive", "neutral", "contradictory"
    var context: RuleContext
    var recency: RecencyStatus = .recent
    var experimentID: UUID? = nil
}

struct PersonalRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var category: RuleCategory
    var matchingContexts: [RuleContext]
    var lifecycle: RuleLifecycle
    var sourceType: RuleSourceType
    var confidence: RuleConfidence
    var supportingObservations: [String]
    var contradictingObservations: [String]
    var recencyStatus: RecencyStatus
    var createdDay: Int
    var lastTestedDay: Int?
    var timesTested: Int
    var timesKept: Int
    var experimentID: UUID? = nil
    var supportingEvidenceIDs: [UUID]? = nil

    var isActivelyInfluencing: Bool {
        lifecycle == .kept && confidence != .needsReview
    }

    var whyRebootSuggested: WhyThisRuleExplanation {
        WhyThisRuleExplanation(rule: self)
    }
}

struct WhyThisRuleExplanation: Equatable {
    let ruleTitle: String
    let sourceDescription: String
    let supportingPoints: [String]
    let contradictionPoint: String?
    let maturityAndRecency: String
    let disclaimer: String

    init(rule: PersonalRule) {
        self.ruleTitle = rule.title
        self.sourceDescription = rule.sourceType == .userCreated
            ? "Created by you."
            : (rule.sourceType == .experiment ? "KEPT FROM PERSONAL LAB" : "WHY REBOOT SUGGESTED THIS")
        if rule.sourceType == .userCreated {
            self.supportingPoints = []
            self.contradictionPoint = nil
            self.maturityAndRecency = rule.recencyStatus.humanLabel
            self.disclaimer = "This is a rule created directly by you."
        } else {
            self.supportingPoints = Array(rule.supportingObservations.prefix(3))
            self.contradictionPoint = rule.contradictingObservations.first
            self.maturityAndRecency = "\(rule.confidence.displayLabel) · \(rule.recencyStatus.humanLabel.lowercased())"
            self.disclaimer = "This is an association from your recent sessions, not proof of cause."
        }
    }
}

// MARK: - Attention Profile

struct AttentionProfile: Codable, Equatable {
    var primaryGoal: Knowledge<String> = .unknown
    var goals: Knowledge<[String]> = .unknown
    var distractors: Knowledge<[String]> = .unknown
    var reflex: Knowledge<ReflexLevel> = .unknown
    var attentionStability: Knowledge<StabilityLevel> = .unknown
    var returnAfterDistraction: Knowledge<ReturnLevel> = .unknown
    var recall: Knowledge<RecallLevel> = .unknown
    var depth: Knowledge<DepthLevel> = .unknown
    var environment: Knowledge<String> = .unknown
    var flowConditions: Knowledge<[String]> = .unknown
    var energyContext: Knowledge<String> = .unknown
    /// Digital-environment evidence (Screen Time / manual interventions).
    var environmentEvidence: EnvironmentEvidence?

    /// Active or candidate personal rules discovered from sessions or user-defined.
    var personalRules: [PersonalRule] = []

    /// Discovered observations ledger.
    var observations: [EvidenceObservation] = []

    /// Derived focus window in minutes from diagnosis or sessions.
    var focusWindowMinutes: Int? = nil

    var knownDimensions: Int {
        let dims: [Bool] = [
            primaryGoal.isKnown, goals.isKnown, distractors.isKnown, reflex.isKnown,
            attentionStability.isKnown, returnAfterDistraction.isKnown, recall.isKnown,
            depth.isKnown, environment.isKnown, flowConditions.isKnown, energyContext.isKnown,
        ]
        return dims.filter { $0 }.count
    }
}

// MARK: - Training Modes

enum TrainingMode: String, Codable, CaseIterable, Equatable, Identifiable {
    case stay = "STAY"
    case recall = "RECALL"
    case explain = "EXPLAIN"
    case nothing = "NOTHING"
    case observe = "OBSERVE"

    var id: String { rawValue }

    var display: String {
        switch self {
        case .stay: return "Stay"
        case .recall: return "Recall"
        case .explain: return "Explain"
        case .nothing: return "Rest"
        case .observe: return "Observe"
        }
    }

    var tagline: String {
        switch self {
        case .stay: return "Sustained attention"
        case .recall: return "Return & memory"
        case .explain: return "Active recall"
        case .nothing: return "Recovery"
        case .observe: return "Baseline"
        }
    }

    var libraryDescription: String {
        switch self {
        case .stay: return "Hold one task."
        case .recall: return "Read. Close. Reconstruct."
        case .explain: return "Learn. Close. Teach."
        case .nothing: return "No new stimulus."
        case .observe: return "Notice before reacting."
        }
    }

    var trains: String {
        switch self {
        case .stay: return "Sustaining attention and returning after a switch."
        case .recall: return "Bringing material back without keeping it visible."
        case .explain: return "Turning material into an idea you can teach."
        case .nothing: return "Tolerating a short period without new input."
        case .observe: return "Noticing the moment attention changes direction."
        }
    }

    var freeDurations: [Int] {
        switch self {
        case .stay: return [10, 15, 20, 30, 45]
        case .recall: return [10, 15, 20, 30]
        case .explain: return [10, 15, 20, 30]
        case .nothing: return [3, 5, 10]
        case .observe: return [5, 10, 15]
        }
    }

    var usesStrictTimer: Bool {
        self == .stay || self == .nothing || self == .observe
    }
}

// MARK: - Session

enum SessionOrigin: String, Codable, CaseIterable, Equatable {
    case `protocol`
    case freeTraining
    case flow
    case experiment

    var advancesProgram: Bool { self == .protocol }
}

enum FirstSwitchTiming: String, Codable, CaseIterable, Equatable {
    case underFive
    case fiveToTen
    case tenToTwenty
    case twentyPlus
    case notSure

    var label: String {
        switch self {
        case .underFive: return "Under 5 min"
        case .fiveToTen: return "5–10 min"
        case .tenToTwenty: return "10–20 min"
        case .twentyPlus: return "20+ min"
        case .notSure: return "Not sure"
        }
    }

    static func from(legacyMinute: Int?) -> FirstSwitchTiming? {
        guard let legacyMinute else { return nil }
        if legacyMinute < 5 { return .underFive }
        if legacyMinute < 10 { return .fiveToTen }
        if legacyMinute < 20 { return .tenToTwenty }
        return .twentyPlus
    }
}

enum RecallSelfAssessment: String, Codable, Equatable {
    case little
    case some
    case most
}

enum ExplanationMethod: String, Codable, Equatable {
    case spoken
    case written
}

enum ExplanationSelfAssessment: String, Codable, Equatable {
    case yes
    case partly
    case notYet
}

enum NothingDifficulty: String, Codable, Equatable {
    case urgeToCheck
    case restlessness
    case thoughts
    case nothingInParticular
}

struct StayEvidence: Codable, Equatable {
    var task: String
    var completionDefinition: String?
    var switchTimestamps: [Int] = []
    var firstSwitchTiming: FirstSwitchTiming?
    var returnNote: String?
}

struct RecallEvidence: Codable, Equatable {
    var source: String
    var reconstruction: String
    var selfAssessment: RecallSelfAssessment?
    var missedIdea: String?
}

struct ExplainEvidence: Codable, Equatable {
    var topic: String
    var source: String?
    var method: ExplanationMethod?
    var response: String?
    var selfAssessment: ExplanationSelfAssessment?
    var breakdown: String?
}

struct NothingEvidence: Codable, Equatable {
    var difficulty: NothingDifficulty?
}

struct ObserveEvidence: Codable, Equatable {
    var mission: String
    var observation: String?
    var firstSwitchTiming: FirstSwitchTiming?
}

struct SessionEvidence: Codable, Equatable {
    var stay: StayEvidence?
    var recall: RecallEvidence?
    var explain: ExplainEvidence?
    var nothing: NothingEvidence?
    var observe: ObserveEvidence?
}

enum EnvironmentPreparationOutcome: String, Codable, Equatable {
    case pending
    case completed
    case fallback
    case declined
}

struct EnvironmentPreparation: Codable, Equatable {
    var action: String
    var fallback: String?
    var outcome: EnvironmentPreparationOutcome
    var arm: SessionEnvironmentArm?

    var actionWasDone: Bool? {
        switch outcome {
        case .completed, .fallback: return true
        case .declined: return false
        case .pending: return nil
        }
    }
}

struct TrainingSessionRequest: Codable, Identifiable, Equatable {
    var id = UUID()
    var prescriptionID: UUID?
    var origin: SessionOrigin
    var mode: TrainingMode
    var programDay: Int?
    var targetMinutes: Int
    var goal: String
    var task: String?
    var completionDefinition: String?
    var source: String?
    var topic: String?
    var observationMission: String?
    var environmentPreparation: EnvironmentPreparation?
    var appliedRuleIDs: [UUID] = []
    var programPhase: ProgramPhaseID?
    var curriculumIntent: CurriculumIntentKind?
    var adaptationReason: String?
    var experimentParticipation: ExperimentParticipation?
    var createdAt = Date()

    static func protocolRequest(
        prescription: DailyPrescription,
        day: Int,
        environmentPreparation: EnvironmentPreparation?
    ) -> TrainingSessionRequest {
        TrainingSessionRequest(
            id: UUID(),
            prescriptionID: prescription.id,
            origin: .protocol,
            mode: prescription.mode,
            programDay: day,
            targetMinutes: prescription.minutes,
            goal: prescription.goal,
            observationMission: prescription.mode == .observe
                ? (prescription.observationMission ?? "Work normally.")
                : nil,
            environmentPreparation: environmentPreparation,
            appliedRuleIDs: prescription.appliedRuleIDs,
            programPhase: prescription.programPhase,
            curriculumIntent: prescription.curriculumIntent,
            adaptationReason: prescription.adaptationReason
        )
    }

    static func freeTraining(mode: TrainingMode) -> TrainingSessionRequest {
        TrainingSessionRequest(
            id: UUID(),
            prescriptionID: nil,
            origin: .freeTraining,
            mode: mode,
            programDay: nil,
            targetMinutes: mode.freeDurations.first ?? 10,
            goal: mode.libraryDescription,
            observationMission: mode == .observe ? ObservationMission.all.first : nil,
            environmentPreparation: nil,
            appliedRuleIDs: []
        )
    }
}

enum ObservationMission {
    static let all = [
        "Notice what you reach for when attention breaks.",
        "Notice the moment you decide to switch tasks.",
        "Notice what happens just before you unlock your phone.",
        "Notice what makes returning easier.",
    ]
}

struct SessionRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var origin: SessionOrigin = .protocol
    var requestID: UUID?
    var prescriptionID: UUID?
    var day: Int
    var date: Date
    var mode: TrainingMode
    var targetMinutes: Int
    var actualMinutes: Int
    var elapsedSeconds: Int = 0
    var completed: Bool
    var endedEarly: Bool = false
    var firstDistraction: String?
    var switches: Int?
    var difficulty: Int?
    var energy: Int?
    var environmentActionDone: Bool?
    var environmentVerification: EnvironmentVerificationState?
    var startedEasierSelfReport: Bool?

    /// Minutes into the session when the first switch was noticed, if remembered.
    var firstSwitchMinute: Int?

    /// Categorical estimate preserves the precision the user actually supplied.
    var firstSwitchTiming: FirstSwitchTiming?

    var evidence: SessionEvidence?

    /// Captured rules applied during this session.
    var appliedRuleIDs: [UUID] = []

    /// Environment preparation setup at start.
    var environmentPreparation: EnvironmentPreparation?

    /// Curriculum context captured when the protocol request was created.
    var programPhase: ProgramPhaseID?
    var curriculumIntent: CurriculumIntentKind?
    var adaptationReason: String?

    /// What actually happened in the digital environment during the session.
    var environment: EnvironmentSnapshot?

    /// Personal Lab participation is orthogonal to SessionOrigin. A protocol
    /// session remains protocol while contributing one Lab observation.
    var experimentParticipation: ExperimentParticipation?

    init(
        id: UUID = UUID(),
        origin: SessionOrigin = .protocol,
        requestID: UUID? = nil,
        prescriptionID: UUID? = nil,
        day: Int,
        date: Date,
        mode: TrainingMode,
        targetMinutes: Int,
        actualMinutes: Int,
        elapsedSeconds: Int = 0,
        completed: Bool,
        endedEarly: Bool = false,
        firstDistraction: String? = nil,
        switches: Int? = nil,
        difficulty: Int? = nil,
        energy: Int? = nil,
        environmentActionDone: Bool? = nil,
        environmentVerification: EnvironmentVerificationState? = nil,
        startedEasierSelfReport: Bool? = nil,
        firstSwitchMinute: Int? = nil,
        firstSwitchTiming: FirstSwitchTiming? = nil,
        evidence: SessionEvidence? = nil,
        appliedRuleIDs: [UUID] = [],
        environmentPreparation: EnvironmentPreparation? = nil,
        programPhase: ProgramPhaseID? = nil,
        curriculumIntent: CurriculumIntentKind? = nil,
        adaptationReason: String? = nil,
        environment: EnvironmentSnapshot? = nil,
        experimentParticipation: ExperimentParticipation? = nil
    ) {
        self.id = id
        self.origin = origin
        self.requestID = requestID
        self.prescriptionID = prescriptionID
        self.day = day
        self.date = date
        self.mode = mode
        self.targetMinutes = targetMinutes
        self.actualMinutes = actualMinutes
        self.elapsedSeconds = elapsedSeconds
        self.completed = completed
        self.endedEarly = endedEarly
        self.firstDistraction = firstDistraction
        self.switches = switches
        self.difficulty = difficulty
        self.energy = energy
        self.environmentActionDone = environmentActionDone
        self.environmentVerification = environmentVerification
        self.startedEasierSelfReport = startedEasierSelfReport
        self.firstSwitchMinute = firstSwitchMinute
        self.firstSwitchTiming = firstSwitchTiming ?? FirstSwitchTiming.from(legacyMinute: firstSwitchMinute)
        self.evidence = evidence
        self.appliedRuleIDs = appliedRuleIDs
        self.environmentPreparation = environmentPreparation
        self.programPhase = programPhase
        self.curriculumIntent = curriculumIntent
        self.adaptationReason = adaptationReason
        self.environment = environment
        self.experimentParticipation = experimentParticipation
    }

    private enum CodingKeys: String, CodingKey {
        case id, origin, requestID, prescriptionID, day, date, mode, targetMinutes, actualMinutes
        case elapsedSeconds, completed, endedEarly, firstDistraction, switches, difficulty
        case energy, environmentActionDone, environmentVerification, startedEasierSelfReport, firstSwitchMinute, firstSwitchTiming, evidence
        case appliedRuleIDs, environmentPreparation, programPhase, curriculumIntent, adaptationReason, environment
        case experimentParticipation
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        origin = try values.decodeIfPresent(SessionOrigin.self, forKey: .origin) ?? .protocol
        requestID = try values.decodeIfPresent(UUID.self, forKey: .requestID)
        prescriptionID = try values.decodeIfPresent(UUID.self, forKey: .prescriptionID)
        day = try values.decode(Int.self, forKey: .day)
        date = try values.decode(Date.self, forKey: .date)
        mode = try values.decode(TrainingMode.self, forKey: .mode)
        targetMinutes = try values.decode(Int.self, forKey: .targetMinutes)
        actualMinutes = try values.decode(Int.self, forKey: .actualMinutes)
        elapsedSeconds = try values.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? actualMinutes * 60
        completed = try values.decode(Bool.self, forKey: .completed)
        endedEarly = try values.decodeIfPresent(Bool.self, forKey: .endedEarly) ?? false
        firstDistraction = try values.decodeIfPresent(String.self, forKey: .firstDistraction)
        switches = try values.decodeIfPresent(Int.self, forKey: .switches)
        difficulty = try values.decodeIfPresent(Int.self, forKey: .difficulty)
        energy = try values.decodeIfPresent(Int.self, forKey: .energy)
        environmentActionDone = try values.decodeIfPresent(Bool.self, forKey: .environmentActionDone)
        environmentVerification = try values.decodeIfPresent(EnvironmentVerificationState.self, forKey: .environmentVerification)
        startedEasierSelfReport = try values.decodeIfPresent(Bool.self, forKey: .startedEasierSelfReport)
        firstSwitchMinute = try values.decodeIfPresent(Int.self, forKey: .firstSwitchMinute)
        firstSwitchTiming = try values.decodeIfPresent(FirstSwitchTiming.self, forKey: .firstSwitchTiming)
            ?? FirstSwitchTiming.from(legacyMinute: firstSwitchMinute)
        evidence = try values.decodeIfPresent(SessionEvidence.self, forKey: .evidence)
        appliedRuleIDs = try values.decodeIfPresent([UUID].self, forKey: .appliedRuleIDs) ?? []
        environmentPreparation = try values.decodeIfPresent(EnvironmentPreparation.self, forKey: .environmentPreparation)
        programPhase = try values.decodeIfPresent(ProgramPhaseID.self, forKey: .programPhase)
        curriculumIntent = try values.decodeIfPresent(CurriculumIntentKind.self, forKey: .curriculumIntent)
        adaptationReason = try values.decodeIfPresent(String.self, forKey: .adaptationReason)
        environment = try values.decodeIfPresent(EnvironmentSnapshot.self, forKey: .environment)
        experimentParticipation = try values.decodeIfPresent(ExperimentParticipation.self, forKey: .experimentParticipation)
    }

    var targetReached: Bool {
        elapsedSeconds >= targetMinutes * 60
    }
}

struct SessionReflection: Equatable {
    var difficulty: Int
    var energy: Int? = nil
    var firstDistraction: String? = nil
    var switches: Int? = nil
    var firstSwitchTiming: FirstSwitchTiming? = nil
    var startedEasier: Bool? = nil
    var protectionExitReason: String? = nil
    var recallAssessment: RecallSelfAssessment? = nil
    var missedIdea: String? = nil
    var explanationAssessment: ExplanationSelfAssessment? = nil
    var explanationBreakdown: String? = nil
    var nothingDifficulty: NothingDifficulty? = nil
    var observation: String? = nil
}

// MARK: - Prescription

struct DailyPrescription: Codable, Equatable {
    var id: UUID = UUID()
    var day: Int
    var mode: TrainingMode
    var minutes: Int
    var headline: String
    var sentence: String
    var goal: String
    var reason: String
    var action: String
    var actionFallback: String
    var environmentChange: String?
    var adaptationReason: String
    /// Optional environment intervention (friction ladder 0–4).
    var environmentAction: EnvironmentAction?
    var appliedRuleIDs: [UUID] = []
    var appliedRuleTitle: String? = nil
    var programPhase: ProgramPhaseID? = nil
    var curriculumIntent: CurriculumIntentKind? = nil
    var curriculumReason: String? = nil
    var recentEvidenceReason: String? = nil
    var observationMission: String? = nil
    var requiresEnvironmentPreparation: Bool = true

    static let empty = DailyPrescription(
        id: UUID(),
        day: 1,
        mode: .observe,
        minutes: 15,
        headline: "Work normally.",
        sentence: "We're measuring how you work today — nothing to change yet.",
        goal: "One normal focus block.",
        reason: "We need a real baseline before changing anything.",
        action: "Work normally today — this is your baseline.",
        actionFallback: "If you can't work normally, just do 5 focused minutes.",
        environmentChange: nil,
        adaptationReason: "No sessions yet — first observation.",
        environmentAction: nil,
        appliedRuleIDs: [],
        appliedRuleTitle: nil
    )
}

// MARK: - Distractor helpers

enum Distractor {
    static let phone = "phone"
    static let social = "social"
    static let notifications = "notifications"
    static let tabs = "tabs"
    static let people = "people"
    static let internalRestlessness = "internal"

    static func fromDiagnosis(_ answers: Answers) -> [String] {
        var out: [String] = []
        for value in answers["breaker"] ?? [] {
            switch value {
            case "notifications": out.append(notifications)
            case "social": out.append(social)
            case "messages": out.append(notifications)
            case "restlessness": out.append(internalRestlessness)
            case "people": out.append(people)
            case "tabs": out.append(tabs)
            default: break
            }
        }
        if answers["social_app"]?.isEmpty == false {
            out.append(social)
        }
        if answers["phone_place"]?.isEmpty == false {
            out.append(phone)
        }
        return Array(Set(out))
    }

    static func action(for top: String) -> String {
        switch top {
        case phone: return "Leave your phone outside the room."
        case social: return "Leave your phone outside the room."
        case notifications: return "Silence notifications and move your phone out of reach."
        case tabs: return "Close every tab except the one you need."
        case people: return "Find a quiet room, or put on headphones."
        case internalRestlessness: return "Clear your desk — put one task in front of you."
        default: return "Work normally today — this is your baseline."
        }
    }

    static func fallback(for top: String) -> String {
        switch top {
        case phone, social: return "If you can't leave it behind, put it face-down and silenced."
        case notifications: return "If you can't silence everything, use airplane mode for the block."
        case tabs: return "If you need the other tabs, park them in a reading list first."
        case people: return "If there's no quiet room, pick the least noisy corner."
        case internalRestlessness: return "If the desk can't be cleared, just start — the first minute counts."
        default: return "If you can't work normally, just do 5 focused minutes."
        }
    }
}

// MARK: - Profile Builder (diagnosis → profile)

enum ProfileBuilder {
    static func build(from answers: Answers) -> AttentionProfile {
        var profile = AttentionProfile()
        let src = EvidenceSource.selfReport

        if let primary = answers["primary"]?.first {
            profile.primaryGoal = .known(primary, source: src)
        }
        if let goals = answers["goals"], !goals.isEmpty {
            profile.goals = .known(goals, source: src)
        }
        let distractors = Distractor.fromDiagnosis(answers)
        if !distractors.isEmpty {
            profile.distractors = .known(distractors, source: src)
        }

        switch answers["focus_window"]?.first {
        case "lt5":
            profile.focusWindowMinutes = 10
            profile.reflex = .known(.high, source: src)
            profile.attentionStability = .known(.low, source: src)
        case "5_15":
            profile.focusWindowMinutes = 15
            profile.reflex = .known(.medium, source: src)
            profile.attentionStability = .known(.low, source: src)
        case "15_30":
            profile.focusWindowMinutes = 20
            profile.reflex = .known(.medium, source: src)
            profile.attentionStability = .known(.medium, source: src)
        case "30_60":
            profile.focusWindowMinutes = 30
            profile.reflex = .known(.low, source: src)
            profile.attentionStability = .known(.medium, source: src)
        case "gt60":
            profile.focusWindowMinutes = 45
            profile.reflex = .known(.low, source: src)
            profile.attentionStability = .known(.high, source: src)
        default:
            profile.focusWindowMinutes = 15
        }

        switch answers["reading"]?.first {
        case "reread", "drift", "forget":
            profile.recall = .known(.weak, source: src)
        case "screen_only":
            profile.recall = .known(.fair, source: src)
        default:
            break
        }

        if let target = answers["recall_target"]?.first {
            profile.recall = .known(.fair, source: src)
            _ = target
        }

        if let environment = answers["environment"]?.first {
            profile.environment = .known(environment, source: src)
        }
        if let energy = answers["energy"]?.first {
            profile.energyContext = .known(energy, source: src)
        }
        if let flow = answers["absorption"], !flow.isEmpty {
            profile.flowConditions = .known(flow, source: src)
        }
        if let absorption = answers["absorption"], absorption.count >= 2 {
            profile.depth = .known(.fair, source: src)
        } else if answers["absorption"]?.isEmpty == false {
            profile.depth = .known(.shallow, source: src)
        }

        return profile
    }
}

// MARK: - Personal Rule Engine

enum PersonalRuleEngine {
    /// Evaluates completed sessions to discover new candidate rules or update confidence / recency on existing rules.
    static func evaluate(
        session: SessionRecord,
        rules: inout [PersonalRule],
        profile: inout AttentionProfile,
        allSessions: [SessionRecord]
    ) {
        let isDifficult = session.endedEarly || (session.difficulty ?? 0) >= 4 || (session.switches ?? 0) >= 4
        let isSmooth = session.completed && !session.endedEarly && (session.difficulty ?? 0) <= 2 && (session.switches ?? 0) <= 2

        // 1. Update any existing rules that were active during this session
        let activeRuleIDs = Set(session.appliedRuleIDs)
        for i in 0..<rules.count {
            let wasActive = activeRuleIDs.contains(rules[i].id)
            if wasActive {
                rules[i].lastTestedDay = session.day
                rules[i].timesTested += 1

                if isDifficult {
                    let note = "One later session still felt difficult."
                    if !rules[i].contradictingObservations.contains(note) {
                        rules[i].contradictingObservations.append(note)
                    }
                    rules[i].recencyStatus = .mixedRecently
                    // Downgrade confidence, but NEVER silently delete or retire the user's kept rule:
                    if rules[i].confidence == .strong {
                        rules[i].confidence = .moderate
                    } else if rules[i].confidence == .moderate || rules[i].confidence == .emerging {
                        rules[i].confidence = .needsReview
                    }
                } else if isSmooth {
                    if rules[i].confidence == .needsReview {
                        rules[i].confidence = .moderate
                    } else if rules[i].confidence == .moderate {
                        rules[i].confidence = .strong
                    }
                    rules[i].recencyStatus = rules[i].timesTested >= 3 ? .repeatedRecent : .recent
                }
            } else {
                // Rule wasn't tested in this session. If it has not been tested in over 8 sessions, mark recency status as older.
                if let last = rules[i].lastTestedDay, session.day - last >= 8 {
                    if rules[i].recencyStatus == .repeatedRecent {
                        rules[i].recencyStatus = .repeatedOlder
                    } else if rules[i].recencyStatus == .recent || rules[i].recencyStatus == .current {
                        rules[i].recencyStatus = .older
                    }
                }
            }
        }

        // 2. Discover new candidate rules from session history
        discoverCandidateRules(sessions: allSessions, rules: &rules, profile: profile)

        // 3. Record an observation
        let observation = EvidenceObservation(
            id: UUID(),
            sessionID: session.id,
            day: session.day,
            mode: session.mode,
            date: session.date,
            source: session.origin == .protocol ? .session : .selfReport,
            verificationState: session.environmentVerification ?? (session.environmentActionDone == true ? .userReported : .unknown),
            finding: findingText(for: session),
            sentiment: isDifficult ? "contradictory" : (isSmooth ? "positive" : "neutral"),
            context: context(for: session.mode),
            recency: .recent,
            experimentID: session.experimentParticipation?.experimentID
        )
        profile.observations.append(observation)
        profile.personalRules = rules
    }

    static func keep(id: UUID, in rules: inout [PersonalRule]) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].lifecycle = .kept
        rules[index].timesKept += 1
        if rules[index].confidence == .needsReview {
            rules[index].confidence = .moderate
        }
    }

    static func test(id: UUID, in rules: inout [PersonalRule]) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].lifecycle = .testing
        rules[index].timesTested += 1
    }

    static func retire(id: UUID, in rules: inout [PersonalRule]) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].lifecycle = .retired
    }

    static func reject(id: UUID, in rules: inout [PersonalRule]) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].lifecycle = .rejected
    }

    static func addCustom(
        title: String,
        detail: String,
        category: RuleCategory,
        contexts: [RuleContext],
        day: Int,
        into rules: inout [PersonalRule]
    ) {
        let newRule = PersonalRule(
            id: UUID(),
            title: title,
            detail: detail,
            category: category,
            matchingContexts: contexts.isEmpty ? [.general] : contexts,
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: day,
            lastTestedDay: day,
            timesTested: 0,
            timesKept: 1
        )
        rules.append(newRule)
    }

    private static func context(for mode: TrainingMode) -> RuleContext {
        switch mode {
        case .stay: return .stay
        case .recall: return .recall
        case .explain: return .explain
        case .nothing: return .rest
        case .observe: return .observe
        }
    }

    private static func findingText(for session: SessionRecord) -> String {
        if let switches = session.switches {
            return "\(session.mode.rawValue) session (\(session.actualMinutes)m) completed with \(switches) switch\(switches == 1 ? "" : "es")."
        }
        return "\(session.mode.rawValue) session completed (\(session.actualMinutes) min)."
    }

    private static func discoverCandidateRules(
        sessions: [SessionRecord],
        rules: inout [PersonalRule],
        profile: AttentionProfile
    ) {
        let completed = sessions.filter(\.completed)
        guard completed.count >= 2 else { return }

        // Candidate 1: Phone outside reach
        let phoneAwaySessions = completed.filter {
            $0.environmentActionDone == true || $0.environment?.manualIntervention?.contains("reach") == true
        }
        if phoneAwaySessions.count >= 2 && !rules.contains(where: { $0.title.lowercased().contains("phone") }) {
            let avgSwitches = Double(phoneAwaySessions.compactMap(\.switches).reduce(0, +)) / Double(max(1, phoneAwaySessions.compactMap(\.switches).count))
            let candidate = PersonalRule(
                id: UUID(),
                title: "Keep phone outside reach during focus sessions",
                detail: "Leaving your phone out of reach is associated with fewer switches in recent focus sessions.",
                category: .environment,
                matchingContexts: [.stay, .deepWork, .highDistraction],
                lifecycle: .candidate,
                sourceType: .discoveredFromEvidence,
                confidence: phoneAwaySessions.count >= 3 ? .moderate : .emerging,
                supportingObservations: [
                    "Your phone was outside reach in \(phoneAwaySessions.count) recent comparable focus sessions.",
                    "\(phoneAwaySessions.count > 1 ? "\(phoneAwaySessions.count - 1) of those" : "Those") sessions involved fewer reported switches (avg \(Int(avgSwitches.rounded())))."
                ],
                contradictingObservations: [],
                recencyStatus: .recent,
                createdDay: sessions.last?.day ?? 1,
                lastTestedDay: sessions.last?.day,
                timesTested: phoneAwaySessions.count,
                timesKept: 0
            )
            rules.append(candidate)
        }

        // Candidate 2: Single tab / clear desk
        let tabsReported = completed.filter { $0.firstDistraction == "tabs" || $0.mode == .stay }
        if tabsReported.count >= 3 && !rules.contains(where: { $0.title.lowercased().contains("tab") }) {
            let candidate = PersonalRule(
                id: UUID(),
                title: "Close unrelated tabs before starting Stay blocks",
                detail: "Single-window setups reduce accidental switching during sustained work.",
                category: .taskSetup,
                matchingContexts: [.stay, .recall],
                lifecycle: .candidate,
                sourceType: .discoveredFromEvidence,
                confidence: .emerging,
                supportingObservations: [
                    "Unrelated tabs were noted as a trigger in \(tabsReported.count) recent sessions.",
                    "Single-task focus blocks showed longer initial stretches before the first switch."
                ],
                contradictingObservations: [],
                recencyStatus: .current,
                createdDay: sessions.last?.day ?? 1,
                lastTestedDay: sessions.last?.day,
                timesTested: 1,
                timesKept: 0
            )
            rules.append(candidate)
        }
    }
}

// MARK: - Prescription Engine

enum PrescriptionEngine {
    static func prescription(
        profile: AttentionProfile,
        sessions: [SessionRecord],
        day: Int,
        reviews: [WeeklyReviewRecord] = []
    ) -> DailyPrescription {
        let definition = CurriculumEngine.definition(
            for: day,
            profile: profile,
            protocolHistory: sessions,
            reviews: reviews
        )
        return prescription(
            profile: profile,
            protocolHistory: sessions,
            definition: definition,
            reviews: reviews
        )
    }

    static func prescription(
        profile: AttentionProfile,
        protocolHistory: [SessionRecord],
        definition: ProgramDayDefinition,
        reviews: [WeeklyReviewRecord] = []
    ) -> DailyPrescription {
        // Day 1 baseline is protected from all rules and environment interventions
        if definition.day == 1,
           !protocolHistory.contains(where: { $0.day == 1 && $0.completed }) {
            return baseline(definition: definition)
        }

        // Recovery is protected from rules
        if let last = protocolHistory.last,
           last.mode != .nothing,
           last.endedEarly || (last.difficulty ?? 0) >= 4 {
            return recovery(profile: profile, history: protocolHistory, definition: definition)
        }

        let mode = selectMode(
            profile: profile,
            history: protocolHistory,
            definition: definition,
            reviews: reviews
        )
        return makePrescription(
            mode: mode,
            profile: profile,
            history: protocolHistory,
            definition: definition
        )
    }

    private static func baseline(definition: ProgramDayDefinition) -> DailyPrescription {
        return DailyPrescription(
            id: UUID(),
            day: 1,
            mode: .observe,
            minutes: 15,
            headline: "Work normally.",
            sentence: "Notice what happens before changing the conditions.",
            goal: "One normal focus block.",
            reason: "A real baseline comes before any change.",
            action: "Work normally today — this is your baseline.",
            actionFallback: "If you can't work normally, just do 5 focused minutes.",
            environmentChange: nil,
            adaptationReason: "Day 1 protects a natural baseline before any intervention.",
            environmentAction: nil,
            appliedRuleIDs: [],
            appliedRuleTitle: nil,
            programPhase: definition.phase.id,
            curriculumIntent: definition.intent.kind,
            curriculumReason: definition.intent.editorialReason,
            recentEvidenceReason: "No protocol evidence exists yet.",
            observationMission: definition.intent.observationMission,
            requiresEnvironmentPreparation: false
        )
    }

    private static func recovery(
        profile: AttentionProfile,
        history: [SessionRecord],
        definition: ProgramDayDefinition
    ) -> DailyPrescription {
        let recommendation = AdaptiveDurationEngine.recommendation(
            mode: .nothing,
            profile: profile,
            protocolHistory: history,
            phase: definition.phase
        )
        return DailyPrescription(
            id: UUID(),
            day: definition.day,
            mode: .nothing,
            minutes: recommendation.minutes,
            headline: "Give your mind less to react to.",
            sentence: "Your last session felt hard. Recovery is still real protocol work.",
            goal: "A short, easy block.",
            reason: "The last protocol attempt was demanding, so the load is lower today.",
            action: "Choose a quiet place with no new input.",
            actionFallback: "If even that feels like too much, skip it — the program waits.",
            environmentChange: nil,
            adaptationReason: "A lighter recovery block following a demanding session.",
            environmentAction: nil,
            appliedRuleIDs: [],
            appliedRuleTitle: nil,
            programPhase: definition.phase.id,
            curriculumIntent: .tolerateLessStimulus,
            curriculumReason: definition.intent.editorialReason,
            recentEvidenceReason: "Your last session felt demanding, so we're resetting with a lighter block.",
            observationMission: nil,
            requiresEnvironmentPreparation: false
        )
    }

    private static func makePrescription(
        mode: TrainingMode,
        profile: AttentionProfile,
        history: [SessionRecord],
        definition: ProgramDayDefinition
    ) -> DailyPrescription {
        let duration = AdaptiveDurationEngine.recommendation(
            mode: mode,
            profile: profile,
            protocolHistory: history,
            phase: definition.phase
        )
        var copy = copy(for: mode, profile: profile, minutes: duration.minutes, definition: definition)
        var environment = environmentPlan(
            mode: mode,
            profile: profile,
            minutes: duration.minutes,
            phase: definition.phase
        )

        // Matching Personal Rules (Kept rules only, valid context only, no retired/rejected/testing):
        let matchingRules = profile.personalRules.filter { rule in
            rule.isActivelyInfluencing && (
                rule.matchingContexts.contains(where: { $0.rawValue == mode.rawValue })
                || rule.matchingContexts.contains(.general)
                || (mode == .stay && rule.matchingContexts.contains(.deepWork))
            )
        }
        let appliedRuleIDs = matchingRules.map(\.id)
        let appliedRuleTitle = matchingRules.first?.title

        if let rule = matchingRules.first {
            copy.reason = "You chose to keep this rule for focused work: \(rule.title)."
            if rule.category == .environment {
                environment.action = rule.detail
            }
        }

        return DailyPrescription(
            id: UUID(),
            day: definition.day,
            mode: mode,
            minutes: duration.minutes,
            headline: copy.headline,
            sentence: copy.sentence,
            goal: copy.goal,
            reason: copy.reason,
            action: environment.action,
            actionFallback: environment.fallback,
            environmentChange: environmentChange(for: profile),
            adaptationReason: adaptationReason(duration.reason, definition: definition),
            environmentAction: environment.environmentAction,
            appliedRuleIDs: appliedRuleIDs,
            appliedRuleTitle: appliedRuleTitle,
            programPhase: definition.phase.id,
            curriculumIntent: definition.intent.kind,
            curriculumReason: definition.intent.editorialReason,
            recentEvidenceReason: recentEvidenceReason(profile: profile, history: history),
            observationMission: definition.intent.observationMission,
            requiresEnvironmentPreparation:
                definition.phase.environmentIntensity.rawValue >= ProgramEnvironmentIntensity.intentional.rawValue
                    && mode != .observe
                    && mode != .nothing
        )
    }

    private static func selectMode(
        profile: AttentionProfile,
        history: [SessionRecord],
        definition: ProgramDayDefinition,
        reviews: [WeeklyReviewRecord]
    ) -> TrainingMode {
        if definition.intent.kind == .naturalBaseline { return .observe }
        var candidates = definition.phase.allowedModes
        if candidates.isEmpty { candidates = TrainingMode.allCases }
        var scores = Dictionary(uniqueKeysWithValues: candidates.map { ($0, 0) })

        addPreference(definition.phase.preferredModes, weight: 5, to: &scores)
        addPreference(definition.intent.preferredModes, weight: 8, to: &scores)

        let goal = profile.primaryGoal.value ?? ""
        let memoryGoals: Set<String> = ["read_more", "remember_more", "study_better"]
        let controlGoals: Set<String> = ["scroll_less", "phone_less"]
        if memoryGoals.contains(goal) {
            scores[.recall, default: 0] += 16
            scores[.explain, default: 0] += 8
            scores[.stay, default: 0] += 4
        } else if controlGoals.contains(goal) {
            scores[.stay, default: 0] += 12
            scores[.observe, default: 0] += 5
            scores[.nothing, default: 0] += 3
        } else if goal == "deep_work" || goal == "focus_better" {
            scores[.stay, default: 0] += 12
            scores[.observe, default: 0] += 3
            scores[.explain, default: 0] += goal == "deep_work" ? 3 : 0
        } else if goal == "build_flow" {
            scores[.stay, default: 0] += 10
            scores[.observe, default: 0] += 9
        }

        if profile.recall.value == .weak || (memoryGoals.contains(goal) && !profile.recall.isKnown) {
            scores[.recall, default: 0] += 5
        }
        if profile.depth.value == .shallow, definition.phase.id == .deepen {
            scores[.explain, default: 0] += 5
        }
        if !(profile.distractors.value ?? []).isEmpty {
            scores[.stay, default: 0] += 4
        }

        if let preference = reviews.last?.answers.nextTestPreference?.lowercased() {
            if preference.contains("memory") || preference.contains("recall") || preference.contains("read") {
                scores[.recall, default: 0] += 3
            } else if preference.contains("phone") || preference.contains("switch") {
                scores[.stay, default: 0] += 3
            } else if preference.contains("explain") || preference.contains("understand") {
                scores[.explain, default: 0] += 3
            }
        }

        let recentModes = history.filter(\.completed).suffix(5).map(\.mode)
        for mode in candidates {
            scores[mode, default: 0] -= recentModes.filter { $0 == mode }.count * 3
            if recentModes.last == mode { scores[mode, default: 0] -= 2 }
            if recentModes.suffix(3).allSatisfy({ $0 == mode }), recentModes.count >= 3 {
                scores[mode, default: 0] -= 9
            }
        }

        let deterministicOrder = definition.intent.preferredModes
            + definition.phase.preferredModes
            + TrainingMode.allCases
        return candidates.max { lhs, rhs in
            let left = scores[lhs, default: Int.min]
            let right = scores[rhs, default: Int.min]
            if left == right {
                return order(lhs, in: deterministicOrder) > order(rhs, in: deterministicOrder)
            }
            return left < right
        } ?? .stay
    }

    private static func addPreference(
        _ modes: [TrainingMode],
        weight: Int,
        to scores: inout [TrainingMode: Int]
    ) {
        for (index, mode) in modes.enumerated() where scores[mode] != nil {
            scores[mode, default: 0] += max(1, weight - index)
        }
    }

    private static func order(_ mode: TrainingMode, in modes: [TrainingMode]) -> Int {
        modes.firstIndex(of: mode) ?? modes.count
    }

    private struct PrescriptionCopy {
        var headline: String
        var sentence: String
        var goal: String
        var reason: String
    }

    private static func copy(
        for mode: TrainingMode,
        profile: AttentionProfile,
        minutes: Int,
        definition: ProgramDayDefinition
    ) -> PrescriptionCopy {
        let phaseTitle = definition.phase.title.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let primaryGoal = profile.primaryGoal.value.flatMap { DiagnosisModels.goalLabel[$0] }
        let reason = primaryGoal.map { "This supports your goal to \($0.lowercased())." }
            ?? "This fits your current phase without inventing a score."
        switch mode {
        case .stay:
            return PrescriptionCopy(
                headline: profile.returnAfterDistraction.value == .weak ? "Practice the return." : "Stay with one thing.",
                sentence: "In \(phaseTitle), continuity matters more than a perfect block.",
                goal: "Hold one meaningful task for \(minutes) minutes.",
                reason: reason
            )
        case .recall:
            return PrescriptionCopy(
                headline: "Close it. Bring it back.",
                sentence: "Use real material, hide it, then reconstruct what remains.",
                goal: "Read, close, and recall without looking.",
                reason: reason
            )
        case .explain:
            return PrescriptionCopy(
                headline: "Explain the idea simply.",
                sentence: "Understanding becomes clearer when the source is no longer visible.",
                goal: "Teach one useful idea in your own words.",
                reason: reason
            )
        case .nothing:
            return PrescriptionCopy(
                headline: "Add nothing for a moment.",
                sentence: "A short period without new input is enough for today's test.",
                goal: "Spend \(minutes) minutes without adding stimulus.",
                reason: "This phase tests what happens when there is less to react to."
            )
        case .observe:
            return PrescriptionCopy(
                headline: definition.intent.kind == .observeFlowCondition ? "Notice the conditions." : "Notice before changing it.",
                sentence: definition.intent.observationMission ?? "Observe one real moment without turning it into a score.",
                goal: definition.intent.observationMission ?? "Notice what changes attention's direction.",
                reason: reason
            )
        }
    }

    private struct EnvironmentPlan {
        var action: String
        var fallback: String
        var environmentAction: EnvironmentAction?
    }

    private static func environmentPlan(
        mode: TrainingMode,
        profile: AttentionProfile,
        minutes: Int,
        phase: ProgramPhase
    ) -> EnvironmentPlan {
        let distractors = profile.distractors.value ?? []
        let top = topDistractor(distractors, profile: profile)
        guard phase.environmentIntensity.rawValue >= ProgramEnvironmentIntensity.intentional.rawValue,
              mode != .nothing,
              mode != .observe else {
            return EnvironmentPlan(
                action: "Keep the setup simple and honest.",
                fallback: "Start with the conditions you have.",
                environmentAction: nil
            )
        }
        let level = FrictionLadder.chooseLevel(
            env: profile.environmentEvidence,
            distractorKnown: !distractors.isEmpty
        )
        let action = EnvironmentActionFactory.action(
            level: level,
            topDistractor: top,
            minutes: minutes,
            env: profile.environmentEvidence
        )
        return EnvironmentPlan(
            action: action?.title ?? top.map { Distractor.action(for: $0) } ?? "Put one clear task in front of you.",
            fallback: top.map { Distractor.fallback(for: $0) } ?? "If the setup cannot change, begin with one clear task.",
            environmentAction: action
        )
    }

    private static func adaptationReason(
        _ durationReason: AdaptiveDurationReason,
        definition: ProgramDayDefinition
    ) -> String {
        let duration: String
        switch durationReason {
        case .baseline: duration = "The natural baseline stays fixed."
        case .diagnosedWindow: duration = "Duration starts from the reported focus window."
        case .repeatedComfort: duration = "Comparable sessions supported one bounded increase."
        case .repeatedDifficulty: duration = "Repeated difficulty supported a lighter duration."
        case .lowEnergy: duration = "Repeated low-energy reports supported a lighter duration."
        case .heldForEvidence: duration = "Duration is held while comparable evidence accumulates."
        }
        return "\(definition.phase.title) \(duration)"
    }

    private static func recentEvidenceReason(
        profile: AttentionProfile,
        history: [SessionRecord]
    ) -> String {
        if let last = history.last, last.endedEarly {
            return "The most recent protocol attempt ended early."
        }
        if history.suffix(2).allSatisfy({
            $0.completed && !$0.endedEarly && ($0.difficulty ?? 3) <= 2
        }), history.count >= 2 {
            return "Your recent sessions have felt steady and manageable."
        }
        if profile.recall.value == .weak {
            return "Recall remains a supported focus area."
        }
        if !(profile.distractors.value ?? []).isEmpty {
            return "Known distractors still inform the setup."
        }
        return "We're keeping the duration steady while your baseline settles."
    }

    private static func topDistractor(_ distractors: [String], profile: AttentionProfile) -> String? {
        let order = [Distractor.phone, Distractor.social, Distractor.notifications, Distractor.tabs, Distractor.people, Distractor.internalRestlessness]
        for d in order where distractors.contains(d) {
            return d
        }
        return distractors.first
    }

    private static func environmentChange(for profile: AttentionProfile) -> String? {
        let distractors = profile.distractors.value ?? []
        if distractors.contains(Distractor.phone) || distractors.contains(Distractor.social) {
            return "Phone in another room."
        }
        if distractors.contains(Distractor.notifications) {
            return "All notifications silenced."
        }
        if distractors.contains(Distractor.tabs) {
            return "One tab only."
        }
        if distractors.contains(Distractor.people) {
            return "Headphones on."
        }
        return nil
    }
}

// MARK: - Profile Updater (session → profile)

enum ProfileUpdater {
    static func apply(
        session: SessionRecord,
        sessionCount: Int,
        allSessions: [SessionRecord] = [],
        to profile: inout AttentionProfile
    ) {
        let src: EvidenceSource = sessionCount >= 2 ? .repeated : .session

        // Switch counts are useful evidence even when a session ended early.
        if let switches = session.switches, session.mode == .stay || session.mode == .observe {
            let level: StabilityLevel = switches <= 1 ? .high : (switches <= 3 ? .medium : .low)
            if let current = profile.attentionStability.value {
                let merged = merge(current, with: level)
                profile.attentionStability = .known(merged, source: src)
            } else {
                profile.attentionStability = .known(level, source: src)
            }
        }

        if let first = session.firstDistraction,
           first != "none",
           session.mode == .stay || session.mode == .observe {
            if let current = profile.reflex.value {
                let merged = current == .high || session.switches ?? 0 >= 4 ? ReflexLevel.high : current
                profile.reflex = .known(merged, source: src)
            } else {
                profile.reflex = .known(session.switches ?? 0 >= 4 ? .high : .medium, source: src)
            }
        } else if session.firstDistraction == "none",
                  session.mode == .stay || session.mode == .observe {
            if let current = profile.reflex.value {
                profile.reflex = .known(current == .low ? .low : .medium, source: src)
            } else {
                profile.reflex = .known(.low, source: src)
            }
        }

        // Return is only inferred when switching was actually reported.
        if session.completed,
           let switches = session.switches,
           session.mode == .stay || session.mode == .observe {
            let level: ReturnLevel = switches <= 1 ? .strong : (switches <= 4 ? .fair : .weak)
            if let current = profile.returnAfterDistraction.value {
                profile.returnAfterDistraction = .known(merge(current, with: level), source: src)
            } else {
                profile.returnAfterDistraction = .known(level, source: src)
            }
        }

        // Difficulty is not a universal depth score. Restrict this signal to STAY.
        if let difficulty = session.difficulty, session.completed, session.mode == .stay {
            let level: DepthLevel = difficulty <= 2 ? .deep : (difficulty <= 3 ? .fair : .shallow)
            if let current = profile.depth.value {
                profile.depth = .known(merge(current, with: level), source: src)
            } else {
                profile.depth = .known(level, source: src)
            }
        }

        if session.mode == .recall,
           session.completed,
           let assessment = session.evidence?.recall?.selfAssessment {
            let level: RecallLevel
            switch assessment {
            case .little: level = .weak
            case .some: level = .fair
            case .most: level = sessionCount >= 2 ? .strong : .fair
            }
            profile.recall = .known(level, source: src)
        }

        if session.completed, session.actualMinutes > 0 {
            if let window = profile.focusWindowMinutes {
                profile.focusWindowMinutes = max(window, session.actualMinutes)
            } else {
                profile.focusWindowMinutes = session.actualMinutes
            }
        }

        // Personal rules & observations update
        var currentRules = profile.personalRules
        PersonalRuleEngine.evaluate(
            session: session,
            rules: &currentRules,
            profile: &profile,
            allSessions: allSessions.isEmpty ? [session] : allSessions
        )
    }

    private static func merge(_ a: StabilityLevel, with b: StabilityLevel) -> StabilityLevel {
        let order: [StabilityLevel] = [.low, .medium, .high]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }

    private static func merge(_ a: ReturnLevel, with b: ReturnLevel) -> ReturnLevel {
        let order: [ReturnLevel] = [.weak, .fair, .strong]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }

    private static func merge(_ a: DepthLevel, with b: DepthLevel) -> DepthLevel {
        let order: [DepthLevel] = [.shallow, .fair, .deep]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }
}

// MARK: - Insights

enum InsightEngine {
    static func insights(profile: AttentionProfile, sessions: [SessionRecord]) -> [String] {
        guard sessions.count >= 2 else { return [] }
        var out: [String] = []

        let withAction = sessions.filter { $0.environmentActionDone == true }
        let withoutAction = sessions.filter { $0.environmentActionDone == false }
        if !withAction.isEmpty, !withoutAction.isEmpty {
            let avgWith = withAction.map(\.actualMinutes).reduce(0, +) / withAction.count
            let avgWithout = withoutAction.map(\.actualMinutes).reduce(0, +) / withoutAction.count
            if avgWith > avgWithout + 3 {
                out.append("You complete more sessions when your phone is away.")
            }
        }

        let earlySwitches = sessions.filter {
            $0.firstSwitchTiming == .underFive || ($0.firstSwitchMinute ?? 99) < 5
        }
        if earlySwitches.count >= 2, sessions.count >= 2 {
            out.append("Your first switches usually happen early.")
        }

        let recallSessions = sessions.filter { $0.mode == .recall }
        let staySessions = sessions.filter { $0.mode == .stay }
        if let recallAvg = average(recallSessions.map(\.difficulty)),
           let stayAvg = average(staySessions.map(\.difficulty)),
           recallAvg > stayAvg + 0.5 {
            out.append("Recall feels harder than sustained focus.")
        }

        return Array(out.prefix(2))
    }

    private static func average(_ values: [Int?]) -> Double? {
        let vals = values.compactMap { $0 }
        guard !vals.isEmpty else { return nil }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }
}

// MARK: - Focus line data (real only)

struct FocusLinePoint: Identifiable {
    let id = UUID()
    let minutes: Int
}

enum FocusHistory {
    static func points(sessions: [SessionRecord]) -> [FocusLinePoint] {
        sessions.suffix(7).map { FocusLinePoint(minutes: $0.actualMinutes) }
    }
}
