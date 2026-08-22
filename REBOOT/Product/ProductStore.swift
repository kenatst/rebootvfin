import Foundation

enum ProductPhase: Equatable {
    case today
    case lab
    case fuel
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
    @Published private(set) var labState: PersonalLabState = .empty
    @Published var fuelState: FuelState = .empty

    var onObservationSaved: ((EnvironmentObservation) -> Void)?

    private static let storageKey = "reboot.product.v7"
    private static let v6StorageKey = "reboot.product.v6"
    private static let v5StorageKey = "reboot.product.v5"
    private static let v4StorageKey = "reboot.product.v4"
    private static let v3StorageKey = "reboot.product.v3"
    private static let v2StorageKey = "reboot.product.v2"
    private static let v1StorageKey = "reboot.product.v1"
    private let defaults: UserDefaults

    var allSessions: [SessionRecord] { sessions }
    var protocolSessions: [SessionRecord] { sessions.filter { $0.origin == .protocol } }
    var freeTrainingSessions: [SessionRecord] { sessions.filter { $0.origin == .freeTraining } }
    var experimentSessions: [SessionRecord] { sessions.filter { $0.origin == .experiment } }
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

    var activeExperiment: PersonalExperiment? { labState.activeExperiment }
    var pausedExperiment: PersonalExperiment? { labState.pausedExperiment }
    var pastExperiments: [PersonalExperiment] { labState.completedExperiments }

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
            labState = stored.labState
            fuelState = stored.fuelState
            if let active = stored.activeSession {
                phase = .recovery(active)
            }
            if loaded.migrated {
                persist()
                defaults.removeObject(forKey: Self.v6StorageKey)
                defaults.removeObject(forKey: Self.v5StorageKey)
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
            labState = .empty
            fuelState = .empty
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
        if ProcessInfo.processInfo.arguments.contains("-qaLabPrepare") {
            prepareStandaloneLabSession()
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
        if let labState = seed.labState { self.labState = labState }
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
        case "lab":
            phase = .lab
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
        do {
            return try JSONDecoder().decode(QASeed.self, from: data)
        } catch {
#if DEBUG
            print("QA-SEED-ERROR \(error)")
#endif
            return nil
        }
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

    // MARK: - Personal Lab

    func openPersonalLab() {
        phase = .lab
    }

    func closePersonalLab() {
        tab = .profile
        phase = .today
    }

    /// Extends an INCONCLUSIVE experiment with one more balanced pair on the
    /// SAME experiment. Same question, conditions, and primary metric; the
    /// previous result becomes history and is never double-counted.
    @discardableResult
    func extendInconclusiveExperiment(id: UUID) -> Bool {
        guard let index = labState.experiments.firstIndex(where: { $0.id == id }) else { return false }
        let extended = labState.experiments[index].extendForAdditionalComparison()
        if extended { persist() }
        return extended
    }

    // MARK: - Fuel

    func openFuel() {
        phase = .fuel
    }

    func closeFuel() {
        tab = .profile
        phase = .today
    }

    func setFuelPromptsEnabled(_ enabled: Bool) {
        fuelState.promptsEnabled = enabled
        persist()
    }

    var fuelAnalysis: (patterns: [FuelPattern], openQuestions: [FuelOpenQuestion]) {
        FuelPatternEngine.evaluate(sessions: sessions)
    }

    /// Most recent session-linked context. Only actual known values display.
    var latestFuelContext: FuelContextSnapshot? {
        sessions.last(where: { $0.fuelContext != nil && !$0.fuelContext!.isEmpty })?.fuelContext
    }

    /// Today's unconsumed prompt answers. A capture from an earlier day can
    /// never attach to a session and never drives eligibility UI.
    var todaysFuelCapture: FuelContextSnapshot? {
        guard let capture = fuelState.pendingCapture,
              FuelState.calendarDay(capture.capturedAt) == FuelState.calendarDay(Date()) else {
            return nil
        }
        return capture
    }

    /// Sessions with Fuel context, newest first, for restrained display.
    var fuelLinkedSessions: [SessionRecord] {
        sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }.reversed()
    }

    private var isRecoveryPrescribed: Bool {
        prescription.mode == .nothing
            && prescription.adaptationReason.localizedCaseInsensitiveContains("recovery")
    }

    /// The single optional Fuel prompt for today's protocol session, if any.
    var currentFuelPrompt: FuelSamplePrompt? {
        // No prompt once today's protocol session is done: nothing could
        // consume the answer, and an unconsumed answer must never linger.
        guard !hasCompletedCurrentProtocol else { return nil }
        return ContextSamplingEngine.recommendPrompt(.init(
            programDay: day,
            completedProtocolDays: completedProtocolDays,
            phase: currentProgramPhase.id,
            isRecoveryPrescribed: isRecoveryPrescribed,
            promptsEnabled: fuelState.promptsEnabled,
            activeFuelConditionTest: PersonalLabEngine.hasActiveFuelConditionTest(activeExperiment),
            preferredField: activeExperiment.flatMap(PersonalLabEngine.fuelFieldNeeded(by:)),
            pendingCapture: todaysFuelCapture,
            log: fuelState.sampling
        ))
    }

    func answerFuelPrompt(_ prompt: FuelSamplePrompt, rawValue: String) {
        // A stale capture from an earlier day is discarded, not merged into:
        // its fields could never honestly attach to today's session.
        let base = todaysFuelCapture ?? FuelContextSnapshot()
        fuelState.pendingCapture = base.with(field: prompt.field, rawValue: rawValue)
        fuelState.recordAnswer(field: prompt.field)
        persist()
    }

    func skipFuelPrompt(_ prompt: FuelSamplePrompt) {
        fuelState.recordSkip(field: prompt.field)
        persist()
    }

    func experiment(id: UUID) -> PersonalExperiment? {
        labState.experiments.first { $0.id == id }
    }

    func labSuggestions(screenTimeAvailable: Bool) -> [ExperimentSuggestion] {
        PersonalLabEngine.suggestions(
            profile: profile,
            sessions: sessions,
            rules: personalRules,
            state: labState,
            screenTimeAvailable: screenTimeAvailable
        )
    }

    func ruleConflicts(
        template: ExperimentTemplate,
        linkedRuleID: UUID? = nil
    ) -> [PersonalRule] {
        let origin: ExperimentOrigin = linkedRuleID == nil ? .builtIn : .personalRuleRetest
        let draft = PersonalLabEngine.makeExperiment(
            template: template,
            origin: origin,
            linkedRuleID: linkedRuleID
        )
        let ids = Set(PersonalLabEngine.conflictingRuleIDs(for: draft, rules: personalRules))
        return personalRules.filter { ids.contains($0.id) }
    }

    @discardableResult
    func startExperiment(
        template: ExperimentTemplate,
        linkedRuleID: UUID? = nil,
        allowingRuleExceptions: Bool = false
    ) -> ExperimentStartOutcome {
        let origin: ExperimentOrigin
        if linkedRuleID != nil {
            origin = .personalRuleRetest
        } else if labSuggestions(screenTimeAvailable: true).contains(where: { $0.template.id == template.id }) {
            origin = .evidenceSuggestion
        } else {
            origin = .builtIn
        }
        let experiment = PersonalLabEngine.makeExperiment(
            template: template,
            origin: origin,
            linkedRuleID: linkedRuleID
        )
        let outcome = PersonalLabEngine.start(
            experiment,
            in: &labState,
            rules: personalRules,
            allowingRuleExceptions: allowingRuleExceptions
        )
        if case .started = outcome { persist() }
        return outcome
    }

    @discardableResult
    func startCustomExperiment(
        question: String,
        normal: String,
        test: String,
        mode: TrainingMode,
        primaryOutcome: ExperimentOutcomeMetric
    ) -> ExperimentStartOutcome {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNormal = normal.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTest = test.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty, !trimmedNormal.isEmpty, !trimmedTest.isEmpty else {
            return .unavailable
        }
        let experiment = PersonalLabEngine.makeCustomExperiment(
            question: trimmedQuestion,
            normal: trimmedNormal,
            test: trimmedTest,
            mode: mode,
            primaryOutcome: primaryOutcome
        )
        let outcome = PersonalLabEngine.start(
            experiment,
            in: &labState,
            rules: personalRules
        )
        if case .started = outcome { persist() }
        return outcome
    }

    func pauseExperiment(id: UUID) {
        PersonalLabEngine.pause(id: id, in: &labState)
        persist()
    }

    @discardableResult
    func resumeExperiment(id: UUID) -> Bool {
        let resumed = PersonalLabEngine.resume(id: id, in: &labState)
        if resumed { persist() }
        return resumed
    }

    func abandonExperiment(id: UUID) {
        PersonalLabEngine.abandon(id: id, in: &labState)
        persist()
    }

    @discardableResult
    func finalizeExperiment(id: UUID, allowEarly: Bool = true) -> ExperimentResult? {
        let result = PersonalLabEngine.finalize(id: id, in: &labState, allowEarly: allowEarly)
        if result != nil { persist() }
        return result
    }

    @discardableResult
    func repeatExperiment(
        id: UUID,
        allowingRuleExceptions: Bool = false
    ) -> ExperimentStartOutcome {
        if let activeExperiment { return .activeExperimentExists(activeExperiment.id) }
        guard let previous = experiment(id: id) else { return .unavailable }
        var repeated = previous
        repeated.id = UUID()
        repeated.version += 1
        repeated.status = .draft
        repeated.observations = []
        repeated.pairs = []
        repeated.result = nil
        repeated.historicalResults = []
        repeated.approvedRuleExceptionIDs = []
        repeated.createdAt = Date()
        repeated.updatedAt = Date()
        repeated.completedAt = nil
        repeated.normalArm.id = UUID()
        repeated.testArm.id = UUID()
        let outcome = PersonalLabEngine.start(
            repeated,
            in: &labState,
            rules: personalRules,
            allowingRuleExceptions: allowingRuleExceptions
        )
        if case .started = outcome { persist() }
        return outcome
    }

    @discardableResult
    func keepExperimentResultAsRule(experimentID: UUID) -> PersonalRule? {
        guard let experimentIndex = labState.experiments.firstIndex(where: { $0.id == experimentID }),
              labState.experiments[experimentIndex].result?.state == .keep,
              let result = labState.experiments[experimentIndex].result else { return nil }

        if let existing = personalRules.first(where: { $0.experimentID == experimentID }) {
            return existing
        }

        if let linkedID = labState.experiments[experimentIndex].linkedPersonalRuleID,
           let ruleIndex = personalRules.firstIndex(where: { $0.id == linkedID }) {
            PersonalRuleEngine.keep(id: linkedID, in: &personalRules)
            personalRules[ruleIndex].experimentID = experimentID
            personalRules[ruleIndex].supportingEvidenceIDs = result.sourceEvidenceIDs
            personalRules[ruleIndex].supportingObservations.append(result.summary)
            profile.personalRules = personalRules
            labState.experiments[experimentIndex].result?.personalRuleID = linkedID
            persist()
            return personalRules[ruleIndex]
        }

        guard let draft = labState.experiments[experimentIndex].ruleDraft else { return nil }
        let newRule = PersonalRule(
            title: draft.title,
            detail: draft.detail,
            category: draft.category,
            matchingContexts: draft.contexts,
            lifecycle: .kept,
            sourceType: .experiment,
            confidence: .moderate,
            supportingObservations: [result.summary],
            contradictingObservations: [],
            recencyStatus: .repeatedRecent,
            createdDay: day,
            lastTestedDay: day,
            timesTested: result.completedPairs * 2,
            timesKept: 1,
            experimentID: experimentID,
            supportingEvidenceIDs: result.sourceEvidenceIDs
        )
        personalRules.append(newRule)
        profile.personalRules = personalRules
        labState.experiments[experimentIndex].linkedPersonalRuleID = newRule.id
        labState.experiments[experimentIndex].result?.personalRuleID = newRule.id
        persist()
        return newRule
    }

    func retireRuleChallengedByExperiment(experimentID: UUID) {
        guard let experiment = experiment(id: experimentID),
              experiment.result?.state == .drop,
              let linkedID = experiment.linkedPersonalRuleID else { return }
        retirePersonalRule(id: linkedID)
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

    func prepareProtocolSession(
        participatingInLab: Bool = false,
        activeRecurringProtection: Bool = false
    ) {
        guard var request = protocolRequest() else { return }
        if participatingInLab {
            request = attachingActiveExperiment(
                to: request,
                activeRecurringProtection: activeRecurringProtection
            )
        }
        phase = .preparing(request)
    }

    func prepareFreeTraining(_ mode: TrainingMode, participatingInLab: Bool = false) {
        var request = TrainingSessionRequest.freeTraining(mode: mode)
        if participatingInLab {
            request = attachingActiveExperiment(to: request)
        }
        phase = .preparing(request)
    }

    func prepareStandaloneLabSession() {
        guard !labParticipationProtectedToday,
              let experiment = activeExperiment,
              let mode = experiment.eligibleModes.first else { return }
        var request = TrainingSessionRequest(
            origin: .experiment,
            mode: mode,
            programDay: nil,
            targetMinutes: experiment.preferredDuration,
            goal: experiment.question,
            observationMission: mode == .observe ? experiment.question : nil
        )
        let eligibility = PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: false
        )
        guard let participation = PersonalLabEngine.participation(
            for: experiment,
            request: request,
            eligibility: eligibility,
            fuel: todaysFuelCapture,
            sessionDate: Date()
        ) else { return }
        request.experimentParticipation = participation
        labState.pendingParticipation = participation
        phase = .preparing(request)
        persist()
    }

    var canPrepareStandaloneLabSession: Bool {
        guard !labParticipationProtectedToday,
              let experiment = activeExperiment,
              let mode = experiment.eligibleModes.first else { return false }
        let request = TrainingSessionRequest(
            origin: .experiment,
            mode: mode,
            programDay: nil,
            targetMinutes: experiment.preferredDuration,
            goal: experiment.question
        )
        let eligibility = PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: false
        )
        return PersonalLabEngine.participation(
            for: experiment,
            request: request,
            eligibility: eligibility,
            fuel: todaysFuelCapture,
            sessionDate: Date()
        ) != nil
    }

