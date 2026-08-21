import Foundation

enum ProgramStatus: String, Codable, Equatable {
    case active
    case completed
}

enum ProgramPhaseID: String, Codable, CaseIterable, Identifiable, Hashable {
    case calibrate
    case controlInput
    case buildStability
    case deepen
    case findConditions
    case ownSystem

    var id: String { rawValue }
}

enum ProgramSkillPriority: String, Codable, Equatable, Hashable {
    case notice
    case stay
    case returnToTask
    case reduceInput
    case recall
    case explain
    case tolerateStillness
    case depth
    case conditions
    case independentSetup

    var title: String {
        switch self {
        case .notice: return "Notice"
        case .stay: return "Stay"
        case .returnToTask: return "Return"
        case .reduceInput: return "Reduce unnecessary input"
        case .recall: return "Recall"
        case .explain: return "Explain"
        case .tolerateStillness: return "Tolerate less stimulus"
        case .depth: return "Process more deeply"
        case .conditions: return "Notice useful conditions"
        case .independentSetup: return "Set up independently"
        }
    }
}

enum ProgramEnvironmentIntensity: Int, Codable, Equatable {
    case natural = 0
    case minimal = 1
    case intentional = 2
    case evidenceLed = 3
    case independent = 4
}

struct ProgramDurationRange: Codable, Equatable {
    var lower: Int
    var upper: Int
}

struct ProgramDurationGuidance: Codable, Equatable {
    var stay: ProgramDurationRange
    var recall: ProgramDurationRange
    var explain: ProgramDurationRange
    var nothing: ProgramDurationRange
    var observe: ProgramDurationRange

    func range(for mode: TrainingMode) -> ProgramDurationRange {
        switch mode {
        case .stay: return stay
        case .recall: return recall
        case .explain: return explain
        case .nothing: return nothing
        case .observe: return observe
        }
    }
}

struct ProgramPhase: Codable, Equatable, Identifiable {
    var id: ProgramPhaseID
    var number: Int
    var days: ClosedRange<Int>
    var title: String
    var description: String
    var priorities: [ProgramSkillPriority]
    var allowedModes: [TrainingMode]
    var preferredModes: [TrainingMode]
    var environmentIntensity: ProgramEnvironmentIntensity
    var durationGuidance: ProgramDurationGuidance
    var adaptationConstraints: [ProgramAdaptationConstraint]
    var completionObjective: String

