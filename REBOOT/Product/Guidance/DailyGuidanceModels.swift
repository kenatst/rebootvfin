import Foundation

/// The single primary bottleneck currently limiting the user's attention.
enum AttentionBottleneck: String, Codable, Equatable, CaseIterable {
    case starting = "Starting Friction"
    case stability = "Sustained Stability"
    case digitalPull = "Digital Pull"
    case returnStrategy = "Return Strategy"
    case recall = "Recall Consolidation"
    case depth = "Cognitive Depth"
    case energyContext = "Energy & Context"
    case environment = "Physical Environment"
    case flowConditions = "Flow Readiness"
    case uncertaintyExperiment = "Testing Variable"
    case recovery = "Recovery"
    case independence = "Own Mode Focus"
}

/// The kind of action prescribed for Today.
enum GuidancePrimaryActionKind: String, Codable, Equatable {
    case standardProtocolSession = "Protocol Session"
    case projectFlowBlock = "Real-Project Flow Block"
    case personalLabExperiment = "Personal Lab Comparison"
    case recoverySession = "Protected Reset"
    case ownModeSession = "Self-Directed Block"
}

/// Single primary action for Today.
struct DailyGuidancePrimaryAction: Codable, Equatable {
    var kind: GuidancePrimaryActionKind
    var title: String
    var subtitle: String
    var targetMinutes: Int
    var mode: TrainingMode
    var ctaTitle: String
}

/// Optional single secondary action.
struct DailyGuidanceSecondaryAction: Codable, Equatable {
    var title: String
    var actionType: String
    var identifier: String?
}

/// Flow project block opportunity details.
struct FlowOpportunity: Codable, Equatable {
    var projectID: UUID
    var projectTitle: String
    var recommendedMinutes: Int
    var whyNow: String
}

/// Record of a past guidance decision for anti-oscillation and history tracking.
struct GuidanceDecision: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var programDay: Int
    var bottleneck: AttentionBottleneck
    var selectedAction: String
    var evidenceIDs: [UUID] = []
    var outcomeSessionID: UUID? = nil
}

/// State for post-90 Own Mode.
struct OwnModeState: Codable, Equatable {
    var active: Bool = false
    var enteredAt: Date? = nil
    var lastGuidanceDate: Date? = nil
    var preferredDurations: [Int] = [25, 45]
    var focusThemes: [String] = []
}

/// The single canonical Guidance object for Today (derived dynamically, not persisted directly).
struct DailyGuidance: Equatable {
    var bottleneck: AttentionBottleneck
    var primaryAction: DailyGuidancePrimaryAction
    var supportingAction: DailyGuidanceSecondaryAction?
    var sessionPrescription: DailyPrescription
    var environmentAction: EnvironmentAction?
    var fuelPrompt: FuelSamplePrompt?
    var flowOpportunity: FlowOpportunity?
    var experimentOpportunityID: UUID?
    var explanation: String
    var confidence: Double
    var evidenceIDs: [UUID]
    var suppressedOpportunities: [String]
    var generatedAt: Date
    var isOwnMode: Bool
    var noInterventionNeeded: Bool
}
