import Foundation

// MARK: - Environment action (one optional action inside a DailyPrescription)

enum EnvironmentActionKind: String, Codable, Equatable {
    case manualPhoneAway
    case singleTaskBrowser
    case protectSelectedDistractions
    case protectedWindow
    case thresholdRule
}

struct EnvironmentAction: Codable, Equatable {
    var kind: EnvironmentActionKind
    var title: String
    var detail: String
    /// Friction ladder intensity 0–4. Prescriptions prefer the LOWEST level
    /// supported by evidence.
    var level: Int
    /// Focus-window length when the action is session-bound protection.
    var minutes: Int?
}

// MARK: - Experiment-ready condition / outcome (never encoded conclusions)

enum EnvironmentCondition: String, Codable, Equatable {
    case unrestricted
    case phoneAway
    case singleTaskBrowser
    case protected
    case protectedWindow
    case threshold
}

enum ExperimentResultState: String, Codable, Equatable {
    case keep
    case drop
    case inconclusive
}

struct EnvironmentObservation: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var condition: EnvironmentCondition
    var minutes: Int
    var completed: Bool
    var endedEarly: Bool
    var difficulty: Int?
    var switches: Int?
    /// Self-report: "did protecting these apps make starting easier?"
    var startedEasier: Bool?
    var resultState: ExperimentResultState = .inconclusive
}

// MARK: - Session snapshot (capture only what is actually known)

struct EnvironmentSnapshot: Codable, Equatable {
    var protectionOffered: Bool = false
    var protectionAccepted: Bool = false
    var protectionActivated: Bool = false
    var protectionEndedEarly: Bool = false
    var protectedSelectionID: UUID?
    var manualIntervention: String?
    var phoneLocationSelfReport: String?
    /// Our own event names only — never Apple activity tokens.
    var thresholdEvents: [String] = []
    var environmentCondition: String?
    var startedEasierSelfReport: Bool?
    var protectionExitReason: String?

    static let none = EnvironmentSnapshot()
}

// MARK: - Environment evidence (AttentionProfile dimension)

enum EnvironmentTrend: String, Codable, Equatable {
    case improving
    case stable
    case declining
    case unknown
}

struct EnvironmentEvidence: Codable, Equatable {
    /// Human label of the current state, e.g. "manual friction works".
    var state: String?
    var confidence: Double = 0
    var evidenceCount: Int = 0
    var source: EvidenceSource?
    var trend: EnvironmentTrend = .unknown
    var updatedAt: Date?

    var protectedSessionsCompleted: Int = 0
    var protectionEarlyExits: Int = 0
    var manualInterventionsTotal: Int = 0
    var manualInterventionsSuccessful: Int = 0

    /// Device facts that legitimately shape the friction ladder.
    var screenTimeConnected: Bool = false
    var hasSelection: Bool = false
    var hasApprovedWindows: Bool = false
    var thresholdApproved: Bool = false

    /// Best comparable condition so far (condition + outcome stored separately).
    var bestCondition: EnvironmentCondition?
    var bestConditionAvgSwitches: Double?

    var earlyExitRate: Double {
        guard protectedSessionsCompleted + protectionEarlyExits > 0 else { return 0 }
        return Double(protectionEarlyExits) / Double(protectedSessionsCompleted + protectionEarlyExits)
    }
}

// MARK: - Protected window (DeviceActivity schedule)

struct ProtectedWindow: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var weekdays: Set<Int> = [1, 2, 3, 4, 5] // 1 = Sunday … 7 = Saturday (Calendar convention)
    var startMinutes: Int = 9 * 60
    var endMinutes: Int = 11 * 60
    var selectionID: UUID?
    var enabled: Bool = true
    var purpose: String = "Protected focus window"
    var createdAt = Date()

    var deviceActivityName: String { "reboot.window.\(id.uuidString)" }
}

// MARK: - Persisted activity selection (tokens stay opaque)

struct ProtectedSelection: Codable, Equatable {
    var id = UUID()
    var updatedAt = Date()
    /// Encoded `FamilyActivitySelection` — stored as opaque Data, never logged.
    var data: Data
    var hasApplications: Bool
    var hasCategories: Bool
    var hasWebDomains: Bool

    var isEmpty: Bool {
        !hasApplications && !hasCategories && !hasWebDomains
    }
}

/// What the user armed for a session before it started (captured, not inferred).
struct SessionEnvironmentArm: Codable, Equatable {
    var condition: EnvironmentCondition
    var manualIntervention: String?
    var protectedSelectionID: UUID?
    var protectionOffered: Bool
    var protectionAccepted: Bool
    var protectionActivated: Bool
    var phoneLocationSelfReport: String?
}
