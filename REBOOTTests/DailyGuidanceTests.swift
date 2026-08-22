import XCTest
@testable import REBOOT

@MainActor
final class DailyGuidanceTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "reboot.dailyguidance.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "reboot.dailyguidance.tests.\(UUID().uuidString)")
        defaults = nil
        super.tearDown()
    }

    // MARK: - 1. Day 1 Baseline Priority

    func testDayOneAlwaysPrioritizesNaturalBaseline() {
        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 1,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.primaryAction.mode, .observe)
        XCTAssertEqual(guidance.primaryAction.targetMinutes, 10)
        XCTAssertNil(guidance.environmentAction)
        XCTAssertNil(guidance.fuelPrompt)
        XCTAssertNil(guidance.flowOpportunity)
        XCTAssertNil(guidance.experimentOpportunityID)
        XCTAssertEqual(guidance.bottleneck, .starting)
        XCTAssertTrue(guidance.suppressedOpportunities.contains("Fuel Prompt"))
    }

    // MARK: - 2. Recovery Priority

    func testRecoveryPriorityGroundedInFailedOrInterruptedSession() {
        let s1 = SessionRecord(day: 3, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 6, completed: true, endedEarly: true, switches: 4)

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 4,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [s1],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: true,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.bottleneck, .recovery)
        XCTAssertEqual(guidance.primaryAction.mode, .nothing)
        XCTAssertEqual(guidance.primaryAction.kind, .recoverySession)
        XCTAssertNil(guidance.flowOpportunity)
        XCTAssertNil(guidance.experimentOpportunityID)
        XCTAssertNil(guidance.fuelPrompt)
    }

    // MARK: - 3. Single Bottleneck Selection

    func testSingleBottleneckSelectedAtATime() {
        var digitalEnv = DigitalEnvironmentState.empty
        digitalEnv.profile.primaryDigitalPull = EnvironmentDimension(value: .socialMedia, confidence: 0.8, evidenceCount: 4)
        digitalEnv.profile.phoneProximity = EnvironmentDimension(value: .inHand, confidence: 0.8, evidenceCount: 4)

        let s1 = SessionRecord(day: 2, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 3)
        let s2 = SessionRecord(day: 3, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 10, completed: true, endedEarly: true, switches: 2)

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 4,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [s1, s2],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: digitalEnv,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.bottleneck, .digitalPull)
        XCTAssertNotNil(guidance.environmentAction)
    }

    // MARK: - 4. Anti-Oscillation and Hysteresis

    func testAntiOscillationAndHysteresisPreservesStrategyAcrossConsecutiveDays() {
        let prevDecision = GuidanceDecision(
            programDay: 4,
            bottleneck: .stability,
            selectedAction: "Maintain steady continuity",
            evidenceIDs: []
        )

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 5,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [SessionRecord(day: 4, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 1)],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [prevDecision],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.bottleneck, .stability)
    }

    // MARK: - 5. No Overload (Before-Session Burden)

    func testNoOverloadBeforeSessionBurden() {
        var flow = FlowState.empty
        var project = FlowProject(title: "Research Paper", category: .writing)
        project.status = .active
        project.recentBlockIDs = [UUID(), UUID()]
        flow.projects.append(project)

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 15,
            programStatus: .active,
            programPhase: ProgramPhase.all[2],
            profile: AttentionProfile(),
            sessions: [
                SessionRecord(day: 13, date: Date(), mode: .stay, targetMinutes: 25, actualMinutes: 25, completed: true, switches: 0),
                SessionRecord(day: 14, date: Date(), mode: .stay, targetMinutes: 25, actualMinutes: 25, completed: true, switches: 0)
            ],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: flow,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.primaryAction.kind, .projectFlowBlock)
        XCTAssertNil(guidance.fuelPrompt)
        XCTAssertTrue(guidance.suppressedOpportunities.contains(where: { $0.contains("Fuel Prompt") }))
    }

    // MARK: - 6. Personal Rules as Setup Policy

    func testPersonalRulesServeAsSetupPolicy() {
        let rule = PersonalRule(
            title: "Phone in other room",
            detail: "Keep physical distance before starting deep work",
            category: .environment,
            matchingContexts: [.stay],
            lifecycle: .kept,
            sourceType: .discoveredFromEvidence,
            confidence: .strong,
            supportingObservations: ["Observed 3x"],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 1,
            timesTested: 3,
            timesKept: 3
        )

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 6,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [SessionRecord(day: 5, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true, switches: 0)],
            personalRules: [rule],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.environmentAction?.title, "Phone in other room")
    }

    // MARK: - 7. Fuel Context Modulates Demand

    func testFuelContextModulatesDurationWithoutLifestylePrescription() {
        var fuel = FuelState.empty
        fuel.pendingCapture = FuelContextSnapshot(energy: .low)

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 6,
            programStatus: .active,
            programPhase: ProgramPhase.all[0],
            profile: AttentionProfile(),
            sessions: [
                SessionRecord(day: 5, date: Date(), mode: .stay, targetMinutes: 25, actualMinutes: 10, completed: true, endedEarly: true, switches: 3)
            ],
            personalRules: [],
            labExperiments: [],
            fuelState: fuel,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState()
        )

        XCTAssertEqual(guidance.bottleneck, .energyContext)
        XCTAssertLessThanOrEqual(guidance.primaryAction.targetMinutes, 15)
        XCTAssertTrue(guidance.explanation.contains("energy is low"))
    }

    // MARK: - 8. Day 90 Operating Manual Generation

    func testDayNinetyGeneratesAttentionOperatingManualFromRawEvidence() {
        var digitalEnv = DigitalEnvironmentState.empty
        digitalEnv.profile.primaryDigitalPull = EnvironmentDimension(value: .messaging, confidence: 0.85, evidenceCount: 12)
        digitalEnv.profile.phoneProximity = EnvironmentDimension(value: .outsideRoom, confidence: 0.9, evidenceCount: 15)
        digitalEnv.interruptionEvents = [
            InterruptionEvent(sessionID: UUID(), programDay: 1, mode: .stay, trigger: .habit, digitalCategory: .messaging, returnObserved: true),
            InterruptionEvent(sessionID: UUID(), programDay: 2, mode: .stay, trigger: .habit, digitalCategory: .messaging, returnObserved: true)
        ]

        let manual = AttentionOperatingManualEngine.generateManual(
            sessions: (1...90).map { day in
                SessionRecord(day: day, date: Date(), mode: .stay, targetMinutes: 30, actualMinutes: 30, completed: true, switches: 0)
            },
            interruptionEvents: digitalEnv.interruptionEvents,
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: digitalEnv,
            profile: AttentionProfile()
        )

        XCTAssertEqual(manual.totalProtocolDays, 90)
        XCTAssertEqual(manual.howIStartBest.maturity, .repeatedSignal)
        XCTAssertTrue(manual.myMostCommonBreakers.statement.contains("Messaging"))
        XCTAssertTrue(manual.myDigitalEnvironment.statement.contains("Outside the room"))
        XCTAssertFalse(manual.whatRebootStillDoesNotKnow.isEmpty)
    }

    // MARK: - 9. No Day 91 in Own Mode

    func testNoDayNinetyOneGeneratedAfterProgramCompletion() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(day: 90, phase: "today"))

        var prog = store.programState
        prog.status = .completed
        prog.currentDay = 90
        prog.pendingCompletion = false

        let guidance = DailyGuidanceEngine.generateGuidance(
            day: 90,
            programStatus: .completed,
            programPhase: ProgramPhase.all.last!,
            profile: store.profile,
            sessions: (1...90).map { SessionRecord(day: $0, date: Date(), mode: .stay, targetMinutes: 30, actualMinutes: 30, completed: true) },
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: [],
            ownModeState: OwnModeState(active: true)
        )

        XCTAssertTrue(guidance.isOwnMode)
        XCTAssertEqual(guidance.primaryAction.kind, .ownModeSession)
    }

    // MARK: - 10. Operating Manual Export

    func testOperatingManualExportAsText() {
        let manual = AttentionOperatingManualEngine.generateManual(
            sessions: (1...90).map { SessionRecord(day: $0, date: Date(), mode: .stay, targetMinutes: 25, actualMinutes: 25, completed: true) },
            interruptionEvents: [],
            personalRules: [],
            labExperiments: [],
            fuelState: .empty,
            flowState: .empty,
            digitalEnvironmentState: .empty,
            profile: AttentionProfile()
        )

        let exportText = manual.exportAsText()
        XCTAssertTrue(exportText.contains("REBOOT — ATTENTION OPERATING MANUAL"))
        XCTAssertTrue(exportText.contains("1. HOW I START BEST"))
        XCTAssertTrue(exportText.contains("11. WHAT REBOOT STILL DOESN'T KNOW"))
    }

    // MARK: - 11. Persistence V9 Round-Trip

    func testPersistenceV9RoundTrip() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let decision = GuidanceDecision(
            programDay: 5,
            bottleneck: .stability,
            selectedAction: "Stay with 20min block",
            evidenceIDs: []
        )
        store.guidanceDecisions.append(decision)
        store.ownModeState = OwnModeState(active: true, enteredAt: Date(), lastGuidanceDate: Date(), preferredDurations: [35, 50], focusThemes: ["Deep Coding"])
        store.persist()

        let store2 = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store2.guidanceDecisions.count, 1)
        XCTAssertEqual(store2.guidanceDecisions.first?.bottleneck, .stability)
        XCTAssertTrue(store2.ownModeState.active)
        XCTAssertEqual(store2.ownModeState.preferredDurations, [35, 50])
    }
}
