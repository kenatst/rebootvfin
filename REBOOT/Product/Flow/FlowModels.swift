import Foundation

// MARK: - Projects

enum FlowProjectCategory: String, Codable, CaseIterable, Equatable, Identifiable {
    case study
    case reading
    case writing
    case coding
    case creative
    case analysis
    case planning
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .study: return "Study"
        case .reading: return "Reading"
        case .writing: return "Writing"
        case .coding: return "Coding / building"
        case .creative: return "Creative work"
        case .analysis: return "Analysis"
        case .planning: return "Planning"
        case .other: return "Other"
        }
    }

    var fuelTaskContext: FuelTaskContext {
        switch self {
        case .study: return .study
        case .reading: return .reading
        case .writing: return .writing
        case .coding: return .coding
        case .creative: return .creative
        case .analysis, .planning: return .focusedWork
        case .other: return .other
        }
    }
}

enum FlowProjectStatus: String, Codable, Equatable {
    case active
    case archived
}

struct FlowProject: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var category: FlowProjectCategory
    var createdAt = Date()
    var updatedAt = Date()
    var status: FlowProjectStatus = .active
    var note: String?
    var recentBlockIDs: [UUID] = []
    var archivedAt: Date?

    mutating func archive(at date: Date = Date()) {
        status = .archived
        archivedAt = date
        updatedAt = date
    }
}

// MARK: - Block setup

enum FlowChallenge: String, Codable, CaseIterable, Equatable, Identifiable {
    case light
    case stretching
    case hard

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum FlowSkillConfidence: String, Codable, CaseIterable, Equatable, Identifiable {
    case unsure
    case capable
    case strong

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum FlowChallengeSkillRelation: String, Codable, Equatable {
    case underchallenged
    case balancedStretch
    case overreaching
    case uncertain

    var label: String {
        switch self {
        case .underchallenged: return "Light for current confidence"
        case .balancedStretch: return "Stretching but manageable"
        case .overreaching: return "Hard with low confidence"
        case .uncertain: return "Relationship still unclear"
        }
    }

    static func derive(
        challenge: FlowChallenge,
        skill: FlowSkillConfidence
    ) -> FlowChallengeSkillRelation {
        switch (challenge, skill) {
        case (.light, .strong), (.light, .capable): return .underchallenged
        case (.stretching, .capable), (.stretching, .strong), (.hard, .strong): return .balancedStretch
        case (.hard, .unsure): return .overreaching
        default: return .uncertain
        }
    }
}

enum FlowFeedbackMechanism: String, Codable, CaseIterable, Equatable, Identifiable {
    case visibleOutput
    case itemsCompleted
    case problemsSolved
    case sectionsProgressed
    case testsPassing
    case knowFromWork
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .visibleOutput: return "Visible output"
        case .itemsCompleted: return "Items completed"
        case .problemsSolved: return "Problems solved"
        case .sectionsProgressed: return "Pages / sections"
        case .testsPassing: return "Tests passing"
        case .knowFromWork: return "I'll know from the work"
        case .other: return "Other"
        }
    }
}

enum FlowPhoneSetup: String, Codable, CaseIterable, Equatable, Identifiable {
    case usual
    case outsideReach
    case screenTimeProtected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usual: return "Usual setup"
        case .outsideReach: return "Outside reach"
        case .screenTimeProtected: return "Protected with Screen Time"
        }
    }
}

enum FlowSoundContext: String, Codable, CaseIterable, Equatable, Identifiable {
    case usual
    case quiet
    case backgroundSound

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usual: return "Usual sound"
        case .quiet: return "Quiet"
        case .backgroundSound: return "Background sound"
        }
    }
}

struct FlowEnvironmentPlan: Codable, Equatable {
    var phoneSetup: FlowPhoneSetup = .usual
    var soundContext: FlowSoundContext = .usual
    var browserScope: String?
    var appliedRuleIDs: [UUID] = []
    var verification: EnvironmentVerificationState = .unknown
    var protectionActivated: Bool = false
}

struct FlowBlockPlan: Codable, Identifiable, Equatable {
    var id = UUID()
    var blockID = UUID()
    var projectID: UUID
    var task: String
    var definitionOfDone: String
    var challengeBefore: FlowChallenge
    var skillConfidenceBefore: FlowSkillConfidence
    var feedbackMechanism: FlowFeedbackMechanism
    var customFeedback: String?
    var suggestedDuration: Int
    var selectedDuration: Int
    var environmentPlan: FlowEnvironmentPlan
    var fuelContext: FuelContextSnapshot?
    var baseMode: TrainingMode = .stay
    var sessionOrigin: SessionOrigin = .flow
    var programDay: Int?
    var createdAt = Date()

    var challengeSkillRelation: FlowChallengeSkillRelation {
        .derive(challenge: challengeBefore, skill: skillConfidenceBefore)
    }

    var feedbackLabel: String {
        customFeedback?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? feedbackMechanism.label
    }
}

struct FlowContextSnapshot: Codable, Equatable {
    var challengeSkillRelation: FlowChallengeSkillRelation
    var environmentPlan: FlowEnvironmentPlan
    var fuelContext: FuelContextSnapshot?
    var capturedAt = Date()
}