    func canAttachActiveExperiment(
        to mode: TrainingMode,
        origin: SessionOrigin = .freeTraining
    ) -> Bool {
        guard !labParticipationProtectedToday,
              let experiment = activeExperiment else { return false }
        // Observational comparisons join protocol sessions only — the real
        // context that selects the arm comes from the sampled day.
        if experiment.comparisonKind == .observationalComparison { return false }
        let request = TrainingSessionRequest(
            origin: origin,
            mode: mode,
            programDay: origin == .protocol ? day : nil,
            targetMinutes: origin == .protocol ? prescription.minutes : (mode.freeDurations.first ?? 10),
            goal: mode.libraryDescription,
            adaptationReason: origin == .protocol ? prescription.adaptationReason : nil
        )
        return PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: isProtectedRecovery(request)
        ).eligible
    }

    /// Opportunity-aware surfacing: Lab appears on Today only when the real
    /// session genuinely counts toward the current test.
    func todayExperimentOpportunity(activeRecurringProtection: Bool = false) -> ExperimentOpportunity? {
        guard let experiment = activeExperiment,
              let request = protocolRequest() else { return nil }
        return ExperimentOpportunityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: isProtectedRecovery(request),
            activeRecurringProtection: activeRecurringProtection,
            rules: personalRules,
            fuel: todaysFuelCapture ?? request.fuelContext
        )
    }

    func todayExperimentParticipation(
        activeRecurringProtection: Bool = false
    ) -> ExperimentParticipation? {
        guard let experiment = activeExperiment,
              let request = protocolRequest() else { return nil }
        let eligibility = PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: isProtectedRecovery(request),
            activeRecurringProtection: activeRecurringProtection
        )
        return PersonalLabEngine.participation(
            for: experiment,
            request: request,
            eligibility: eligibility,
            fuel: todaysFuelCapture ?? request.fuelContext
        )
    }

    func todayExperimentWaitReason(activeRecurringProtection: Bool = false) -> String? {
        guard let experiment = activeExperiment,
              let request = protocolRequest() else { return nil }
        let eligibility = PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: isProtectedRecovery(request),
            activeRecurringProtection: activeRecurringProtection
        )
        guard !eligibility.eligible else { return nil }
        if eligibility.recoveryProtected {
            return "We'll continue this test when the sessions are comparable again."
        }
        if request.origin == .protocol, request.programDay == 1 {
            return "Day 1 stays a natural baseline. The test will wait."
        }
        return eligibility.reasons.first
    }

    func nextExperimentCondition(for mode: TrainingMode) -> String? {
        guard let experiment = activeExperiment,
              experiment.comparisonKind == .interventionTest,
              experiment.eligibleModes.contains(mode),
              let assignment = PersonalLabEngine.nextAssignment(for: experiment) else { return nil }
        let arm = experiment.arm(for: assignment.armKind)
        return "\(arm.kind.displayLabel): \(arm.condition.title)"
    }

    func experimentTemplate(for rule: PersonalRule) -> ExperimentTemplate? {
        let copy = "\(rule.title) \(rule.detail)".lowercased()
        if copy.contains("phone") { return ExperimentTemplateLibrary.phoneDistance }
        if copy.contains("tab") || copy.contains("browser") { return ExperimentTemplateLibrary.oneBrowserTask }
        if copy.contains("done") || copy.contains("finish") { return ExperimentTemplateLibrary.clearFinishLine }
        if copy.contains("protect") || copy.contains("screen time") { return ExperimentTemplateLibrary.sessionProtection }
        return nil
    }

    @discardableResult
    func startExperimentForRule(
        id: UUID,
        allowingRuleExceptions: Bool = false
    ) -> ExperimentStartOutcome {
        guard let rule = personalRules.first(where: { $0.id == id }),
              let template = experimentTemplate(for: rule) else { return .unavailable }
        return startExperiment(
            template: template,
            linkedRuleID: id,
            allowingRuleExceptions: allowingRuleExceptions
        )
    }

    func updatePreparedRequest(_ request: TrainingSessionRequest) {
        guard case .preparing = phase else { return }
        phase = .preparing(request)
    }

    func cancelPreparation() {
        labState.pendingParticipation = nil
        phase = .today
        persist()
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

        if isProtectedRecovery(request) {
            request.experimentParticipation = nil
            labState.pendingParticipation = nil
        } else if let participation = request.experimentParticipation {
            let valid = activeExperiment.map { experiment in
                experiment.id == participation.experimentID
                    && experiment.eligibleModes.contains(request.mode)
                    && experiment.arm(for: participation.armKind).id == participation.armID
            } ?? false
            if !valid {
                request.experimentParticipation = nil
                labState.pendingParticipation = nil
            }
        }

        let isNaturalBaseline = request.origin == .protocol && request.programDay == 1
        // Fuel context attaches only when honestly captured today, never on
        // Day 1. Protocol sessions consume the day's optional prompt; a
        // standalone Lab session consumes it only when an observational
        // comparison needs the field. Free training and deliberate
        // intervention tests never touch it.
        let standaloneNeedsFuel = request.origin == .experiment
            && activeExperiment?.comparisonKind == .observationalComparison
        if request.fuelContext == nil, !isNaturalBaseline,
           request.origin == .protocol || standaloneNeedsFuel,
           let pending = todaysFuelCapture {
            request.fuelContext = pending
            fuelState.pendingCapture = nil
        }
        if isNaturalBaseline {
            request.fuelContext = nil
        }

        if let participation = request.experimentParticipation,
           let experiment = activeExperiment,
           experiment.comparisonKind == .observationalComparison {
            // The naturally occurring context must still select this arm at
            // actual session start — a session prepared before noon and begun
            // after lunch is an afternoon session, honestly.
            let arm = experiment.arm(for: participation.armKind)
            let stillMatches = arm.condition.contextMatcher?.matches(
                snapshot: request.fuelContext,
                sessionDate: Date()
            ) == true
            if !stillMatches {
                request.experimentParticipation = nil
                labState.pendingParticipation = nil
            }
        }
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

        let verification: EnvironmentVerificationState?
        switch request.experimentParticipation?.conditionSnapshot.truthSource {
        case .userReported: verification = .userReported
        case .systemConfirmed: verification = .systemConfirmed
        case .notConfirmed: verification = nil
        case nil: verification = capturedArm != nil ? .systemConfirmed : (capturedPreparation?.actionWasDone == true ? .userReported : nil)
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
            environmentVerification: verification,
            evidence: evidence,
            appliedRuleIDs: request.appliedRuleIDs,
            environmentPreparation: capturedPreparation,
            programPhase: request.programPhase,
            curriculumIntent: request.curriculumIntent,
            adaptationReason: request.adaptationReason,
            experimentParticipation: request.experimentParticipation,
            fuelContext: request.fuelContext
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

    private func attachingActiveExperiment(
        to request: TrainingSessionRequest,
        activeRecurringProtection: Bool = false
    ) -> TrainingSessionRequest {
        guard !labParticipationProtectedToday,
              let experiment = activeExperiment else { return request }
        // Observational comparisons join protocol sessions only — the real
        // context that selects the arm comes from the sampled day. Enforced
        // here too, not only in the Train-tab gate.
        if experiment.comparisonKind == .observationalComparison,
           request.origin != .protocol {
            return request
        }
        let eligibility = PersonalLabEligibilityEngine.evaluate(
            request: request,
            experiment: experiment,
            isRecovery: isProtectedRecovery(request),
            activeRecurringProtection: activeRecurringProtection
        )
        guard let participation = PersonalLabEngine.participation(
            for: experiment,
            request: request,
            eligibility: eligibility,
            fuel: todaysFuelCapture ?? request.fuelContext
        ) else { return request }
        var updated = request
        updated.experimentParticipation = participation
        labState.pendingParticipation = participation
        persist()
        return updated
    }

    private func isProtectedRecovery(_ request: TrainingSessionRequest) -> Bool {
        request.origin == .protocol
            && request.mode == .nothing
            && (request.adaptationReason?.localizedCaseInsensitiveContains("recovery") == true)
    }

    private var labParticipationProtectedToday: Bool {
        if day == 1, completedProtocolDays == 0 { return true }
        return prescription.mode == .nothing
            && prescription.adaptationReason.localizedCaseInsensitiveContains("recovery")
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
        record.startedEasierSelfReport = reflection.startedEasier
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

        if record.experimentParticipation != nil {
            let sourceEvidenceIDs = profile.observations
                .filter { $0.sessionID == record.id }
                .map(\.id)
            PersonalLabEngine.record(
                session: record,
                sourceEvidenceIDs: sourceEvidenceIDs,
                in: &labState
            )
        }

        environmentPreparation = nil
        tab = record.origin == .freeTraining ? .train : .today
        persist(activeSession: nil)
        if record.origin == .protocol, record.completed, programState.hasPendingRequiredFlow {
            routePendingProgramFlow()
        } else if record.experimentParticipation != nil {
            phase = .lab
        } else if record.origin == .freeTraining || record.origin == .experiment || !record.completed {
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
        labState = .empty
        fuelState = .empty
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
            "personalLab": (try? JSONEncoder().encode(labState)) ?? Data(),
            "activeSession": (try? JSONEncoder().encode(active)) ?? Data(),
            "fuel": (try? JSONEncoder().encode(fuelState)) ?? Data(),
        ]
        defaults.set(payload, forKey: Self.storageKey)
    }

    private typealias StoredState = (
        profile: AttentionProfile,
        sessions: [SessionRecord],
        programState: ProgramState,
        preparation: EnvironmentPreparation?,
        activeSession: SessionRecord?,
        labState: PersonalLabState,
        fuelState: FuelState
    )

    private static func load(defaults: UserDefaults) -> (state: StoredState?, migrated: Bool) {
        if defaults.object(forKey: storageKey) != nil {
            return (decodeV7(defaults: defaults), false)
        }
        if defaults.object(forKey: v6StorageKey) != nil {
            return (decodeV6(defaults: defaults, key: v6StorageKey), true)
        }
        if defaults.object(forKey: v5StorageKey) != nil {
            return (decodeV5(defaults: defaults), true)
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

    /// v7 decode is intentionally field-tolerant: a corrupted Fuel payload
    /// degrades to defaults without discarding the rest of the state, and
    /// never rolls back to a stale v6 snapshot.
    private static func decodeV7(defaults: UserDefaults) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: storageKey) else {
            return (AttentionProfile(), [], .fresh, nil, nil, .empty, .empty)
        }
        let base = decodeCore(raw: raw)
        let fuelState = (raw["fuel"] as? Data).flatMap {
            try? JSONDecoder().decode(FuelState.self, from: $0)
        } ?? .empty
        return (base.profile, base.sessions, base.programState, base.preparation, base.active, base.labState, fuelState)
    }

    private static func decodeV6(defaults: UserDefaults, key: String = "reboot.product.v6") -> StoredState? {
        guard let raw = defaults.dictionary(forKey: key) else {
            return (AttentionProfile(), [], .fresh, nil, nil, .empty, .empty)
        }
        let base = decodeCore(raw: raw)
        return (base.profile, base.sessions, base.programState, base.preparation, base.active, base.labState, .empty)
    }

    /// Shared v6/v7 body: profile, sessions, program, rules, observations,
    /// preparation, active session, lab state. Fuel is handled per-version.
    private static func decodeCore(raw: [String: Any]) -> (
        profile: AttentionProfile,
        sessions: [SessionRecord],
        programState: ProgramState,
        preparation: EnvironmentPreparation?,
        active: SessionRecord?,
        labState: PersonalLabState
    ) {
        let profileData = raw["profile"] as? Data
        let sessionsData = raw["sessions"] as? Data
        let programData = raw["programState"] as? Data

        var profile = profileData.flatMap { try? JSONDecoder().decode(AttentionProfile.self, from: $0) }
            ?? AttentionProfile()
        let sessions = sessionsData.flatMap { data -> [SessionRecord]? in
            if let all = try? JSONDecoder().decode([SessionRecord].self, from: data) { return all }
            // One malformed record must never discard the rest of the history.
            guard let elements = try? JSONDecoder().decode([FailableSessionRecord].self, from: data) else { return nil }
            return elements.compactMap(\.value)
        } ?? []
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
        let labState = (raw["personalLab"] as? Data).flatMap {
            try? JSONDecoder().decode(PersonalLabState.self, from: $0)
        } ?? .empty
        return (profile, sessions, programState, preparation, active, labState)
    }

    private static func decodeV5(defaults: UserDefaults) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: v5StorageKey) else {
            return (AttentionProfile(), [], .fresh, nil, nil, .empty, .empty)
        }
        let base = decodePreLab(raw: raw)
        return (base.profile, base.sessions, base.programState, base.preparation, base.active, base.labState, .empty)
    }

    private static func decodeV4(from key: String, defaults: UserDefaults) -> StoredState? {
        guard let raw = defaults.dictionary(forKey: key) else {
            return (AttentionProfile(), [], .fresh, nil, nil, .empty, .empty)
        }
        let base = decodePreLab(raw: raw)
        return (base.profile, base.sessions, base.programState, base.preparation, base.active, base.labState, .empty)
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
            active,
            .empty,
            .empty
        )
    }

    private static func decodePreLab(raw: [String: Any]) -> (
        profile: AttentionProfile,
        sessions: [SessionRecord],
        programState: ProgramState,
        preparation: EnvironmentPreparation?,
        active: SessionRecord?,
        labState: PersonalLabState
    ) {
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
        if let observationsData = raw["observations"] as? Data,
           let decoded = try? JSONDecoder().decode([EvidenceObservation].self, from: observationsData),
           profile.observations.isEmpty {
            profile.observations = decoded
        }
        let preparation = (raw["preparation"] as? Data).flatMap {
            try? JSONDecoder().decode(EnvironmentPreparation?.self, from: $0)
        } ?? nil
        let active = (raw["activeSession"] as? Data).flatMap {
            try? JSONDecoder().decode(SessionRecord?.self, from: $0)
        } ?? nil
        return (profile, sessions, programState, preparation, active, .empty)
    }

    private func timing(forElapsedSeconds elapsed: Int) -> FirstSwitchTiming {
        if elapsed < 5 * 60 { return .underFive }
        if elapsed < 10 * 60 { return .fiveToTen }
        if elapsed < 20 * 60 { return .tenToTwenty }
        return .twentyPlus
    }
}

/// Per-element recovery wrapper: a single undecodable session degrades to nil
/// instead of failing the whole array.
private struct FailableSessionRecord: Codable {
    let value: SessionRecord?

    init(from decoder: Decoder) throws {
        value = try? SessionRecord(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value { try container.encode(value) }
    }
}
