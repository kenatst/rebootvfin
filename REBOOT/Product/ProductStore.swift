import Foundation

enum ProductPhase: Equatable {
    case today
    case preparing(TrainingSessionRequest)
    case running(SessionRecord)
    case recovery(SessionRecord)
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
    @Published private(set) var environmentPreparation: EnvironmentPreparation?
    @Published var tab: ProductTab = .today
    @Published var phase: ProductPhase = .today

    var onObservationSaved: ((EnvironmentObservation) -> Void)?

    private static let storageKey = "reboot.product.v3"
    private static let v2StorageKey = "reboot.product.v2"
    private static let v1StorageKey = "reboot.product.v1"
    private let defaults: UserDefaults

    var allSessions: [SessionRecord] { sessions }
    var protocolSessions: [SessionRecord] { sessions.filter { $0.origin == .protocol } }
    var freeTrainingSessions: [SessionRecord] { sessions.filter { $0.origin == .freeTraining } }
    var completedProtocolSessions: [SessionRecord] { protocolSessions.filter(\.completed) }

    var prescription: DailyPrescription {
        PrescriptionEngine.prescription(profile: profile, sessions: protocolSessions, day: day)
    }

    var isCalibrating: Bool { completedProtocolSessions.count < 3 }

    var hasCompletedCurrentProtocol: Bool {
        protocolSessions.contains { $0.day == day && $0.completed }
    }

    var insights: [String] {
        var base = InsightEngine.insights(profile: profile, sessions: sessions)
        if let env = EnvironmentInsight.from(profile.environmentEvidence), !base.contains(env) {
            base.append(env)
        }
        return Array(base.prefix(2))
    }

    var focusHistory: [FocusLinePoint] {
        FocusHistory.points(sessions: sessions.filter(\.completed))
    }

    init(diagnosisAnswers: Answers, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(defaults: defaults)
        if let stored = loaded.state {
            profile = stored.profile
            sessions = stored.sessions
            day = min(90, max(1, stored.day))
            environmentPreparation = stored.preparation
            if let active = stored.activeSession {
                phase = .recovery(active)
            }
            if loaded.migrated {
                persist()
            }
        } else {
            profile = ProfileBuilder.build(from: diagnosisAnswers)
            sessions = []
            day = 1
            environmentPreparation = nil
            persist()
        }

        if let seed = Self.loadQASeed() {
            apply(seed)
        }
        if let name = ProcessInfo.processInfo.arguments.valueAfter("-qaSeed"),
           let seed = QASeeds.named(name) {
            apply(seed)
        }
#if DEBUG
        if let tabName = ProcessInfo.processInfo.arguments.valueAfter("-qaTab"),
           let qaTab = ProductTab(rawValue: tabName) {
            tab = qaTab
        }
        if let modeName = ProcessInfo.processInfo.arguments.valueAfter("-qaMode"),
           let qaMode = TrainingMode(rawValue: modeName) {
            prepareFreeTraining(qaMode)
        }
#endif
    }

    // MARK: - QA seeding