    static let all: [ProgramPhase] = [
        ProgramPhase(
            id: .calibrate,
            number: 1,
            days: 1...7,
            title: "Learn your attention.",
            description: "Notice what changes direction, how long attention stays, and what makes returning easier.",
            priorities: [.notice, .stay, .returnToTask],
            allowedModes: [.observe, .stay, .recall],
            preferredModes: [.observe, .stay, .recall],
            environmentIntensity: .minimal,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 20),
                recall: .init(lower: 5, upper: 15),
                explain: .init(lower: 5, upper: 15),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 15)
            ),
            adaptationConstraints: [.naturalBaseline, .noAggressiveProtection, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Establish an honest baseline before changing too much."
        ),
        ProgramPhase(
            id: .controlInput,
            number: 2,
            days: 8...21,
            title: "Make space.",
            description: "Reduce unnecessary switching and test the lightest useful friction around attention.",
            priorities: [.reduceInput, .returnToTask, .tolerateStillness],
            allowedModes: [.stay, .observe, .nothing, .recall],
            preferredModes: [.stay, .observe, .nothing, .recall],
            environmentIntensity: .intentional,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 25),
                recall: .init(lower: 5, upper: 20),
                explain: .init(lower: 5, upper: 20),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 15)
            ),
            adaptationConstraints: [.evidenceLedEnvironment, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Find low-friction ways to create room for intentional work."
        ),
        ProgramPhase(
            id: .buildStability,
            number: 3,
            days: 22...40,
            title: "Stay longer.",
            description: "Build task continuity and a more reliable return after attention moves.",
            priorities: [.stay, .returnToTask, .recall],
            allowedModes: [.stay, .recall, .explain, .observe, .nothing],
            preferredModes: [.stay, .recall, .explain, .observe],
            environmentIntensity: .evidenceLed,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 35),
                recall: .init(lower: 5, upper: 25),
                explain: .init(lower: 5, upper: 25),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 15)
            ),
            adaptationConstraints: [.evidenceLedEnvironment, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Sustain meaningful work without treating every switch as failure."
        ),
        ProgramPhase(
            id: .deepen,
            number: 4,
            days: 41...60,
            title: "Go deeper.",
            description: "Move from merely staying to remembering, understanding, and explaining real material.",
            priorities: [.recall, .explain, .depth],
            allowedModes: [.recall, .explain, .stay, .nothing],
            preferredModes: [.recall, .explain, .stay],
            environmentIntensity: .evidenceLed,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 40),
                recall: .init(lower: 5, upper: 30),
                explain: .init(lower: 5, upper: 30),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 15)
            ),
            adaptationConstraints: [.evidenceLedEnvironment, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Use attention to process meaningful work more deeply."
        ),
        ProgramPhase(
            id: .findConditions,
            number: 5,
            days: 61...75,
            title: "Find your conditions.",
            description: "Observe which tasks, environments, and time windows are associated with deeper absorption.",
            priorities: [.conditions, .stay, .notice],
            allowedModes: [.stay, .observe, .recall, .explain, .nothing],
            preferredModes: [.stay, .observe],
            environmentIntensity: .evidenceLed,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 45),
                recall: .init(lower: 5, upper: 30),
                explain: .init(lower: 5, upper: 30),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 20)
            ),
            adaptationConstraints: [.evidenceLedEnvironment, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Identify useful conditions without promising or scoring flow."
        ),
        ProgramPhase(
            id: .ownSystem,
            number: 6,
            days: 76...90,
            title: "Make it yours.",
            description: "Apply what works with less direction and consolidate the areas that still need attention.",
            priorities: [.independentSetup, .stay, .depth],
            allowedModes: TrainingMode.allCases,
            preferredModes: [.stay, .recall, .explain, .observe],
            environmentIntensity: .independent,
            durationGuidance: .init(
                stay: .init(lower: 5, upper: 45),
                recall: .init(lower: 5, upper: 30),
                explain: .init(lower: 5, upper: 30),
                nothing: .init(lower: 3, upper: 10),
                observe: .init(lower: 5, upper: 20)
            ),
            adaptationConstraints: [.independentChoice, .evidenceLedEnvironment, .boundedDuration, .avoidModeMonotony, .recoveryAllowed],
            completionObjective: "Leave with a system the user can apply without depending on REBOOT."
        ),
    ]

    static func phase(for day: Int) -> ProgramPhase {
        let bounded = min(90, max(1, day))
        return all.first { $0.days.contains(bounded) } ?? all[0]
    }
}

enum ProgramObjective: String, Codable, Equatable, Hashable {
    case establishBaseline
    case observeSwitches
    case practiceReturn
    case reduceUnnecessaryInput
    case tolerateLessStimulus
    case buildTaskContinuity
    case strengthenRecall
    case explainUnderstanding
    case observeFlowConditions
    case testDeepWorkCondition
    case protectDeepBlock
    case chooseIndependentSetup
    case testRemainingWeakness
    case finalSynthesis
}

enum ProgramAdaptationConstraint: String, Codable, Equatable, Hashable {
    case naturalBaseline
    case noAggressiveProtection
    case evidenceLedEnvironment
    case boundedDuration
    case avoidModeMonotony
    case recoveryAllowed
    case independentChoice
}

enum CurriculumIntentKind: String, Codable, Equatable, Hashable {
    case naturalBaseline
    case observePattern
    case practiceReturn
    case controlInput
    case tolerateLessStimulus
    case buildContinuity
    case deepenUnderstanding
    case observeFlowCondition
    case testDeepWorkCondition
    case protectDeepBlock
    case independentSetup
    case testRemainingWeakness
    case finalSynthesis

