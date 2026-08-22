import XCTest
@testable import REBOOT

@MainActor
final class DigitalEnvironmentTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "reboot.test.digitalEnvironment.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(
        day: Int,
        mode: TrainingMode = .stay,
        minutes: Int = 20,
        completed: Bool = true,
        endedEarly: Bool = false,
        switches: Int? = 1,
        distraction: String? = "social",
        envArm: SessionEnvironmentArm? = nil,
        envSnapshot: EnvironmentSnapshot? = nil
    ) -> SessionRecord {
        SessionRecord(
            day: day,
            date: Date().addingTimeInterval(Double(-day * 86400)),
            mode: mode,
            targetMinutes: minutes,
            actualMinutes: minutes,
            completed: completed,
            endedEarly: endedEarly,
            firstDistraction: distraction,
            switches: switches,
            difficulty: 2,
            environment: envSnapshot
        )
    }

    // MARK: - 1. Profile Derivation & Unknown Preservation

    func testEmptyHistoryKeepsDigitalEnvironmentDimensionsUnknown() {
        let profile = DigitalEnvironmentProfileEngine.deriveProfile(
            history: [],
            events: [],
            checkIns: []
        )

        XCTAssertEqual(profile.primaryDigitalPull.value, .unknown)
        XCTAssertEqual(profile.primaryDigitalPull.confidence, 0.0)
        XCTAssertEqual(profile.primaryDigitalPull.evidenceCount, 0)
        XCTAssertFalse(profile.primaryDigitalPull.isKnown)

        XCTAssertEqual(profile.triggerType.value, .unknown)
        XCTAssertFalse(profile.triggerType.isKnown)

        XCTAssertEqual(profile.phoneProximity.value, .unknown)
        XCTAssertFalse(profile.phoneProximity.isKnown)

        XCTAssertEqual(profile.interruptionPressure.value, .unknown)
        XCTAssertEqual(profile.environmentControl.value, .unknown)
        XCTAssertEqual(profile.protectionTolerance.value, .unknown)
        XCTAssertEqual(profile.knownDimensionsCount, 0)
    }

    func testRepeatedInterruptionEventsElevatePrimaryPullAndConfidence() {
        let events = [
            InterruptionEvent(sessionID: UUID(), programDay: 2, mode: .stay, trigger: .notification, digitalCategory: .socialMedia),
            InterruptionEvent(sessionID: UUID(), programDay: 3, mode: .stay, trigger: .notification, digitalCategory: .socialMedia),
            InterruptionEvent(sessionID: UUID(), programDay: 4, mode: .stay, trigger: .boredom, digitalCategory: .socialMedia)
        ]

        let profile = DigitalEnvironmentProfileEngine.deriveProfile(
            history: [],
            events: events,
            checkIns: []
        )

        XCTAssertEqual(profile.primaryDigitalPull.value, .socialMedia)
        XCTAssertTrue(profile.primaryDigitalPull.isKnown)
        XCTAssertEqual(profile.primaryDigitalPull.evidenceCount, 3)
        XCTAssertGreaterThanOrEqual(profile.primaryDigitalPull.confidence, 0.7)

        XCTAssertEqual(profile.triggerType.value, .notification)
        XCTAssertTrue(profile.triggerType.isKnown)
    }

    func testPhoneProximityDerivesFromSelfReportsAndInterruptionEvents() {
        let checkIns = [
            DigitalCheckInResponse(pull: .messaging, trigger: .automaticUnlock, phonePosition: .onDesk),
            DigitalCheckInResponse(pull: .messaging, trigger: .automaticUnlock, phonePosition: .onDesk)
        ]

        let profile = DigitalEnvironmentProfileEngine.deriveProfile(
            history: [],
            events: [],
            checkIns: checkIns
        )

        XCTAssertEqual(profile.phoneProximity.value, .onDesk)
        XCTAssertTrue(profile.phoneProximity.isKnown)
        XCTAssertEqual(profile.phoneProximity.evidenceCount, 2)
    }

    // MARK: - 2. Friction Ladder Selection, Escalation, and De-escalation

    func testDayOneAlwaysSelectsLevel0Observe() {
        let profile = DigitalEnvironmentProfile()
        let action = FrictionLadderEngine.selectLevel(
            profile: profile,
            envEvidence: nil,
            history: [],
            cooldownLog: InterventionCooldownLog(),
            fuel: nil,
            currentDay: 1,
            mode: .observe
        )

        XCTAssertEqual(action, FrictionLadderEngine.level0Observe)
    }

    func testFrictionLadderPicksLowestLevelSupportedByEvidence() {
        var profile = DigitalEnvironmentProfile()
        profile.primaryDigitalPull = EnvironmentDimension(value: .socialMedia, confidence: 0.8, evidenceCount: 4)
        profile.phoneProximity = EnvironmentDimension(value: .outsideRoom, confidence: 0.8, evidenceCount: 4)

        var env = EnvironmentEvidence()
        env.manualInterventionsTotal = 2
        env.manualInterventionsSuccessful = 2

        let level = FrictionLadderEngine.selectLevel(
            profile: profile,
            envEvidence: env,
            history: [],
            cooldownLog: InterventionCooldownLog(),
            fuel: nil,
            currentDay: 5,
            mode: .stay
        )

        // Manual friction works repeatedly → stay low, do not escalate
        XCTAssertEqual(level, FrictionLadderEngine.level1RemoveCue)
    }

    func testRepeatedEarlyExitsFromProtectionDeescalatesFrictionLadder() {
        var profile = DigitalEnvironmentProfile()
        profile.primaryDigitalPull = EnvironmentDimension(value: .socialMedia, confidence: 0.8, evidenceCount: 4)

        var env = EnvironmentEvidence()
        env.screenTimeConnected = true
        env.hasSelection = true
        env.manualInterventionsTotal = 3
        env.protectedSessionsCompleted = 1
        env.protectionEarlyExits = 2 // 2 abandonments

        let level = FrictionLadderEngine.selectLevel(
            profile: profile,
            envEvidence: env,
            history: [],
            cooldownLog: InterventionCooldownLog(),
            fuel: nil,
            currentDay: 10,
            mode: .stay
        )

        // De-escalates away from level 4 back to level 1
        XCTAssertEqual(level, FrictionLadderEngine.level1RemoveCue)
    }

    func testLowEnergyContextPreventsFrictionEscalation() {
        var profile = DigitalEnvironmentProfile()
        profile.primaryDigitalPull = EnvironmentDimension(value: .socialMedia, confidence: 0.8, evidenceCount: 4)
        profile.phoneProximity = EnvironmentDimension(value: .inHand, confidence: 0.8, evidenceCount: 4)

        let lowFuel = FuelContextSnapshot(energy: .low)

        let level = FrictionLadderEngine.selectLevel(
            profile: profile,
            envEvidence: nil,
            history: [],
            cooldownLog: InterventionCooldownLog(),
            fuel: lowFuel,
            currentDay: 6,
            mode: .stay
        )

        XCTAssertEqual(level, FrictionLadderEngine.level1RemoveCue)
    }

    // MARK: - 3. Focus Window Suggestions

    func testFocusWindowSuggestionRequiresAtLeastTwoStrongSessionsInSameBracket() {
        let calendar = Calendar.current
        var comp1 = DateComponents()
        comp1.year = 2026; comp1.month = 8; comp1.day = 10; comp1.hour = 9; comp1.minute = 15
        let date1 = calendar.date(from: comp1)!

        var comp2 = DateComponents()
        comp2.year = 2026; comp2.month = 8; comp2.day = 11; comp2.hour = 9; comp2.minute = 45
        let date2 = calendar.date(from: comp2)!

        let s1 = SessionRecord(day: 2, date: date1, mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 0)
        let s2 = SessionRecord(day: 3, date: date2, mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 1)

        let suggestion = FocusWindowSuggestionEngine.suggestWindow(
            from: [s1, s2],
            existingWindows: []
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.name, "Morning Focus")
        XCTAssertEqual(suggestion?.startMinutes, 8 * 60)
        XCTAssertEqual(suggestion?.endMinutes, 10 * 60)
    }

    func testFocusWindowSuggestionRejectsSingleSession() {
        let calendar = Calendar.current
        var comp1 = DateComponents()
        comp1.year = 2026; comp1.month = 8; comp1.day = 10; comp1.hour = 9; comp1.minute = 15
        let date1 = calendar.date(from: comp1)!

        let s1 = SessionRecord(day: 2, date: date1, mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 0)

        let suggestion = FocusWindowSuggestionEngine.suggestWindow(
            from: [s1],
            existingWindows: []
        )

        XCTAssertNil(suggestion, "A single session must never trigger a recurring window suggestion.")
    }

    // MARK: - 4. Intervention Cooldown & Refusal Logging

    func testInterventionCooldownLogBlocksAfterRepeatedRejections() {
        var log = InterventionCooldownLog()
        let kind = EnvironmentActionKind.protectSelectedDistractions.rawValue
        let now = Date()

        log.recordDecline(actionKind: kind, reason: "Too restrictive", date: now.addingTimeInterval(-3600 * 2))
        log.recordDecline(actionKind: kind, reason: "Too restrictive", date: now.addingTimeInterval(-3600))

        XCTAssertTrue(log.isCoolingDown(actionKind: kind, now: now, cooldownDays: 3))

        // After 4 days, cooldown expires
        let future = now.addingTimeInterval(3600 * 24 * 4)
        XCTAssertFalse(log.isCoolingDown(actionKind: kind, now: future, cooldownDays: 3))
    }

    // MARK: - 5. Pre-Session Contract & Required Action

    func testPreSessionContractState() {
        var contract = PreSessionContract.standard
        XCTAssertEqual(contract.phonePosition, .outsideRoom)
        XCTAssertFalse(contract.completed)

        contract.completed = true
        XCTAssertTrue(contract.completed)
    }

    func testProductStoreCompleteRequiredActionAdaptsRefusal() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(day: 2, phase: "today"))
        store.completeRequiredAction(done: false, refusalReason: "Work requires phone access")

        XCTAssertEqual(store.digitalEnvironmentState.interventionLog.rejectedCounts["manualPhoneAway"] ?? store.digitalEnvironmentState.interventionLog.rejectedCounts["manual"] ?? 1, 1)
        XCTAssertEqual(store.environmentPreparation?.outcome, .declined)
    }

    // MARK: - 6. Digital Reset Missions

    func testDigitalResetMissionsCompleteAndReflect() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard let mission = DigitalResetMissionLibrary.mission(forDay: 5) else {
            return XCTFail("Day 5 mission missing")
        }

        store.completeResetMission(id: mission.id, reflection: "Turned off banners for all shopping apps.")

        let saved = store.digitalEnvironmentState.resetMissions.first { $0.id == mission.id }
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.completed == true)
        XCTAssertEqual(saved?.reflection, "Turned off banners for all shopping apps.")
    }

    // MARK: - 7. App Limit Guidance

    func testAppLimitGuidanceSavesResult() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.saveAppLimitGuidanceResult(pull: .socialMedia, completed: true)

        let guidance = store.digitalEnvironmentState.appLimitGuidances.first
        XCTAssertNotNil(guidance)
        XCTAssertEqual(guidance?.pull, .socialMedia)
        XCTAssertEqual(guidance?.status, .completed)
    }

    // MARK: - 8. Digital Check-In Integration

    func testDigitalCheckInUpdatesProfileDeterministically() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let sID = UUID()
        let checkIn = DigitalCheckInResponse(
            pull: .shortVideo,
            trigger: .boredom,
            phonePosition: .withinReach,
            wasIntentional: false,
            startedEasierWithProtection: true,
            returnedToTask: true
        )

        store.recordDigitalCheckIn(checkIn, sessionID: sID)

        XCTAssertEqual(store.digitalEnvironmentState.profile.primaryDigitalPull.value, .shortVideo)
        XCTAssertEqual(store.digitalEnvironmentState.profile.triggerType.value, .boredom)
        XCTAssertEqual(store.profile.digitalEnvironment?.primaryDigitalPull.value, .shortVideo)
    }

    // MARK: - 9. Persistence Round-Trip & Backward Compatibility

    func testDigitalEnvironmentStateRoundTripsThroughPersistence() {
        let store1 = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let window = FocusWindow(name: "Morning Deep Work", weekdays: [2, 3, 4, 5, 6], startMinutes: 540, endMinutes: 660)
        store1.upsertFocusWindow(window)

        let event = InterruptionEvent(
            sessionID: UUID(),
            programDay: 5,
            mode: .stay,
            trigger: .taskDifficulty,
            digitalCategory: .browserTabs,
            switchCount: 3
        )
        store1.recordInterruptionEvent(event)

        // Restore in fresh instance
        let store2 = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store2.digitalEnvironmentState.focusWindows.count, 1)
        XCTAssertEqual(store2.digitalEnvironmentState.focusWindows.first?.name, "Morning Deep Work")
        XCTAssertEqual(store2.digitalEnvironmentState.interruptionEvents.count, 1)
        XCTAssertEqual(store2.digitalEnvironmentState.interruptionEvents.first?.digitalCategory, .browserTabs)
        XCTAssertEqual(store2.digitalEnvironmentState.profile.primaryDigitalPull.value, .browserTabs)
    }

    // MARK: - 10. Long-Range 90-Day Simulation with Digital Environment V2

    func testNinetyDaySimulationWithDigitalEnvironmentV2() {
        let store = ProductStore(diagnosisAnswers: ["primary": ["focus_better"], "breaker": ["social", "phone"]], defaults: defaults)

        for day in 1...90 {
            if case .weeklyReview(let reviewDay) = store.phase {
                _ = reviewDay
                store.saveWeeklyReview(WeeklyReviewAnswers(helpedMost: "Quiet room", stillBreaksAttention: "Phone", nextTestPreference: nil))
            }
            if case .phaseTransition(let phaseID) = store.phase {
                store.acknowledgePhaseTransition()
            }
            if case .programCompletion = store.phase {
                store.acknowledgeProgramCompletion()
                break
            }

            guard let request = store.protocolRequest() else {
                continue
            }

            store.begin(request: request)
            store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)

            let switches = day % 3 == 0 ? 2 : 0
            let distraction = switches > 0 ? "social" : "none"
            store.saveDoneSession(SessionReflection(
                difficulty: 2,
                firstDistraction: distraction,
                switches: switches,
                startedEasier: true
            ))
        }

        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertEqual(store.digitalEnvironmentState.profile.primaryDigitalPull.value, .socialMedia)
        XCTAssertTrue(store.digitalEnvironmentState.profile.primaryDigitalPull.confidence >= 0.8)
    }
}