/// Flow participation is independent from SessionOrigin. A protocol session
/// remains protocol while contributing one block to Flow Lab.
struct FlowParticipation: Codable, Equatable {
    var flowBlockID: UUID
    var flowProjectID: UUID
    var flowPlanID: UUID
    var contextSnapshot: FlowContextSnapshot
    var attachedAt = Date()
}

struct FlowSetupDraft: Codable, Identifiable, Equatable {
    var id = UUID()
    var projectID: UUID?
    var sessionOrigin: SessionOrigin = .flow
    var programDay: Int?
    var task = ""
    var definitionOfDone = ""
    var challenge: FlowChallenge = .stretching
    var skillConfidence: FlowSkillConfidence = .capable
    var feedbackMechanism: FlowFeedbackMechanism = .visibleOutput
    var customFeedback = ""
    var selectedDuration = 25
    var phoneSetup: FlowPhoneSetup = .usual
    var soundContext: FlowSoundContext = .usual
    var browserScope = ""
    var confirmedRuleIDs: [UUID] = []
    var createdAt = Date()

    var isComplete: Bool {
        projectID != nil
            && !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !definitionOfDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (10...120).contains(selectedDuration)
            && (feedbackMechanism != .other
                || !customFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

extension FlowSetupDraft {
    private enum CodingKeys: String, CodingKey {
        case id, projectID, sessionOrigin, programDay, task, definitionOfDone
        case challenge, skillConfidence, feedbackMechanism, customFeedback
        case selectedDuration, phoneSetup, soundContext, browserScope
        case confirmedRuleIDs, createdAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? values.decode(UUID.self, forKey: .id)) ?? UUID()
        projectID = try? values.decode(UUID.self, forKey: .projectID)
        sessionOrigin = (try? values.decode(SessionOrigin.self, forKey: .sessionOrigin)) ?? .flow
        programDay = try? values.decode(Int.self, forKey: .programDay)
        task = (try? values.decode(String.self, forKey: .task)) ?? ""
        definitionOfDone = (try? values.decode(String.self, forKey: .definitionOfDone)) ?? ""
        challenge = (try? values.decode(FlowChallenge.self, forKey: .challenge)) ?? .stretching
        skillConfidence = (try? values.decode(FlowSkillConfidence.self, forKey: .skillConfidence)) ?? .capable
        feedbackMechanism = (try? values.decode(FlowFeedbackMechanism.self, forKey: .feedbackMechanism)) ?? .visibleOutput
        customFeedback = (try? values.decode(String.self, forKey: .customFeedback)) ?? ""
        selectedDuration = (try? values.decode(Int.self, forKey: .selectedDuration)) ?? 25
        phoneSetup = (try? values.decode(FlowPhoneSetup.self, forKey: .phoneSetup)) ?? .usual
        soundContext = (try? values.decode(FlowSoundContext.self, forKey: .soundContext)) ?? .usual
        browserScope = (try? values.decode(String.self, forKey: .browserScope)) ?? ""
        confirmedRuleIDs = (try? values.decode([UUID].self, forKey: .confirmedRuleIDs)) ?? []
        createdAt = (try? values.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encodeIfPresent(projectID, forKey: .projectID)
        try values.encode(sessionOrigin, forKey: .sessionOrigin)
        try values.encodeIfPresent(programDay, forKey: .programDay)
        try values.encode(task, forKey: .task)
        try values.encode(definitionOfDone, forKey: .definitionOfDone)
        try values.encode(challenge, forKey: .challenge)
        try values.encode(skillConfidence, forKey: .skillConfidence)
        try values.encode(feedbackMechanism, forKey: .feedbackMechanism)
        try values.encode(customFeedback, forKey: .customFeedback)
        try values.encode(selectedDuration, forKey: .selectedDuration)
        try values.encode(phoneSetup, forKey: .phoneSetup)
        try values.encode(soundContext, forKey: .soundContext)
        try values.encode(browserScope, forKey: .browserScope)
        try values.encode(confirmedRuleIDs, forKey: .confirmedRuleIDs)
        try values.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Reflection and evidence

enum FlowAbsorption: String, Codable, CaseIterable, Equatable, Identifiable {
    case low
    case some
    case high

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum FlowTimePerception: String, Codable, CaseIterable, Equatable, Identifiable {
    case slower
    case normal
    case faster

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum FlowDesireToContinue: String, Codable, CaseIterable, Equatable, Identifiable {
    case stop
    case neutral
    case `continue`

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stop: return "Stop"
        case .neutral: return "Neutral"
        case .continue: return "Continue"
        }
    }
}

enum FlowDoneOutcome: String, Codable, CaseIterable, Equatable, Identifiable {
    case notReached
    case partly
    case reached

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notReached: return "Not reached"
        case .partly: return "Partly"
        case .reached: return "Reached"
        }
    }
}

struct FlowBlockReflection: Codable, Equatable {
    var absorption: FlowAbsorption?
    var timePerception: FlowTimePerception?
    var desireToContinue: FlowDesireToContinue?
    var definitionOfDoneOutcome: FlowDoneOutcome?
    var note: String?

    var isComplete: Bool {
        absorption != nil
            && timePerception != nil
            && desireToContinue != nil
            && definitionOfDoneOutcome != nil
    }
}

struct FlowSwitchEvidence: Codable, Equatable {
    var count: Int?
    var firstSwitchTiming: FirstSwitchTiming?
}

enum FlowEngagementSignal: String, Codable, Equatable {
    case insufficient
    case lowerSignal
    case mixed
    case strongerSignal

    var label: String {
        switch self {
        case .insufficient: return "Still learning"
        case .lowerSignal: return "Lower signal"
        case .mixed: return "Mixed"
        case .strongerSignal: return "Stronger signal"
        }
    }
}

struct FlowBlockEvidence: Codable, Identifiable, Equatable {
    var id = UUID()
    var blockID: UUID
    var projectID: UUID
    var planID: UUID
    var sessionID: UUID
    var reflection: FlowBlockReflection
    var challengeBefore: FlowChallenge
    var skillBefore: FlowSkillConfidence
    var feedbackMechanism: FlowFeedbackMechanism
    var environment: EnvironmentSnapshot?
    var fuelContext: FuelContextSnapshot?
    var switches: FlowSwitchEvidence
    var actualDuration: Int
    var completed: Bool
    var endedEarly: Bool
    var date: Date

    var engagementSignal: FlowEngagementSignal {
        FlowEngagementClassifier.classify(reflection: reflection, completed: completed, endedEarly: endedEarly)
    }
}

// MARK: - Persisted state

struct FlowState: Codable, Equatable {
    var projects: [FlowProject] = []
    var plans: [FlowBlockPlan] = []
    var evidence: [FlowBlockEvidence] = []
    var pendingSetup: FlowSetupDraft?
    var activeBlockID: UUID?
    var activeProjectID: UUID?
    var pendingEntryOrigin: SessionOrigin?
    var returnToLabAfterProgramFlow = false

    static let empty = FlowState()

    var activeProjects: [FlowProject] {
        projects.filter { $0.status == .active }
    }

    func project(id: UUID) -> FlowProject? {
        projects.first { $0.id == id }
    }

    func plan(id: UUID) -> FlowBlockPlan? {
        plans.first { $0.id == id }
    }

    func plan(blockID: UUID) -> FlowBlockPlan? {
        plans.first { $0.blockID == blockID }
    }

    private enum CodingKeys: String, CodingKey {
        case projects, plans, evidence, pendingSetup, activeBlockID, activeProjectID
        case pendingEntryOrigin, returnToLabAfterProgramFlow
    }

    init(
        projects: [FlowProject] = [],
        plans: [FlowBlockPlan] = [],
        evidence: [FlowBlockEvidence] = [],
        pendingSetup: FlowSetupDraft? = nil,
        activeBlockID: UUID? = nil,
        activeProjectID: UUID? = nil,
        pendingEntryOrigin: SessionOrigin? = nil,
        returnToLabAfterProgramFlow: Bool = false
    ) {
        self.projects = projects
        self.plans = plans
        self.evidence = evidence
        self.pendingSetup = pendingSetup
        self.activeBlockID = activeBlockID
        self.activeProjectID = activeProjectID
        self.pendingEntryOrigin = pendingEntryOrigin
        self.returnToLabAfterProgramFlow = returnToLabAfterProgramFlow
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        projects = (try? values.decode([FailableFlowValue<FlowProject>].self, forKey: .projects))?
            .compactMap(\.value) ?? []
        plans = (try? values.decode([FailableFlowValue<FlowBlockPlan>].self, forKey: .plans))?
            .compactMap(\.value) ?? []
        evidence = (try? values.decode([FailableFlowValue<FlowBlockEvidence>].self, forKey: .evidence))?
            .compactMap(\.value) ?? []
        pendingSetup = try? values.decodeIfPresent(FlowSetupDraft.self, forKey: .pendingSetup)
        activeBlockID = try? values.decodeIfPresent(UUID.self, forKey: .activeBlockID)
        activeProjectID = try? values.decodeIfPresent(UUID.self, forKey: .activeProjectID)
        pendingEntryOrigin = try? values.decodeIfPresent(SessionOrigin.self, forKey: .pendingEntryOrigin)
        returnToLabAfterProgramFlow = (try? values.decodeIfPresent(
            Bool.self,
            forKey: .returnToLabAfterProgramFlow
        )) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(projects, forKey: .projects)
        try values.encode(plans, forKey: .plans)
        try values.encode(evidence, forKey: .evidence)
        try values.encodeIfPresent(pendingSetup, forKey: .pendingSetup)
        try values.encodeIfPresent(activeBlockID, forKey: .activeBlockID)
        try values.encodeIfPresent(activeProjectID, forKey: .activeProjectID)
        try values.encodeIfPresent(pendingEntryOrigin, forKey: .pendingEntryOrigin)
        try values.encode(returnToLabAfterProgramFlow, forKey: .returnToLabAfterProgramFlow)
    }
}

private struct FailableFlowValue<Value: Codable>: Codable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value { try container.encode(value) }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