    var resolvedModes: [TrainingMode] {
        switch self {
        case .naturalBaseline, .observePattern: return [.observe]
        case .practiceReturn, .buildContinuity, .protectDeepBlock: return [.stay, .observe]
        case .controlInput: return [.stay, .observe, .nothing]
        case .tolerateLessStimulus: return [.nothing, .stay]
        case .deepenUnderstanding: return [.recall, .explain, .stay]
        case .observeFlowCondition: return [.observe, .stay]
        case .testDeepWorkCondition: return [.stay, .observe]
        case .independentSetup, .testRemainingWeakness, .finalSynthesis: return TrainingMode.allCases
        }
    }
}

struct CurriculumIntent: Codable, Equatable {
    var kind: CurriculumIntentKind
    var objectives: [ProgramObjective]
    var constraints: [ProgramAdaptationConstraint]
    var preferredModes: [TrainingMode]
    var editorialReason: String
    var observationMission: String?
}

enum ProgramMilestone: String, Codable, Equatable {
    case baseline
    case weeklyCheckpoint
    case phaseBoundary
    case finalSynthesis
}

struct ProgramCheckpoint: Codable, Equatable, Identifiable {
    var programDay: Int
    var id: Int { programDay }
}

struct ProgramDayDefinition: Codable, Equatable {
    var day: Int
    var phase: ProgramPhase
    var intent: CurriculumIntent
    var milestone: ProgramMilestone?
    var checkpoint: ProgramCheckpoint?
}

enum ProgramCheckpointSchedule {
    static let weeklyDays = Array(stride(from: 7, through: 84, by: 7))

    static func isWeeklyCheckpoint(_ completedDay: Int) -> Bool {
        weeklyDays.contains(completedDay)
    }

    static func nextCheckpointDay(after completedDays: Int) -> Int? {
        weeklyDays.first { $0 > completedDays }
    }

    static func sessionsUntilNextCheckpoint(after completedDays: Int) -> Int? {
        nextCheckpointDay(after: completedDays).map { $0 - completedDays }
    }
}

struct WeeklyReviewAnswers: Codable, Equatable {
    var helpedMost: String?
    var stillBreaksAttention: String?
    var nextTestPreference: String?

    static let empty = WeeklyReviewAnswers()
}

struct WeeklyReviewRecord: Codable, Equatable, Identifiable {
    var id = UUID()
    var programDay: Int
    var date: Date
    var shownInsights: [String]
    var answers: WeeklyReviewAnswers
    var createdAt = Date()
}

enum ProgramProgressionOutcome: Equatable {
    case ignored
    case advanced(to: Int)
    case checkpoint(day: Int, nextDay: Int)
    case completed
}

struct ProgramState: Codable, Equatable {
    var currentDay: Int
    var status: ProgramStatus
    var reviews: [WeeklyReviewRecord]
    var acknowledgedPhaseTransitions: Set<ProgramPhaseID>
    var pendingReviewDay: Int?
    var pendingPhaseTransition: ProgramPhaseID?
    var pendingCompletion: Bool
    var processedProtocolSessionIDs: Set<UUID>

    var hasPendingRequiredFlow: Bool {
        pendingReviewDay != nil || pendingPhaseTransition != nil || pendingCompletion
    }

    static var fresh: ProgramState {
        ProgramState(
            currentDay: 1,
            status: .active,
            reviews: [],
            acknowledgedPhaseTransitions: [.calibrate],
            pendingReviewDay: nil,
            pendingPhaseTransition: nil,
            pendingCompletion: false,
            processedProtocolSessionIDs: []
        )
    }

    static func migrated(day: Int, sessions: [SessionRecord]) -> ProgramState {
        let boundedDay = min(90, max(1, day))
        let completed = sessions.filter {
            $0.origin == .protocol && $0.completed && (1...90).contains($0.day)
        }
        let day90Complete = completed.contains { $0.day == 90 }
        let currentPhase = ProgramPhase.phase(for: boundedDay)
        let seen = Set(ProgramPhase.all.filter { $0.number <= currentPhase.number }.map(\.id))
        return ProgramState(
            currentDay: boundedDay,
            status: day90Complete ? .completed : .active,
            reviews: [],
            acknowledgedPhaseTransitions: seen,
            pendingReviewDay: nil,
            pendingPhaseTransition: nil,
            pendingCompletion: false,
            processedProtocolSessionIDs: Set(completed.map(\.id))
        )
    }

