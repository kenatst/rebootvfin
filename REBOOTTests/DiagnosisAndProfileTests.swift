import XCTest
@testable import REBOOT

// MARK: - Diagnosis → Profile Mapping (Phase 2 regression)

@MainActor
final class DiagnosisMappingTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "reboot.diagnosis.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        if let name = defaults.dictionaryRepresentation()["__suite"] as? String {
            defaults.removePersistentDomain(forName: name)
        }
        defaults = nil
        super.tearDown()
    }

    func testQuestionCountIsWithinTargetRange() {
        // 5–8 high-information questions; the full branch may add one.
        XCTAssertLessThanOrEqual(DiagnosisModels.questions.count, 9)
        XCTAssertGreaterThanOrEqual(DiagnosisModels.questions.count, 5)
        for question in DiagnosisModels.questions {
            XCTAssertNotNil(question.title)
            // Every question must carry an escape hatch or be inherently
            // skippable (multi via Continue, derived options from prior answers).
            if question.unknownLabel == nil && question.optionsFrom == nil {
                XCTAssertEqual(question.kind, .multi, "\(question.id) has no unknown escape and is not multi")
            }
        }
    }

    func testSingleGoalBecomesPrimaryWithoutExtraQuestion() {
        let profile = ProfileBuilder.build(from: ["goals": ["deep_work"]])
        XCTAssertEqual(profile.primaryGoal.value, "deep_work")
        XCTAssertEqual(profile.goals.value, ["deep_work"])
        XCTAssertEqual(profile.primaryGoal.source, .selfReport)
    }

    func testMultiGoalWithoutPrimaryKeepsGoalListAndLeavesPrimaryUnknown() {
        let profile = ProfileBuilder.build(from: ["goals": ["deep_work", "read_more"]])
        XCTAssertNil(profile.primaryGoal.value)
        XCTAssertEqual(profile.goals.value?.count, 2)
    }

    func testFocusWindowAnchorsMapToPriors() {
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["lt5"]]).focusWindowMinutes, 10)
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["5_15"]]).focusWindowMinutes, 15)
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["15_30"]]).focusWindowMinutes, 20)
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["30_60"]]).focusWindowMinutes, 30)
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["usually_60_plus"]]).focusWindowMinutes, 45)
        // Legacy value from an earlier install still decodes.
        XCTAssertEqual(ProfileBuilder.build(from: ["focus_window": ["gt60"]]).focusWindowMinutes, 45)
        // Unknown stays a neutral prior, never a fabricated claim.
        XCTAssertEqual(ProfileBuilder.build(from: [:]).focusWindowMinutes, 15)
    }

    func testReturnAbilityPriorMapsAndUnknownStaysUnknown() {
        XCTAssertEqual(ProfileBuilder.build(from: ["return_ability": ["quick_return"]]).returnAfterDistraction.value, .strong)
        XCTAssertEqual(ProfileBuilder.build(from: ["return_ability": ["effortful_return"]]).returnAfterDistraction.value, .fair)
        XCTAssertEqual(ProfileBuilder.build(from: ["return_ability": ["abandon_original"]]).returnAfterDistraction.value, .weak)
        XCTAssertNil(ProfileBuilder.build(from: ["return_ability": ["__unknown__"]]).returnAfterDistraction.value)
        XCTAssertNil(ProfileBuilder.build(from: [:]).returnAfterDistraction.value)
    }

    func testRecallIsNeverClaimedStrongAtIntake() {
        let profile = ProfileBuilder.build(from: [
            "hardest": ["remembering"],
            "switch_response": ["keep_going_shallow"],
        ])
        XCTAssertEqual(profile.recall.value, .weak)
        XCTAssertEqual(profile.depth.value, .shallow)
        // No answer → no claim at all.
        let empty = ProfileBuilder.build(from: [:])
        XCTAssertNil(empty.recall.value)
        XCTAssertNil(empty.depth.value)
    }

    func testPhoneHypothesisComesFromBreakerOrSwitchResponse() {
        let fromBreaker = Distractor.fromDiagnosis(["breaker": ["phone"]])
        XCTAssertTrue(fromBreaker.contains(Distractor.phone))
        let fromSwitch = Distractor.fromDiagnosis(["switch_response": ["check_phone"]])
        XCTAssertTrue(fromSwitch.contains(Distractor.phone))
        let internalOnly = Distractor.fromDiagnosis(["breaker": ["thoughts"]])
        XCTAssertTrue(internalOnly.contains(Distractor.internalRestlessness))
        XCTAssertFalse(internalOnly.contains(Distractor.phone))
        // Legacy answers still decode.
        XCTAssertTrue(Distractor.fromDiagnosis(["phone_place": ["on_desk"]]).contains(Distractor.phone))
    }

    func testEveryGoalValueHasALabelAndEngineMapping() {
        for goal in DiagnosisModels.goals {
            XCTAssertNotNil(DiagnosisModels.goalLabel[goal.value])
        }
        // All goal values must survive the mode-selection vocabulary.
        let recognized: Set<String> = [
            "read_more", "remember_more", "study_better",
            "scroll_less", "calmer_phone",
            "deep_work", "focus_better", "finish_tasks",
        ]
        for goal in DiagnosisModels.goals {
            XCTAssertTrue(recognized.contains(goal.value), "\(goal.value) has no mode-selection mapping")
        }
    }

    func testBranchingKeepsFlowTight() {
        // A single-goal user never sees the primary disambiguation question.
        let answers: Answers = ["goals": ["deep_work"]]
        let visible = DiagnosisModels.visibleQuestions(answers)
        XCTAssertFalse(visible.contains { $0.id == "primary" })
        // Multi-goal users do.
        let multi: Answers = ["goals": ["deep_work", "read_more"]]
        XCTAssertTrue(DiagnosisModels.visibleQuestions(multi).contains { $0.id == "primary" })
    }

    func testDiagnosisAnswersArePriorsNotIdentity() {
        // The phone answer initializes a hypothesis; one contradicting session
        // must be able to move the profile away from it (observed > claimed).
        var profile = ProfileBuilder.build(from: ["breaker": ["phone"], "focus_window": ["lt5"]])
        XCTAssertEqual(profile.distractors.value?.contains(Distractor.phone), true)
        XCTAssertEqual(profile.distractors.source, .selfReport)

        let smoothSession = SessionRecord(
            day: 2, date: Date(), mode: .stay, targetMinutes: 15, actualMinutes: 15,
            completed: true, firstDistraction: "none", switches: 0
        )
        ProfileUpdater.apply(session: smoothSession, sessionCount: 1, allSessions: [smoothSession], to: &profile)
        // Observed evidence has begun to outrank the intake claim.
        XCTAssertNotEqual(profile.attentionStability.source, .selfReport)
    }
}

