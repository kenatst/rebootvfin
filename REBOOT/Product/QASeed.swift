import Foundation

/// Seeded product state for QA and debug navigation.
/// Every field is optional; only provided data is applied.
struct QASeed: Codable {
    var profile: AttentionProfile?
    var sessions: [SessionRecord]?
    var day: Int?
    var phase: String?
    var record: SessionRecord?
    var programState: ProgramState? = nil
    var labState: PersonalLabState? = nil
}

enum QASeeds {
    static let day1 = QASeed(profile: nil, sessions: [], day: 1, phase: nil, record: nil)

    static let stay = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("focus_better", source: .selfReport),
            goals: .known(["focus_better", "deep_work"], source: .selfReport),
            distractors: .known([Distractor.phone, Distractor.social], source: .selfReport),
            reflex: .known(.high, source: .selfReport),
            attentionStability: .known(.low, source: .selfReport),
            returnAfterDistraction: .unknown,
            recall: .unknown,
            depth: .known(.fair, source: .session),
            environment: .known("A desk at home", source: .selfReport),
            flowConditions: .known(["Building or coding"], source: .selfReport),
            energyContext: .unknown,
            focusWindowMinutes: 20
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 6), mode: .observe, targetMinutes: 15, actualMinutes: 14, completed: true, endedEarly: false, firstDistraction: "social", switches: 5, difficulty: 4, energy: nil, environmentActionDone: nil, firstSwitchMinute: 3),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 4), mode: .stay, targetMinutes: 20, actualMinutes: 12, completed: true, endedEarly: true, firstDistraction: "notifications", switches: 6, difficulty: 5, energy: nil, environmentActionDone: nil, firstSwitchMinute: 2),
            SessionRecord(day: 3, date: Date().addingTimeInterval(-86400 * 2), mode: .stay, targetMinutes: 20, actualMinutes: 19, completed: true, endedEarly: false, firstDistraction: "social", switches: 3, difficulty: 3, energy: 3, environmentActionDone: true, firstSwitchMinute: 4),
        ],
        day: 4,
        phase: nil,
        record: nil
    )

    static let recall = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("read_more", source: .selfReport),
            goals: .known(["read_more", "remember_more"], source: .selfReport),
            distractors: .known([Distractor.tabs], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .selfReport),
            returnAfterDistraction: .known(.fair, source: .session),
            recall: .known(.weak, source: .selfReport),
            depth: .known(.fair, source: .session),
            environment: .known("A library", source: .selfReport),
            flowConditions: .known(["Writing"], source: .selfReport),
            energyContext: .known("Early morning", source: .selfReport),
            focusWindowMinutes: 30
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 6), mode: .observe, targetMinutes: 15, actualMinutes: 16, completed: true, endedEarly: false, firstDistraction: "tabs", switches: 2, difficulty: 2, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 5), mode: .recall, targetMinutes: 30, actualMinutes: 27, completed: true, endedEarly: false, firstDistraction: "none", switches: 1, difficulty: 3, energy: 4, environmentActionDone: true, firstSwitchMinute: nil),
            SessionRecord(day: 3, date: Date().addingTimeInterval(-86400 * 3), mode: .recall, targetMinutes: 30, actualMinutes: 30, completed: true, endedEarly: false, firstDistraction: "none", switches: 1, difficulty: 2, energy: 4, environmentActionDone: true, firstSwitchMinute: nil),
            SessionRecord(day: 4, date: Date().addingTimeInterval(-86400 * 1), mode: .stay, targetMinutes: 30, actualMinutes: 25, completed: true, endedEarly: false, firstDistraction: "tabs", switches: 2, difficulty: 2, energy: 3, environmentActionDone: nil, firstSwitchMinute: 6),
        ],
        day: 5,
        phase: nil,
        record: nil
    )

    static let rest = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("deep_work", source: .selfReport),
            goals: .known(["deep_work"], source: .selfReport),
            distractors: .known([Distractor.internalRestlessness], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .session),
            returnAfterDistraction: .known(.weak, source: .session),
            recall: .unknown,
            depth: .known(.shallow, source: .session),
            environment: .known("An open office", source: .selfReport),
            flowConditions: .unknown,
            energyContext: .unknown,
            focusWindowMinutes: 15
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 3), mode: .observe, targetMinutes: 15, actualMinutes: 15, completed: true, endedEarly: false, firstDistraction: "people", switches: 3, difficulty: 3, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 1), mode: .stay, targetMinutes: 15, actualMinutes: 6, completed: true, endedEarly: true, firstDistraction: "internal", switches: 8, difficulty: 5, energy: 1, environmentActionDone: nil, firstSwitchMinute: 1),
        ],
        day: 3,
        phase: nil,
        record: nil
    )

    static let running = QASeed(
        profile: nil,
        sessions: [],
        day: 1,
        phase: "running",
        record: SessionRecord(day: 1, date: Date().addingTimeInterval(-600), mode: .observe, targetMinutes: 15, actualMinutes: 0, completed: false, endedEarly: false, firstDistraction: nil, switches: nil, difficulty: nil, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil)
    )

    static let done = QASeed(
        profile: nil,
        sessions: [],
        day: 1,
        phase: "done",
        record: SessionRecord(day: 1, date: Date().addingTimeInterval(-900), mode: .observe, targetMinutes: 15, actualMinutes: 14, completed: true, endedEarly: false, firstDistraction: nil, switches: nil, difficulty: nil, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil)
    )