    mutating func registerCompletedProtocolSession(id: UUID, day completedDay: Int) -> ProgramProgressionOutcome {
        guard status == .active,
              !hasPendingRequiredFlow,
              (1...90).contains(completedDay),
              completedDay == currentDay,
              !processedProtocolSessionIDs.contains(id) else {
            return .ignored
        }
        processedProtocolSessionIDs.insert(id)

        if completedDay == 90 {
            status = .completed
            currentDay = 90
            pendingCompletion = true
            return .completed
        }

        let oldPhase = ProgramPhase.phase(for: completedDay).id
        currentDay = completedDay + 1
        let nextPhase = ProgramPhase.phase(for: currentDay).id
        if nextPhase != oldPhase, !acknowledgedPhaseTransitions.contains(nextPhase) {
            pendingPhaseTransition = nextPhase
        }
        if ProgramCheckpointSchedule.isWeeklyCheckpoint(completedDay),
           !reviews.contains(where: { $0.programDay == completedDay }) {
            pendingReviewDay = completedDay
            return .checkpoint(day: completedDay, nextDay: currentDay)
        }
        return .advanced(to: currentDay)
    }

    mutating func recordReview(_ review: WeeklyReviewRecord) {
        if !reviews.contains(where: { $0.programDay == review.programDay }) {
            reviews.append(review)
            reviews.sort { $0.programDay < $1.programDay }
        }
        if pendingReviewDay == review.programDay {
            pendingReviewDay = nil
        }
    }

    mutating func acknowledgePhaseTransition(_ phase: ProgramPhaseID) {
        acknowledgedPhaseTransitions.insert(phase)
        if pendingPhaseTransition == phase { pendingPhaseTransition = nil }
    }

    mutating func acknowledgeCompletion() {
        pendingCompletion = false
    }
}

enum CurriculumEngine {
    static func definition(
        for day: Int,
        profile: AttentionProfile,
        protocolHistory: [SessionRecord],
        reviews: [WeeklyReviewRecord] = []
    ) -> ProgramDayDefinition {
        let boundedDay = min(90, max(1, day))
        let phase = ProgramPhase.phase(for: boundedDay)
        let intent = intent(
            for: boundedDay,
            phase: phase,
            profile: profile,
            protocolHistory: protocolHistory,
            reviews: reviews
        )
        let checkpoint = ProgramCheckpointSchedule.isWeeklyCheckpoint(boundedDay)
            ? ProgramCheckpoint(programDay: boundedDay)
            : nil
        let milestone: ProgramMilestone?
        if boundedDay == 1 {
            milestone = .baseline
        } else if boundedDay == 90 {
            milestone = .finalSynthesis
        } else if checkpoint != nil {
            milestone = .weeklyCheckpoint
        } else if phase.days.lowerBound == boundedDay {
            milestone = .phaseBoundary
        } else {
            milestone = nil
        }
        return ProgramDayDefinition(
            day: boundedDay,
            phase: phase,
            intent: intent,
            milestone: milestone,
            checkpoint: checkpoint
        )
    }

