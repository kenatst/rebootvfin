import XCTest
@testable import REBOOT

@MainActor
final class REBOOTTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "REBOOTTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    func testCompletedProtocolAdvancesExactlyOnce() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let request = tryUnwrap(store.protocolRequest())
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        let record = doneRecord(store)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.protocolSessions.count, 1)

        store.phase = .done(record)
        store.saveDoneSession(SessionReflection(difficulty: 2))
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.protocolSessions.count, 1)
    }

    func testDayOneIsNaturalObserveBaselineEvenWhenEnvironmentIsArmed() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let preparation = EnvironmentPreparation(
            action: "Move phone",
            fallback: "Face down",
            outcome: .completed,
            arm: protectedArm()
        )
        store.setEnvironmentPreparation(preparation)

        let prescription = store.prescription
        XCTAssertEqual(prescription.day, 1)
        XCTAssertEqual(prescription.mode, .observe)
        XCTAssertEqual(prescription.minutes, 15)
        XCTAssertEqual(prescription.curriculumIntent, .naturalBaseline)
        XCTAssertFalse(prescription.requiresEnvironmentPreparation)
        XCTAssertNil(prescription.environmentAction)
        XCTAssertNil(store.environmentPreparation)

        var request = tryUnwrap(store.protocolRequest())
        XCTAssertNil(request.environmentPreparation)
        request.mode = .stay
        request.targetMinutes = 45
        request.goal = "Altered goal"
        request.task = "Altered task"
        request.environmentPreparation = preparation
        request.programPhase = .ownSystem
        request.curriculumIntent = .buildContinuity
        store.begin(request: request, environment: protectedArm())

        guard case .running(let record) = store.phase else {
            return XCTFail("Expected running session")
        }
        XCTAssertEqual(record.mode, .observe)
        XCTAssertEqual(record.targetMinutes, 15)
        XCTAssertEqual(record.curriculumIntent, .naturalBaseline)
        XCTAssertEqual(record.programPhase, .calibrate)
        XCTAssertNil(record.environmentActionDone)
        XCTAssertNil(record.environment)

        store.reset()
        store.beginSession(environment: protectedArm(), minutesOverride: 10)
        guard case .running(let overrideRecord) = store.phase else {
            return XCTFail("Expected canonical Day 1 session")
        }
        XCTAssertEqual(overrideRecord.mode, .observe)
        XCTAssertEqual(overrideRecord.targetMinutes, 15)
        XCTAssertNil(overrideRecord.environment)
    }

    func testCompletedProtocolDaysAreUniqueAndDriveExactProgress() {
        var sessions = protocolHistory(through: 17)
        sessions.append(protocolRecord(day: 17))
        sessions.append(protocolRecord(day: 18, completed: false, endedEarly: true))
        sessions.append(protocolRecord(day: 19, origin: .freeTraining))

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(profile: AttentionProfile(), sessions: sessions, day: 18))

        XCTAssertEqual(store.day, 18)
        XCTAssertEqual(store.completedProtocolDays, 17)
        XCTAssertEqual(store.programProgress, 17.0 / 90.0, accuracy: 0.000_001)
        XCTAssertNotEqual(store.programProgress, Double(store.day) / 90.0)
    }

    func testFreeTrainingNeverAdvancesProgram() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        var request = TrainingSessionRequest.freeTraining(mode: .stay)
        request.task = "Read one section"
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))

        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.freeTrainingSessions.count, 1)
        XCTAssertTrue(store.freeTrainingSessions[0].completed)
    }

    func testEarlyProtocolEndIsEvidenceButDoesNotAdvance() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let request = tryUnwrap(store.protocolRequest())
        store.begin(request: request)
        store.finishRunning(actualMinutes: 1, endedEarly: true)
        store.saveDoneSession(SessionReflection(difficulty: 4, firstDistraction: "social", switches: 3))

        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.protocolSessions.count, 1)
        XCTAssertFalse(store.protocolSessions[0].completed)
        XCTAssertTrue(store.protocolSessions[0].endedEarly)
        XCTAssertEqual(store.prescription.mode, .observe)
    }

    func testDayNinetyNeverBecomesNinetyOne() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(profile: AttentionProfile(), sessions: [], day: 90))
        let request = tryUnwrap(store.protocolRequest())
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 0))

        XCTAssertEqual(store.day, 90)
        XCTAssertTrue(store.hasCompletedCurrentProtocol)
        XCTAssertNil(store.protocolRequest())
        guard case .programCompletion = store.phase else {
            return XCTFail("Expected the Day 90 completion screen")
        }

        let completionRestored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .programCompletion = completionRestored.phase else {
            return XCTFail("The pending completion must survive restoration")
        }
        completionRestored.acknowledgeProgramCompletion()

        let acknowledged = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .today = acknowledged.phase else {
            return XCTFail("Acknowledged completion must restore to Today")
        }
        XCTAssertEqual(acknowledged.day, 90)
        XCTAssertEqual(acknowledged.programStatus, .completed)
        XCTAssertNil(acknowledged.protocolRequest())
    }

    func testProgramStateCheckpointsAtSevenAndFourteenAreIdempotent() {
        var state = ProgramState.fresh
        var ids: [Int: UUID] = [:]

        for day in 1...7 {
            let id = UUID()
            ids[day] = id
            _ = state.registerCompletedProtocolSession(id: id, day: day)
        }

        XCTAssertEqual(state.currentDay, 8)
        XCTAssertEqual(state.pendingReviewDay, 7)
        XCTAssertEqual(state.pendingPhaseTransition, .controlInput)
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: UUID(), day: 8),
            .ignored
        )
        XCTAssertEqual(state.currentDay, 8)
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: tryUnwrap(ids[7]), day: 7),
            .ignored
        )
        XCTAssertEqual(state.processedProtocolSessionIDs.count, 7)

        let firstReview = weeklyReview(day: 7)
        state.recordReview(firstReview)
        state.recordReview(weeklyReview(day: 7))
        XCTAssertEqual(state.reviews.map(\.programDay), [7])
        XCTAssertNil(state.pendingReviewDay)
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: UUID(), day: 8),
            .ignored
        )
        state.acknowledgePhaseTransition(.controlInput)

        for day in 8...14 {
            _ = state.registerCompletedProtocolSession(id: UUID(), day: day)
        }
        XCTAssertEqual(state.currentDay, 15)
        XCTAssertEqual(state.pendingReviewDay, 14)
        XCTAssertEqual(state.reviews.count, 1)
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: UUID(), day: 15),
            .ignored
        )
    }

    func testCanonicalProgramPhasesKeepTheirFixedCompletedDayRanges() {
        XCTAssertEqual(ProgramPhase.all.map(\.days), [
            1...7,
            8...21,
            22...40,
            41...60,
            61...75,
            76...90,
        ])
        XCTAssertEqual(ProgramPhase.all.map(\.title), [
            "Learn your attention.",
            "Make space.",
            "Stay longer.",
            "Go deeper.",
            "Find your conditions.",
            "Make it yours.",
        ])
    }

    func testDaySevenRoutesReviewBeforeTransitionAndPersistsAcknowledgement() {
        let history = protocolHistory(through: 6)
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: history,
            day: 7,
            programState: .migrated(day: 7, sessions: history)
        ))

        let request = tryUnwrap(store.protocolRequest())
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))

        guard case .weeklyReview(7) = store.phase else {
            return XCTFail("Expected Day 7 review before the phase transition")
        }
        XCTAssertEqual(store.day, 8)
        XCTAssertNil(store.protocolRequest())
        let blockedDuringReview = TrainingSessionRequest.protocolRequest(
            prescription: store.prescription,
            day: store.day,
            environmentPreparation: nil
        )
        store.begin(request: blockedDuringReview)
        guard case .weeklyReview(7) = store.phase else {
            return XCTFail("A protocol session must not bypass the pending review")
        }

        let reviewRestored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .weeklyReview(7) = reviewRestored.phase else {
            return XCTFail("The pending review must survive restoration")
        }
        reviewRestored.skipWeeklyReviewQuestions()
        guard case .phaseTransition(.controlInput) = reviewRestored.phase else {
            return XCTFail("Expected Phase 2 transition after the review")
        }
        XCTAssertNil(reviewRestored.protocolRequest())

        let transitionRestored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .phaseTransition(.controlInput) = transitionRestored.phase else {
            return XCTFail("The pending transition must survive restoration")
        }
        transitionRestored.acknowledgePhaseTransition()
        guard case .today = transitionRestored.phase else {
            return XCTFail("Expected Today after acknowledging the transition")
        }

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .today = restored.phase else {
            return XCTFail("The acknowledged transition must not replay")
        }
        XCTAssertEqual(restored.day, 8)
        XCTAssertEqual(restored.programState.reviews.map(\.programDay), [7])
        XCTAssertTrue(restored.programState.acknowledgedPhaseTransitions.contains(.controlInput))
    }

    func testAllFivePhaseTransitionsOccurAfterBoundaryCompletion() {
        let expected: [Int: ProgramPhaseID] = [
            7: .controlInput,
            21: .buildStability,
            40: .deepen,
            60: .findConditions,
            75: .ownSystem,
        ]
        var state = ProgramState.fresh
        var observed: [Int: ProgramPhaseID] = [:]

        for day in 1...75 {
            _ = state.registerCompletedProtocolSession(id: UUID(), day: day)
            if let expectedPhase = expected[day] {
                XCTAssertEqual(state.currentDay, day + 1)
                XCTAssertEqual(state.pendingPhaseTransition, expectedPhase)
                observed[day] = state.pendingPhaseTransition
            }
            if let reviewDay = state.pendingReviewDay {
                state.recordReview(weeklyReview(day: reviewDay))
            }
            if let phase = state.pendingPhaseTransition {
                state.acknowledgePhaseTransition(phase)
            }
        }

        XCTAssertEqual(observed, expected)
        XCTAssertEqual(state.currentDay, 76)
    }

    func testDayNinetyHasExplicitActiveThenCompletedStateAndNeverDayNinetyOne() {
        var state = progressedState(through: 89)
        XCTAssertEqual(state.currentDay, 90)
        XCTAssertEqual(state.status, .active)
        XCTAssertFalse(state.pendingCompletion)

        let completionID = UUID()
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: completionID, day: 90),
            .completed
        )
        XCTAssertEqual(state.currentDay, 90)
        XCTAssertEqual(state.status, .completed)
        XCTAssertTrue(state.pendingCompletion)
        XCTAssertEqual(
            state.registerCompletedProtocolSession(id: UUID(), day: 90),
            .ignored
        )
        XCTAssertEqual(state.currentDay, 90)

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: protocolHistory(through: 90),
            day: 90,
            programState: state
        ))
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programProgress, 1, accuracy: 0.000_001)
        XCTAssertNil(store.protocolRequest())
    }

    func testFreeEarlyAndElapsedCalendarTimeDoNotAdvanceProgram() {
        let oldDate = Date().addingTimeInterval(-30 * 86_400)
        let completed = protocolRecord(day: 1, date: oldDate)
        let early = protocolRecord(
            day: 2,
            date: oldDate.addingTimeInterval(86_400),
            completed: false,
            endedEarly: true
        )
        let free = protocolRecord(
            day: 2,
            date: Date(),
            origin: .freeTraining
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(profile: AttentionProfile(), sessions: [completed, early, free], day: 2))

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.completedProtocolDays, 1)
        XCTAssertEqual(store.freeTrainingSessions.count, 1)
        XCTAssertEqual(store.programProgress, 1.0 / 90.0, accuracy: 0.000_001)
    }

    func testLegacyV1AndV2SessionsMigrateAsProtocol() throws {
        for key in ["reboot.product.v1", "reboot.product.v2"] {
            clearProductPersistence()
            let legacy = LegacySession(
                day: 1,
                date: Date(),
                mode: .observe,
                targetMinutes: 15,
                actualMinutes: 15,
                completed: true
            )
            defaults.set([
                "profile": try JSONEncoder().encode(AttentionProfile()),
                "sessions": try JSONEncoder().encode([legacy]),
                "day": 2,
            ], forKey: key)

            let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
            XCTAssertEqual(store.protocolSessions.count, 1)
            XCTAssertEqual(store.protocolSessions[0].origin, .protocol)
            XCTAssertEqual(store.day, 2)
            XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v4"))
        }
    }

    func testV3MigratesToV4WithProgramStateAndPreparationPreserved() throws {
        clearProductPersistence()
        let sessions = protocolHistory(through: 7)
        let preparation = EnvironmentPreparation(
            action: "Move phone",
            fallback: "Face down",
            outcome: .fallback,
            arm: protectedArm()
        )
        defaults.set([
            "profile": try JSONEncoder().encode(AttentionProfile()),
            "sessions": try JSONEncoder().encode(sessions),
            "day": 8,
            "preparation": try JSONEncoder().encode(Optional(preparation)),
            "activeSession": try JSONEncoder().encode(Optional<SessionRecord>.none),
        ], forKey: "reboot.product.v3")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)

        XCTAssertEqual(store.day, 8)
        XCTAssertEqual(store.programStatus, .active)
        XCTAssertEqual(store.completedProtocolDays, 7)
        XCTAssertEqual(store.environmentPreparation, preparation)
        XCTAssertNil(store.programState.pendingReviewDay)
        XCTAssertNil(store.programState.pendingPhaseTransition)
        XCTAssertTrue(store.programState.acknowledgedPhaseTransitions.contains(.controlInput))
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v4"))
        XCTAssertNil(defaults.object(forKey: "reboot.product.v3"))
    }

    func testInvalidV4NeverRollsBackToLegacyState() throws {
        let legacySessions = protocolHistory(through: 7)
        defaults.set([
            "profile": try JSONEncoder().encode(AttentionProfile()),
            "sessions": try JSONEncoder().encode(legacySessions),
            "day": 8,
        ], forKey: "reboot.product.v3")
        defaults.set([
            "profile": Data("invalid".utf8),
            "sessions": Data("invalid".utf8),
            "programState": Data("invalid".utf8),
        ], forKey: "reboot.product.v4")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.day, 1)
        XCTAssertTrue(store.sessions.isEmpty)

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(restored.day, 1)
        XCTAssertTrue(restored.sessions.isEmpty)
    }

    func testV3DayNinetyOnlyCompletesWhenProtocolDayNinetyWasCompleted() throws {
        for didCompleteDayNinety in [false, true] {
            clearProductPersistence()
            var sessions = protocolHistory(through: 89)
            sessions.append(protocolRecord(
                day: 90,
                completed: didCompleteDayNinety,
                endedEarly: !didCompleteDayNinety
            ))
            defaults.set([
                "profile": try JSONEncoder().encode(AttentionProfile()),
                "sessions": try JSONEncoder().encode(sessions),
                "day": 90,
            ], forKey: "reboot.product.v3")

            let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
            XCTAssertEqual(store.day, 90)
            XCTAssertEqual(store.programStatus, didCompleteDayNinety ? .completed : .active)
            XCTAssertEqual(store.protocolRequest() == nil, didCompleteDayNinety)
        }
    }

    func testV3RestoresInterruptedSessionAsRecovery() {
        let first = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let request = tryUnwrap(first.protocolRequest())
        first.begin(request: request)

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .recovery(let record) = restored.phase else {
            return XCTFail("Expected recovery phase")
        }
        XCTAssertEqual(record.requestID, request.id)
        XCTAssertFalse(record.completed)
    }

    func testManualPreparationPersistsIntoDayTwoSession() {
        let first = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        first.apply(QASeed(
            profile: AttentionProfile(),
            sessions: [protocolRecord(day: 1)],
            day: 2
        ))
        first.setEnvironmentPreparation(
            EnvironmentPreparation(action: "Move phone", fallback: "Face down", outcome: .fallback)
        )
        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let request = tryUnwrap(restored.protocolRequest())
        restored.begin(request: request)

        guard case .running(let record) = restored.phase else {
            return XCTFail("Expected running session")
        }
        XCTAssertEqual(record.environmentActionDone, true)
    }

    func testDuplicateRequestCannotBeSavedOrAdvanceTwice() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let request = tryUnwrap(store.protocolRequest())
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        let record = doneRecord(store)
        store.saveDoneSession(SessionReflection(difficulty: 2))

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.protocolSessions.count, 1)
        XCTAssertEqual(store.programState.processedProtocolSessionIDs, [record.id])

        var duplicate = record
        duplicate.id = UUID()
        store.phase = .done(duplicate)
        store.saveDoneSession(SessionReflection(difficulty: 1))

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.protocolSessions.count, 1)
        XCTAssertEqual(store.programState.processedProtocolSessionIDs, [record.id])
    }

    func testEnvironmentSnapshotSurvivesPersistence() {
        let first = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let arm = SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: UUID(),
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: true,
            phoneLocationSelfReport: nil
        )
        let request = TrainingSessionRequest.freeTraining(mode: .observe)
        first.begin(request: request, environment: arm)

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .recovery(let record) = restored.phase else {
            return XCTFail("Expected recovery phase")
        }
        XCTAssertTrue(record.environment?.protectionActivated == true)
        XCTAssertEqual(record.environment?.protectedSelectionID, arm.protectedSelectionID)
    }

    func testModeSpecificEvidencePersists() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)

        saveFree(mode: .stay, store: store) { request in
            request.task = "One task"
        } reflection: {
            SessionReflection(difficulty: 2, firstDistraction: "tabs", switches: 2, firstSwitchTiming: .fiveToTen)
        }
        saveFree(mode: .recall, store: store) { request in
            request.source = "A source"
        } reflection: {
            SessionReflection(difficulty: 3, recallAssessment: .some, missedIdea: "One detail")
        }
        saveFree(mode: .explain, store: store) { request in
            request.topic = "A topic"
            request.source = "Notes"
        } reflection: {
            SessionReflection(difficulty: 3, explanationAssessment: .partly, explanationBreakdown: "The ending")
        }
        saveFree(mode: .nothing, store: store) { _ in } reflection: {
            SessionReflection(difficulty: 4, nothingDifficulty: .urgeToCheck)
        }
        saveFree(mode: .observe, store: store) { request in
            request.observationMission = ObservationMission.all[1]
        } reflection: {
            SessionReflection(difficulty: 2, firstDistraction: "social", switches: 1, observation: "I reached before deciding")
        }

        XCTAssertEqual(store.freeTrainingSessions.count, 5)
        XCTAssertEqual(store.freeTrainingSessions.first { $0.mode == .recall }?.evidence?.recall?.selfAssessment, .some)
        XCTAssertEqual(store.freeTrainingSessions.first { $0.mode == .explain }?.evidence?.explain?.selfAssessment, .partly)
        XCTAssertEqual(store.freeTrainingSessions.first { $0.mode == .nothing }?.evidence?.nothing?.difficulty, .urgeToCheck)
        XCTAssertEqual(store.freeTrainingSessions.first { $0.mode == .observe }?.evidence?.observe?.observation, "I reached before deciding")
    }

    func testPrescriptionRegressionsAndUnknownIntegrity() {
        XCTAssertEqual(PrescriptionEngine.prescription(profile: AttentionProfile(), sessions: [], day: 1).mode, .observe)
        XCTAssertEqual(PrescriptionEngine.prescription(profile: QASeeds.stay.profile!, sessions: QASeeds.stay.sessions!, day: 4).mode, .stay)
        XCTAssertEqual(PrescriptionEngine.prescription(profile: QASeeds.recall.profile!, sessions: QASeeds.recall.sessions!, day: 5).mode, .recall)
        XCTAssertEqual(PrescriptionEngine.prescription(profile: QASeeds.rest.profile!, sessions: QASeeds.rest.sessions!, day: 3).mode, .nothing)

        var profile = AttentionProfile()
        let nothing = SessionRecord(
            origin: .freeTraining,
            day: 1,
            date: Date(),
            mode: .nothing,
            targetMinutes: 3,
            actualMinutes: 3,
            completed: true,
            difficulty: 5,
            evidence: SessionEvidence(nothing: NothingEvidence(difficulty: .restlessness))
        )
        ProfileUpdater.apply(session: nothing, sessionCount: 1, to: &profile)
        XCTAssertFalse(profile.recall.isKnown)
        XCTAssertFalse(profile.depth.isKnown)
        XCTAssertFalse(profile.returnAfterDistraction.isKnown)
    }

    func testDayTwentySixStudyAndScrollProfilesReceiveDifferentPrescriptions() {
        var study = AttentionProfile()
        study.primaryGoal = .known("study_better", source: .selfReport)
        study.goals = .known(["study_better", "remember_more"], source: .selfReport)
        study.recall = .known(.weak, source: .selfReport)
        study.focusWindowMinutes = 20

        var scroll = AttentionProfile()
        scroll.primaryGoal = .known("scroll_less", source: .selfReport)
        scroll.goals = .known(["scroll_less", "phone_less"], source: .selfReport)
        scroll.distractors = .known([Distractor.phone, Distractor.social], source: .selfReport)
        scroll.focusWindowMinutes = 20

        let history = protocolHistory(through: 25, mode: .observe)
        let studyPrescription = PrescriptionEngine.prescription(
            profile: study,
            sessions: history,
            day: 26
        )
        let scrollPrescription = PrescriptionEngine.prescription(
            profile: scroll,
            sessions: history,
            day: 26
        )

        XCTAssertEqual(studyPrescription.programPhase, .buildStability)
        XCTAssertEqual(scrollPrescription.programPhase, .buildStability)
        XCTAssertEqual(studyPrescription.mode, .recall)
        XCTAssertEqual(scrollPrescription.mode, .stay)
        XCTAssertNotEqual(studyPrescription.mode, scrollPrescription.mode)
        XCTAssertNotEqual(studyPrescription.goal, scrollPrescription.goal)
    }

    func testRecoveryUsesLatestDifficultProtocolSessionAndDoesNotRepeatNothing() {
        let easy = protocolRecord(day: 8, mode: .stay, difficulty: 2)
        let latestHard = protocolRecord(day: 9, mode: .stay, difficulty: 5)
        let recovery = PrescriptionEngine.prescription(
            profile: AttentionProfile(),
            sessions: [easy, latestHard],
            day: 10
        )
        XCTAssertEqual(recovery.mode, .nothing)
        XCTAssertEqual(recovery.curriculumIntent, .tolerateLessStimulus)
        XCTAssertTrue(recovery.recentEvidenceReason?.contains("last protocol session") == true)

        let completedRecovery = protocolRecord(day: 10, mode: .nothing, difficulty: 5)
        let next = PrescriptionEngine.prescription(
            profile: AttentionProfile(),
            sessions: [easy, latestHard, completedRecovery],
            day: 11
        )
        XCTAssertNotEqual(next.mode, .nothing)
    }

    func testInterruptedSessionIsNeverDescribedAsManageable() {
        let interrupted = protocolRecord(
            day: 24,
            mode: .stay,
            completed: false,
            endedEarly: true,
            difficulty: 1
        )
        let completed = protocolRecord(day: 25, mode: .stay, difficulty: 1)
        let prescription = PrescriptionEngine.prescription(
            profile: AttentionProfile(),
            sessions: [interrupted, completed],
            day: 26
        )

        XCTAssertNotEqual(
            prescription.recentEvidenceReason,
            "Two recent protocol sessions were reported as manageable."
        )
    }

    func testAdaptiveDurationIncreaseIsCappedAtFiveMinutes() {
        let phase = ProgramPhase.phase(for: 26)
        let history = [
            protocolRecord(day: 24, mode: .stay, targetMinutes: 20, actualMinutes: 20, difficulty: 2),
            protocolRecord(day: 25, mode: .stay, targetMinutes: 20, actualMinutes: 20, difficulty: 1),
        ]
        let result = AdaptiveDurationEngine.recommendation(
            mode: .stay,
            profile: AttentionProfile(focusWindowMinutes: 20),
            protocolHistory: history,
            phase: phase
        )

        XCTAssertEqual(result.reason, .repeatedComfort)
        XCTAssertEqual(result.minutes, 25)
        XCTAssertLessThanOrEqual(result.minutes - 20, 5)
    }

    func testAdaptiveDurationHoldsAfterOneHardSessionThenDropsAfterRepeatedDifficulty() {
        let phase = ProgramPhase.phase(for: 26)
        let firstHard = protocolRecord(
            day: 24,
            mode: .stay,
            targetMinutes: 25,
            actualMinutes: 15,
            completed: false,
            endedEarly: true,
            difficulty: 5
        )
        let held = AdaptiveDurationEngine.recommendation(
            mode: .stay,
            profile: AttentionProfile(focusWindowMinutes: 25),
            protocolHistory: [firstHard],
            phase: phase
        )
        XCTAssertEqual(held.reason, .heldForEvidence)
        XCTAssertEqual(held.minutes, 25)

        let secondHard = protocolRecord(
            day: 25,
            mode: .stay,
            targetMinutes: 25,
            actualMinutes: 12,
            completed: false,
            endedEarly: true,
            difficulty: 4
        )
        let reduced = AdaptiveDurationEngine.recommendation(
            mode: .stay,
            profile: AttentionProfile(focusWindowMinutes: 25),
            protocolHistory: [firstHard, secondHard],
            phase: phase
        )
        XCTAssertEqual(reduced.reason, .repeatedDifficulty)
        XCTAssertEqual(reduced.minutes, 20)
    }

    private func saveFree(
        mode: TrainingMode,
        store: ProductStore,
        configure: (inout TrainingSessionRequest) -> Void,
        reflection: () -> SessionReflection
    ) {
        var request = TrainingSessionRequest.freeTraining(mode: mode)
        configure(&request)
        store.begin(request: request)
        if mode.usesStrictTimer {
            store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        } else {
            store.finishRunning(endedEarly: false, semanticCompletion: true)
        }
        store.saveDoneSession(reflection())
    }

    private func doneRecord(_ store: ProductStore) -> SessionRecord {
        guard case .done(let record) = store.phase else {
            XCTFail("Expected done phase")
            fatalError("Expected done phase")
        }
        return record
    }

    private func protocolRecord(
        day: Int,
        date: Date = Date(),
        origin: SessionOrigin = .protocol,
        mode: TrainingMode = .stay,
        targetMinutes: Int = 15,
        actualMinutes: Int = 15,
        completed: Bool = true,
        endedEarly: Bool = false,
        difficulty: Int = 2,
        energy: Int? = 3
    ) -> SessionRecord {
        SessionRecord(
            origin: origin,
            requestID: UUID(),
            day: day,
            date: date,
            mode: mode,
            targetMinutes: targetMinutes,
            actualMinutes: actualMinutes,
            completed: completed,
            endedEarly: endedEarly,
            switches: mode == .stay ? 2 : nil,
            difficulty: difficulty,
            energy: energy
        )
    }

    private func protocolHistory(
        through day: Int,
        mode: TrainingMode = .stay
    ) -> [SessionRecord] {
        guard day > 0 else { return [] }
        return (1...day).map {
            protocolRecord(
                day: $0,
                date: Date().addingTimeInterval(Double($0 - day) * 86_400),
                mode: mode
            )
        }
    }

    private func progressedState(through day: Int) -> ProgramState {
        var state = ProgramState.fresh
        guard day > 0 else { return state }
        for programDay in 1...day {
            _ = state.registerCompletedProtocolSession(id: UUID(), day: programDay)
            if let reviewDay = state.pendingReviewDay {
                state.recordReview(weeklyReview(day: reviewDay))
            }
            if let phase = state.pendingPhaseTransition {
                state.acknowledgePhaseTransition(phase)
            }
        }
        return state
    }

    private func weeklyReview(day: Int) -> WeeklyReviewRecord {
        WeeklyReviewRecord(
            programDay: day,
            date: Date(),
            shownInsights: [],
            answers: .empty
        )
    }

    private func protectedArm() -> SessionEnvironmentArm {
        SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: UUID(),
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: true,
            phoneLocationSelfReport: nil
        )
    }

    private func clearProductPersistence() {
        for key in [
            "reboot.product.v1",
            "reboot.product.v2",
            "reboot.product.v3",
            "reboot.product.v4",
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}

private struct LegacySession: Codable {
    var id = UUID()
    var day: Int
    var date: Date
    var mode: TrainingMode
    var targetMinutes: Int
    var actualMinutes: Int
    var completed: Bool
    var endedEarly = false
    var firstDistraction: String?
    var switches: Int?
    var difficulty: Int?
    var energy: Int?
    var environmentActionDone: Bool?
    var firstSwitchMinute: Int?
    var environment: EnvironmentSnapshot?
}