#if DEBUG
    static var programDay1: QASeed {
        QASeed(
            profile: focusProfile,
            sessions: [],
            day: 1,
            phase: nil,
            record: nil,
            programState: .fresh
        )
    }

    /// Seven protocol days are complete. The weekly review is shown before the
    /// already-earned transition into Phase 2.
    static var programDay7Checkpoint: QASeed {
        let sessions = programHistory(through: 7, profile: focusProfile, track: .focus)
        let state = programState(
            currentDay: 8,
            sessions: sessions,
            reviews: [],
            pendingReviewDay: 7,
            pendingPhaseTransition: .controlInput
        )
        return QASeed(
            profile: focusProfile,
            sessions: sessions,
            day: state.currentDay,
            phase: nil,
            record: nil,
            programState: state
        )
    }

    /// The Day 7 review has been recorded, so the next routed surface is the
    /// one-time transition into Phase 2 and its first prescription, Day 8.
    static var programDay8Transition: QASeed {
        let sessions = programHistory(through: 7, profile: focusProfile, track: .focus)
        let reviews = completedReviews(for: sessions, track: .focus, through: 7)
        let state = programState(
            currentDay: 8,
            sessions: sessions,
            reviews: reviews,
            pendingPhaseTransition: .controlInput
        )
        return QASeed(
            profile: focusProfile,
            sessions: sessions,
            day: state.currentDay,
            phase: nil,
            record: nil,
            programState: state
        )
    }

    static var programDay26Study: QASeed {
        activeProgramSeed(day: 26, profile: studyProfile, track: .study)
    }

    static var programDay26ScrollControl: QASeed {
        activeProgramSeed(day: 26, profile: scrollControlProfile, track: .scrollControl)
    }

    static var programDay45Memory: QASeed {
        activeProgramSeed(day: 45, profile: memoryProfile, track: .memory)
    }

    static var programDay65FlowConditions: QASeed {
        activeProgramSeed(day: 65, profile: flowProfile, track: .flow)
    }

    static var programDay82Mature: QASeed {
        activeProgramSeed(day: 82, profile: matureProfile, track: .mature)
    }

    static var programDay90BeforeCompletion: QASeed {
        activeProgramSeed(day: 90, profile: matureProfile, track: .mature)
    }

    static var programCompleted: QASeed {
        let sessions = programHistory(through: 90, profile: matureProfile, track: .mature)
        let reviews = completedReviews(for: sessions, track: .mature, through: 90)
        let state = programState(
            currentDay: 90,
            status: .completed,
            sessions: sessions,
            reviews: reviews
        )
        return QASeed(
            profile: matureProfile,
            sessions: sessions,
            day: state.currentDay,
            phase: nil,
            record: nil,
            programState: state
        )
    }

    private enum FixtureTrack: Int {
        case focus = 1
        case study = 2
        case scrollControl = 3
        case memory = 4
        case flow = 5
        case mature = 6

        var preferredModes: [TrainingMode] {
            switch self {
            case .focus: return [.stay, .observe, .recall]
            case .study: return [.recall, .explain, .stay, .recall, .observe]
            case .scrollControl: return [.stay, .observe, .stay, .nothing, .recall]
            case .memory: return [.recall, .explain, .recall, .stay, .observe]
            case .flow: return [.stay, .observe, .stay, .recall, .explain]
            case .mature: return [.stay, .recall, .explain, .observe, .nothing]
            }
        }

        var task: String {
            switch self {
            case .focus: return "One meaningful work task"
            case .study: return "Study one section of course material"
            case .scrollControl: return "Finish one task without opening a feed"
            case .memory: return "Reconstruct one idea from memory"
            case .flow: return "Continue one absorbing creative task"
            case .mature: return "Choose and complete the day's most useful block"
            }
        }

        var source: String {
            switch self {
            case .study: return "Course notes"
            case .memory: return "A chapter worth remembering"
            case .mature: return "Current project material"
            default: return "Current working material"
            }
        }

        var reviewPreference: String {
            switch self {
            case .study: return "Test recall with real study material"
            case .scrollControl: return "Test one lighter phone boundary"
            case .memory: return "Keep testing recall and explanation"
            case .flow: return "Compare the conditions that help absorption begin"
            case .mature: return "Choose the setup independently"
            case .focus: return "Practice returning without restarting"
            }
        }
    }

    private static let fixtureReferenceDate = Date(timeIntervalSince1970: 1_787_295_600)

    private static var focusProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("focus_better", source: .selfReport),
            goals: .known(["focus_better", "deep_work"], source: .selfReport),
            distractors: .known([Distractor.notifications, Distractor.tabs], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .selfReport),
            returnAfterDistraction: .known(.fair, source: .session),
            recall: .unknown,
            depth: .known(.fair, source: .session),
            environment: .known("A desk near a window", source: .selfReport),
            flowConditions: .unknown,
            energyContext: .known("Morning", source: .selfReport),
            focusWindowMinutes: 20
        )
    }

    private static var studyProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("study_better", source: .selfReport),
            goals: .known(["study_better", "remember_more"], source: .selfReport),
            distractors: .known([Distractor.tabs, Distractor.notifications], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .session),
            returnAfterDistraction: .known(.fair, source: .session),
            recall: .known(.weak, source: .selfReport),
            depth: .known(.fair, source: .session),
            environment: .known("A quiet library table", source: .selfReport),
            flowConditions: .known(["A clear chapter goal"], source: .selfReport),
            energyContext: .known("Early afternoon", source: .selfReport),
            focusWindowMinutes: 25
        )
    }

    private static var scrollControlProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("scroll_less", source: .selfReport),
            goals: .known(["scroll_less", "phone_less", "focus_better"], source: .selfReport),
            distractors: .known([Distractor.phone, Distractor.social], source: .selfReport),
            reflex: .known(.high, source: .selfReport),
            attentionStability: .known(.low, source: .selfReport),
            returnAfterDistraction: .known(.fair, source: .session),
            recall: .unknown,
            depth: .known(.fair, source: .session),
            environment: .known("A shared desk with the phone nearby", source: .selfReport),
            flowConditions: .unknown,
            energyContext: .known("Late afternoon", source: .selfReport),
            focusWindowMinutes: 15
        )
    }

    private static var memoryProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("remember_more", source: .selfReport),
            goals: .known(["remember_more", "read_more"], source: .selfReport),
            distractors: .known([Distractor.tabs], source: .selfReport),
            reflex: .known(.low, source: .session),
            attentionStability: .known(.high, source: .session),
            returnAfterDistraction: .known(.strong, source: .session),
            recall: .known(.weak, source: .selfReport),
            depth: .known(.shallow, source: .session),
            environment: .known("A reading chair", source: .selfReport),
            flowConditions: .known(["Paper notes", "Morning reading"], source: .repeated),
            energyContext: .known("Morning", source: .selfReport),
            focusWindowMinutes: 30
        )
    }

    private static var flowProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("build_flow", source: .selfReport),
            goals: .known(["build_flow", "deep_work"], source: .selfReport),
            distractors: .known([Distractor.notifications], source: .selfReport),
            reflex: .known(.low, source: .session),
            attentionStability: .known(.high, source: .session),
            returnAfterDistraction: .known(.strong, source: .session),
            recall: .known(.fair, source: .session),
            depth: .known(.deep, source: .repeated),
            environment: .known("A closed studio", source: .selfReport),
            flowConditions: .known(["One difficult build", "No notifications", "Late morning"], source: .repeated),
            energyContext: .known("Late morning", source: .repeated),
            focusWindowMinutes: 40
        )
    }

    private static var matureProfile: AttentionProfile {
        let phoneRule = PersonalRule(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "Keep phone outside reach during focus sessions",
            detail: "Physical distance prevents subconscious checking between tasks.",
            category: .environment,
            matchingContexts: [.stay, .deepWork],
            lifecycle: .kept,
            sourceType: .discoveredFromEvidence,
            confidence: .strong,
            supportingObservations: [
                "Your phone was outside reach in 8 recent comparable focus sessions.",
                "Sessions with physical distance involved 60% fewer recorded switches."
            ],
            contradictingObservations: [
                "One later session still felt difficult during low energy."
            ],
            recencyStatus: .repeatedRecent,
            createdDay: 12,
            lastTestedDay: 44,
            timesTested: 10,
            timesKept: 1
        )

        let tabRule = PersonalRule(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            title: "Close unrelated browser tabs before Stay blocks",
            detail: "Single-window setups reduce accidental switching during sustained work.",
            category: .taskSetup,
            matchingContexts: [.stay, .recall],
            lifecycle: .candidate,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [
                "Unrelated tabs were noted as a switch trigger in 4 recent sessions.",
                "Single-task focus blocks showed longer initial stretches before the first switch."
            ],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 35,
            lastTestedDay: 42,
            timesTested: 3,
            timesKept: 0
        )

        return AttentionProfile(
            primaryGoal: .known("deep_work", source: .selfReport),
            goals: .known(["deep_work", "remember_more", "build_flow"], source: .selfReport),
            distractors: .known([Distractor.notifications, Distractor.tabs], source: .selfReport),
            reflex: .known(.low, source: .repeated),
            attentionStability: .known(.high, source: .repeated),
            returnAfterDistraction: .known(.strong, source: .repeated),
            recall: .known(.strong, source: .repeated),
            depth: .known(.deep, source: .repeated),
            environment: .known("A prepared project desk", source: .selfReport),
            flowConditions: .known(["One defined outcome", "Phone outside", "Morning"], source: .repeated),
            energyContext: .known("Morning", source: .repeated),
            personalRules: [phoneRule, tabRule],
            focusWindowMinutes: 40
        )
    }

    private static func activeProgramSeed(
        day: Int,
        profile: AttentionProfile,
        track: FixtureTrack
    ) -> QASeed {
        let sessions = programHistory(through: day - 1, profile: profile, track: track)
        let reviews = completedReviews(for: sessions, track: track, through: day - 1)
        let state = programState(
            currentDay: day,
            sessions: sessions,
            reviews: reviews
        )
        return QASeed(
            profile: profile,
            sessions: sessions,
            day: state.currentDay,
            phase: nil,
            record: nil,
            programState: state
        )
    }

    /// Builds attained history from phase-aware rules. This deliberately avoids
    /// encoding 90 separately authored sessions in debug data.
    private static func programHistory(
        through lastCompletedDay: Int,
        profile: AttentionProfile,
        track: FixtureTrack
    ) -> [SessionRecord] {
        guard lastCompletedDay > 0 else { return [] }
        var history: [SessionRecord] = []

        for day in 1...min(90, lastCompletedDay) {
            let definition = CurriculumEngine.definition(
                for: day,
                profile: profile,
                protocolHistory: history
            )
            let mode = fixtureMode(day: day, phase: definition.phase, track: track)
            let target = fixtureMinutes(day: day, mode: mode, phase: definition.phase, profile: profile)
            let protected = track == .scrollControl && day >= 8 && day.isMultiple(of: 2)
            let switches: Int? = (mode == .stay || mode == .observe)
                ? (protected ? 2 : max(1, 5 - day / 20))
                : nil
            let timing: FirstSwitchTiming? = switches == nil
                ? nil
                : (day <= 14 && day.isMultiple(of: 3) ? .underFive : .fiveToTen)
            var environment: EnvironmentSnapshot?
            if track == .scrollControl, day >= 8 {
                var snapshot = EnvironmentSnapshot.none
                snapshot.protectionOffered = true
                snapshot.protectionAccepted = protected
                snapshot.protectionActivated = protected
                snapshot.manualIntervention = "Phone placed out of reach"
                snapshot.phoneLocationSelfReport = protected ? "Outside the room" : "On the desk"
                snapshot.environmentCondition = protected
                    ? EnvironmentCondition.protected.rawValue
                    : EnvironmentCondition.unrestricted.rawValue
                snapshot.startedEasierSelfReport = protected
                environment = snapshot
            }

            history.append(SessionRecord(
                id: stableUUID(prefix: 1, track: track, value: day),
                origin: .protocol,
                requestID: stableUUID(prefix: 2, track: track, value: day),
                day: day,
                date: fixtureReferenceDate.addingTimeInterval(-Double(lastCompletedDay - day) * 86_400),
                mode: mode,
                targetMinutes: target,
                actualMinutes: target,
                elapsedSeconds: target * 60,
                completed: true,
                endedEarly: false,
                firstDistraction: track == .scrollControl ? Distractor.social : Distractor.notifications,
                switches: switches,
                difficulty: day.isMultiple(of: 6) ? 3 : 2,
                energy: day.isMultiple(of: 5) ? 3 : 4,
                environmentActionDone: day == 1 ? nil : environment.map { _ in true },
                firstSwitchTiming: timing,
                evidence: fixtureEvidence(
                    mode: mode,
                    definition: definition,
                    track: track,
                    timing: timing
                ),
                programPhase: definition.phase.id,
                curriculumIntent: definition.intent.kind,
                adaptationReason: "Completed within the shared phase curriculum.",
                environment: environment
            ))
        }
        return history
    }

    private static func fixtureMode(
        day: Int,
        phase: ProgramPhase,
        track: FixtureTrack
    ) -> TrainingMode {
        if day == 1 { return .observe }
        let allowedPreferences = track.preferredModes.filter(phase.allowedModes.contains)
        let choices = allowedPreferences.isEmpty ? phase.preferredModes : allowedPreferences
        return choices[(day - 2) % choices.count]
    }

    private static func fixtureMinutes(
        day: Int,
        mode: TrainingMode,
        phase: ProgramPhase,
        profile: AttentionProfile
    ) -> Int {
        if day == 1 { return 15 }
        let range = phase.durationGuidance.range(for: mode)
        let defaultMinutes: Int
        switch mode {
        case .nothing: defaultMinutes = 5
        case .observe: defaultMinutes = 10
        case .recall, .explain: defaultMinutes = min(25, profile.focusWindowMinutes ?? 15)
        case .stay: defaultMinutes = profile.focusWindowMinutes ?? 15
        }
        let progression = min(10, (day / 20) * 5)
        return min(range.upper, max(range.lower, defaultMinutes + progression))
    }

    private static func fixtureEvidence(
        mode: TrainingMode,
        definition: ProgramDayDefinition,
        track: FixtureTrack,
        timing: FirstSwitchTiming?
    ) -> SessionEvidence {
        var evidence = SessionEvidence()
        switch mode {
        case .stay:
            evidence.stay = StayEvidence(
                task: track.task,
                completionDefinition: "Reach one clear stopping point",
                firstSwitchTiming: timing,
                returnNote: "Returned to the same task without restarting."
            )
        case .recall:
            evidence.recall = RecallEvidence(
                source: track.source,
                reconstruction: "Reconstructed the main idea in my own words.",
                selfAssessment: .some,
                missedIdea: "One supporting detail"
            )
        case .explain:
            evidence.explain = ExplainEvidence(
                topic: track.task,
                source: track.source,
                method: .spoken,
                response: "Explained the idea without reopening the source.",
                selfAssessment: .yes,
                breakdown: nil
            )
        case .nothing:
            evidence.nothing = NothingEvidence(difficulty: .thoughts)
        case .observe:
            evidence.observe = ObserveEvidence(
                mission: definition.intent.observationMission
                    ?? "Notice what changes the direction of attention.",
                observation: "The first urge appeared before the task became difficult.",
                firstSwitchTiming: timing
            )
        }
        return evidence
    }

    private static func completedReviews(
        for sessions: [SessionRecord],
        track: FixtureTrack,
        through lastCompletedDay: Int
    ) -> [WeeklyReviewRecord] {
        ProgramCheckpointSchedule.weeklyDays
            .filter { $0 <= lastCompletedDay }
            .map { checkpointDay in
                let date = sessions.first(where: { $0.day == checkpointDay })?.date
                    ?? fixtureReferenceDate
                let insights = ProgramInsightEngine.insights(
                    from: sessions.filter { $0.day <= checkpointDay }
                )
                .map(\.text)
                var review = WeeklyReviewRecord(
                    programDay: checkpointDay,
                    date: date,
                    shownInsights: Array(insights.prefix(2)),
                    answers: WeeklyReviewAnswers(
                        helpedMost: track == .scrollControl
                            ? "Putting the phone out of reach"
                            : "Starting with one clear outcome",
                        stillBreaksAttention: track == .scrollControl
                            ? "Opening a feed between steps"
                            : "Unclear stopping points",
                        nextTestPreference: track.reviewPreference
                    )
                )
                review.id = stableUUID(prefix: 3, track: track, value: checkpointDay)
                review.createdAt = date
                return review
            }
    }

    private static func programState(
        currentDay: Int,
        status: ProgramStatus = .active,
        sessions: [SessionRecord],
        reviews: [WeeklyReviewRecord],
        pendingReviewDay: Int? = nil,
        pendingPhaseTransition: ProgramPhaseID? = nil,
        pendingCompletion: Bool = false
    ) -> ProgramState {
        let currentPhaseNumber = ProgramPhase.phase(for: currentDay).number
        var acknowledged = Set(
            ProgramPhase.all
                .filter { $0.number <= currentPhaseNumber }
                .map(\.id)
        )
        if let pendingPhaseTransition {
            acknowledged.remove(pendingPhaseTransition)
        }
        return ProgramState(
            currentDay: currentDay,
            status: status,
            reviews: reviews,
            acknowledgedPhaseTransitions: acknowledged,
            pendingReviewDay: pendingReviewDay,
            pendingPhaseTransition: pendingPhaseTransition,
            pendingCompletion: pendingCompletion,
            processedProtocolSessionIDs: Set(
                sessions
                    .filter { $0.origin == .protocol && $0.completed }
                    .map(\.id)
            )
        )
    }

    static var labSuggested: QASeed {
        var seed = activeProgramSeed(day: 18, profile: scrollControlProfile, track: .scrollControl)
        seed.phase = "lab"
        seed.labState = .empty
        return seed
    }

    static var labActivePair1: QASeed {
        labSeed(experiment: activeLabExperiment())
    }

    static var labActiveMidway: QASeed {
        var experiment = activeLabExperiment()
        appendLabPair(normalSwitches: 5, testSwitches: 2, pairIndex: 1, to: &experiment)
        experiment.observations.append(labObservation(
            experiment: experiment,
            armKind: .test,
            pairIndex: 2,
            switches: 2,
            dateOffset: 4
        ))
        ExperimentComparisonEngine.updateComparability(&experiment)
        stabilizeLabPairIDs(&experiment)
        return labSeed(experiment: experiment)
    }

    static var labResultKeep: QASeed {
        var experiment = activeLabExperiment()
        appendLabPair(normalSwitches: 6, testSwitches: 2, pairIndex: 1, to: &experiment)
        appendLabPair(normalSwitches: 5, testSwitches: 2, pairIndex: 2, to: &experiment)
        appendLabPair(normalSwitches: 4, testSwitches: 2, pairIndex: 3, to: &experiment)
        finalizeLabFixture(&experiment)
        return labSeed(experiment: experiment)
    }

    static var labResultInconclusive: QASeed {
        var experiment = activeLabExperiment(template: ExperimentTemplateLibrary.oneBrowserTask)
        appendLabPair(normalSwitches: 5, testSwitches: 2, pairIndex: 1, to: &experiment)
        appendLabPair(normalSwitches: 2, testSwitches: 5, pairIndex: 2, to: &experiment)
        appendLabPair(normalSwitches: 3, testSwitches: 3, pairIndex: 3, to: &experiment)
        finalizeLabFixture(&experiment)
        return labSeed(experiment: experiment)
    }

    private static func activeLabExperiment(
        template: ExperimentTemplate = ExperimentTemplateLibrary.phoneDistance
    ) -> PersonalExperiment {
        var experiment = PersonalLabEngine.makeExperiment(
            template: template,
            origin: .evidenceSuggestion,
            now: fixtureReferenceDate
        )
        let fixtureValue = labTemplateValue(template.id)
        experiment.id = stableUUID(prefix: 70, track: .focus, value: fixtureValue)
        experiment.normalArm.id = stableUUID(prefix: 71, track: .focus, value: fixtureValue * 10 + 1)
        experiment.testArm.id = stableUUID(prefix: 71, track: .focus, value: fixtureValue * 10 + 2)
        experiment.status = .active
        return experiment
    }

    private static func labSeed(experiment: PersonalExperiment) -> QASeed {
        var seed = activeProgramSeed(day: 18, profile: scrollControlProfile, track: .scrollControl)
        seed.phase = "lab"
        seed.labState = PersonalLabState(experiments: [experiment])
        return seed
    }

    private static func appendLabPair(
        normalSwitches: Int,
        testSwitches: Int,
        pairIndex: Int,
        to experiment: inout PersonalExperiment
    ) {
        experiment.observations.append(labObservation(
            experiment: experiment,
            armKind: .normal,
            pairIndex: pairIndex,
            switches: normalSwitches,
            dateOffset: pairIndex * 2
        ))
        experiment.observations.append(labObservation(
            experiment: experiment,
            armKind: .test,
            pairIndex: pairIndex,
            switches: testSwitches,
            dateOffset: pairIndex * 2 + 1
        ))
        ExperimentComparisonEngine.updateComparability(&experiment)
        stabilizeLabPairIDs(&experiment)
    }

    private static func labObservation(
        experiment: PersonalExperiment,
        armKind: ExperimentArmKind,
        pairIndex: Int,
        switches: Int,
        dateOffset: Int
    ) -> ExperimentObservation {
        let arm = experiment.arm(for: armKind)
        var snapshot = ExperimentConditionSnapshot.pending(arm.condition)
        snapshot.actualDescription = arm.condition.detail
        snapshot.truthSource = .userReported
        snapshot.conditionFollowed = true
        snapshot.capturedAt = fixtureReferenceDate.addingTimeInterval(Double(dateOffset) * 3_600)
        return ExperimentObservation(
            id: stableUUID(prefix: 72, track: .focus, value: dateOffset),
            experimentID: experiment.id,
            sessionID: stableUUID(prefix: 73, track: .focus, value: dateOffset),
            armID: arm.id,
            armKind: armKind,
            pairIndex: pairIndex,
            requestedCondition: snapshot,
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            endedEarly: false,
            outcomes: [ExperimentOutcomeMetric.reportedSwitches.key: .integer(switches)],
            classification: .usableButUnmatched,
            classificationReason: "Waiting for the matching condition.",
            confounds: [],
            sourceEvidenceIDs: [stableUUID(prefix: 74, track: .focus, value: dateOffset)],
            date: fixtureReferenceDate.addingTimeInterval(Double(dateOffset) * 3_600)
        )
    }

    private static func finalizeLabFixture(_ experiment: inout PersonalExperiment) {
        _ = ExperimentResultEngine.finalize(&experiment)
        let fixtureValue = labTemplateValue(experiment.templateID)
        experiment.result?.id = stableUUID(prefix: 75, track: .focus, value: fixtureValue)
        experiment.result?.finalizedAt = fixtureReferenceDate.addingTimeInterval(86_400)
        experiment.completedAt = experiment.result?.finalizedAt
        experiment.updatedAt = experiment.result?.finalizedAt ?? fixtureReferenceDate
        stabilizeLabPairIDs(&experiment)
    }

    private static func stabilizeLabPairIDs(_ experiment: inout PersonalExperiment) {
        let fixtureValue = labTemplateValue(experiment.templateID)
        for index in experiment.pairs.indices {
            experiment.pairs[index].id = stableUUID(
                prefix: 76,
                track: .focus,
                value: fixtureValue * 10 + experiment.pairs[index].pairIndex
            )
        }
        if experiment.result != nil {
            experiment.result?.pairResults = experiment.pairs.filter(\.isComplete)
        }
    }

    private static func labTemplateValue(_ templateID: String?) -> Int {
        switch templateID {
        case ExperimentTemplateLibrary.phoneDistance.id: return 1
        case ExperimentTemplateLibrary.sessionProtection.id: return 2
        case ExperimentTemplateLibrary.oneBrowserTask.id: return 3
        case ExperimentTemplateLibrary.sound.id: return 4
        case ExperimentTemplateLibrary.clearFinishLine.id: return 5
        default: return 9
        }
    }

    private static func stableUUID(
        prefix: Int,
        track: FixtureTrack,
        value: Int
    ) -> UUID {
        let suffix = track.rawValue * 1_000 + value
        return UUID(
            uuidString: String(
                format: "%08d-0000-4000-8000-%012d",
                prefix,
                suffix
            )
        )!
    }