    static func intent(
        for day: Int,
        phase: ProgramPhase,
        profile: AttentionProfile,
        protocolHistory: [SessionRecord],
        reviews: [WeeklyReviewRecord]
    ) -> CurriculumIntent {
        if day == 1 {
            return CurriculumIntent(
                kind: .naturalBaseline,
                objectives: [.establishBaseline, .observeSwitches],
                constraints: [.naturalBaseline, .noAggressiveProtection, .boundedDuration],
                preferredModes: [.observe],
                editorialReason: "The program starts by observing before changing anything.",
                observationMission: "Work normally. Notice what changes the direction of your attention."
            )
        }
        if day == 90 {
            return CurriculumIntent(
                kind: .finalSynthesis,
                objectives: [.finalSynthesis, .chooseIndependentSetup],
                constraints: [.independentChoice, .boundedDuration, .avoidModeMonotony],
                preferredModes: phase.preferredModes,
                editorialReason: "The final protocol day brings the user's strongest useful practices together.",
                observationMission: nil
            )
        }

        let kind: CurriculumIntentKind
        switch phase.id {
        case .calibrate:
            kind = day == 2 || day == 5 ? .observePattern : .practiceReturn
        case .controlInput:
            kind = day.isMultiple(of: 5) ? .tolerateLessStimulus : .controlInput
        case .buildStability:
            kind = .buildContinuity
        case .deepen:
            kind = .deepenUnderstanding
        case .findConditions:
            kind = day.isMultiple(of: 2) ? .testDeepWorkCondition : .observeFlowCondition
        case .ownSystem:
            kind = day.isMultiple(of: 4) ? .testRemainingWeakness : .independentSetup
        }

        let objectives: [ProgramObjective]
        switch kind {
        case .observePattern: objectives = [.observeSwitches]
        case .practiceReturn: objectives = [.practiceReturn]
        case .controlInput: objectives = [.reduceUnnecessaryInput, .practiceReturn]
        case .tolerateLessStimulus: objectives = [.tolerateLessStimulus]
        case .buildContinuity: objectives = [.buildTaskContinuity, .practiceReturn]
        case .deepenUnderstanding: objectives = [.strengthenRecall, .explainUnderstanding]
        case .observeFlowCondition: objectives = [.observeFlowConditions]
        case .testDeepWorkCondition: objectives = [.testDeepWorkCondition, .buildTaskContinuity]
        case .protectDeepBlock: objectives = [.testDeepWorkCondition]
        case .independentSetup: objectives = [.chooseIndependentSetup]
        case .testRemainingWeakness: objectives = [.testRemainingWeakness]
        case .naturalBaseline: objectives = [.establishBaseline]
        case .finalSynthesis: objectives = [.finalSynthesis]
        }

        let allowedPreferred = kind.resolvedModes.filter { phase.allowedModes.contains($0) }
        let preferred = allowedPreferred.isEmpty ? phase.preferredModes : allowedPreferred
        return CurriculumIntent(
            kind: kind,
            objectives: objectives,
            constraints: phase.adaptationConstraints,
            preferredModes: preferred,
            editorialReason: phase.completionObjective,
            observationMission: observationMission(for: kind)
        )
    }

    private static func observationMission(for kind: CurriculumIntentKind) -> String? {
        switch kind {
        case .observePattern: return "Notice what happens just before attention changes direction."
        case .observeFlowCondition: return "Notice which part of the setup helps absorption begin."
        case .testDeepWorkCondition: return "Notice whether this setup makes staying feel more natural."
        case .independentSetup: return "Choose your setup, then notice which choice mattered."
        default: return nil
        }
    }
}

enum ProgramInsightConfidence: String, Codable, Equatable {
    case earlySignal
    case repeated
}

struct ProgramInsight: Codable, Equatable, Identifiable {
    var id: String
    var text: String
    var confidence: ProgramInsightConfidence
}

enum ProgramInsightEngine {
    static func insights(from sessions: [SessionRecord]) -> [ProgramInsight] {
        let protocolSessions = sessions.filter { $0.origin == .protocol }
        var result: [ProgramInsight] = []

        let earlySwitches = protocolSessions.filter {
            $0.firstSwitchTiming == .underFive || ($0.firstSwitchMinute.map { $0 < 5 } == true)
        }
        if earlySwitches.count >= 2 {
            result.append(ProgramInsight(
                id: "early-switch",
                text: "Your first reported switches often happen near the start.",
                confidence: earlySwitches.count >= 4 ? .repeated : .earlySignal
            ))
        }

        let completed = protocolSessions.filter(\.completed)
        if completed.count >= 6 {
            let first = completed.prefix(3).map(\.actualMinutes)
            let last = completed.suffix(3).map(\.actualMinutes)
            let firstAverage = first.reduce(0, +) / first.count
            let lastAverage = last.reduce(0, +) / last.count
            if lastAverage >= firstAverage + 3 {
                result.append(ProgramInsight(
                    id: "duration-trend",
                    text: "Recent completed blocks have lasted a little longer.",
                    confidence: .repeated
                ))
            }
        }

        let recallAssessments = completed.compactMap { $0.evidence?.recall?.selfAssessment }
        if recallAssessments.count >= 2 {
            let positive = recallAssessments.filter { $0 == .some || $0 == .most }.count
            if positive >= 2 {
                result.append(ProgramInsight(
                    id: "recall-signal",
                    text: "More than one recall session brought at least some material back.",
                    confidence: recallAssessments.count >= 4 ? .repeated : .earlySignal
                ))
            }
        }

        let protected = completed.filter { $0.environment?.protectionActivated == true }
        let unprotected = completed.filter { $0.environment?.protectionActivated != true }
        if protected.count >= 2, unprotected.count >= 2,
           let protectedSwitches = averageSwitches(protected),
           let unprotectedSwitches = averageSwitches(unprotected),
           protectedSwitches + 1 <= unprotectedSwitches {
            result.append(ProgramInsight(
                id: "protection-signal",
                text: "Early signal: protected sessions have involved fewer reported switches.",
                confidence: .earlySignal
            ))
        }

        return Array(result.prefix(2))
    }

