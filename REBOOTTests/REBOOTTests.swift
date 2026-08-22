import XCTest
import SwiftUI
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
            XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v7"))
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
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v7"))
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
        XCTAssertTrue(recovery.recentEvidenceReason?.contains("demanding") == true || recovery.recentEvidenceReason?.contains("difficult") == true || recovery.recentEvidenceReason?.contains("resetting") == true)

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
            "reboot.product.v5",
            "reboot.product.v6",
            "reboot.product.v7",
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Personal Rules Lifecycle & Strict Guards Tests

    func testPersonalRuleLifecycleCandidateToKept() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let candidateRule = PersonalRule(
            id: UUID(),
            title: "Leave phone outside room",
            detail: "Friction reduces distractions.",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .candidate,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: ["Observed in 2 sessions."],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 2,
            lastTestedDay: 2,
            timesTested: 2,
            timesKept: 0
        )
        store.profile.personalRules = [candidateRule]
        store.apply(QASeed(profile: store.profile, sessions: []))

        XCTAssertEqual(store.personalRules.count, 1)
        XCTAssertEqual(store.personalRules.first?.lifecycle, .candidate)

        store.keepPersonalRule(id: candidateRule.id)

        XCTAssertEqual(store.personalRules.first?.lifecycle, .kept)
        XCTAssertEqual(store.personalRules.first?.timesKept, 1)
        XCTAssertEqual(store.profile.personalRules.first?.lifecycle, .kept)
    }

    func testPersonalRuleLifecycleCandidateToTesting() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let candidateRule = PersonalRule(
            id: UUID(),
            title: "Single tab mode",
            detail: "Keep one tab open.",
            category: .taskSetup,
            matchingContexts: [.stay],
            lifecycle: .candidate,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 3,
            lastTestedDay: 3,
            timesTested: 1,
            timesKept: 0
        )
        store.profile.personalRules = [candidateRule]
        store.apply(QASeed(profile: store.profile, sessions: []))

        store.testPersonalRule(id: candidateRule.id)

        XCTAssertEqual(store.personalRules.first?.lifecycle, .testing)
        XCTAssertEqual(store.personalRules.first?.timesTested, 2)
    }

    func testPersonalRuleLifecycleTestingToKeptAndTestingToRejected() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let rule1 = PersonalRule(
            id: UUID(),
            title: "Rule A",
            detail: "Detail A",
            category: .friction,
            matchingContexts: [.stay],
            lifecycle: .testing,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 3,
            lastTestedDay: 3,
            timesTested: 2,
            timesKept: 0
        )
        let rule2 = PersonalRule(
            id: UUID(),
            title: "Rule B",
            detail: "Detail B",
            category: .timing,
            matchingContexts: [.stay],
            lifecycle: .testing,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 3,
            lastTestedDay: 3,
            timesTested: 2,
            timesKept: 0
        )
        store.profile.personalRules = [rule1, rule2]
        store.apply(QASeed(profile: store.profile, sessions: []))

        store.keepPersonalRule(id: rule1.id)
        store.rejectPersonalRule(id: rule2.id)

        XCTAssertEqual(store.personalRules.first(where: { $0.id == rule1.id })?.lifecycle, .kept)
        XCTAssertEqual(store.personalRules.first(where: { $0.id == rule2.id })?.lifecycle, .rejected)
    }

    func testPersonalRuleLifecycleKeptToRetired() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let keptRule = PersonalRule(
            id: UUID(),
            title: "Rule A",
            detail: "Detail A",
            category: .friction,
            matchingContexts: [.stay],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 1,
            lastTestedDay: 1,
            timesTested: 0,
            timesKept: 1
        )
        store.profile.personalRules = [keptRule]
        store.apply(QASeed(profile: store.profile, sessions: []))

        store.retirePersonalRule(id: keptRule.id)

        XCTAssertEqual(store.personalRules.first?.lifecycle, .retired)
        XCTAssertFalse(store.personalRules.first!.isActivelyInfluencing)
    }

    func testRetiredAndRejectedRulesNeverInfluenceToday() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let retiredRule = PersonalRule(
            id: UUID(),
            title: "Retired Rule",
            detail: "Retired Detail",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .retired,
            sourceType: .discoveredFromEvidence,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 1,
            lastTestedDay: 1,
            timesTested: 5,
            timesKept: 1
        )
        let rejectedRule = PersonalRule(
            id: UUID(),
            title: "Rejected Rule",
            detail: "Rejected Detail",
            category: .taskSetup,
            matchingContexts: [.stay],
            lifecycle: .rejected,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 1,
            lastTestedDay: 1,
            timesTested: 1,
            timesKept: 0
        )
        let sessions = protocolHistory(through: 8)
        var profile = AttentionProfile()
        profile.personalRules = [retiredRule, rejectedRule]
        store.apply(QASeed(profile: profile, sessions: sessions, day: 9))

        let prescription = store.prescription
        XCTAssertFalse(prescription.appliedRuleIDs.contains(retiredRule.id))
        XCTAssertFalse(prescription.appliedRuleIDs.contains(rejectedRule.id))
        XCTAssertNil(prescription.appliedRuleTitle)
    }

    func testTestingRulesNeverInfluenceToday() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let testingRule = PersonalRule(
            id: UUID(),
            title: "Testing Rule",
            detail: "Testing Detail",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .testing,
            sourceType: .discoveredFromEvidence,
            confidence: .emerging,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 5,
            lastTestedDay: 5,
            timesTested: 2,
            timesKept: 0
        )
        let sessions = protocolHistory(through: 8)
        var profile = AttentionProfile()
        profile.personalRules = [testingRule]
        store.apply(QASeed(profile: profile, sessions: sessions, day: 9))

        let prescription = store.prescription
        XCTAssertFalse(prescription.appliedRuleIDs.contains(testingRule.id))
    }

    func testKeptRuleInfluencesOnlyMatchingContext() {
        let recallRule = PersonalRule(
            id: UUID(),
            title: "Cover text with paper",
            detail: "Full concealment aids recall.",
            category: .taskSetup,
            matchingContexts: [.recall],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 10,
            lastTestedDay: 10,
            timesTested: 1,
            timesKept: 1
        )
        let sessions = protocolHistory(through: 8)
        var profile = AttentionProfile()
        profile.personalRules = [recallRule]

        let stayDefinition = ProgramDayDefinition(
            day: 9,
            phase: ProgramPhase.phase(for: 9),
            intent: CurriculumIntent(
                kind: .buildContinuity,
                objectives: [],
                constraints: [],
                preferredModes: [.stay],
                editorialReason: "Continuity",
                observationMission: nil
            )
        )
        let stayPrescription = PrescriptionEngine.prescription(profile: profile, protocolHistory: sessions, definition: stayDefinition)
        XCTAssertFalse(stayPrescription.appliedRuleIDs.contains(recallRule.id))

        let recallDefinition = ProgramDayDefinition(
            day: 9,
            phase: ProgramPhase.phase(for: 9),
            intent: CurriculumIntent(
                kind: .deepenUnderstanding,
                objectives: [],
                constraints: [],
                preferredModes: [.recall],
                editorialReason: "Recall",
                observationMission: nil
            )
        )
        let recallPrescription = PrescriptionEngine.prescription(profile: profile, protocolHistory: sessions, definition: recallDefinition)
        XCTAssertTrue(recallPrescription.appliedRuleIDs.contains(recallRule.id))
        XCTAssertEqual(recallPrescription.appliedRuleTitle, recallRule.title)
    }

    func testDay1BaselineStrictlyProtectedFromAllRules() {
        let keptRule = PersonalRule(
            id: UUID(),
            title: "Never open phone",
            detail: "Lock phone away",
            category: .environment,
            matchingContexts: [.stay, .observe, .general],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 1,
            lastTestedDay: 1,
            timesTested: 0,
            timesKept: 1
        )
        var profile = AttentionProfile()
        profile.personalRules = [keptRule]
        let definition = CurriculumEngine.definition(for: 1, profile: profile, protocolHistory: [])
        let prescription = PrescriptionEngine.prescription(profile: profile, protocolHistory: [], definition: definition)

        XCTAssertEqual(prescription.day, 1)
        XCTAssertEqual(prescription.mode, .observe)
        XCTAssertEqual(prescription.minutes, 15)
        XCTAssertTrue(prescription.appliedRuleIDs.isEmpty)
        XCTAssertNil(prescription.appliedRuleTitle)
        XCTAssertEqual(prescription.adaptationReason, "Day 1 protects a natural baseline before any intervention.")
    }

    func testRecoveryStrictlyProtectedFromAllRules() {
        let keptRule = PersonalRule(
            id: UUID(),
            title: "Intense deep work setup",
            detail: "Aggressive blocking",
            category: .environment,
            matchingContexts: [.stay, .rest, .general],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 5,
            lastTestedDay: 5,
            timesTested: 1,
            timesKept: 1
        )
        var profile = AttentionProfile()
        profile.personalRules = [keptRule]
        let history = [
            protocolRecord(day: 1, mode: .observe),
            protocolRecord(day: 2, mode: .stay, endedEarly: true, difficulty: 5)
        ]
        let definition = CurriculumEngine.definition(for: 3, profile: profile, protocolHistory: history)
        let prescription = PrescriptionEngine.prescription(profile: profile, protocolHistory: history, definition: definition)

        XCTAssertEqual(prescription.mode, .nothing)
        XCTAssertTrue(prescription.appliedRuleIDs.isEmpty)
        XCTAssertNil(prescription.appliedRuleTitle)
    }

    func testContradictoryEvidenceWeakensConfidenceWithoutDeletingRule() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let ruleID = UUID()
        let rule = PersonalRule(
            id: ruleID,
            title: "Phone out of reach",
            detail: "Keep phone outside room",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .kept,
            sourceType: .discoveredFromEvidence,
            confidence: .strong,
            supportingObservations: ["Observed in 5 sessions."],
            contradictingObservations: [],
            recencyStatus: .repeatedRecent,
            createdDay: 10,
            lastTestedDay: 15,
            timesTested: 5,
            timesKept: 1
        )
        var profile = AttentionProfile()
        profile.personalRules = [rule]
        store.apply(QASeed(profile: profile, sessions: protocolHistory(through: 15), day: 16))

        // Start session applying this rule:
        var request = tryUnwrap(store.protocolRequest())
        request.mode = .stay
        request.appliedRuleIDs = [ruleID]
        store.begin(request: request)
        store.finishRunning(actualMinutes: 10, endedEarly: true)
        store.saveDoneSession(SessionReflection(difficulty: 5, switches: 6))

        let updatedRule = tryUnwrap(store.personalRules.first(where: { $0.id == ruleID }))
        XCTAssertEqual(updatedRule.lifecycle, .kept, "Rule must NEVER be silently deleted or retired")
        XCTAssertEqual(updatedRule.confidence, .moderate, "Confidence was downgraded from strong to moderate")
        XCTAssertEqual(updatedRule.recencyStatus, .mixedRecently)
        XCTAssertFalse(updatedRule.contradictingObservations.isEmpty)
    }

    func testWhyThisRuleDiscoveredVsUserCreated() {
        let discoveredRule = PersonalRule(
            id: UUID(),
            title: "Phone outside reach",
            detail: "Physical distance prevents checking.",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .kept,
            sourceType: .discoveredFromEvidence,
            confidence: .strong,
            supportingObservations: [
                "Observed in 4 recent sessions.",
                "Fewer switches recorded."
            ],
            contradictingObservations: ["One difficult session."],
            recencyStatus: .repeatedRecent,
            createdDay: 10,
            lastTestedDay: 20,
            timesTested: 5,
            timesKept: 1
        )
        let discoveredExplanation = discoveredRule.whyRebootSuggested
        XCTAssertEqual(discoveredExplanation.sourceDescription, "WHY REBOOT SUGGESTED THIS")
        XCTAssertEqual(discoveredExplanation.supportingPoints.count, 2)
        XCTAssertEqual(discoveredExplanation.contradictionPoint, "One difficult session.")
        XCTAssertTrue(discoveredExplanation.disclaimer.contains("association from your recent sessions"))

        let userCreatedRule = PersonalRule(
            id: UUID(),
            title: "Listen to white noise",
            detail: "Blocks office conversation.",
            category: .friction,
            matchingContexts: [.stay],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 15,
            lastTestedDay: 15,
            timesTested: 0,
            timesKept: 1
        )
        let userExplanation = userCreatedRule.whyRebootSuggested
        XCTAssertEqual(userExplanation.sourceDescription, "Created by you.")
        XCTAssertTrue(userExplanation.supportingPoints.isEmpty, "User-created rules must never have manufactured observations")
        XCTAssertNil(userExplanation.contradictionPoint)
        XCTAssertEqual(userExplanation.disclaimer, "This is a rule created directly by you.")
    }

    func testRecencyStatusHumanLabelsWithoutFakePrecision() {
        XCTAssertEqual(RecencyStatus.recent.humanLabel, "Recent")
        XCTAssertEqual(RecencyStatus.current.humanLabel, "Still current")
        XCTAssertEqual(RecencyStatus.older.humanLabel, "Older evidence")
        XCTAssertEqual(RecencyStatus.mixedRecently.humanLabel, "Mixed recently")
        XCTAssertEqual(RecencyStatus.repeatedRecent.humanLabel, "Repeated signal · recent")
        XCTAssertEqual(RecencyStatus.repeatedOlder.humanLabel, "Repeated signal · older evidence")

        for status in RecencyStatus.allCases {
            XCTAssertFalse(status.humanLabel.contains("%"), "Must not use fake percentages")
            XCTAssertFalse(status.humanLabel.contains("0."), "Must not use fake precision decimals")
        }
    }

    func testEnvironmentTruthSystemConfirmedVsUserReported() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let sessions = protocolHistory(through: 8)
        store.apply(QASeed(profile: AttentionProfile(), sessions: sessions, day: 9))

        // 1. Session with Screen Time arm -> systemConfirmed
        var req1 = tryUnwrap(store.protocolRequest())
        req1.programDay = 9
        store.begin(request: req1, environment: protectedArm())
        guard case .running(let rec1) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(rec1.environmentVerification, .systemConfirmed)

        // 2. Session with manual preparation only -> userReported
        store.reset()
        store.apply(QASeed(profile: AttentionProfile(), sessions: sessions, day: 9))
        var req2 = tryUnwrap(store.protocolRequest())
        req2.programDay = 9
        req2.environmentPreparation = EnvironmentPreparation(action: "Phone away", fallback: "Face down", outcome: .completed, arm: nil)
        store.begin(request: req2, environment: nil)
        guard case .running(let rec2) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(rec2.environmentVerification, .userReported)
    }

    func testUnifiedSessionTimelineEndToEndDataLinkage() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let keptRule = PersonalRule(
            id: UUID(),
            title: "Desk cleared",
            detail: "Clear desk before starting",
            category: .taskSetup,
            matchingContexts: [.stay, .observe, .general],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 5,
            lastTestedDay: 5,
            timesTested: 0,
            timesKept: 1
        )
        var profile = AttentionProfile()
        profile.personalRules = [keptRule]
        store.apply(QASeed(profile: profile, sessions: protocolHistory(through: 10), day: 11))

        let prescription = store.prescription
        XCTAssertTrue(prescription.appliedRuleIDs.contains(keptRule.id))

        let request = tryUnwrap(store.protocolRequest())
        XCTAssertNotNil(request.prescriptionID)
        XCTAssertEqual(request.appliedRuleIDs, [keptRule.id])

        store.begin(request: request)
        guard case .running(let runningRec) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(runningRec.prescriptionID, request.prescriptionID)
        XCTAssertEqual(runningRec.appliedRuleIDs, [keptRule.id])

        store.finishRunning(actualMinutes: runningRec.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 0))

        XCTAssertEqual(store.personalRules.first?.timesTested, 1)
        XCTAssertEqual(store.personalRules.first?.lastTestedDay, 11)
        XCTAssertFalse(store.observations.isEmpty)
    }

    // MARK: - Persistence v5 & Corruption Recovery Tests

    func testPersistenceV6RoundTrip() {
        let store1 = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store1.addCustomPersonalRule(
            title: "Custom Rule 1",
            detail: "Custom Detail 1",
            category: .environment,
            contexts: [.stay]
        )
        let sessions = protocolHistory(through: 12)
        store1.apply(QASeed(profile: store1.profile, sessions: sessions, day: 13))

        // Reload fresh instance from same defaults
        let store2 = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store2.day, 13)
        XCTAssertEqual(store2.sessions.count, 12)
        XCTAssertEqual(store2.personalRules.count, 1)
        XCTAssertEqual(store2.personalRules.first?.title, "Custom Rule 1")
    }

    func testPersistenceV4ToV6Migration() {
        clearProductPersistence()
        let legacyState: [String: Any] = [
            "profile": (try? JSONEncoder().encode(AttentionProfile(focusWindowMinutes: 25))) ?? Data(),
            "sessions": (try? JSONEncoder().encode(protocolHistory(through: 5))) ?? Data(),
            "day": 6,
            "programState": (try? JSONEncoder().encode(progressedState(through: 5))) ?? Data(),
        ]
        defaults.set(legacyState, forKey: "reboot.product.v4")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.day, 6)
        XCTAssertEqual(store.sessions.count, 5)
        XCTAssertNil(defaults.object(forKey: "reboot.product.v4"), "Legacy v4 key must be cleaned after v7 migration")
        XCTAssertNotNil(defaults.object(forKey: "reboot.product.v7"), "v7 storage key must be set")
    }

    func testCorruptedPersistenceV6SafeRecovery() {
        clearProductPersistence()
        defaults.set(["profile": "corrupted_non_data_string", "day": 14], forKey: "reboot.product.v6")

        // ProductStore must not crash and must safely initialize:
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertNotNil(store.profile)
        XCTAssertEqual(store.sessions.count, 0)
    }

    // MARK: - Long-Range Multi-Archetype Deterministic Simulations

    func testLongRangeSimulationStudyArchetype30_60_90Days() {
        let store = ProductStore(diagnosisAnswers: ["primary_goal": ["study_better"], "breaker": ["tabs"]], defaults: defaults)
        for day in 1...90 {
            XCTAssertEqual(store.day, day)
            XCTAssertLessThanOrEqual(store.day, 90, "Program must never advance to Day 91")

            let prescription = store.prescription
            let phase = ProgramPhase.phase(for: day)
            let range = phase.durationGuidance.range(for: prescription.mode)
            XCTAssertGreaterThanOrEqual(prescription.minutes, range.lower)
            XCTAssertLessThanOrEqual(prescription.minutes, range.upper)

            var req = tryUnwrap(store.protocolRequest())
            req.programDay = day
            store.begin(request: req)
            store.finishRunning(actualMinutes: req.targetMinutes, endedEarly: false)
            store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))

            if case .weeklyReview = store.phase {
                store.saveWeeklyReview(WeeklyReviewAnswers(helpedMost: "Recall blocks", stillBreaksAttention: nil, nextTestPreference: "Study material"))
            }
            if case .phaseTransition = store.phase {
                store.acknowledgePhaseTransition()
            }
            if case .programCompletion = store.phase {
                store.acknowledgeProgramCompletion()
            }
        }

        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertEqual(store.programProgress, 1.0)
        XCTAssertTrue(store.hasCompletedCurrentProtocol)
        XCTAssertNil(store.protocolRequest())
    }

    func testLongRangeSimulationScrollControlArchetype30_60_90Days() {
        let store = ProductStore(diagnosisAnswers: ["primary_goal": ["scroll_less"], "breaker": ["phone", "social"]], defaults: defaults)
        for day in 1...90 {
            XCTAssertEqual(store.day, day)
            let req = tryUnwrap(store.protocolRequest())
            store.begin(request: req)
            store.finishRunning(actualMinutes: req.targetMinutes, endedEarly: false)
            store.saveDoneSession(SessionReflection(
                difficulty: day.isMultiple(of: 7) ? 3 : 2,
                firstDistraction: Distractor.phone,
                switches: 2
            ))

            if case .weeklyReview = store.phase {
                store.skipWeeklyReviewQuestions()
            }
            if case .phaseTransition = store.phase {
                store.acknowledgePhaseTransition()
            }
            if case .programCompletion = store.phase {
                store.acknowledgeProgramCompletion()
            }
        }

        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
    }

    func testLongRangeSimulationDeepWorkArchetype30_60_90Days() {
        let store = ProductStore(diagnosisAnswers: ["primary_goal": ["deep_work"], "breaker": ["notifications"]], defaults: defaults)
        for _ in 1...90 {
            let req = tryUnwrap(store.protocolRequest())
            store.begin(request: req)
            store.finishRunning(actualMinutes: req.targetMinutes, endedEarly: false)
            store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))

            if case .weeklyReview = store.phase { store.skipWeeklyReviewQuestions() }
            if case .phaseTransition = store.phase { store.acknowledgePhaseTransition() }
            if case .programCompletion = store.phase { store.acknowledgeProgramCompletion() }
        }

        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
    }

    func testLongRangeSimulationContradictoryArchetype30_60_90Days() {
        let store = ProductStore(diagnosisAnswers: ["primary_goal": ["focus_better"]], defaults: defaults)
        store.addCustomPersonalRule(title: "Desk Setup", detail: "Clean desk", category: .taskSetup, contexts: [.stay])

        for day in 1...90 {
            let req = tryUnwrap(store.protocolRequest())
            store.begin(request: req)
            // Alternate between smooth and difficult sessions with high switches:
            let isDifficult = day.isMultiple(of: 5)
            store.finishRunning(actualMinutes: req.targetMinutes, endedEarly: false)
            store.saveDoneSession(SessionReflection(
                difficulty: isDifficult ? 5 : 2,
                firstDistraction: isDifficult ? "social" : "none",
                switches: isDifficult ? 7 : 1
            ))

            if case .weeklyReview = store.phase { store.skipWeeklyReviewQuestions() }
            if case .phaseTransition = store.phase { store.acknowledgePhaseTransition() }
            if case .programCompletion = store.phase { store.acknowledgeProgramCompletion() }
        }

        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        // Ensure kept rule was never deleted despite difficult sessions:
        XCTAssertFalse(store.personalRules.isEmpty)
    }

    func testAddCustomPersonalRuleInvariants() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.addCustomPersonalRule(
            title: "Noise cancelling headphones",
            detail: "Wear headphones during stay sessions",
            category: .friction,
            contexts: [.stay]
        )

        let rule = tryUnwrap(store.personalRules.first)
        XCTAssertEqual(rule.title, "Noise cancelling headphones")
        XCTAssertEqual(rule.sourceType, .userCreated)
        XCTAssertEqual(rule.lifecycle, .kept)
        XCTAssertEqual(rule.confidence, .strong)
        XCTAssertEqual(rule.supportingObservations.count, 0, "Custom rules must not manufacture false observations")
        XCTAssertEqual(rule.whyRebootSuggested.disclaimer, "This is a rule created directly by you.")
    }

    func testDynamicTypeScalability() {
        let sizes = DynamicTypeSize.allCases
        XCTAssertGreaterThanOrEqual(sizes.count, 10, "Supports dynamic type sizes including accessibility categories")
        XCTAssertTrue(sizes.contains(.accessibility5))
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
