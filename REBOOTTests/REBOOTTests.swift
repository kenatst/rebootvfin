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
    }

    func testLegacyV1AndV2SessionsMigrateAsProtocol() throws {
        for key in ["reboot.product.v1", "reboot.product.v2"] {
            defaults.removeObject(forKey: "reboot.product.v3")
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
            defaults.removeObject(forKey: key)
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

    func testManualPreparationPersistsIntoSession() {
        let first = ProductStore(diagnosisAnswers: [:], defaults: defaults)
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