    func apply(_ seed: QASeed) {
        if let profile = seed.profile { self.profile = profile }
        if let sessions = seed.sessions { self.sessions = sessions }
        if let day = seed.day { self.day = min(90, max(1, day)) }
        switch seed.phase {
        case "running":
            if let record = seed.record { phase = .running(record) }
        case "done":
            if let record = seed.record { phase = .done(record) }
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

    // MARK: - Canonical session requests

    func protocolRequest() -> TrainingSessionRequest? {
        guard !hasCompletedCurrentProtocol else { return nil }
        return .protocolRequest(
            prescription: prescription,
            day: day,
            environmentPreparation: environmentPreparation
        )
    }

    func prepareProtocolSession() {
        guard let request = protocolRequest() else { return }
        phase = .preparing(request)
    }

    func prepareFreeTraining(_ mode: TrainingMode) {
        phase = .preparing(.freeTraining(mode: mode))
    }

    func updatePreparedRequest(_ request: TrainingSessionRequest) {
        guard case .preparing = phase else { return }
        phase = .preparing(request)
    }

    func cancelPreparation() {
        phase = .today
    }

    func setEnvironmentPreparation(_ preparation: EnvironmentPreparation?) {
        environmentPreparation = preparation
        persist()
    }

    func beginPreparedSession(environment arm: SessionEnvironmentArm? = nil) {
        guard case .preparing(let request) = phase else { return }
        begin(request: request, environment: arm)
    }

    func begin(request: TrainingSessionRequest, environment arm: SessionEnvironmentArm? = nil) {
        if request.origin == .protocol {
            guard request.programDay == day, !hasCompletedCurrentProtocol else { return }
        }

        let capturedPreparation = request.origin == .protocol
            ? (request.environmentPreparation ?? environmentPreparation)
            : request.environmentPreparation
        let capturedArm = arm ?? capturedPreparation?.arm
        var evidence = SessionEvidence()
        switch request.mode {
        case .stay:
            evidence.stay = StayEvidence(
                task: request.task ?? request.goal,
                completionDefinition: request.completionDefinition
            )
        case .recall:
            evidence.recall = RecallEvidence(source: request.source ?? "", reconstruction: "")
        case .explain:
            evidence.explain = ExplainEvidence(topic: request.topic ?? request.goal, source: request.source)
        case .nothing:
            evidence.nothing = NothingEvidence()
        case .observe:
            evidence.observe = ObserveEvidence(
                mission: request.observationMission
                    ?? (request.origin == .protocol ? "Work normally." : ObservationMission.all[0])
            )
        }

        var record = SessionRecord(
            origin: request.origin,
            requestID: request.id,
            day: request.programDay ?? day,
            date: Date(),
            mode: request.mode,
            targetMinutes: request.targetMinutes,
            actualMinutes: 0,
            completed: false,
            environmentActionDone: capturedPreparation?.actionWasDone,
            evidence: evidence
        )
        if let capturedArm {
            record.environment = EnvironmentSnapshot(
                protectionOffered: capturedArm.protectionOffered,
                protectionAccepted: capturedArm.protectionAccepted,
                protectionActivated: capturedArm.protectionActivated,
                protectionEndedEarly: false,
                protectedSelectionID: capturedArm.protectedSelectionID,
                manualIntervention: capturedArm.manualIntervention,
                phoneLocationSelfReport: capturedArm.phoneLocationSelfReport,
                thresholdEvents: [],
                environmentCondition: capturedArm.condition.rawValue,
                startedEasierSelfReport: nil
            )
        }
        phase = .running(record)
        persist()
    }

    /// Compatibility entry point used by the existing deterministic QA harness.
    func beginSession(environment arm: SessionEnvironmentArm? = nil, minutesOverride: Int? = nil) {
        guard var request = protocolRequest() else { return }
        if let minutesOverride { request.targetMinutes = minutesOverride }
        begin(request: request, environment: arm)
    }

    func updateRunningEvidence(_ update: (inout SessionEvidence) -> Void) {
        guard case .running(var record) = phase else { return }
        var evidence = record.evidence ?? SessionEvidence()
        update(&evidence)
        record.evidence = evidence
        phase = .running(record)
        persist()
    }

    func markSwitch(at date: Date = Date()) {
        guard case .running(var record) = phase, record.mode == .stay else { return }
        let elapsed = max(0, Int(date.timeIntervalSince(record.date)))
        var stay = record.evidence?.stay ?? StayEvidence(task: "Current task")
        stay.switchTimestamps.append(elapsed)
        if stay.firstSwitchTiming == nil {
            stay.firstSwitchTiming = timing(forElapsedSeconds: elapsed)
            record.firstSwitchTiming = stay.firstSwitchTiming
            record.firstSwitchMinute = elapsed / 60
        }
        record.switches = stay.switchTimestamps.count
        var evidence = record.evidence ?? SessionEvidence()
        evidence.stay = stay
        record.evidence = evidence
        phase = .running(record)
        persist()
    }

    func finishRunning(at date: Date = Date(), endedEarly: Bool, semanticCompletion: Bool = false) {
        guard case .running(var record) = phase else { return }
        let elapsed = max(0, Int(date.timeIntervalSince(record.date)))
        finish(&record, elapsedSeconds: elapsed, endedEarly: endedEarly, semanticCompletion: semanticCompletion)
    }

    /// Deterministic entry point for tests and the existing QA auto-loop.
    func finishRunning(actualMinutes: Int, endedEarly: Bool) {
        guard case .running(var record) = phase else { return }
        finish(
            &record,
            elapsedSeconds: max(0, actualMinutes * 60),
            endedEarly: endedEarly,
            semanticCompletion: !record.mode.usesStrictTimer
        )
    }

    private func finish(
        _ record: inout SessionRecord,
        elapsedSeconds: Int,
        endedEarly: Bool,
        semanticCompletion: Bool
    ) {
        record.elapsedSeconds = elapsedSeconds
        record.actualMinutes = elapsedSeconds / 60
        record.endedEarly = endedEarly
        let reachedTarget = elapsedSeconds >= record.targetMinutes * 60
        record.completed = !endedEarly && (record.mode.usesStrictTimer ? reachedTarget : semanticCompletion)
        if record.environment != nil {
            record.environment?.protectionEndedEarly = endedEarly
        }
        phase = .done(record)
        persist(activeSession: nil)
    }

    func resumeRecoveredSession() {
        guard case .recovery(let record) = phase else { return }
        phase = .running(record)
        persist()
    }

    func endRecoveredSession(at date: Date = Date()) {
        guard case .recovery(var record) = phase else { return }
        let elapsed = max(0, Int(date.timeIntervalSince(record.date)))
        finish(&record, elapsedSeconds: elapsed, endedEarly: true, semanticCompletion: false)
    }

    func abandonRunning() {
        finishRunning(endedEarly: true)
    }

    func saveDoneSession(_ reflection: SessionReflection) {
        guard case .done(var record) = phase else { return }
        guard !sessions.contains(where: { $0.id == record.id }) else {
            phase = .today
            return
        }

        record.difficulty = reflection.difficulty
        record.energy = reflection.energy
        record.firstDistraction = reflection.firstDistraction
        record.switches = reflection.switches ?? record.switches
        record.firstSwitchTiming = reflection.firstSwitchTiming ?? record.firstSwitchTiming
        if record.environment != nil {
            record.environment?.startedEasierSelfReport = reflection.startedEasier
            record.environment?.protectionEndedEarly = record.endedEarly
            record.environment?.protectionExitReason = reflection.protectionExitReason
        }

        var evidence = record.evidence ?? SessionEvidence()
        if var stay = evidence.stay {
            stay.firstSwitchTiming = record.firstSwitchTiming
            evidence.stay = stay
        }
        if var recall = evidence.recall {
            recall.selfAssessment = reflection.recallAssessment
            recall.missedIdea = reflection.missedIdea
            evidence.recall = recall
        }
        if var explain = evidence.explain {
            explain.selfAssessment = reflection.explanationAssessment
            explain.breakdown = reflection.explanationBreakdown
            evidence.explain = explain
        }
        if var nothing = evidence.nothing {
            nothing.difficulty = reflection.nothingDifficulty
            evidence.nothing = nothing
        }
        if var observe = evidence.observe {
            observe.observation = reflection.observation
            observe.firstSwitchTiming = record.firstSwitchTiming
            evidence.observe = observe
        }
        record.evidence = evidence

        sessions.append(record)
        if record.origin.advancesProgram, record.completed, record.day == day, day < 90 {
            day += 1
        }

        if let observation = EnvironmentObservationFactory.observation(from: record) {
            EnvironmentUpdater.apply(session: record, observation: observation, to: &profile.environmentEvidence)
            onObservationSaved?(observation)
        }
        let comparableCount = sessions.filter { $0.mode == record.mode }.count
        ProfileUpdater.apply(session: record, sessionCount: comparableCount, to: &profile)

        environmentPreparation = nil
        tab = record.origin == .freeTraining ? .train : .today
        persist(activeSession: nil)
        phase = .today
    }

    /// Compatibility wrapper for deterministic QA seeds.
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
        if case .done(var record) = phase {
            record.environmentActionDone = environmentActionDone
            record.firstSwitchMinute = firstSwitchMinute
            record.firstSwitchTiming = FirstSwitchTiming.from(legacyMinute: firstSwitchMinute)
            phase = .done(record)
        }
        saveDoneSession(
            SessionReflection(
                difficulty: difficulty,
                energy: energy,
                firstDistraction: firstDistraction,
                switches: switches,
                firstSwitchTiming: FirstSwitchTiming.from(legacyMinute: firstSwitchMinute),
                startedEasier: startedEasier,
                protectionExitReason: protectionExitReason
            )
        )
    }

    // MARK: - Device facts

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
        setEnvironmentPreparation(
            EnvironmentPreparation(
                action: prescription.action,
                fallback: prescription.actionFallback,
                outcome: done ? .completed : .declined
            )
        )
    }