// MARK: - Attention Profile Living Model (Phase 3 regression)

@MainActor
final class AttentionProfileEngineTests: XCTestCase {

    func testMaturityEscalatesOnlyWithEvidence() {
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .selfReport, observedCount: 0), .startingPoint)
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .selfReport, observedCount: 1), .startingPoint)
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .selfReport, observedCount: 2), .earlySignal)
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .session, observedCount: 2), .earlySignal)
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .session, observedCount: 3), .repeatedSignal)
        XCTAssertEqual(AttentionProfileEngine.maturity(source: .repeated, observedCount: 1), .repeatedSignal)
    }

    func testUnknownDimensionsLookIntentional() {
        let dimensions = AttentionProfileEngine.dimensions(profile: AttentionProfile(), sessions: [])
        XCTAssertFalse(dimensions.isEmpty)
        for dim in dimensions {
            XCTAssertTrue(dim.isUnknown, "\(dim.name) should be unknown for an empty profile")
            XCTAssertTrue(dim.value.contains("Still learning"), "Unknown must read as intentional: \(dim.value)")
        }
    }

    func testOverallMaturityGrowsWithProtocolDays() {
        let profile = ProfileBuilder.build(from: ["goals": ["deep_work"], "focus_window": ["15_30"]])
        XCTAssertEqual(AttentionProfileEngine.overallMaturity(profile: profile, sessions: []), .startingPoint)
        let early = (1...2).map { SessionRecord(day: $0, date: Date(), mode: .stay, targetMinutes: 15, actualMinutes: 15, completed: true) }
        XCTAssertEqual(AttentionProfileEngine.overallMaturity(profile: profile, sessions: early), .earlySignal)
        let mature = (1...5).map { SessionRecord(day: $0, date: Date(), mode: .stay, targetMinutes: 20, actualMinutes: 20, completed: true) }
        XCTAssertEqual(AttentionProfileEngine.overallMaturity(profile: profile, sessions: mature), .repeatedSignal)
    }

    func testNoFakePercentagesInDimensionSummaries() {
        let profile = ProfileBuilder.build(from: [
            "goals": ["deep_work"], "focus_window": ["15_30"], "return_ability": ["effortful_return"],
        ])
        let dimensions = AttentionProfileEngine.dimensions(profile: profile, sessions: [])
        for dim in dimensions {
            XCTAssertFalse(dim.value.contains("%"), "No fake confidence percentages: \(dim.value)")
            XCTAssertFalse(dim.maturity.explanation.contains("%"))
        }
    }
}
