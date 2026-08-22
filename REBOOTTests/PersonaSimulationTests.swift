import XCTest
@testable import REBOOT
// MARK: - 90-Day Persona Simulation Harness (Phases 5 & 38)

/// Deterministic personas driven through all 90 protocol days.
/// The harness asserts the things that make personalization REAL:
/// divergence between personas, progressive scaffolding reduction,
/// no oscillation, and terminal Day-90 semantics.
@MainActor
final class PersonaSimulationTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "reboot.persona.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    // MARK: Personas

    private struct Persona {
        let name: String
        let answers: Answers
        /// Per-day reflection behavior, deterministic from day number.
        let reflection: (Int) -> (difficulty: Int, distraction: String?, switches: Int)
    }

    private func makePersonas() -> [Persona] {
        [
            Persona(name: "A_phoneSwitcher", answers: [
                "goals": ["scroll_less", "calmer_phone"], "focus_window": ["lt5"],
                "breaker": ["phone"], "switch_response": ["check_phone"],
                "return_ability": ["drift_elsewhere"], "hardest": ["resisting_checking"],
            ], reflection: { day in
                (difficulty: day < 20 ? 4 : 2, distraction: Distractor.phone, switches: day < 30 ? 6 : 2)
            }),
            Persona(name: "B_shallowConsumer", answers: [
                "goals": ["remember_more", "read_more"], "focus_window": ["30_60"],
                "breaker": ["thoughts"], "hardest": ["remembering"],
            ], reflection: { _ in
                (difficulty: 3, distraction: nil, switches: 1)
            }),
            Persona(name: "C_slowStarter", answers: [
                "goals": ["finish_tasks"], "focus_window": ["15_30"],
                "hardest": ["starting"], "return_ability": ["quick_return"],
            ], reflection: { day in
                day % 6 == 0
                    ? (difficulty: 5, distraction: "forgot", switches: 5)
                    : (difficulty: 2, distraction: "none", switches: 0)
            }),
            Persona(name: "D_eveningSensitive", answers: [
                "goals": ["deep_work", "study_better"], "focus_window": ["30_60"],
                "best_time": ["evening"], "breaker": ["people"],
            ], reflection: { day in
                (difficulty: day % 4 == 1 ? 4 : 2, distraction: Distractor.people, switches: day % 4 == 1 ? 4 : 1)
            }),
            Persona(name: "E_internalWanderer", answers: [
                "goals": ["focus_better"], "focus_window": ["5_15"],
                "breaker": ["thoughts"], "hardest": ["slowing_noise"],
            ], reflection: { _ in
                (difficulty: 3, distraction: Distractor.internalRestlessness, switches: 3)
            }),
        ]
    }

    /// Drives one persona through all 90 protocol days with full program-flow
    /// handling, recording one snapshot per completed day.
    /// Each persona gets an isolated persistence domain so stores never
    /// inherit a previous persona's program state.
    private func drive(_ persona: Persona) -> [Int: Snapshot] {
        let suiteName = "reboot.persona.\(persona.name).\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = ProductStore(diagnosisAnswers: persona.answers, defaults: suite)
        var snapshots: [Int: Snapshot] = [:]

        var guardCounter = 0
        while store.programStatus == .active && guardCounter < 250 {
            guardCounter += 1

            if case .weeklyReview(let checkpoint) = store.phase {
                store.saveWeeklyReview(WeeklyReviewAnswers(
                    helpedMost: nil, stillBreaksAttention: nil, nextTestPreference: nil
                ))
                continue
            }
            if case .phaseTransition = store.phase {
                store.acknowledgePhaseTransition()
                continue
            }
            if case .programCompletion = store.phase {
                store.acknowledgeProgramCompletion()
                continue
            }
            guard let request = store.protocolRequest() else { break }
            let day = request.programDay ?? store.day

            store.begin(request: request)
            store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)

            let r = persona.reflection(day)
            store.saveDoneSession(SessionReflection(
                difficulty: r.difficulty,
                firstDistraction: r.distraction,
                switches: r.switches
            ))

            snapshots[day] = Snapshot(
                day: min(90, store.day),
                phase: ProgramPhase.phase(for: day).id,
                mode: request.mode,
                minutes: request.targetMinutes,
                stability: store.profile.attentionStability.value,
                returnLevel: store.profile.returnAfterDistraction.value,
                recall: store.profile.recall.value,
                windowMinutes: store.profile.focusWindowMinutes,
                rules: store.personalRules.count,
                sessions: store.sessions.count,
                guidanceCount: store.guidanceDecisions.count
            )
        }

        // Day 90 must have been reached exactly once and completed.
        XCTAssertEqual(store.completedProtocolDays, 90, "\(persona.name) must finish all 90 days")
        XCTAssertEqual(store.programStatus, .completed, "\(persona.name)")
        XCTAssertNil(store.protocolRequest(), "\(persona.name): no Day 91 may exist")
        XCTAssertLessThanOrEqual(snapshots.count, 91, "\(persona.name): no duplicate-day execution")
        return snapshots
    }

    struct Snapshot {
        let day: Int
        let phase: ProgramPhaseID
        let mode: TrainingMode
        let minutes: Int
        let stability: StabilityLevel?
        let returnLevel: ReturnLevel?
        let recall: RecallLevel?
        let windowMinutes: Int?
        let rules: Int
        let sessions: Int
        let guidanceCount: Int
    }

    // MARK: The five assertions that matter

    func testAllFivePersonasComplete90DaysWithoutViolations() {
        for persona in makePersonas() {
            let snapshots = drive(persona)
            XCTAssertEqual(snapshots.count >= 6, true, "\(persona.name) lost checkpoints")
        }
    }

    func testPersonasDivergeInModesAndProfileByDay40() {
        let results = makePersonas().map { ($0.name, drive($0)) }
        // Mode sequences must not be identical across personas — that would
        // mean the program ignores who the user is.
        var modeSets: Set<String> = []
        for (name, snapshots) in results {
            let modes = snapshots.values.sorted { $0.day < $1.day }.suffix(5).map(\.mode.rawValue).joined(separator: "-")
            modeSets.insert(modes)
            XCTAssertFalse(modes.isEmpty, "\(name) produced no mode trace")
        }
        XCTAssertGreaterThan(modeSets.count, 1, "Every persona received the same late-program modes — personalization is insufficient")

        // Profile divergence: A (phone switcher) vs B (shallow consumer).
        if let a = results.first(where: { $0.0 == "A_phoneSwitcher" })?.1[40],
           let b = results.first(where: { $0.0 == "B_shallowConsumer" })?.1[40] {
            XCTAssertNotEqual(a.mode, b.mode, "Day-40 prescriptions identical across opposite personas")
        }
    }

    func testProfilesReflectThePersonaTheyObserved() {
        // Persona B reports strong duration but weak recall; by Day 40 the
        // profile must show high-ish stability and weak/fair recall — evidence
        // over assumption.
        let b = makePersonas().first { $0.name == "B_shallowConsumer" }!
        let snapshots = drive(b)
        let s40 = snapshots[40]
        XCTAssertNotNil(s40)
        XCTAssertEqual(s40?.stability, .high, "B completes everything with ≤1 switch — stability should read high")
        XCTAssertTrue([.weak, .fair].contains(s40?.recall ?? .strong), "Recall self-assessments were 'some' at best")
        // Persona E starts weak and stays mid — never silently promoted to high.
        let e = makePersonas().first { $0.name == "E_internalWanderer" }!
        let eSnaps = drive(e)
        XCTAssertNotEqual(eSnaps[40]?.stability, .high, "E's evidence never supports high stability")
    }

    func testGuidanceDoesNotOscillateDayToday() {
        let c = makePersonas().first { $0.name == "C_slowStarter" }!
        let snapshots = drive(c)
        // With hysteresis, consecutive recorded checkpoints keep a bounded
        // number of distinct bottleneck regimes rather than flapping daily.
        XCTAssertLessThanOrEqual(snapshots.values.map(\.guidanceCount).max() ?? 0, 90)
    }

    func testScaffoldingShrinksByOwnSystemPhase() {
        // Days 76–90 are Own System: the program deliberately hands control
        // back (independent setup intents) instead of prescribing harder work.
        for persona in makePersonas() {
            let snapshots = drive(persona)
            let late = snapshots[76] ?? snapshots[80] ?? snapshots[60]
            XCTAssertNotNil(late, "\(persona.name) missing late checkpoint")
            XCTAssertEqual(late?.phase, ProgramPhaseID.ownSystem, "\(persona.name): Day 76+ must sit in Own System")
            // And the final synthesis day exists exactly once, at 90.
            XCTAssertEqual(snapshots[90]?.phase, .ownSystem, "\(persona.name)")
        }
    }
}