    private static func averageSwitches(_ sessions: [SessionRecord]) -> Double? {
        let values = sessions.compactMap(\.switches)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

enum AdaptiveDurationReason: String, Codable, Equatable {
    case baseline
    case diagnosedWindow
    case repeatedComfort
    case repeatedDifficulty
    case lowEnergy
    case heldForEvidence
}

struct AdaptiveDurationRecommendation: Codable, Equatable {
    var minutes: Int
    var reason: AdaptiveDurationReason
}

enum AdaptiveDurationEngine {
    static func recommendation(
        mode: TrainingMode,
        profile: AttentionProfile,
        protocolHistory: [SessionRecord],
        phase: ProgramPhase
    ) -> AdaptiveDurationRecommendation {
        if phase.id == .calibrate, protocolHistory.isEmpty, mode == .observe {
            return AdaptiveDurationRecommendation(minutes: 15, reason: .baseline)
        }

        let range = phase.durationGuidance.range(for: mode)
        let comparable = protocolHistory.filter { $0.origin == .protocol && $0.mode == mode }
        let reference = comparable.last?.targetMinutes ?? profile.focusWindowMinutes ?? defaultMinutes(for: mode)
        let recent = Array(comparable.suffix(3))
        let hard = recent.suffix(2).filter {
            $0.endedEarly || ($0.difficulty ?? 0) >= 4 || (mode == .stay && ($0.switches ?? 0) >= 7)
        }
        let lowEnergy = recent.suffix(2).filter { ($0.energy ?? 5) <= 2 }
        let comfortable = recent.suffix(2).filter {
            $0.completed
                && !$0.endedEarly
                && ($0.difficulty ?? 3) <= 2
                && $0.actualMinutes >= $0.targetMinutes
                && (mode != .stay || ($0.switches ?? 0) <= 3)
        }

        let proposed: Int
        let reason: AdaptiveDurationReason
        if hard.count >= 2 {
            proposed = reference - 5
            reason = .repeatedDifficulty
        } else if lowEnergy.count >= 2 {
            proposed = reference - 5
            reason = .lowEnergy
        } else if comfortable.count >= 2 {
            proposed = reference + 5
            reason = .repeatedComfort
        } else {
            proposed = reference
            reason = comparable.isEmpty ? .diagnosedWindow : .heldForEvidence
        }

        let bounded = min(range.upper, max(range.lower, proposed))
        let stepped = min(reference + 5, max(reference - 5, bounded))
        return AdaptiveDurationRecommendation(minutes: min(range.upper, max(range.lower, stepped)), reason: reason)
    }

    static func minutes(
        mode: TrainingMode,
        profile: AttentionProfile,
        protocolHistory: [SessionRecord],
        phase: ProgramPhase
    ) -> Int {
        recommendation(
            mode: mode,
            profile: profile,
            protocolHistory: protocolHistory,
            phase: phase
        ).minutes
    }

    private static func defaultMinutes(for mode: TrainingMode) -> Int {
        switch mode {
        case .stay: return 15
        case .recall, .explain: return 10
        case .nothing: return 5
        case .observe: return 10
        }
    }
}