#endif

    static func named(_ name: String) -> QASeed? {
        switch name {
        case "day1": return day1
        case "stay": return stay
        case "recall": return recall
        case "rest": return rest
        case "running": return running
        case "done": return done
        case "profileSparse": return day1
#if DEBUG
        case "profileMature": return programDay82Mature
        case "rulesWhyThisRule": return programDay82Mature
        case "programMidPhase": return programDay45Memory
        case "programDay90Complete": return programCompleted
        case "programDay1": return programDay1
        case "programDay7Checkpoint": return programDay7Checkpoint
        case "programDay8Transition": return programDay8Transition
        case "programDay26Study": return programDay26Study
        case "programDay26ScrollControl": return programDay26ScrollControl
        case "programDay45Memory": return programDay45Memory
        case "programDay65FlowConditions": return programDay65FlowConditions
        case "programDay82Mature": return programDay82Mature
        case "programDay90BeforeCompletion": return programDay90BeforeCompletion
        case "programCompleted": return programCompleted
        case "labSuggested": return labSuggested
        case "labActivePair1": return labActivePair1
        case "labActiveMidway": return labActiveMidway
        case "labResultKeep": return labResultKeep
        case "labResultInconclusive": return labResultInconclusive
#endif
        default: return nil
        }
    }
}
