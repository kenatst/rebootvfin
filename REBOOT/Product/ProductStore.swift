import Foundation

enum ProductPhase: Equatable {
    case today
    case preparing(TrainingSessionRequest)
    case running(SessionRecord)
    case recovery(SessionRecord)
    case done(SessionRecord)
    case weeklyReview(Int)
    case phaseTransition(ProgramPhaseID)
    case programCompletion
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
    @Published private(set) var programState: ProgramState
    @Published private(set) var environmentPreparation: EnvironmentPreparation?
    @Published var tab: ProductTab = .today
    @Published var phase: ProductPhase = .today
    @Published private(set) var personalRules: [PersonalRule] = []
    @Published private(set) var observations: [EvidenceObservation] = []

    var onObservationSaved: ((EnvironmentObservation) -> Void)?

    private static let storageKey = "reboot.product.v5"
    private static let v4StorageKey = "reboot.product.v4"
    private static let v3StorageKey = "reboot.product.v3"
    private static let v2StorageKey = "reboot.product.v2"
    private static let v1StorageKey = "reboot.product.v1"
    private let defaults: UserDefaults

    var allSessions: [SessionRecord] { sessions }
    var protocolSessions: [SessionRecord] { sessions.filter { $0.origin == .protocol } }
    var freeTrainingSessions: [SessionRecord] { sessions.filter { $0.origin == .freeTraining } }
    var completedProtocolSessions: [SessionRecord] { protocolSessions.filter(\.completed) }
    var completedProtocolDays: Int {
        min(90, Set(completedProtocolSessions.map(\.day).filter { (1...90).contains($0) }).count)
    }
    var programProgress: Double { Double(completedProtocolDays) / 90.0 }
    var day: Int { programState.currentDay }
    var programStatus: ProgramStatus { programState.status }
    var currentProgramDefinition: ProgramDayDefinition {
        CurriculumEngine.definition(
            for: day,
            profile: profile,
            protocolHistory: protocolSessions,
            reviews: programState.reviews
        )
    }
    var currentProgramPhase: ProgramPhase { currentProgramDefinition.phase }
    var programInsights: [ProgramInsight] { ProgramInsightEngine.insights(from: protocolSessions) }
    var nextCheckpointDay: Int? {
        ProgramCheckpointSchedule.nextCheckpointDay(after: completedProtocolDays)
    }
    var sessionsUntilNextCheckpoint: Int? {
        ProgramCheckpointSchedule.sessionsUntilNextCheckpoint(after: completedProtocolDays)
    }

    var prescription: DailyPrescription {
        PrescriptionEngine.prescription(
            profile: profile,
            sessions: protocolSessions,
            day: day,
            reviews: programState.reviews
        )
    }

    var isCalibrating: Bool { completedProtocolDays < 3 }

    var hasCompletedCurrentProtocol: Bool {
        programStatus == .completed || protocolSessions.contains { $0.day == day && $0.completed }
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
            programState = stored.programState
            environmentPreparation = stored.preparation
            personalRules = profile.personalRules
            observations = profile.observations
            if let active = stored.activeSession {
                phase = .recovery(active)
            }
            if loaded.migrated {
                persist()
                defaults.removeObject(forKey: Self.v4StorageKey)
                defaults.removeObject(forKey: Self.v3StorageKey)
                defaults.removeObject(forKey: Self.v2StorageKey)
                defaults.removeObject(forKey: Self.v1StorageKey)
            }
        } else {
            profile = ProfileBuilder.build(from: diagnosisAnswers)
            sessions = []
            programState = .fresh
            environmentPreparation = nil
            personalRules = []
            observations = []
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
           let qaTab = ProductTab.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(tabName) == .orderedSame }) {
            tab = qaTab
        }
        if let modeName = ProcessInfo.processInfo.arguments.valueAfter("-qaMode"),
           let qaMode = TrainingMode(rawValue: modeName) {
            prepareFreeTraining(qaMode)
        }