    // MARK: - Persistence

    func reset() {
        profile = AttentionProfile()
        sessions = []
        day = 1
        environmentPreparation = nil
        tab = .today
        phase = .today
        persist(activeSession: nil)
    }

    private func persist(activeSession explicitActive: SessionRecord? = nil) {
        let active: SessionRecord?
        if let explicitActive {
            active = explicitActive
        } else if case .running(let record) = phase {
            active = record
        } else if case .recovery(let record) = phase {
            active = record
        } else {
            active = nil
        }
        let payload: [String: Any] = [
            "profile": (try? JSONEncoder().encode(profile)) ?? Data(),
            "sessions": (try? JSONEncoder().encode(sessions)) ?? Data(),
            "day": day,
            "preparation": (try? JSONEncoder().encode(environmentPreparation)) ?? Data(),
            "activeSession": (try? JSONEncoder().encode(active)) ?? Data(),
        ]
        defaults.set(payload, forKey: Self.storageKey)
    }

    private typealias StoredState = (
        profile: AttentionProfile,
        sessions: [SessionRecord],
        day: Int,
        preparation: EnvironmentPreparation?,
        activeSession: SessionRecord?
    )

    private static func load(defaults: UserDefaults) -> (state: StoredState?, migrated: Bool) {
        if let state = decode(from: storageKey, defaults: defaults, includesV3Fields: true) {
            return (state, false)
        }
        if let state = decode(from: v2StorageKey, defaults: defaults, includesV3Fields: false) {
            return (state, true)
        }
        if let state = decode(from: v1StorageKey, defaults: defaults, includesV3Fields: false) {
            return (state, true)
        }
        return (nil, false)
    }

