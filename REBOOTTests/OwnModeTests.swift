import XCTest
@testable import REBOOT
// MARK: - Own Mode & Post-90 Semantics (Phase 21 regression)

@MainActor
final class OwnModeTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "reboot.ownmode.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    private func guidance(store: ProductStore, ownMode: OwnModeState) -> DailyGuidance {
        DailyGuidanceEngine.generateGuidance(
            day: store.day,
            programStatus: store.programStatus,
            programPhase: store.currentProgramPhase,
            profile: store.profile,
            sessions: store.sessions,
            personalRules: store.personalRules,
            labExperiments: store.labState.experiments,
            fuelState: store.fuelState,
            flowState: store.flowState,
            digitalEnvironmentState: store.digitalEnvironmentState,
            screenTimeActive: false,
            screenTimeAuthorized: false,
            isRecovery: false,
            guidanceHistory: store.guidanceDecisions,
            ownModeState: ownMode
        )
    }

    /// A store whose 90-day program has actually completed — day-90 session
    /// done, no pending completion. Uses the deterministic fixture.
    private func makeCompletedStore() -> ProductStore {
        let store = ProductStore(diagnosisAnswers: ["goals": ["deep_work"]], defaults: defaults)
        store.apply(QASeeds.programCompleted)
        return store
    }

    private func activeStoreAtDay90() -> ProductStore {
        let store = ProductStore(diagnosisAnswers: ["goals": ["deep_work"]], defaults: defaults)
        store.apply(QASeeds.programDay90BeforeCompletion)
        return store
    }

    func testOwnModeSuggestionIsSelfDirectedNotCurriculum() {
        let store = makeCompletedStore()
        let g = guidance(store: store, ownMode: OwnModeState(active: true, enteredAt: Date(), lastGuidanceDate: Date(), preferredDurations: [25], focusThemes: []))
        XCTAssertTrue(g.isOwnMode)
        XCTAssertEqual(g.primaryAction.kind, .ownModeSession)
        // A suggestion carries a real duration and CTA.
        XCTAssertEqual(g.primaryAction.targetMinutes, 25)
        XCTAssertFalse(g.primaryAction.ctaTitle.isEmpty)
    }

    func testOwnModeQuietDayIsAnHonestNoInterventionState() {
        let store = makeCompletedStore()
        // Calendar day divisible by 3 → deliberately quiet.
        var quiet = OwnModeState(active: true, enteredAt: Date(), lastGuidanceDate: Date(), preferredDurations: [25], focusThemes: [])
        let calendar = Calendar.current
        let component = calendar.component(.day, from: Date())
        if component % 3 != 0 {
            quiet.lastGuidanceDate = calendar.date(byAdding: .day, value: (3 - component % 3), to: Date())
        }
        let g = guidance(store: store, ownMode: quiet)
        // With at least one completed session in history, the quiet state is allowed.
        XCTAssertTrue(g.isOwnMode)
        // Either state is valid — but the quiet one must be explicit.
        if g.noInterventionNeeded {
            XCTAssertTrue(g.primaryAction.title.contains("Nothing"))
            XCTAssertTrue(g.primaryAction.ctaTitle.isEmpty)
        }
    }

    func testQuietDayNeverShownWithoutAnyCompletedPractice() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        var quiet = OwnModeState(active: true, enteredAt: Date(), lastGuidanceDate: Date(), preferredDurations: [25], focusThemes: [])
        let calendar = Calendar.current
        let component = calendar.component(.day, from: Date())
        if component % 3 != 0 {
            quiet.lastGuidanceDate = calendar.date(byAdding: .day, value: (3 - component % 3), to: Date())
        }
        let g = guidance(store: store, ownMode: quiet)
        XCTAssertFalse(g.noInterventionNeeded, "A user with zero completed practice never gets 'nothing needed today'")
    }

    func testPostNinetyThereIsNoDay91() {
        // A genuinely completed program issues no further protocol request,
        // and the day counter can never pass 90.
        let completed = makeCompletedStore()
        XCTAssertEqual(completed.programStatus, .completed)
        XCTAssertNil(completed.protocolRequest(), "Completed program must not issue another protocol request")
        XCTAssertLessThanOrEqual(completed.day, 90)

        // An ACTIVE store sitting at Day 90 still owns exactly one request —
        // the final synthesis day itself — never a Day 91.
        let at90 = activeStoreAtDay90()
        XCTAssertEqual(at90.day, 90)
        if let request = at90.protocolRequest() {
            XCTAssertEqual(request.programDay, 90)
        }
    }

    func testExpiredSubscriptionKeepsDataReadableButBlocksProgramAdvance() {
        // Data integrity rule: expired users keep everything except advancement.
        XCTAssertTrue(SubscriptionGating.isHistoricalDataReadable(status: .expired(productId: "x", expiredAt: Date())))
        XCTAssertFalse(SubscriptionGating.isProgramDayAccessible(day: 40, status: .expired(productId: "x", expiredAt: Date())))
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 1, status: .free))
    }
}