#endif
        if case .today = phase {
            routePendingProgramFlow()
        }
    }

    // MARK: - QA seeding

    func apply(_ seed: QASeed) {
        if let profile = seed.profile {
            self.profile = profile
            self.personalRules = profile.personalRules
            self.observations = profile.observations
        }
        if let sessions = seed.sessions { self.sessions = sessions }
        if let programState = seed.programState {
            self.programState = programState
        } else if let day = seed.day {
            self.programState = .migrated(day: day, sessions: seed.sessions ?? sessions)
        }
        switch seed.phase {
        case "running":
            if let record = seed.record { phase = .running(record) }
        case "done":
            if let record = seed.record { phase = .done(record) }
        default:
            phase = .today
        }
        tab = .today
        if case .today = phase {
            routePendingProgramFlow()
        }
        persist()
    }

    private static func loadQASeed() -> QASeed? {
        guard let path = ProcessInfo.processInfo.arguments.valueAfter("-qaProduct"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return try? JSONDecoder().decode(QASeed.self, from: data)
    }

    // MARK: - Personal Rules actions

    func keepPersonalRule(id: UUID) {
        PersonalRuleEngine.keep(id: id, in: &personalRules)
        profile.personalRules = personalRules
        persist()
    }

    func testPersonalRule(id: UUID) {
        PersonalRuleEngine.test(id: id, in: &personalRules)
        profile.personalRules = personalRules
        persist()
    }

    func retirePersonalRule(id: UUID) {
        PersonalRuleEngine.retire(id: id, in: &personalRules)
        profile.personalRules = personalRules
        persist()
    }

    func rejectPersonalRule(id: UUID) {
        PersonalRuleEngine.reject(id: id, in: &personalRules)
        profile.personalRules = personalRules
        persist()
    }

    func addCustomPersonalRule(
        title: String,
        detail: String,
        category: RuleCategory,
        contexts: [RuleContext]
    ) {
        PersonalRuleEngine.addCustom(
            title: title,
            detail: detail,
            category: category,
            contexts: contexts,
            day: day,
            into: &personalRules
        )
        profile.personalRules = personalRules
        persist()
    }

    // MARK: - Canonical session requests

    func protocolRequest() -> TrainingSessionRequest? {
        guard programStatus == .active,
              !programState.hasPendingRequiredFlow,
              !hasCompletedCurrentProtocol else { return nil }
        return .protocolRequest(
            prescription: prescription,
            day: day,
            environmentPreparation: day == 1 ? nil : environmentPreparation
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
        environmentPreparation = day == 1 ? nil : preparation
        persist()
    }

    func beginPreparedSession(environment arm: SessionEnvironmentArm? = nil) {
        guard case .preparing(let request) = phase else { return }
        begin(request: request, environment: arm)
    }

    func begin(request: TrainingSessionRequest, environment arm: SessionEnvironmentArm? = nil) {
        var request = request
        if request.origin == .protocol {
            guard programStatus == .active,
                  !programState.hasPendingRequiredFlow,
                  request.programDay == day,
                  !hasCompletedCurrentProtocol else { return }
            if day == 1 {
                let requestID = request.id
                let createdAt = request.createdAt
                request = .protocolRequest(
                    prescription: prescription,
                    day: 1,
                    environmentPreparation: nil
                )
                request.id = requestID
                request.createdAt = createdAt
            }
        }

        let isNaturalBaseline = request.origin == .protocol && request.programDay == 1
        let capturedPreparation = isNaturalBaseline
            ? nil
            : (request.origin == .protocol
                ? (request.environmentPreparation ?? environmentPreparation)
                : request.environmentPreparation)
        let capturedArm = isNaturalBaseline ? nil : (arm ?? capturedPreparation?.arm)
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
            prescriptionID: request.prescriptionID,
            day: request.programDay ?? day,
            date: Date(),
            mode: request.mode,
            targetMinutes: request.targetMinutes,
            actualMinutes: 0,
            completed: false,
            environmentActionDone: capturedPreparation?.actionWasDone,
            environmentVerification: capturedArm != nil ? .systemConfirmed : (capturedPreparation?.actionWasDone == true ? .userReported : nil),
            evidence: evidence,
            appliedRuleIDs: request.appliedRuleIDs,
            environmentPreparation: capturedPreparation,
            programPhase: request.programPhase,
            curriculumIntent: request.curriculumIntent,
            adaptationReason: request.adaptationReason
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
        let alreadySaved = sessions.contains { saved in
            saved.id == record.id
                || (record.requestID != nil && saved.requestID == record.requestID)
        }
        guard !alreadySaved else {
            routePendingProgramFlow()
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

        if record.origin.advancesProgram, record.completed {
            let outcome = programState.registerCompletedProtocolSession(id: record.id, day: record.day)
            guard outcome != .ignored else {
                routePendingProgramFlow()
                return
            }
        }

        sessions.append(record)

        if let observation = EnvironmentObservationFactory.observation(from: record) {
            EnvironmentUpdater.apply(session: record, observation: observation, to: &profile.environmentEvidence)
            onObservationSaved?(observation)
        }
        let comparableCount = sessions.filter { $0.mode == record.mode }.count
        ProfileUpdater.apply(session: record, sessionCount: comparableCount, allSessions: sessions, to: &profile)

        personalRules = profile.personalRules
        observations = profile.observations

        environmentPreparation = nil
        tab = record.origin == .freeTraining ? .train : .today
        persist(activeSession: nil)
        if record.origin == .freeTraining || !record.completed {
            phase = .today
        } else {
            routePendingProgramFlow()
        }
    }

    func saveWeeklyReview(_ answers: WeeklyReviewAnswers) {
        guard case .weeklyReview(let checkpointDay) = phase,
              programState.pendingReviewDay == checkpointDay else { return }
        let insights = ProgramInsightEngine.insights(
            from: protocolSessions.filter { $0.day <= checkpointDay }
        )
        .map(\.text)
        let review = WeeklyReviewRecord(
            programDay: checkpointDay,
            date: Date(),
            shownInsights: Array(insights.prefix(2)),
            answers: answers
        )
        programState.recordReview(review)
        persist(activeSession: nil)
        routePendingProgramFlow()
    }

    func skipWeeklyReviewQuestions() {
        saveWeeklyReview(.empty)
    }

    func acknowledgePhaseTransition() {
        guard case .phaseTransition(let phaseID) = phase else { return }
        programState.acknowledgePhaseTransition(phaseID)
        persist(activeSession: nil)
        routePendingProgramFlow()
    }

    func acknowledgeProgramCompletion() {
        guard case .programCompletion = phase else { return }
        programState.acknowledgeCompletion()
        persist(activeSession: nil)
        phase = .today
    }

    private func routePendingProgramFlow() {
        if let reviewDay = programState.pendingReviewDay {
            phase = .weeklyReview(reviewDay)
        } else if let transition = programState.pendingPhaseTransition {
            phase = .phaseTransition(transition)
        } else if programState.pendingCompletion {
            phase = .programCompletion
        } else {
            phase = .today
        }
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
            let isNaturalBaseline = record.origin == .protocol && record.day == 1
            record.environmentActionDone = isNaturalBaseline ? nil : environmentActionDone
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
        programState = .fresh
        environmentPreparation = nil
        personalRules = []
        observations = []
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
            "programState": (try? JSONEncoder().encode(programState)) ?? Data(),
            "preparation": (try? JSONEncoder().encode(environmentPreparation)) ?? Data(),
            "personalRules": (try? JSONEncoder().encode(personalRules)) ?? Data(),
            "observations": (try? JSONEncoder().encode(observations)) ?? Data(),
            "activeSession": (try? JSONEncoder().encode(active)) ?? Data(),
        ]
        defaults.set(payload, forKey: Self.storageKey)
    }

    private typealias StoredState = (
        profile: AttentionProfile,
        sessions: [SessionRecord],
        programState: ProgramState,
        preparation: EnvironmentPreparation?,
        activeSession: SessionRecord?
    )

    private static func load(defaults: UserDefaults) -> (state: StoredState?, migrated: Bool) {
        if defaults.object(forKey: storageKey) != nil {
            return (decodeV5(defaults: defaults), false)
        }
        if defaults.object(forKey: v4StorageKey) != nil {
            return (decodeV4(from: v4StorageKey, defaults: defaults), true)
        }
        if defaults.object(forKey: v3StorageKey) != nil {
            return (decodeLegacy(from: v3StorageKey, defaults: defaults, includesV3Fields: true), true)
        }
        if defaults.object(forKey: v2StorageKey) != nil {
            return (decodeLegacy(from: v2StorageKey, defaults: defaults, includesV3Fields: false), true)
        }
        if defaults.object(forKey: v1StorageKey) != nil {
            return (decodeLegacy(from: v1StorageKey, defaults: defaults, includesV3Fields: false), true)
        }
        return (nil, false)
    }

    private static func decodeV5(defaults: UserDefaults) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: storageKey) else {
            return (AttentionProfile(), [], .fresh, nil, nil)
        }
        let profileData = raw["profile"] as? Data
        let sessionsData = raw["sessions"] as? Data
        let programData = raw["programState"] as? Data

        var profile = profileData.flatMap { try? JSONDecoder().decode(AttentionProfile.self, from: $0) }
            ?? AttentionProfile()
        let sessions = sessionsData.flatMap { try? JSONDecoder().decode([SessionRecord].self, from: $0) }
            ?? []
        let programState = programData.flatMap { try? JSONDecoder().decode(ProgramState.self, from: $0) }
            ?? .migrated(day: (raw["day"] as? Int) ?? 1, sessions: sessions)

        if let rulesData = raw["personalRules"] as? Data,
           let rules = try? JSONDecoder().decode([PersonalRule].self, from: rulesData),
           profile.personalRules.isEmpty {
            profile.personalRules = rules
        }

        if let obsData = raw["observations"] as? Data,
           let obs = try? JSONDecoder().decode([EvidenceObservation].self, from: obsData),
           profile.observations.isEmpty {
            profile.observations = obs
        }

        let preparation = (raw["preparation"] as? Data).flatMap {
            try? JSONDecoder().decode(EnvironmentPreparation?.self, from: $0)
        } ?? nil
        let active = (raw["activeSession"] as? Data).flatMap {
            try? JSONDecoder().decode(SessionRecord?.self, from: $0)
        } ?? nil
        return (profile, sessions, programState, preparation, active)
    }

    private static func decodeV4(from key: String, defaults: UserDefaults) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: key) else {
            return (AttentionProfile(), [], .fresh, nil, nil)
        }
        let profileData = raw["profile"] as? Data
        let sessionsData = raw["sessions"] as? Data
        let programData = raw["programState"] as? Data

        let profile = profileData.flatMap { try? JSONDecoder().decode(AttentionProfile.self, from: $0) }
            ?? AttentionProfile()
        let sessions = sessionsData.flatMap { try? JSONDecoder().decode([SessionRecord].self, from: $0) }
            ?? []
        let programState = programData.flatMap { try? JSONDecoder().decode(ProgramState.self, from: $0) }
            ?? .migrated(day: (raw["day"] as? Int) ?? 1, sessions: sessions)
        let preparation = (raw["preparation"] as? Data).flatMap {
            try? JSONDecoder().decode(EnvironmentPreparation?.self, from: $0)
        } ?? nil
        let active = (raw["activeSession"] as? Data).flatMap {
            try? JSONDecoder().decode(SessionRecord?.self, from: $0)
        } ?? nil
        return (profile, sessions, programState, preparation, active)
    }

    private static func decodeLegacy(
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
        let legacyDay = (raw["day"] as? Int) ?? 1
        return (
            profile,
            sessions,
            ProgramState.migrated(day: legacyDay, sessions: sessions),
            preparation,
            active
        )
    }

    private func timing(forElapsedSeconds elapsed: Int) -> FirstSwitchTiming {
        if elapsed < 5 * 60 { return .underFive }
        if elapsed < 10 * 60 { return .fiveToTen }
        if elapsed < 20 * 60 { return .tenToTwenty }
        return .twentyPlus
    }
}