    private static func decode(
        from key: String,
        defaults: UserDefaults,
        includesV3Fields: Bool
    ) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: key),
              let profileData = raw["profile"] as? Data,
              let sessionsData = raw["sessions"] as? Data,
              let profile = try? JSONDecoder().decode(AttentionProfile.self, from: profileData),
              let sessions = try? JSONDecoder().decode([SessionRecord].self, from: sessionsData) else {
            return nil
        }
        let preparation: EnvironmentPreparation?
        let active: SessionRecord?
        if includesV3Fields {
            preparation = (raw["preparation"] as? Data).flatMap {
                try? JSONDecoder().decode(EnvironmentPreparation?.self, from: $0)
            } ?? nil
            active = (raw["activeSession"] as? Data).flatMap {
                try? JSONDecoder().decode(SessionRecord?.self, from: $0)
            } ?? nil
        } else {
            preparation = nil
            active = nil
        }
        return (profile, sessions, (raw["day"] as? Int) ?? 1, preparation, active)
    }

    private func timing(forElapsedSeconds elapsed: Int) -> FirstSwitchTiming {
        if elapsed < 5 * 60 { return .underFive }
        if elapsed < 10 * 60 { return .fiveToTen }
        if elapsed < 20 * 60 { return .tenToTwenty }
        return .twentyPlus
    }
}
