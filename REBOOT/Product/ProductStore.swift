import Foundation

enum ProductPhase: Equatable {
    case today
    case running(SessionRecord)
    case done(SessionRecord)
}

enum ProductTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case train = "Train"
    case program = "Program"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: return "circle.circle"
        case .train: return "arrow.triangle.2.circlepath"
        case .program: return "calendar"
        case .profile: return "person"
        }
    }
}

@MainActor
final class ProductStore: ObservableObject {
    @Published var profile: AttentionProfile
    @Published private(set) var sessions: [SessionRecord]
    @Published private(set) var day: Int
    @Published var tab: ProductTab = .today
    @Published var phase: ProductPhase = .today

    /// Observation sink so EnvironmentStore can mirror session outcomes.
    var onObservationSaved: ((EnvironmentObservation) -> Void)?

    private static let storageKey = "reboot.product.v2"
    private static let legacyStorageKey = "reboot.product.v1"

    var prescription: DailyPrescription {
        PrescriptionEngine.prescription(profile: profile, sessions: sessions, day: day)
    }

    var isCalibrating: Bool {
        sessions.count < 3
    }

    var insights: [String] {
        var base = InsightEngine.insights(profile: profile, sessions: sessions)
        if let env = EnvironmentInsight.from(profile.environmentEvidence), !base.contains(env) {
            base.append(env)
        }
        return Array(base.prefix(2))
    }

    var focusHistory: [FocusLinePoint] {
        FocusHistory.points(sessions: sessions)
    }

    init(diagnosisAnswers: Answers) {
        let loaded = Self.load()
        if let stored = loaded.state {
            profile = stored.profile
            sessions = stored.sessions
            day = stored.day
            if loaded.migrated {
                persist()
            }
        } else {
            profile = ProfileBuilder.build(from: diagnosisAnswers)
            sessions = []
            day = 1
            persist()
        }
        if let seed = Self.loadQASeed() {
            apply(seed)
        }
        if let name = ProcessInfo.processInfo.arguments.valueAfter("-qaSeed"),
           let seed = QASeeds.named(name) {
            apply(seed)
        }
    }

    // MARK: - QA seeding

    func apply(_ seed: QASeed) {
        if let profile = seed.profile { self.profile = profile }
        if let sessions = seed.sessions { self.sessions = sessions }
        if let day = seed.day { self.day = day }
        switch seed.phase {
        case "running":
            if let record = seed.record {
                phase = .running(record)
            }
        case "done":
            if let record = seed.record {
                phase = .done(record)
            }
        default:
            phase = .today
        }
        tab = .today
    }

    private static func loadQASeed() -> QASeed? {
        guard let path = ProcessInfo.processInfo.arguments.valueAfter("-qaProduct"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return try? JSONDecoder().decode(QASeed.self, from: data)
    }

    // MARK: - Session flow

    func beginSession(environment arm: SessionEnvironmentArm? = nil, minutesOverride: Int? = nil) {
        let p = prescription
        var record = SessionRecord(
            day: day,
            date: Date(),
            mode: p.mode,
            targetMinutes: minutesOverride ?? p.minutes,
            actualMinutes: 0,
            completed: false
        )
        if minutesOverride != nil {
            record.environment?.environmentCondition = EnvironmentCondition.protected.rawValue
        }
        if let arm {
            record.environment = EnvironmentSnapshot(
                protectionOffered: arm.protectionOffered,
                protectionAccepted: arm.protectionAccepted,
                protectionActivated: arm.protectionActivated,
                protectionEndedEarly: false,
                protectedSelectionID: arm.protectedSelectionID,
                manualIntervention: arm.manualIntervention,
                phoneLocationSelfReport: arm.phoneLocationSelfReport,
                thresholdEvents: [],
                environmentCondition: arm.condition.rawValue,
                startedEasierSelfReport: nil
            )
        }
        phase = .running(record)
    }

    func finishRunning(actualMinutes: Int, endedEarly: Bool) {
        guard case .running(var record) = phase else { return }
        record.actualMinutes = actualMinutes
        record.completed = true
        record.endedEarly = endedEarly
        phase = .done(record)
    }

    func abandonRunning() {
        phase = .today
    }

    func saveDoneSession(
        difficulty: Int,
        firstDistraction: String?,
        switches: Int?,
        firstSwitchMinute: Int?,
        energy: Int?,
        environmentActionDone: Bool?,
        startedEasier: Bool? = nil,
        protectionExitReason: String? = nil
    ) {
        guard case .done(var record) = phase else { return }
        record.difficulty = difficulty
        record.firstDistraction = firstDistraction
        record.switches = switches
        record.firstSwitchMinute = firstSwitchMinute
        record.energy = energy
        record.environmentActionDone = environmentActionDone
        if record.environment != nil {
            record.environment?.startedEasierSelfReport = startedEasier
            record.environment?.protectionEndedEarly = record.endedEarly
            record.environment?.protectionExitReason = protectionExitReason
        }

        sessions.append(record)
        day = min(90, sessions.count + 1)
        if let observation = EnvironmentObservationFactory.observation(from: record) {
            EnvironmentUpdater.apply(session: record, observation: observation, to: &profile.environmentEvidence)
            onObservationSaved?(observation)
        }
        ProfileUpdater.apply(session: record, sessionCount: sessions.count, to: &profile)
        persist()
        phase = .today
    }

    // MARK: - Device facts (called when Screen Time state changes)

    func updateEnvironmentDeviceFacts(
        screenTimeConnected: Bool,
        hasSelection: Bool,
        hasApprovedWindows: Bool,
        thresholdApproved: Bool
    ) {
        EnvironmentUpdater.updateDeviceFacts(
            screenTimeConnected: screenTimeConnected,
            hasSelection: hasSelection,
            hasApprovedWindows: hasApprovedWindows,
            thresholdApproved: thresholdApproved,
            evidence: &profile.environmentEvidence
        )
        persist()
    }

    func setEnvironmentActionDone(_ done: Bool) {
        guard case .running(var record) = phase else { return }
        record.environmentActionDone = done
        phase = .running(record)
    }

    // MARK: - Persistence

    func reset() {
        profile = AttentionProfile()
        sessions = []
        day = 1
        tab = .today
        phase = .today
        persist()
    }

    private func persist() {
        let payload: [String: Any] = [
            "profile": (try? JSONEncoder().encode(profile)) ?? Data(),
            "sessions": (try? JSONEncoder().encode(sessions)) ?? Data(),
            "day": day,
        ]
        UserDefaults.standard.set(payload, forKey: Self.storageKey)
    }

    private static func load() -> (state: (profile: AttentionProfile, sessions: [SessionRecord], day: Int)?, migrated: Bool) {
        if let state = decode(from: storageKey) {
            return (state, false)
        }
        if let state = decode(from: legacyStorageKey) {
            return (state, true)
        }
        return (nil, false)
    }

    private static func decode(from key: String) -> (profile: AttentionProfile, sessions: [SessionRecord], day: Int)? {
        guard let raw = UserDefaults.standard.dictionary(forKey: key),
              let profileData = raw["profile"] as? Data,
              let sessionsData = raw["sessions"] as? Data,
              let profile = try? JSONDecoder().decode(AttentionProfile.self, from: profileData),
              let sessions = try? JSONDecoder().decode([SessionRecord].self, from: sessionsData) else {
            return nil
        }
        return (profile, sessions, (raw["day"] as? Int) ?? 1)
    }
}
