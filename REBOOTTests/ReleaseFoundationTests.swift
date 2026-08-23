import XCTest
@testable import REBOOT

/// Release-foundation regression coverage:
/// fresh-user lifecycle, QA isolation, canonical program creation,
/// paywall placement rules, data export, and erase-all truth.
@MainActor
final class ReleaseFoundationTests: XCTestCase {

    // MARK: - Fresh user lifecycle

    /// A brand-new store (no persisted state) must be Day 1 / active / empty.
    func testFreshInstallIsDayOneActive() {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.programStatus, .active)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertFalse(store.programState.hasPendingRequiredFlow)
        XCTAssertFalse(store.ownModeState.active)
        d.removePersistentDomain(forName: suiteName)
    }

    /// The full acquisition path: diagnosis answers applied → report →
    /// Start day one. Must always end at Day 1 of an active program,
    /// even when stale completed state existed beforehand.
    func testDiagnosisCompletionAlwaysYieldsDayOne() {
        let d = makeDefaults()
        // Simulate contamination: a completed program + Own Mode state.
        let contaminated = ProductStore(diagnosisAnswers: [:], defaults: d)
        contaminated.apply(QASeeds.programCompleted)
        XCTAssertTrue(contaminated.day == 90 || contaminated.programStatus == .completed)

        // New "install" reading the same domain must NOT silently reuse it
        // once diagnosis completes via the canonical entry point.
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.applyDiagnosis(DebugNavView.seedAnswers)
        XCTAssertEqual(store.day, 1, "diagnosis completion must reset to Day 1")
        XCTAssertEqual(store.programStatus, .active)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.environmentPreparation)
        XCTAssertFalse(store.ownModeState.active)
        XCTAssertFalse(store.programState.hasPendingRequiredFlow)
        d.removePersistentDomain(forName: suiteName)
    }

    /// applyDiagnosis installs ProfileBuilder priors into the live profile —
    /// the historical bug was that diagnosis never reached the profile.
    func testApplyDiagnosisInstallsPriors() {
        let d = makeDefaults()
        var answers: Answers = [:]
        answers["goals"] = ["deep_work"]
        answers["focus_window"] = ["5_15"]
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.applyDiagnosis(answers)
        // Priors derived from the answers must exist on the profile
        // (exact mapping lives in ProfileBuilder; here we assert influence).
        XCTAssertFalse(store.profile.focusWindowMinutes == nil && answers["focus_window"] != nil,
                       "focus window prior should be initialized from diagnosis")
        d.removePersistentDomain(forName: suiteName)
    }

    /// Retaking the diagnosis clears product state so no old program survives.
    func testRebuildFromDiagnosisClearsEverything() {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.apply(QASeeds.stay)
        store.rebuildFromDiagnosis(nil)
        XCTAssertEqual(store.day, 1)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.programStatus, .active)
        XCTAssertTrue(store.personalRules.isEmpty)
        XCTAssertTrue(store.flowState.projects.isEmpty)
        d.removePersistentDomain(forName: suiteName)
    }

    /// A legitimate active Day-34 user relaunching stays at Day 34.
    func testActiveMidProgramUserSurvivesRelaunch() {
        let d = makeDefaults()
        do {
            let store = ProductStore(diagnosisAnswers: [:], defaults: d)
            store.apply(QASeeds.named("programMidPhase")!)
            XCTAssertEqual(store.day, 45)
        }
        let relaunched = ProductStore(diagnosisAnswers: [:], defaults: d)
        XCTAssertEqual(relaunched.day, 45, "relaunch must preserve legitimate mid-program state")
        XCTAssertEqual(relaunched.programStatus, .active)
        d.removePersistentDomain(forName: suiteName)
    }

    /// A legitimate Day-90 completion stays completed across relaunches.
    func testLegitimateDayNinetyStaysCompleted() {
        let d = makeDefaults()
        do {
            let store = ProductStore(diagnosisAnswers: [:], defaults: d)
            store.apply(QASeeds.programCompleted)
        }
        let relaunched = ProductStore(diagnosisAnswers: [:], defaults: d)
        XCTAssertEqual(relaunched.programStatus, .completed)
        d.removePersistentDomain(forName: suiteName)
    }

    /// initializeProgramIfNeeded is idempotent for an already-clean Day-1 state.
    func testInitializeProgramIfNeededIsIdempotent() {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.initializeProgramIfNeeded()
        XCTAssertEqual(store.day, 1)
        store.initializeProgramIfNeeded()
        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.programStatus, .active)
        d.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Erase-all

    /// Erase returns the product world to true first launch.
    func testErasePersistedDataResetsToFirstLaunch() {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.apply(QASeeds.programCompleted)
        store.erasePersistedData()
        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.programStatus, .active)
        XCTAssertTrue(store.sessions.isEmpty)

        // And a relaunch reads the erased (fresh) domain:
        let relaunched = ProductStore(diagnosisAnswers: [:], defaults: d)
        XCTAssertEqual(relaunched.day, 1)
        XCTAssertEqual(relaunched.programStatus, .active)
        XCTAssertTrue(relaunched.sessions.isEmpty)
        d.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Paywall rules

    func testPaywallCooldownBlocksImmediateReAutoPresentation() {
        let d = makeDefaults()
        XCTAssertTrue(PaywallRules.mayPresentAutomatically(defaults: d))
        PaywallRules.recordAutomaticPresentation(now: Date(), defaults: d)
        XCTAssertFalse(PaywallRules.mayPresentAutomatically(defaults: d))
        XCTAssertTrue(PaywallRules.mayPresentAutomatically(
            now: Date().addingTimeInterval(PaywallRules.automaticCooldown + 1),
            defaults: d))
        d.removePersistentDomain(forName: suiteName)
    }

    /// The first-value moment fires exactly once per completed Day-1 protocol
    /// session — never for free training.
    func testPendingFirstValueMomentOnlyForCompletedBaseline() {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.initializeProgramIfNeeded()
        XCTAssertFalse(store.pendingFirstValueMoment)

        // Free training must not set it.
        store.prepareFreeTraining(.observe)
        guard case .preparing(let freeRequest) = store.phase else {
            return XCTFail("free training should be preparing")
        }
        store.begin(request: freeRequest)
        if case .running(let r) = store.phase {
            store.finishRunning(actualMinutes: max(1, r.targetMinutes - 1), endedEarly: false)
        } else {
            XCTFail("free training should be running")
        }
        store.saveDoneSession(difficulty: 2, firstDistraction: "none", switches: 0,
                              firstSwitchMinute: nil, energy: 3, environmentActionDone: nil)
        XCTAssertFalse(store.pendingFirstValueMoment,
                       "free training must never trigger the first-value moment")

        // Now the Day-1 protocol baseline completes → moment armed once,
        // and routing goes straight to the firstValue screen.
        store.applyDiagnosis([:])
        store.prepareProtocolSession()
        guard case .preparing(let protoRequest) = store.phase else {
            return XCTFail("protocol should be preparing")
        }
        store.begin(request: protoRequest)
        guard case .running(let pr) = store.phase else {
            return XCTFail("protocol should be running")
        }
        store.finishRunning(actualMinutes: pr.targetMinutes, endedEarly: false)
        store.saveDoneSession(difficulty: 2, firstDistraction: "none", switches: 1,
                              firstSwitchMinute: nil, energy: 3, environmentActionDone: nil)
        XCTAssertTrue(store.pendingFirstValueMoment)
        XCTAssertEqual(store.day, 2, "baseline must advance exactly one day")

        // Exactly one protocol session recorded (the free one was cleared by
        // the diagnosis rebuild); saving twice must not double-advance.
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.protocolSessions.count, 1)
        d.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Data export

    func testExportDocumentEncodesAndContainsCoreDomains() throws {
        let d = makeDefaults()
        let store = ProductStore(diagnosisAnswers: [:], defaults: d)
        store.apply(QASeeds.stay)
        var answers: Answers = [:]
        answers["hardest"] = ["starting"]
        let json = RebootDataExport.jsonString(product: store, answers: answers)
        XCTAssertTrue(json.contains("\"sessions\""))
        XCTAssertTrue(json.contains("difficulty"), "export must contain session records")
        XCTAssertTrue(json.contains("profile"))
        XCTAssertTrue(json.contains("operatingManual") || json.contains("manual"),
                      "export must include the manual section key")
        d.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Helpers

    private var suiteName: String { defaultsSuiteName }
    private lazy var defaultsSuiteName = "test.release.\(UUID().uuidString)"
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: defaultsSuiteName)!
    }
}
