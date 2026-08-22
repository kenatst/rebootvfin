import Foundation
import XCTest
@testable import REBOOT

@MainActor
final class FlowTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "FlowTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Domain and snapshots

    func testFlowProjectCreateAndArchivePreservesIdentityAndHistoryFields() {
        let store = makeProgramStore(day: 2)

        XCTAssertNil(store.createFlowProject(title: "   ", category: .coding))
        let project = tryUnwrap(store.createFlowProject(
            title: "  Build the import pipeline  ",
            category: .coding,
            note: "  Ship one vertical slice.  "
        ))

        XCTAssertEqual(project.title, "Build the import pipeline")
        XCTAssertEqual(project.note, "Ship one vertical slice.")
        XCTAssertEqual(store.activeFlowProjects.map(\.id), [project.id])

        let archivedAt = dateAt(hour: 12, dayOffset: 1)
        store.archiveFlowProject(id: project.id, at: archivedAt)

        let archived = tryUnwrap(store.flowProject(id: project.id))
        XCTAssertEqual(archived.status, .archived)
        XCTAssertEqual(archived.archivedAt, archivedAt)
        XCTAssertTrue(store.activeFlowProjects.isEmpty)
        XCTAssertEqual(store.archivedFlowProjects.map(\.id), [project.id])
    }

    func testFlowBlockPlanRoundTripFreezesDefinitionChallengeSkillFeedbackEnvironmentAndFuel() throws {
        let projectID = UUID()
        let ruleID = UUID()
        var environment = FlowEnvironmentPlan(
            phoneSetup: .screenTimeProtected,
            soundContext: .quiet,
            browserScope: "One documentation tab",
            appliedRuleIDs: [ruleID],
            verification: .systemConfirmed,
            protectionActivated: true
        )
        var fuel = completeFuel(capturedAt: dateAt(hour: 9))
        let plan = FlowBlockPlan(
            projectID: projectID,
            task: "Implement decoder",
            definitionOfDone: "All migration fixtures pass",
            challengeBefore: .stretching,
            skillConfidenceBefore: .capable,
            feedbackMechanism: .testsPassing,
            customFeedback: nil,
            suggestedDuration: 30,
            selectedDuration: 35,
            environmentPlan: environment,
            fuelContext: fuel,
            baseMode: .stay,
            sessionOrigin: .flow,
            programDay: nil,
            createdAt: dateAt(hour: 9)
        )

        environment.phoneSetup = .usual
        environment.appliedRuleIDs = []
        fuel.energy = .low

        XCTAssertEqual(plan.definitionOfDone, "All migration fixtures pass")
        XCTAssertEqual(plan.challengeBefore, .stretching)
        XCTAssertEqual(plan.skillConfidenceBefore, .capable)
        XCTAssertEqual(plan.challengeSkillRelation, .balancedStretch)
        XCTAssertEqual(plan.feedbackMechanism, .testsPassing)
        XCTAssertEqual(plan.feedbackLabel, "Tests passing")
        XCTAssertEqual(plan.environmentPlan.phoneSetup, .screenTimeProtected)
        XCTAssertEqual(plan.environmentPlan.appliedRuleIDs, [ruleID])
        XCTAssertEqual(plan.fuelContext?.energy, .high)

        let decoded = try JSONDecoder().decode(
            FlowBlockPlan.self,
            from: JSONEncoder().encode(plan)
        )
        XCTAssertEqual(decoded, plan)
    }

    func testChallengeSkillRelationshipsAreQualitativeAndDoNotCreateAConclusionAlone() {
        XCTAssertEqual(
            FlowChallengeSkillRelation.derive(challenge: .light, skill: .strong),
            .underchallenged
        )
        XCTAssertEqual(
            FlowChallengeSkillRelation.derive(challenge: .stretching, skill: .capable),
            .balancedStretch
        )
        XCTAssertEqual(
            FlowChallengeSkillRelation.derive(challenge: .hard, skill: .unsure),
            .overreaching
        )
        XCTAssertEqual(
            FlowChallengeSkillRelation.derive(challenge: .stretching, skill: .unsure),
            .uncertain
        )

        let project = makeProject(category: .study)
        let block = makeBlock(
            project: project,
            index: 0,
            signal: .strongerSignal,
            challenge: .stretching,
            skill: .capable
        )
        let state = FlowState(projects: [project], plans: [block.plan], evidence: [block.evidence])
        XCTAssertTrue(
            FlowConditionEngine.evaluate(state: state).isEmpty,
            "A challenge/skill self-report and one outcome cannot become a condition conclusion"
        )
    }

    // MARK: - Engagement and condition engines

    func testEngagementClassifierExactQualitativeCases() {
        XCTAssertEqual(
            FlowEngagementClassifier.classify(
                reflection: reflection(for: .strongerSignal),
                completed: true,
                endedEarly: false
            ),
            .strongerSignal
        )
        XCTAssertEqual(
            FlowEngagementClassifier.classify(
                reflection: reflection(for: .lowerSignal),
                completed: true,
                endedEarly: false
            ),
            .lowerSignal
        )
        XCTAssertEqual(
            FlowEngagementClassifier.classify(
                reflection: reflection(for: .mixed),
                completed: true,
                endedEarly: false
            ),
            .mixed
        )
        XCTAssertEqual(
            FlowEngagementClassifier.classify(
                reflection: FlowBlockReflection(
                    absorption: .high,
                    timePerception: nil,
                    desireToContinue: .continue,
                    definitionOfDoneOutcome: .reached
                ),
                completed: false,
                endedEarly: true
            ),
            .insufficient
        )
    }

    func testComparabilityRequiresModeAndRelatedTaskContextWithBoundedDuration() {
        let writingA = makeProject(title: "Essay A", category: .writing)
        let writingB = makeProject(title: "Essay B", category: .writing)
        let coding = makeProject(title: "App", category: .coding)
        let anchor = makeBlock(project: writingA, index: 0, signal: .strongerSignal, duration: 25)
        let sameProjectAtLimit = makeBlock(project: writingA, index: 1, signal: .strongerSignal, duration: 45)
        let sameProjectTooFar = makeBlock(project: writingA, index: 2, signal: .strongerSignal, duration: 46)
        let sameCategoryAtLimit = makeBlock(project: writingB, index: 3, signal: .strongerSignal, duration: 40)
        let differentCategory = makeBlock(project: coding, index: 4, signal: .strongerSignal, duration: 25)
        let differentMode = makeBlock(
            project: writingA,
            index: 5,
            signal: .strongerSignal,
            duration: 25,
            baseMode: .recall
        )
        let blocks = [anchor, sameProjectAtLimit, sameProjectTooFar, sameCategoryAtLimit, differentCategory, differentMode]
        let state = FlowState(
            projects: [writingA, writingB, coding],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )

        XCTAssertTrue(FlowComparabilityEngine.areComparable(anchor.evidence, sameProjectAtLimit.evidence, state: state))
        XCTAssertFalse(FlowComparabilityEngine.areComparable(anchor.evidence, sameProjectTooFar.evidence, state: state))
        XCTAssertTrue(FlowComparabilityEngine.areComparable(anchor.evidence, sameCategoryAtLimit.evidence, state: state))
        XCTAssertFalse(FlowComparabilityEngine.areComparable(anchor.evidence, differentCategory.evidence, state: state))
        XCTAssertFalse(FlowComparabilityEngine.areComparable(anchor.evidence, differentMode.evidence, state: state))
    }

    func testOneOrTwoBlocksCannotCreatePatterns() {
        let one = makeState(signals: [.strongerSignal])
        let two = makeState(signals: [.strongerSignal, .strongerSignal])

        XCTAssertTrue(FlowConditionEngine.evaluate(state: one).isEmpty)
        XCTAssertTrue(FlowConditionEngine.evaluate(state: two).isEmpty)
    }

    func testThreeComparableStrongerBlocksCreateEarlyPatternsAcrossSupportedDimensions() {
        let state = makeState(signals: Array(repeating: .strongerSignal, count: 3))
        let patterns = FlowConditionEngine.evaluate(state: state)
        let dimensions = Set(patterns.map { $0.dimension.rawValue })

        XCTAssertEqual(dimensions, Set(FlowConditionDimension.allCases.map(\.rawValue)))
        XCTAssertTrue(patterns.allSatisfy { $0.maturity == .earlySignal })
        XCTAssertEqual(patterns.first(where: { $0.dimension == .finishLine })?.strongerCount, 3)
        XCTAssertEqual(
            patterns.first(where: { $0.dimension == .challengeSkill })?.value,
            FlowChallengeSkillRelation.balancedStretch.label
        )
        XCTAssertEqual(patterns.first(where: { $0.dimension == .phoneSetup })?.value, "Protected with Screen Time")
        XCTAssertEqual(patterns.first(where: { $0.dimension == .taskCategory })?.value, "Writing")
        XCTAssertEqual(patterns.first(where: { $0.dimension == .energy })?.value, "High")
        XCTAssertEqual(patterns.first(where: { $0.dimension == .breakState })?.value, "Returning from a break")
        XCTAssertEqual(patterns.first(where: { $0.dimension == .duration })?.value, "About 30 min")
    }

    func testFourConsistentBlocksCreateRepeatedSignalWithoutCausalCopy() {
        let state = makeState(signals: Array(repeating: .strongerSignal, count: 4))
        let patterns = FlowConditionEngine.evaluate(state: state)

        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(patterns.allSatisfy { $0.maturity == .repeatedSignal })
        for statement in patterns.map(\.statement) {
            let copy = statement.lowercased()
            XCTAssertFalse(copy.contains("caused flow"))
            XCTAssertFalse(copy.contains("enter flow"))
            XCTAssertFalse(copy.contains("you need"))
            XCTAssertFalse(copy.contains("optimal"))
        }
    }

    func testContradictionsReduceMaturityInsteadOfBlindlyInflatingConfidence() {
        let state = makeState(signals:
            Array(repeating: .strongerSignal, count: 3)
                + Array(repeating: .lowerSignal, count: 3)
        )
        let patterns = FlowConditionEngine.evaluate(state: state)
        let finishLine = tryUnwrap(patterns.first { $0.dimension == .finishLine })

        XCTAssertEqual(finishLine.strongerCount, 3)
        XCTAssertEqual(finishLine.contradictingEvidenceIDs.count, 3)
        XCTAssertEqual(finishLine.maturity, .mixedRecently)
        XCTAssertTrue(finishLine.statement.localizedCaseInsensitiveContains("mixed"))
    }

    func testMixedEvidencePreventsRepeatedMaturity() {
        let state = makeState(signals:
            Array(repeating: .strongerSignal, count: 4)
                + Array(repeating: .mixed, count: 4)
        )
        let finishLine = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .finishLine }
        )

        XCTAssertEqual(finishLine.maturity, .mixedRecently)
        XCTAssertEqual(finishLine.strongerCount, 4)
        XCTAssertEqual(finishLine.comparableCount, 8)
        XCTAssertTrue(finishLine.contradictingEvidenceIDs.isEmpty)
    }

    func testDurationPatternKeepsSubTwentyMinuteEvidenceHonest() {
        let project = makeProject(category: .coding)
        let blocks = (0..<3).map {
            makeBlock(project: project, index: $0, signal: .strongerSignal, duration: 10)
        }
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )

        let duration = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .duration }
        )
        XCTAssertEqual(duration.value, "About 10 min")
    }

    func testBridgeDurationsCannotCreateAFalseComparableCohort() {
        let project = makeProject(category: .coding)
        let blocks = [10, 30, 50].enumerated().map { index, duration in
            makeBlock(
                project: project,
                index: index,
                signal: .strongerSignal,
                duration: duration
            )
        }
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )

        XCTAssertTrue(FlowComparabilityEngine.areComparable(
            blocks[0].evidence,
            blocks[1].evidence,
            state: state
        ))
        XCTAssertTrue(FlowComparabilityEngine.areComparable(
            blocks[1].evidence,
            blocks[2].evidence,
            state: state
        ))
        XCTAssertFalse(FlowComparabilityEngine.areComparable(
            blocks[0].evidence,
            blocks[2].evidence,
            state: state
        ))
        XCTAssertEqual(
            FlowComparabilityEngine.strongestMutuallyComparableCohort(
                blocks.map(\.evidence),
                state: state
            ).count,
            2
        )
        XCTAssertTrue(FlowConditionEngine.evaluate(state: state).isEmpty)
    }

    func testLaterCompetingDaypartEvidenceMakesOldIdentityMixed() {
        let project = makeProject(category: .writing)
        let morning = (0..<4).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                date: dateAt(hour: 9, dayOffset: $0)
            )
        }
        let evening = (0..<3).map {
            makeBlock(
                project: project,
                index: $0 + 4,
                signal: .strongerSignal,
                date: dateAt(hour: 19, dayOffset: $0 + 10)
            )
        }
        let blocks = morning + evening
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
        let daypart = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .daypart }
        )

        XCTAssertEqual(daypart.maturity, .mixedRecently)
        XCTAssertTrue(daypart.statement.localizedCaseInsensitiveContains("keep observing"))
    }

    func testEnoughRecentEvidenceEventuallyOutweighsAnOlderCompetingCondition() {
        let project = makeProject(category: .writing)
        let oldMorning = (0..<3).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                date: dateAt(hour: 9, dayOffset: $0 - 30)
            )
        }
        let recentEvening = (0..<6).map {
            makeBlock(
                project: project,
                index: $0 + 3,
                signal: .strongerSignal,
                date: dateAt(hour: 19, dayOffset: $0)
            )
        }
        let blocks = oldMorning + recentEvening
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
        let daypart = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .daypart }
        )

        XCTAssertEqual(daypart.value, FuelDaypart.evening.label)
        XCTAssertEqual(daypart.maturity, .repeatedSignal)
        XCTAssertEqual(daypart.strongerCount, 6)
    }

    func testIncompatibleModeEvidenceCannotInflateOrContradictAComparableCohort() {
        let project = makeProject(category: .study)
        let comparableStay = (0..<3).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                date: dateAt(hour: 9, dayOffset: $0 + 10),
                baseMode: .stay
            )
        }
        let incompatibleRecall = (0..<3).map {
            makeBlock(
                project: project,
                index: $0 + 3,
                signal: .lowerSignal,
                date: dateAt(hour: 9, dayOffset: $0),
                baseMode: .recall
            )
        }
        let blocks = comparableStay + incompatibleRecall
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
        let finishLine = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .finishLine }
        )

        XCTAssertEqual(finishLine.maturity, .earlySignal)
        XCTAssertEqual(finishLine.comparableCount, 3)
        XCTAssertEqual(finishLine.strongerCount, 3)
        XCTAssertTrue(finishLine.contradictingEvidenceIDs.isEmpty)
    }

    func testSelfReportedPhoneSetupRemainsDistinctFromConfirmedScreenTimeProtection() {
        let project = makeProject(category: .coding)
        let selfReported = (0..<3).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                phoneSetup: .outsideReach,
                protectionActivated: false,
                verification: .userReported
            )
        }
        let state = FlowState(
            projects: [project],
            plans: selfReported.map(\.plan),
            evidence: selfReported.map(\.evidence)
        )
        let patterns = FlowConditionEngine.evaluate(state: state)

        XCTAssertEqual(
            patterns.first(where: { $0.dimension == .phoneSetup })?.value,
            FlowPhoneSetup.outsideReach.label
        )
        XCTAssertNil(patterns.first { $0.dimension == .screenTimeProtection })
        XCTAssertTrue(state.plans.allSatisfy { $0.environmentPlan.verification == .userReported })
    }

    func testFailedScreenTimeActivationIsNotCountedAsProtectedEvidence() {
        let project = makeProject(category: .coding)
        let failedAttempts = (0..<4).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                phoneSetup: .screenTimeProtected,
                protectionActivated: false,
                verification: .systemConfirmed
            )
        }
        let state = FlowState(
            projects: [project],
            plans: failedAttempts.map(\.plan),
            evidence: failedAttempts.map(\.evidence)
        )

        XCTAssertNil(
            FlowConditionEngine.evaluate(state: state).first {
                $0.dimension == .screenTimeProtection
            },
            "Requested but inactive protection is not evidence of protected work"
        )
        XCTAssertNil(
            FlowConditionEngine.evaluate(state: state).first {
                $0.dimension == .phoneSetup
            },
            "An unfulfilled Screen Time request cannot become positive phone-setup evidence"
        )
    }

    func testFlowSetupRejectsUnconfirmedScreenTimeAndKeepsTheDraftAtomic() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(
            title: "Protected parser",
            category: .coding
        ))
        XCTAssertTrue(store.beginFlowSetup(projectID: project.id, origin: .flow))
        var draft = tryUnwrap(store.flowState.pendingSetup)
        draft.task = "Implement the parser"
        draft.definitionOfDone = "Malformed input tests pass"
        draft.phoneSetup = .screenTimeProtected
        store.updateFlowSetup(draft)
        let failedArm = SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: UUID(),
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: false,
            phoneLocationSelfReport: nil
        )

        XCTAssertFalse(store.startFlowBlock(
            environmentPlan: FlowEnvironmentPlan(
                phoneSetup: .screenTimeProtected,
                verification: .screenTimeIntervention,
                protectionActivated: true
            ),
            environmentArm: failedArm
        ))
        XCTAssertTrue(store.flowState.plans.isEmpty)
        XCTAssertNil(store.flowState.activeBlockID)
        XCTAssertEqual(store.flowState.pendingSetup, draft)
        guard case .flowSetup = store.phase else {
            return XCTFail("A failed protection attempt must leave setup recoverable")
        }
    }

    // MARK: - Origin and ProductStore integration

    func testFlowParticipationIsOrthogonalToOriginAndDoesNotAddATrainingMode() throws {
        let project = makeProject()
        let block = makeBlock(project: project, index: 0, signal: .strongerSignal)
        let participation = makeParticipation(plan: block.plan)

        for origin in [SessionOrigin.protocol, .freeTraining, .flow] {
            let record = SessionRecord(
                origin: origin,
                requestID: UUID(),
                day: 65,
                date: dateAt(hour: 9),
                mode: .stay,
                targetMinutes: 30,
                actualMinutes: 30,
                completed: true,
                flowParticipation: participation
            )
            let decoded = try JSONDecoder().decode(
                SessionRecord.self,
                from: JSONEncoder().encode(record)
            )
            XCTAssertEqual(decoded.origin, origin)
            XCTAssertEqual(decoded.flowParticipation, participation)
            XCTAssertEqual(decoded.origin.advancesProgram, origin == .protocol)
        }

        XCTAssertEqual(Set(TrainingMode.allCases.map(\.rawValue)), ["STAY", "RECALL", "EXPLAIN", "NOTHING", "OBSERVE"])
    }

    func testProtocolFlowBlockAdvancesExactlyOnceAndPreservesFullContext() {
        let store = makeProgramStore(day: 65)
        XCTAssertEqual(store.prescription.mode, .stay)
        XCTAssertTrue(store.currentProtocolCanParticipateInFlow)
        let project = tryUnwrap(store.createFlowProject(title: "Compiler", category: .coding))
        let fuel = completeFuel(capturedAt: Date())
        store.fuelState.pendingCapture = fuel
        let forgedRuleID = UUID()
        let environmentPlan = FlowEnvironmentPlan(
            phoneSetup: .screenTimeProtected,
            soundContext: .quiet,
            browserScope: "One issue and one editor",
            appliedRuleIDs: [forgedRuleID],
            verification: .systemConfirmed,
            protectionActivated: true
        )
        let arm = protectedArm()

        let plan = startFlowBlock(
            store: store,
            projectID: project.id,
            origin: .protocol,
            environmentPlan: environmentPlan,
            environmentArm: arm
        )
        guard case .running(let running) = store.phase else {
            return XCTFail("Expected running protocol Flow block")
        }
        XCTAssertEqual(running.origin, .protocol)
        XCTAssertEqual(running.day, 65)
        XCTAssertEqual(running.flowParticipation?.flowPlanID, plan.id)
        XCTAssertEqual(running.fuelContext, fuel)
        XCTAssertTrue(running.appliedRuleIDs.isEmpty, "Flow setup cannot silently attach an unowned rule ID")
        XCTAssertTrue(plan.environmentPlan.appliedRuleIDs.isEmpty)
        XCTAssertEqual(running.environment?.protectionActivated, true)
        XCTAssertEqual(running.evidence?.stay?.completionDefinition, "All focused tests pass")

        store.markSwitch(at: running.date.addingTimeInterval(120))
        store.finishRunning(actualMinutes: running.targetMinutes, endedEarly: false)
        let done = doneRecord(store)
        store.saveDoneSession(SessionReflection(
            difficulty: 2,
            flowReflection: reflection(for: .strongerSignal)
        ))

        XCTAssertEqual(store.day, 66)
        XCTAssertEqual(store.completedProtocolDays, 65)
        XCTAssertEqual(store.sessions.filter { $0.requestID == done.requestID }.count, 1)
        XCTAssertEqual(store.flowState.evidence.count, 1)
        let evidence = tryUnwrap(store.flowState.evidence.first)
        XCTAssertEqual(evidence.projectID, project.id)
        XCTAssertEqual(evidence.planID, plan.id)
        XCTAssertEqual(evidence.fuelContext, fuel)
        XCTAssertEqual(evidence.environment?.protectionActivated, true)
        XCTAssertEqual(evidence.switches.count, 1)
        XCTAssertEqual(evidence.switches.firstSwitchTiming, .underFive)

        store.phase = .done(done)
        store.saveDoneSession(SessionReflection(
            difficulty: 1,
            flowReflection: reflection(for: .lowerSignal)
        ))
        XCTAssertEqual(store.day, 66)
        XCTAssertEqual(store.completedProtocolDays, 65)
        XCTAssertEqual(store.flowState.evidence.count, 1, "Session, reflection and Flow evidence are idempotent")
        guard case .flowLab = store.phase else {
            return XCTFail("An idempotent replay should keep the Flow Lab return route")
        }
    }

    func testTodayProtocolOriginSurvivesCreatingTheFirstFlowProject() {
        let store = makeProgramStore(day: 65)
        XCTAssertTrue(store.activeFlowProjects.isEmpty)
        XCTAssertTrue(store.currentProtocolCanParticipateInFlow)

        store.openFlowLab(origin: .protocol)
        XCTAssertEqual(store.flowState.pendingEntryOrigin, .protocol)
        let resumed = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .flowLab = resumed.phase else {
            return XCTFail("The protocol Flow entry should survive relaunch")
        }
        XCTAssertEqual(resumed.flowState.pendingEntryOrigin, .protocol)
        let project = tryUnwrap(resumed.createFlowProject(
            title: "First protocol project",
            category: .study
        ))
        XCTAssertTrue(resumed.beginFlowSetup(projectID: project.id))
        XCTAssertEqual(resumed.flowState.pendingSetup?.sessionOrigin, .protocol)
        XCTAssertEqual(resumed.flowState.pendingSetup?.programDay, 65)

        var draft = tryUnwrap(resumed.flowState.pendingSetup)
        draft.task = "Review the difficult chapter"
        draft.definitionOfDone = "Three ideas are reconstructed"
        resumed.updateFlowSetup(draft)
        XCTAssertTrue(resumed.startFlowBlock(
            environmentPlan: FlowEnvironmentPlan(),
            environmentArm: nil
        ))
        guard case .running(let running) = resumed.phase else {
            return XCTFail("The Today entry must start one protocol session")
        }
        XCTAssertEqual(running.origin, .protocol)

        finishAndSaveFlow(
            resumed,
            signal: .strongerSignal,
            actualMinutes: running.targetMinutes
        )
        XCTAssertEqual(resumed.day, 66)
        XCTAssertEqual(resumed.completedProtocolDays, 65)
        XCTAssertEqual(resumed.flowState.evidence.count, 1)
    }

    func testFreeAndStandaloneFlowBlocksNeverAdvanceProgram() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Research note", category: .writing))

        _ = startFlowBlock(store: store, projectID: project.id, origin: .freeTraining)
        finishAndSaveFlow(store, signal: .mixed)
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions.last?.origin, .freeTraining)
        XCTAssertEqual(store.freeTrainingSessions.count, 1)

        _ = startFlowBlock(store: store, projectID: project.id, origin: .flow)
        finishAndSaveFlow(store, signal: .strongerSignal)
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions.last?.origin, .flow)
        XCTAssertEqual(store.completedProtocolDays, 1)
        XCTAssertEqual(store.flowState.evidence.count, 2)
    }

    func testStandaloneFlowRemainsUsableAfterProgramCompletion() {
        let day90 = protocolRecord(day: 90, mode: .stay)
        var completed = ProgramState.migrated(day: 90, sessions: [day90])
        completed.pendingCompletion = false
        writeV8(
            profile: deepWorkProfile,
            sessions: [day90],
            programState: completed,
            flowState: .empty
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.programStatus, .completed)
        let project = tryUnwrap(store.createFlowProject(
            title: "Post-program research",
            category: .analysis
        ))

        _ = startFlowBlock(
            store: store,
            projectID: project.id,
            origin: .flow
        )
        finishAndSaveFlow(store, signal: .strongerSignal)

        XCTAssertEqual(store.day, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertEqual(store.sessions.last?.origin, .flow)
        XCTAssertEqual(store.flowState.evidence.count, 1)
        XCTAssertNil(store.protocolRequest())
    }

    func testDayOneAndRecoveryBlockFlowSetup() {
        let dayOne = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let baselineProject = tryUnwrap(dayOne.createFlowProject(title: "Baseline project", category: .other))
        XCTAssertNotNil(dayOne.flowWaitReason)
        XCTAssertFalse(dayOne.beginFlowSetup(projectID: baselineProject.id, origin: .flow))
        XCTAssertNil(dayOne.flowState.pendingSetup)

        clearPersistence()
        let recovery = makeProgramStore(day: 2, lastDifficulty: 5)
        let recoveryProject = tryUnwrap(recovery.createFlowProject(title: "Wait for recovery", category: .study))
        XCTAssertEqual(recovery.prescription.mode, .nothing)
        XCTAssertNotNil(recovery.flowWaitReason)
        XCTAssertFalse(recovery.beginFlowSetup(projectID: recoveryProject.id, origin: .flow))
        XCTAssertFalse(recovery.beginFlowSetup(projectID: recoveryProject.id, origin: .protocol))
        XCTAssertNil(recovery.flowState.pendingSetup)
    }

    func testDirectEntryCannotBypassRecoveryFlowGuard() {
        let history = [protocolRecord(day: 1, mode: .stay, difficulty: 5)]
        let project = makeProject(title: "Deferred project", category: .coding)
        let block = makeBlock(project: project, index: 0, signal: .insufficient)
        let state = FlowState(
            projects: [project],
            plans: [block.plan],
            activeBlockID: block.plan.blockID,
            activeProjectID: project.id
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: state
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.prescription.mode, .nothing)

        let request = TrainingSessionRequest(
            origin: .flow,
            mode: .stay,
            programDay: nil,
            targetMinutes: 20,
            goal: block.plan.task,
            task: block.plan.task,
            completionDefinition: block.plan.definitionOfDone,
            flowParticipation: makeParticipation(plan: block.plan)
        )
        store.begin(request: request)

        if case .running(let record) = store.phase {
            XCTAssertNil(record.flowParticipation, "Recovery must strip a directly injected Flow participation")
        }
        XCTAssertNil(store.flowState.activeBlockID)
    }

    func testDirectFlowEntryRejectsAProtectedPlanWithoutAnActivatedArm() {
        let history = [protocolRecord(day: 1, mode: .observe)]
        let project = makeProject(title: "Truthful protection", category: .coding)
        let fuel = FuelContextSnapshot(taskContext: .coding, capturedAt: Date())
        let environment = FlowEnvironmentPlan(
            phoneSetup: .screenTimeProtected,
            soundContext: .quiet,
            verification: .screenTimeIntervention,
            protectionActivated: true
        )
        let plan = FlowBlockPlan(
            projectID: project.id,
            task: "Implement the shield path",
            definitionOfDone: "Activation truth is preserved",
            challengeBefore: .stretching,
            skillConfidenceBefore: .capable,
            feedbackMechanism: .testsPassing,
            customFeedback: nil,
            suggestedDuration: 20,
            selectedDuration: 20,
            environmentPlan: environment,
            fuelContext: fuel,
            baseMode: .stay,
            sessionOrigin: .flow,
            programDay: nil
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: FlowState(
                projects: [project],
                plans: [plan],
                activeBlockID: plan.blockID,
                activeProjectID: project.id
            )
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.begin(request: TrainingSessionRequest(
            origin: .flow,
            mode: .stay,
            programDay: nil,
            targetMinutes: plan.selectedDuration,
            goal: plan.task,
            task: plan.task,
            completionDefinition: plan.definitionOfDone,
            appliedRuleIDs: [],
            flowParticipation: makeParticipation(plan: plan),
            fuelContext: fuel
        ))

        if case .running = store.phase {
            XCTFail("A protected Flow block cannot start without the real activated arm")
        }
        XCTAssertNil(store.flowState.activeBlockID)
        XCTAssertTrue(store.sessions.filter { $0.flowParticipation != nil }.isEmpty)
    }

    func testForgedProtocolFlowRequestCannotReplaceRecoveryPrescription() {
        let history = [protocolRecord(day: 1, mode: .stay, difficulty: 5)]
        let project = makeProject(title: "Recovery stays authoritative", category: .coding)
        let block = makeBlock(project: project, index: 0, signal: .insufficient)
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: FlowState(projects: [project], plans: [block.plan])
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.prescription.mode, .nothing)

        store.begin(request: TrainingSessionRequest(
            origin: .protocol,
            mode: .stay,
            programDay: 2,
            targetMinutes: 20,
            goal: block.plan.task,
            task: block.plan.task,
            completionDefinition: block.plan.definitionOfDone,
            flowParticipation: makeParticipation(plan: block.plan)
        ))

        if case .running = store.phase {
            XCTFail("A forged protocol Flow request must not replace Recovery")
        }
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions, history)
        XCTAssertNil(store.flowState.activeBlockID)
    }

    func testValidLookingProtocolFlowCannotRunOnAnIneligibleCurriculumDay() {
        let targetDay = 22
        let history = (1..<targetDay).map {
            protocolRecord(day: $0, mode: .observe, difficulty: 2)
        }
        let program = ProgramState.migrated(day: targetDay, sessions: history)
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: program,
            flowState: .empty
        )
        let probe = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let canonical = tryUnwrap(probe.protocolRequest())
        XCTAssertEqual(canonical.mode, .stay)
        XCTAssertFalse(probe.currentProtocolCanParticipateInFlow)

        let project = makeProject(title: "Ordinary stability day", category: .coding)
        let fuel = FuelContextSnapshot(taskContext: .coding, capturedAt: Date())
        let environment = FlowEnvironmentPlan(
            phoneSetup: .usual,
            soundContext: .usual,
            verification: .userReported,
            protectionActivated: false
        )
        let plan = FlowBlockPlan(
            projectID: project.id,
            task: "Attempt an ineligible Flow block",
            definitionOfDone: "The curriculum guard rejects it",
            challengeBefore: .stretching,
            skillConfidenceBefore: .capable,
            feedbackMechanism: .visibleOutput,
            customFeedback: nil,
            suggestedDuration: canonical.targetMinutes,
            selectedDuration: canonical.targetMinutes,
            environmentPlan: environment,
            fuelContext: fuel,
            baseMode: .stay,
            sessionOrigin: .protocol,
            programDay: targetDay
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: program,
            flowState: FlowState(
                projects: [project],
                plans: [plan],
                activeBlockID: plan.blockID,
                activeProjectID: project.id
            )
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        var request = tryUnwrap(store.protocolRequest())
        request.targetMinutes = plan.selectedDuration
        request.goal = plan.task
        request.task = plan.task
        request.completionDefinition = plan.definitionOfDone
        request.fuelContext = fuel
        request.appliedRuleIDs = []
        request.flowParticipation = makeParticipation(plan: plan)
        store.begin(
            request: request,
            environment: SessionEnvironmentArm(
                condition: .unrestricted,
                manualIntervention: "Usual phone setup",
                protectedSelectionID: nil,
                protectionOffered: false,
                protectionAccepted: false,
                protectionActivated: false,
                phoneLocationSelfReport: "Usual setup"
            )
        )

        if case .running = store.phase {
            XCTFail("Only the eligible curriculum intents may join Flow Lab")
        }
        XCTAssertEqual(store.day, targetDay)
        XCTAssertNil(store.flowState.activeBlockID)
    }

    func testProtocolFlowConsumesPendingFuelOnceWhileKeepingTheFrozenSnapshot() {
        let store = makeProgramStore(day: 65)
        let project = tryUnwrap(store.createFlowProject(title: "Fuel-aware protocol", category: .coding))
        let capture = completeFuel(capturedAt: Date())
        store.fuelState.pendingCapture = capture
        store.fuelState.recordAnswer(field: .energy)
        let sampling = store.fuelState.sampling

        let plan = startFlowBlock(store: store, projectID: project.id, origin: .protocol)

        XCTAssertEqual(plan.fuelContext, capture)
        XCTAssertNil(store.fuelState.pendingCapture)
        XCTAssertEqual(store.fuelState.sampling, sampling)
        guard case .running(let record) = store.phase else {
            return XCTFail("Expected running protocol Flow block")
        }
        XCTAssertEqual(record.fuelContext, capture)

        finishAndSaveFlow(store, signal: .strongerSignal, actualMinutes: record.targetMinutes)
        XCTAssertEqual(store.flowState.evidence.last?.fuelContext, capture)
    }

    func testFlowFuelFillsMissingProjectTaskContextAndConsumesCaptureOnce() {
        let store = makeProgramStore(day: 2)
        let coding = tryUnwrap(store.createFlowProject(title: "Parser", category: .coding))
        let capture = FuelContextSnapshot(energy: .okay, capturedAt: Date())
        store.fuelState.pendingCapture = capture

        let firstPlan = startFlowBlock(store: store, projectID: coding.id, origin: .flow)
        XCTAssertEqual(firstPlan.fuelContext?.energy, .okay)
        XCTAssertEqual(firstPlan.fuelContext?.taskContext, .coding)
        XCTAssertNil(store.fuelState.pendingCapture)
        guard case .running(let firstRecord) = store.phase else {
            return XCTFail("Expected first Flow session")
        }
        XCTAssertEqual(firstRecord.fuelContext, firstPlan.fuelContext)
        finishAndSaveFlow(store, signal: .strongerSignal)

        let writing = tryUnwrap(store.createFlowProject(title: "Essay", category: .writing))
        let secondPlan = startFlowBlock(store: store, projectID: writing.id, origin: .flow)
        XCTAssertNil(secondPlan.fuelContext?.energy, "Consumed context must not attach twice")
        XCTAssertEqual(secondPlan.fuelContext?.taskContext, .writing)
    }

    func testExtremeFlowDurationsAreRejectedOrIgnoredWithoutOverflow() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Bounded timer", category: .coding))
        XCTAssertTrue(store.beginFlowSetup(projectID: project.id, origin: .flow))
        var draft = tryUnwrap(store.flowState.pendingSetup)
        draft.task = "Exercise the timer"
        draft.definitionOfDone = "Overflow path is closed"
        draft.selectedDuration = .max
        store.updateFlowSetup(draft)

        XCTAssertFalse(store.startFlowBlock(environmentPlan: FlowEnvironmentPlan(), environmentArm: nil))
        XCTAssertTrue(store.flowState.plans.isEmpty)
        XCTAssertEqual(store.flowState.pendingSetup, draft)

        let malformedRecord = SessionRecord(
            origin: .flow,
            day: 2,
            date: Date(),
            mode: .stay,
            targetMinutes: .max,
            actualMinutes: 0,
            completed: false,
            endedEarly: false
        )
        store.phase = .running(malformedRecord)
        store.finishRunning(actualMinutes: 1, endedEarly: false)
        XCTAssertFalse(doneRecord(store).completed)

        store.phase = .running(SessionRecord(
            origin: .flow,
            day: 2,
            date: Date(),
            mode: .stay,
            targetMinutes: 20,
            actualMinutes: 0,
            completed: false
        ))
        store.finishRunning(actualMinutes: .max, endedEarly: false)
        XCTAssertTrue(doneRecord(store).endedEarly)
        XCTAssertFalse(doneRecord(store).completed)

        let blocks = (0..<4).map { index -> FlowBlockFixture in
            var block = makeBlock(project: project, index: index, signal: .strongerSignal)
            block.evidence.actualDuration = .max
            return block
        }
        XCTAssertTrue(FlowConditionEngine.evaluate(state: FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )).isEmpty)
    }

    func testActiveFlowSessionAndPendingReflectionRestoreWithoutDuplicateEvidence() {
        let first = makeProgramStore(day: 2)
        let project = tryUnwrap(first.createFlowProject(title: "Persistent block", category: .coding))
        let plan = startFlowBlock(store: first, projectID: project.id, origin: .flow)
        guard case .running(let running) = first.phase else {
            return XCTFail("Expected running Flow session")
        }

        let recovered = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .recovery(let recoveredRecord) = recovered.phase else {
            return XCTFail("Expected canonical active-session recovery")
        }
        XCTAssertEqual(recoveredRecord.id, running.id)
        XCTAssertEqual(recoveredRecord.date, running.date, "Restoration must not reset the timer anchor")
        XCTAssertEqual(recovered.flowState.activeBlockID, plan.blockID)

        recovered.resumeRecoveredSession()
        recovered.finishRunning(actualMinutes: 20, endedEarly: false)
        let awaitingReflection = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .done(let pending) = awaitingReflection.phase else {
            return XCTFail("Expected pending Flow reflection to survive relaunch")
        }
        XCTAssertEqual(pending.id, running.id)

        awaitingReflection.saveDoneSession(SessionReflection(
            flowReflection: reflection(for: .strongerSignal)
        ))
        XCTAssertEqual(awaitingReflection.flowState.evidence.count, 1)

        let finalized = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(finalized.sessions.filter { $0.id == running.id }.count, 1)
        XCTAssertEqual(finalized.flowState.evidence.filter { $0.sessionID == running.id }.count, 1)
        XCTAssertNil(finalized.flowState.activeBlockID)
    }

    func testRecoveredScreenTimeTruthReflectsWhetherProtectionWasActuallyRestored() {
        let first = makeProgramStore(day: 2)
        let project = tryUnwrap(first.createFlowProject(
            title: "Recovered protection",
            category: .coding
        ))
        var failedStore = first
        for expectedEvidenceCount in 1...3 {
            _ = startFlowBlock(
                store: failedStore,
                projectID: project.id,
                origin: .flow,
                environmentPlan: FlowEnvironmentPlan(
                    phoneSetup: .screenTimeProtected,
                    soundContext: .quiet,
                    verification: .screenTimeIntervention,
                    protectionActivated: true
                ),
                environmentArm: protectedArm()
            )

            let recovered = ProductStore(diagnosisAnswers: [:], defaults: defaults)
            guard case .recovery = recovered.phase else {
                return XCTFail("Expected protected-session recovery")
            }
            recovered.resumeRecoveredSession(protectionRestored: false)
            guard case .running(let downgraded) = recovered.phase else {
                return XCTFail("Expected the downgraded session to resume")
            }
            XCTAssertEqual(downgraded.environment?.protectionActivated, false)
            XCTAssertEqual(
                downgraded.environment?.environmentCondition,
                EnvironmentCondition.unrestricted.rawValue
            )
            XCTAssertEqual(downgraded.environmentVerification, .unknown)
            recovered.finishRunning(actualMinutes: 20, endedEarly: false)
            recovered.saveDoneSession(SessionReflection(
                flowReflection: reflection(for: .strongerSignal)
            ))
            XCTAssertEqual(recovered.flowState.evidence.count, expectedEvidenceCount)
            failedStore = recovered
        }
        XCTAssertTrue(failedStore.flowState.evidence.allSatisfy {
            $0.environment?.protectionActivated == false
        })
        XCTAssertNil(failedStore.flowPatterns.first {
            $0.dimension == .screenTimeProtection || $0.dimension == .phoneSetup
        })

        clearPersistence()
        let second = makeProgramStore(day: 2)
        let secondProject = tryUnwrap(second.createFlowProject(
            title: "Restored protection",
            category: .coding
        ))
        _ = startFlowBlock(
            store: second,
            projectID: secondProject.id,
            origin: .flow,
            environmentPlan: FlowEnvironmentPlan(
                phoneSetup: .screenTimeProtected,
                soundContext: .quiet,
                verification: .screenTimeIntervention,
                protectionActivated: true
            ),
            environmentArm: protectedArm()
        )
        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        restored.resumeRecoveredSession(protectionRestored: true)
        guard case .running(let protected) = restored.phase else {
            return XCTFail("Expected restored protection to resume")
        }
        XCTAssertEqual(protected.environment?.protectionActivated, true)
        XCTAssertEqual(
            protected.environment?.environmentCondition,
            EnvironmentCondition.protected.rawValue
        )
        XCTAssertEqual(protected.environmentVerification, .screenTimeIntervention)
    }

    func testPendingFlowSetupRestoresWithEveryUserEnteredField() {
        let first = makeProgramStore(day: 2)
        let project = tryUnwrap(first.createFlowProject(title: "Resume setup", category: .writing))
        XCTAssertTrue(first.beginFlowSetup(projectID: project.id, origin: .flow))
        var draft = tryUnwrap(first.flowState.pendingSetup)
        draft.task = "Draft the opening section"
        draft.definitionOfDone = "Opening has a claim and two examples"
        draft.challenge = .hard
        draft.skillConfidence = .strong
        draft.feedbackMechanism = .other
        draft.customFeedback = "The argument reads cleanly"
        draft.selectedDuration = 35
        draft.phoneSetup = .outsideReach
        draft.soundContext = .backgroundSound
        draft.browserScope = "Source and draft only"
        draft.confirmedRuleIDs = [UUID()]
        first.updateFlowSetup(draft)

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)

        guard case .flowSetup = restored.phase else {
            return XCTFail("An unfinished Flow setup should reopen after relaunch")
        }
        XCTAssertEqual(restored.flowState.pendingSetup, draft)
        XCTAssertTrue(restored.flowState.plans.isEmpty)
        XCTAssertTrue(restored.flowState.evidence.isEmpty)
    }

    func testFlowStatePendingEntryOriginRoundTripsAndOlderPayloadDefaultsSafely() throws {
        let state = FlowState(pendingEntryOrigin: .protocol)
        let encoded = try JSONEncoder().encode(state)
        XCTAssertEqual(
            try JSONDecoder().decode(FlowState.self, from: encoded).pendingEntryOrigin,
            .protocol
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "pendingEntryOrigin")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(
            try JSONDecoder().decode(FlowState.self, from: legacy).pendingEntryOrigin
        )
    }

    func testEarlyEndedFlowBlockStillPersistsHonestEvidence() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Hard chapter", category: .study))
        _ = startFlowBlock(store: store, projectID: project.id, origin: .flow)
        store.finishRunning(actualMinutes: 4, endedEarly: true)
        store.saveDoneSession(SessionReflection(
            flowReflection: reflection(for: .mixed)
        ))

        let evidence = tryUnwrap(store.flowState.evidence.first)
        XCTAssertTrue(evidence.endedEarly)
        XCTAssertFalse(evidence.completed)
        XCTAssertEqual(evidence.actualDuration, 4)
        XCTAssertEqual(evidence.reflection, reflection(for: .mixed))
    }

    func testArchivingProjectRetainsPlanEvidenceAndPatternInputs() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Archived essay", category: .writing))
        _ = startFlowBlock(store: store, projectID: project.id, origin: .flow)
        finishAndSaveFlow(store, signal: .strongerSignal)
        let evidenceID = tryUnwrap(store.flowState.evidence.first?.id)
        let planID = tryUnwrap(store.flowState.plans.first?.id)

        store.archiveFlowProject(id: project.id)

        XCTAssertEqual(store.flowProject(id: project.id)?.status, .archived)
        XCTAssertEqual(store.flowState.evidence.map(\.id), [evidenceID])
        XCTAssertEqual(store.flowState.plans.map(\.id), [planID])
        XCTAssertEqual(store.flowState.evidence.first?.projectID, project.id)
    }

    func testTestingFlowPatternDelegatesToPersonalLabAndDoesNotAutoCreateRule() {
        let project = makeProject(category: .coding)
        let blocks = (0..<4).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                phoneSetup: .outsideReach,
                protectionActivated: false,
                verification: .userReported
            )
        }
        let flowState = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
        let history = [protocolRecord(day: 1, mode: .observe)]
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: flowState
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let pattern = tryUnwrap(
            store.flowPatterns.first { $0.dimension == .phoneSetup }
        )

        XCTAssertTrue(store.canTestFlowPattern(pattern))
        guard case .started = store.testFlowPattern(pattern) else {
            return XCTFail("Flow uncertainty should delegate to the canonical Personal Lab engine")
        }
        XCTAssertNotNil(store.activeExperiment)
        XCTAssertTrue(store.personalRules.isEmpty, "A Flow association must never auto-create or keep a Personal Rule")
        guard case .lab = store.phase else {
            return XCTFail("Expected canonical Personal Lab destination")
        }
    }

    func testOpenQuestionExperimentRequiresRealComparableEvidenceAndCapability() {
        let history = [protocolRecord(day: 1, mode: .observe)]
        let project = makeProject(title: "Evidence provenance", category: .coding)
        let bridgeBlocks = [10, 30, 50].enumerated().map { index, duration in
            makeBlock(
                project: project,
                index: index,
                signal: .strongerSignal,
                duration: duration
            )
        }
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: FlowState(
                projects: [project],
                plans: bridgeBlocks.map(\.plan),
                evidence: bridgeBlocks.map(\.evidence)
            )
        )
        let bridgeStore = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .unavailable = bridgeStore.testFlowDimension(
            .sound,
            evidenceIDs: bridgeBlocks.map(\.evidence.id)
        ) else {
            return XCTFail("Bridge comparability must be rejected by the backend")
        }

        clearPersistence()
        let comparableBlocks = (0..<3).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                duration: 30
            )
        }
        let comparableState = FlowState(
            projects: [project],
            plans: comparableBlocks.map(\.plan),
            evidence: comparableBlocks.map(\.evidence)
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: comparableState
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .unavailable = store.testFlowDimension(
            .sound,
            evidenceIDs: [UUID(), UUID(), UUID()]
        ) else {
            return XCTFail("Fabricated evidence IDs must never become provenance")
        }
        guard case .unavailable = store.testFlowDimension(
            .screenTimeProtection,
            evidenceIDs: comparableBlocks.map(\.evidence.id),
            screenTimeAvailable: false
        ) else {
            return XCTFail("Screen Time tests need an available connection and selection")
        }
        guard case .started = store.testFlowDimension(
            .sound,
            evidenceIDs: comparableBlocks.map(\.evidence.id)
        ) else {
            return XCTFail("Three real comparable blocks should open Personal Lab")
        }
        XCTAssertEqual(store.activeExperiment?.sourceFlowPatternID, "open.sound")
        XCTAssertEqual(
            Set(store.activeExperiment?.discoveryEvidenceIDs ?? []),
            Set(comparableBlocks.map(\.evidence.id))
        )
        XCTAssertTrue(store.personalRules.isEmpty)

        clearPersistence()
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: comparableState
        )
        let capableStore = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .started = capableStore.testFlowDimension(
            .screenTimeProtection,
            evidenceIDs: comparableBlocks.map(\.evidence.id),
            screenTimeAvailable: true
        ) else {
            return XCTFail("A real Screen Time capability may open the canonical comparison")
        }
        XCTAssertEqual(
            capableStore.activeExperiment?.templateID,
            ExperimentTemplateLibrary.sessionProtection.id
        )
    }

    func testStandaloneFlowDoesNotAutoApplyOrInflateExistingRules() {
        let history = [protocolRecord(day: 1, mode: .observe)]
        var profile = deepWorkProfile
        let existingRule = keptRule()
        var recallOnlyRule = keptRule()
        recallOnlyRule.id = UUID()
        recallOnlyRule.title = "Use this only for recall"
        recallOnlyRule.matchingContexts = [.recall]
        let originalRules = [existingRule, recallOnlyRule]
        profile.personalRules = originalRules
        writeV8(
            profile: profile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: .empty
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let project = tryUnwrap(store.createFlowProject(title: "No implicit rules", category: .coding))

        _ = startFlowBlock(
            store: store,
            projectID: project.id,
            origin: .flow,
            environmentPlan: FlowEnvironmentPlan()
        )
        guard case .running(let record) = store.phase else {
            return XCTFail("Expected standalone Flow session")
        }
        XCTAssertTrue(record.appliedRuleIDs.isEmpty)
        finishAndSaveFlow(store, signal: .strongerSignal)

        XCTAssertEqual(store.personalRules.count, 1)
        XCTAssertEqual(store.personalRules.first?.id, existingRule.id)
        XCTAssertEqual(store.personalRules.first?.lifecycle, .kept)
        XCTAssertEqual(store.personalRules.first?.timesKept, existingRule.timesKept)
        XCTAssertTrue(store.flowState.plans.last?.environmentPlan.appliedRuleIDs.isEmpty == true)
    }

    func testExplicitFlowRuleConfirmationIsCapturedWithoutTestingOrMutatingTheRule() {
        let history = [protocolRecord(day: 1, mode: .observe)]
        var profile = deepWorkProfile
        let existingRule = keptRule()
        profile.personalRules = [existingRule]
        writeV8(
            profile: profile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: .empty
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let project = tryUnwrap(store.createFlowProject(
            title: "Explicit setup",
            category: .coding
        ))

        let plan = startFlowBlock(
            store: store,
            projectID: project.id,
            origin: .flow,
            confirmedRuleIDs: [UUID(), existingRule.id, existingRule.id, recallOnlyRule.id]
        )
        guard case .running(let record) = store.phase else {
            return XCTFail("Expected a running confirmed-rule Flow block")
        }
        XCTAssertEqual(plan.environmentPlan.appliedRuleIDs, [existingRule.id])
        XCTAssertEqual(record.appliedRuleIDs, [existingRule.id])

        finishAndSaveFlow(store, signal: .strongerSignal)
        XCTAssertEqual(store.personalRules, originalRules)
        XCTAssertEqual(store.profile.personalRules, originalRules)

        _ = startFlowBlock(
            store: store,
            projectID: project.id,
            origin: .flow,
            confirmedRuleIDs: [existingRule.id]
        )
        finishAndSaveFlow(
            store,
            signal: .lowerSignal,
            actualMinutes: 4,
            endedEarly: true
        )
        XCTAssertEqual(store.personalRules, originalRules)
        XCTAssertEqual(store.profile.personalRules, originalRules)
        XCTAssertEqual(store.flowState.evidence.count, 2)
    }

    func testFlowDurationSuggestionNeedsThreeSignalsAndMovesOneStepWithoutInflatingProfile() {
        let history = [protocolRecord(day: 1, mode: .observe)]
        var profile = deepWorkProfile
        profile.focusWindowMinutes = 20
        writeV8(
            profile: profile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: .empty
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let project = tryUnwrap(store.createFlowProject(
            title: "Long-form implementation",
            category: .coding
        ))

        for evidenceCount in 1...3 {
            _ = startFlowBlock(
                store: store,
                projectID: project.id,
                origin: .flow,
                selectedDuration: 60
            )
            finishAndSaveFlow(
                store,
                signal: .strongerSignal,
                actualMinutes: 60
            )
            XCTAssertEqual(store.profile.focusWindowMinutes, 20)
            XCTAssertEqual(
                store.suggestedFlowDuration,
                evidenceCount < 3 ? 20 : 25
            )
        }
    }

    func testThreeRealFlowSavesDoNotAutoCreateGenericCandidateRules() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Repeated real work", category: .coding))

        for signal in [
            FlowEngagementSignal.strongerSignal,
            .strongerSignal,
            .mixed,
        ] {
            _ = startFlowBlock(store: store, projectID: project.id, origin: .flow)
            finishAndSaveFlow(store, signal: signal)
        }

        XCTAssertEqual(store.flowState.evidence.count, 3)
        XCTAssertEqual(store.sessions.filter { $0.origin == .flow }.count, 3)
        XCTAssertTrue(store.personalRules.isEmpty)
        XCTAssertTrue(store.profile.personalRules.isEmpty)
    }

    func testStandaloneFlowConsumesFuelCaptureOnceWithoutMutatingSnapshotOrPromptLog() {
        let store = makeProgramStore(day: 2)
        let project = tryUnwrap(store.createFlowProject(title: "Fuel context", category: .coding))
        let capture = completeFuel(capturedAt: Date())
        store.fuelState.pendingCapture = capture
        store.fuelState.recordAnswer(field: .energy)
        let samplingBefore = store.fuelState.sampling

        _ = startFlowBlock(store: store, projectID: project.id, origin: .flow)
        XCTAssertNil(store.fuelState.pendingCapture)
        finishAndSaveFlow(store, signal: .strongerSignal)

        XCTAssertEqual(store.flowState.plans.last?.fuelContext, capture)
        XCTAssertEqual(store.flowState.evidence.last?.fuelContext, capture)
        XCTAssertNil(store.fuelState.pendingCapture)
        XCTAssertEqual(store.fuelState.sampling, samplingBefore)
        XCTAssertNil(store.currentFuelPrompt, "Using an already-answered capture must not trigger another prompt")
    }

    func testProtocolCheckpointCompletesBeforeDeferredReturnToFlowLab() {
        let store = makeProgramStore(day: 70)
        XCTAssertTrue(store.currentProtocolCanParticipateInFlow)
        let project = tryUnwrap(store.createFlowProject(title: "Checkpoint block", category: .coding))
        _ = startFlowBlock(store: store, projectID: project.id, origin: .protocol)
        guard case .running(let running) = store.phase else {
            return XCTFail("Expected running checkpoint block")
        }
        finishAndSaveFlow(store, signal: .strongerSignal, actualMinutes: running.targetMinutes)

        guard case .weeklyReview(70) = store.phase else {
            return XCTFail("Program checkpoint must remain authoritative")
        }
        store.skipWeeklyReviewQuestions()
        guard case .flowLab = store.phase else {
            return XCTFail("Flow Lab return should resume after the required Program checkpoint")
        }
    }

    func testRequiredProgramFlowsPrecedeAndThenRestoreAPendingFlowSetup() {
        let history = [protocolRecord(day: 70, mode: .stay)]
        var program = ProgramState.migrated(day: 71, sessions: history)
        program.pendingReviewDay = 70
        program.pendingPhaseTransition = .findConditions
        let project = makeProject(title: "Deferred setup", category: .study)
        let draft = FlowSetupDraft(
            projectID: project.id,
            sessionOrigin: .flow,
            task: "Resume after required Program screens",
            definitionOfDone: "The setup reappears intact"
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: program,
            flowState: FlowState(
                projects: [project],
                pendingSetup: draft,
                activeProjectID: project.id
            )
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .weeklyReview(70) = store.phase else {
            return XCTFail("Weekly review must win restoration priority")
        }
        store.skipWeeklyReviewQuestions()
        guard case .phaseTransition(.findConditions) = store.phase else {
            return XCTFail("Phase transition must follow the weekly review")
        }
        store.acknowledgePhaseTransition()
        guard case .flowSetup = store.phase else {
            return XCTFail("Pending Flow setup should resume after required Program flows")
        }
        XCTAssertEqual(store.flowState.pendingSetup, draft)

        clearPersistence()
        let day90 = protocolRecord(day: 90, mode: .stay)
        var completed = ProgramState.migrated(day: 90, sessions: [day90])
        completed.pendingCompletion = true
        writeV8(
            profile: deepWorkProfile,
            sessions: [day90],
            programState: completed,
            flowState: FlowState(
                projects: [project],
                pendingSetup: draft,
                activeProjectID: project.id
            )
        )
        let finalStore = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .programCompletion = finalStore.phase else {
            return XCTFail("Program completion must win restoration priority")
        }
        finalStore.acknowledgeProgramCompletion()
        guard case .flowSetup = finalStore.phase else {
            return XCTFail("Setup should survive the Day 90 completion acknowledgement")
        }
        XCTAssertEqual(finalStore.flowState.pendingSetup, draft)
    }

    // MARK: - Persistence v8

    func testProcessedProtocolReflectionReconstructsMissingSessionAndEvidenceOnce() {
        let project = makeProject(title: "Crash-window recovery", category: .coding)
        let fuel = FuelContextSnapshot(taskContext: .coding, capturedAt: Date())
        let plan = FlowBlockPlan(
            projectID: project.id,
            task: "Finalize the atomic save",
            definitionOfDone: "Session and evidence both exist",
            challengeBefore: .stretching,
            skillConfidenceBefore: .capable,
            feedbackMechanism: .testsPassing,
            customFeedback: nil,
            suggestedDuration: 20,
            selectedDuration: 20,
            environmentPlan: FlowEnvironmentPlan(
                phoneSetup: .usual,
                verification: .userReported,
                protectionActivated: false
            ),
            fuelContext: fuel,
            baseMode: .stay,
            sessionOrigin: .protocol,
            programDay: 65
        )
        let record = SessionRecord(
            origin: .protocol,
            requestID: UUID(),
            day: 65,
            date: Date(),
            mode: .stay,
            targetMinutes: 20,
            actualMinutes: 20,
            elapsedSeconds: 1_200,
            completed: true,
            endedEarly: false,
            evidence: SessionEvidence(stay: StayEvidence(
                task: plan.task,
                completionDefinition: plan.definitionOfDone
            )),
            appliedRuleIDs: [],
            flowParticipation: makeParticipation(plan: plan),
            fuelContext: fuel
        )
        var program = ProgramState.migrated(day: 66, sessions: [])
        program.processedProtocolSessionIDs.insert(record.id)
        writeV8(
            profile: deepWorkProfile,
            sessions: [],
            programState: program,
            flowState: FlowState(
                projects: [project],
                plans: [plan],
                activeBlockID: plan.blockID,
                activeProjectID: project.id
            ),
            pendingReflectionSession: record
        )

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        guard case .done(let restored) = store.phase else {
            return XCTFail("Expected the crash-window reflection to restore")
        }
        XCTAssertEqual(restored.id, record.id)
        store.saveDoneSession(SessionReflection(
            difficulty: 2,
            flowReflection: reflection(for: .strongerSignal)
        ))
        XCTAssertEqual(store.day, 66)
        XCTAssertEqual(store.sessions.map(\.id), [record.id])
        XCTAssertEqual(store.flowState.evidence.map(\.sessionID), [record.id])

        let relaunched = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        if case .done = relaunched.phase {
            XCTFail("A reconstructed reflection must not resurrect after relaunch")
        }
        XCTAssertEqual(relaunched.sessions.map(\.id), [record.id])
        XCTAssertEqual(relaunched.flowState.evidence.map(\.sessionID), [record.id])
    }

    func testV7MigratesToV8WithExistingDomainsAndAnEmptyFlowState() throws {
        let history = [protocolRecord(day: 1, mode: .observe)]
        let state = ProgramState.migrated(day: 2, sessions: history)
        var fuel = FuelState.empty
        fuel.promptsEnabled = false
        defaults.set([
            "profile": try JSONEncoder().encode(deepWorkProfile),
            "sessions": try JSONEncoder().encode(history),
            "day": 2,
            "programState": try JSONEncoder().encode(state),
            "personalLab": try JSONEncoder().encode(PersonalLabState.empty),
            "fuel": try JSONEncoder().encode(fuel),
        ], forKey: "reboot.product.v7")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions.map(\.id), history.map(\.id))
        XCTAssertFalse(store.fuelState.promptsEnabled)
        XCTAssertEqual(store.flowState, .empty)
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v8"))
        XCTAssertNil(defaults.object(forKey: "reboot.product.v7"))
    }

    func testCorruptedFlowElementIsSkippedWithoutDroppingValidElements() throws {
        let goodProject = makeProject(title: "Keep me", category: .coding)
        let state = FlowState(projects: [goodProject])
        let encoded = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var projects = try XCTUnwrap(object["projects"] as? [[String: Any]])
        projects.append([
            "id": UUID().uuidString,
            "title": 42,
            "category": "not-a-category",
            "createdAt": 0,
            "updatedAt": 0,
            "status": "active",
        ])
        object["projects"] = projects
        let corrupted = try JSONSerialization.data(withJSONObject: object)

        let recovered = try JSONDecoder().decode(FlowState.self, from: corrupted)

        XCTAssertEqual(recovered.projects, [goodProject])
        XCTAssertTrue(recovered.plans.isEmpty)
        XCTAssertTrue(recovered.evidence.isEmpty)
    }

    func testCorruptStandaloneFlowParticipationCannotMutateGenericProfileOrRules() throws {
        let project = makeProject(title: "Corrupt participation", category: .coding)
        let plan = makeBlock(
            project: project,
            index: 0,
            signal: .strongerSignal,
            duration: 60
        ).plan
        let existingRule = keptRule()
        var profile = deepWorkProfile
        profile.focusWindowMinutes = 20
        profile.personalRules = [existingRule]
        let valid = SessionRecord(
            origin: .flow,
            requestID: UUID(),
            day: 2,
            date: Date(),
            mode: .stay,
            targetMinutes: 60,
            actualMinutes: 60,
            elapsedSeconds: 3_600,
            completed: true,
            endedEarly: false,
            switches: 1,
            difficulty: 1,
            appliedRuleIDs: [existingRule.id],
            flowParticipation: makeParticipation(plan: plan)
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        object["flowParticipation"] = ["malformed": true]
        let corrupted = try JSONSerialization.data(withJSONObject: object)
        let recovered = try JSONDecoder().decode(SessionRecord.self, from: corrupted)
        XCTAssertEqual(recovered.origin, .flow)
        XCTAssertNil(recovered.flowParticipation)
        XCTAssertTrue(recovered.flowParticipationWasMalformed)

        let history = [protocolRecord(day: 1, mode: .observe)]
        writeV8(
            profile: profile,
            sessions: history,
            programState: .migrated(day: 2, sessions: history),
            flowState: FlowState(projects: [project], plans: [plan]),
            pendingReflectionSession: recovered
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.saveDoneSession(SessionReflection(difficulty: 1, switches: 1))

        XCTAssertEqual(store.profile.focusWindowMinutes, 20)
        XCTAssertEqual(store.personalRules, [existingRule])
        XCTAssertEqual(store.profile.personalRules, [existingRule])
        XCTAssertTrue(store.flowState.evidence.isEmpty)
        XCTAssertEqual(store.sessions.filter { $0.id == recovered.id }.count, 1)
    }

    func testCorruptFlowProvenanceDegradesLossilyWithoutDroppingPersonalExperiment() throws {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.clearFinishLine,
            origin: .evidenceSuggestion,
            now: dateAt(hour: 12)
        )
        experiment.sourceFlowPatternID = "finishLine.Clear"
        experiment.discoveryEvidenceIDs = [UUID(), UUID(), UUID()]
        let encoded = try JSONEncoder().encode(experiment)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["sourceFlowPatternID"] = ["unexpected": true]
        object["discoveryEvidenceIDs"] = ["not-a-uuid", 17]
        let corrupted = try JSONSerialization.data(withJSONObject: object)

        let recovered = try JSONDecoder().decode(PersonalExperiment.self, from: corrupted)

        XCTAssertEqual(recovered.id, experiment.id)
        XCTAssertEqual(recovered.templateID, experiment.templateID)
        XCTAssertEqual(recovered.question, experiment.question)
        XCTAssertEqual(recovered.normalArm, experiment.normalArm)
        XCTAssertEqual(recovered.testArm, experiment.testArm)
        XCTAssertNil(recovered.sourceFlowPatternID)
        XCTAssertTrue(recovered.discoveryEvidenceIDs.isEmpty)
    }

    func testCorruptV8FlowPayloadPreservesCoreAndNeverRollsBackToStaleV7() throws {
        let currentHistory = [protocolRecord(day: 1, mode: .observe)]
        writeV8(
            profile: deepWorkProfile,
            sessions: currentHistory,
            programState: .migrated(day: 2, sessions: currentHistory),
            flowData: Data("invalid-flow-json".utf8)
        )

        let staleHistory = (1...20).map { protocolRecord(day: $0, mode: .stay) }
        defaults.set([
            "profile": try JSONEncoder().encode(AttentionProfile(focusWindowMinutes: 60)),
            "sessions": try JSONEncoder().encode(staleHistory),
            "day": 21,
            "programState": try JSONEncoder().encode(ProgramState.migrated(day: 21, sessions: staleHistory)),
        ], forKey: "reboot.product.v7")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)

        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions.map(\.id), currentHistory.map(\.id))
        XCTAssertEqual(store.profile.primaryGoal.value, "deep_work")
        XCTAssertEqual(store.flowState, .empty)
    }

    // MARK: - Long-range deterministic simulations

    func testStudySimulationKeepsRecallAndStayEvidenceInSeparateDaypartCohorts() {
        let project = makeProject(title: "Neuroscience course", category: .study)
        let morningStay = (0..<3).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                date: dateAt(hour: 8, dayOffset: $0),
                baseMode: .stay
            )
        }
        let eveningRecall = (0..<3).map {
            makeBlock(
                project: project,
                index: $0 + 3,
                signal: .strongerSignal,
                date: dateAt(hour: 20, dayOffset: $0 + 20),
                baseMode: .recall
            )
        }
        let blocks = morningStay + eveningRecall
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )

        XCTAssertFalse(FlowComparabilityEngine.areComparable(
            morningStay[0].evidence,
            eveningRecall[0].evidence,
            state: state
        ))
        let daypart = tryUnwrap(
            FlowConditionEngine.evaluate(state: state).first { $0.dimension == .daypart }
        )
        XCTAssertEqual(daypart.value, FuelDaypart.evening.label)
        XCTAssertEqual(daypart.maturity, .earlySignal)
        XCTAssertEqual(daypart.comparableCount, 3)
    }

    func testDeepWorkBuilderSimulationFindsRepeatedAssociationsWithoutCreatingRules() {
        let project = makeProject(title: "Offline sync", category: .coding)
        let blocks = (0..<5).map {
            makeBlock(
                project: project,
                index: $0,
                signal: .strongerSignal,
                date: dateAt(hour: 10, dayOffset: $0),
                duration: 35,
                phoneSetup: .screenTimeProtected,
                protectionActivated: true
            )
        }
        let state = FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
        writeV8(
            profile: deepWorkProfile,
            sessions: [],
            programState: .fresh,
            flowState: state
        )
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let dimensions = Set(store.flowPatterns.map { $0.dimension.rawValue })

        XCTAssertTrue(dimensions.isSuperset(of: [
            FlowConditionDimension.finishLine.rawValue,
            FlowConditionDimension.phoneSetup.rawValue,
            FlowConditionDimension.screenTimeProtection.rawValue,
            FlowConditionDimension.energy.rawValue,
        ]))
        XCTAssertTrue(store.flowPatterns.allSatisfy { $0.maturity == .repeatedSignal })
        XCTAssertTrue(store.personalRules.isEmpty)
        XCTAssertTrue(store.labState.experiments.isEmpty)
    }

    func testLowDataSimulationProducesNoConclusionOrConfidenceInflation() {
        let state = makeState(signals: [.strongerSignal, .strongerSignal])
        XCTAssertTrue(FlowConditionEngine.evaluate(state: state).isEmpty)
    }

    func testNinetyDayProductStoreProgramNeverCreatesDayNinetyOneOrMutatesRulesFromFlow() {
        let store = makeProgramStore(day: 1)
        let project = tryUnwrap(store.createFlowProject(
            title: "Ninety-day study system",
            category: .study
        ))
        var flowSessionCount = 0
        var answeredFuelPromptCount = 0

        for expectedDay in 1...90 {
            XCTAssertEqual(store.day, expectedDay)
            XCTAssertEqual(store.completedProtocolDays, expectedDay - 1)

            if let prompt = store.currentFuelPrompt,
               let answer = prompt.options.first?.rawValue {
                store.answerFuelPrompt(prompt, rawValue: answer)
                answeredFuelPromptCount += 1
            }

            let usesFlow = store.currentProtocolCanParticipateInFlow
            let rulesBeforeFlow = store.personalRules
            if usesFlow {
                _ = startFlowBlock(
                    store: store,
                    projectID: project.id,
                    origin: .protocol
                )
                flowSessionCount += 1
            } else {
                let request = tryUnwrap(store.protocolRequest())
                store.begin(request: request)
            }

            guard case .running(let running) = store.phase else {
                return XCTFail("Day \(expectedDay) did not create one canonical session")
            }
            store.finishRunning(
                actualMinutes: running.targetMinutes,
                endedEarly: false
            )
            store.saveDoneSession(SessionReflection(
                difficulty: 2,
                energy: 3,
                firstDistraction: "none",
                switches: running.mode == .stay || running.mode == .observe ? 1 : nil,
                firstSwitchTiming: running.mode == .stay || running.mode == .observe
                    ? .tenToTwenty
                    : nil,
                recallAssessment: running.mode == .recall ? .most : nil,
                explanationAssessment: running.mode == .explain ? .yes : nil,
                nothingDifficulty: running.mode == .nothing ? .nothingInParticular : nil,
                observation: running.mode == .observe ? "Returned to the same task." : nil,
                flowReflection: usesFlow ? reflection(for: .strongerSignal) : nil
            ))
            if usesFlow {
                XCTAssertEqual(
                    store.personalRules,
                    rulesBeforeFlow,
                    "Flow evidence cannot mutate Personal Rules"
                )
            }

            var routing = true
            while routing {
                switch store.phase {
                case .weeklyReview:
                    store.skipWeeklyReviewQuestions()
                case .phaseTransition:
                    store.acknowledgePhaseTransition()
                case .programCompletion:
                    store.acknowledgeProgramCompletion()
                case .flowLab:
                    store.closeFlowLab()
                    routing = false
                default:
                    routing = false
                }
            }
        }

        XCTAssertEqual(store.day, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programProgress, 1, accuracy: 0.000_001)
        XCTAssertEqual(store.protocolSessions.count, 90)
        XCTAssertEqual(Set(store.protocolSessions.map(\.day)), Set(1...90))
        XCTAssertEqual(Set(store.protocolSessions.map(\.id)).count, 90)
        XCTAssertEqual(store.programState.processedProtocolSessionIDs.count, 90)
        XCTAssertGreaterThan(flowSessionCount, 0)
        XCTAssertEqual(
            store.protocolSessions.filter { $0.flowParticipation != nil }.count,
            flowSessionCount
        )
        XCTAssertEqual(store.flowState.evidence.count, flowSessionCount)
        XCTAssertEqual(Set(store.flowState.evidence.map(\.sessionID)).count, flowSessionCount)
        XCTAssertEqual(store.flowState.plans.count, flowSessionCount)
        XCTAssertTrue(store.protocolSessions.contains { $0.mode == .stay })
        XCTAssertTrue(store.protocolSessions.contains { $0.mode == .recall })
        XCTAssertNil(store.fuelState.pendingCapture)
        XCTAssertEqual(
            store.fuelState.sampling.answeredCounts.values.reduce(0, +),
            answeredFuelPromptCount
        )
        XCTAssertLessThanOrEqual(answeredFuelPromptCount, 1)
        XCTAssertTrue(store.labState.experiments.isEmpty)
        XCTAssertNil(store.protocolRequest())

        let sessionCount = store.sessions.count
        store.begin(request: TrainingSessionRequest(
            origin: .protocol,
            mode: .stay,
            programDay: 91,
            targetMinutes: 20,
            goal: "Day 91 must not exist"
        ))
        XCTAssertEqual(store.sessions.count, sessionCount)
        XCTAssertEqual(store.day, 90)
    }

    // MARK: - Fixtures

    private typealias FlowBlockFixture = (plan: FlowBlockPlan, evidence: FlowBlockEvidence)

    private var deepWorkProfile: AttentionProfile {
        AttentionProfile(
            primaryGoal: .known("deep_work", source: .selfReport),
            goals: .known(["deep_work"], source: .selfReport),
            distractors: .known([Distractor.tabs], source: .selfReport),
            focusWindowMinutes: 30
        )
    }

    private func makeProject(
        title: String = "Long-form essay",
        category: FlowProjectCategory = .writing
    ) -> FlowProject {
        FlowProject(
            title: title,
            category: category,
            createdAt: dateAt(hour: 8),
            updatedAt: dateAt(hour: 8)
        )
    }

    private func makeBlock(
        project: FlowProject,
        index: Int,
        signal: FlowEngagementSignal,
        date: Date? = nil,
        duration: Int = 30,
        baseMode: TrainingMode = .stay,
        challenge: FlowChallenge = .stretching,
        skill: FlowSkillConfidence = .capable,
        phoneSetup: FlowPhoneSetup = .screenTimeProtected,
        protectionActivated: Bool = true,
        verification: EnvironmentVerificationState = .systemConfirmed
    ) -> FlowBlockFixture {
        let blockDate = date ?? dateAt(hour: 9, dayOffset: index)
        let environmentPlan = FlowEnvironmentPlan(
            phoneSetup: phoneSetup,
            soundContext: .quiet,
            browserScope: "One document",
            appliedRuleIDs: [],
            verification: verification,
            protectionActivated: protectionActivated
        )
        let fuel = completeFuel(capturedAt: blockDate.addingTimeInterval(-300))
        let plan = FlowBlockPlan(
            projectID: project.id,
            task: "Draft section \(index + 1)",
            definitionOfDone: "Section \(index + 1) has a complete argument",
            challengeBefore: challenge,
            skillConfidenceBefore: skill,
            feedbackMechanism: .visibleOutput,
            customFeedback: nil,
            suggestedDuration: duration,
            selectedDuration: duration,
            environmentPlan: environmentPlan,
            fuelContext: fuel,
            baseMode: baseMode,
            sessionOrigin: .flow,
            programDay: nil,
            createdAt: blockDate.addingTimeInterval(-60)
        )
        let sessionID = UUID()
        let evidence = FlowBlockEvidence(
            blockID: plan.blockID,
            projectID: project.id,
            planID: plan.id,
            sessionID: sessionID,
            reflection: reflection(for: signal),
            challengeBefore: challenge,
            skillBefore: skill,
            feedbackMechanism: .visibleOutput,
            environment: EnvironmentSnapshot(
                protectionOffered: phoneSetup == .screenTimeProtected,
                protectionAccepted: phoneSetup == .screenTimeProtected,
                protectionActivated: protectionActivated,
                protectedSelectionID: phoneSetup == .screenTimeProtected ? UUID() : nil,
                environmentCondition: phoneSetup == .screenTimeProtected && protectionActivated
                    ? EnvironmentCondition.protected.rawValue
                    : EnvironmentCondition.unrestricted.rawValue
            ),
            fuelContext: fuel,
            switches: FlowSwitchEvidence(count: 1, firstSwitchTiming: .tenToTwenty),
            actualDuration: duration,
            completed: true,
            endedEarly: false,
            date: blockDate
        )
        return (plan, evidence)
    }

    private func makeState(signals: [FlowEngagementSignal]) -> FlowState {
        let project = makeProject()
        let blocks = signals.enumerated().map {
            makeBlock(project: project, index: $0.offset, signal: $0.element)
        }
        return FlowState(
            projects: [project],
            plans: blocks.map(\.plan),
            evidence: blocks.map(\.evidence)
        )
    }

    private func reflection(for signal: FlowEngagementSignal) -> FlowBlockReflection {
        switch signal {
        case .strongerSignal:
            return FlowBlockReflection(
                absorption: .high,
                timePerception: .faster,
                desireToContinue: .continue,
                definitionOfDoneOutcome: .reached,
                note: "Momentum stayed steady."
            )
        case .lowerSignal:
            return FlowBlockReflection(
                absorption: .low,
                timePerception: .slower,
                desireToContinue: .stop,
                definitionOfDoneOutcome: .notReached,
                note: nil
            )
        case .mixed:
            return FlowBlockReflection(
                absorption: .high,
                timePerception: .normal,
                desireToContinue: .neutral,
                definitionOfDoneOutcome: .partly,
                note: nil
            )
        case .insufficient:
            return FlowBlockReflection(
                absorption: .some,
                timePerception: nil,
                desireToContinue: nil,
                definitionOfDoneOutcome: nil,
                note: nil
            )
        }
    }

    private func completeFuel(capturedAt: Date) -> FuelContextSnapshot {
        FuelContextSnapshot(
            energy: .high,
            sleepQuality: .good,
            mealTiming: .betweenMeals,
            movement: .shortWalkBefore,
            breakState: .returningFromBreak,
            taskContext: .writing,
            captureSource: .manual,
            capturedAt: capturedAt
        )
    }

    @discardableResult
    private func startFlowBlock(
        store: ProductStore,
        projectID: UUID,
        origin: SessionOrigin,
        environmentPlan: FlowEnvironmentPlan = FlowEnvironmentPlan(),
        environmentArm: SessionEnvironmentArm? = nil,
        selectedDuration: Int? = nil,
        confirmedRuleIDs: [UUID] = []
    ) -> FlowBlockPlan {
        XCTAssertTrue(store.beginFlowSetup(projectID: projectID, origin: origin))
        var draft = tryUnwrap(store.flowState.pendingSetup)
        draft.task = "Implement the focused slice"
        draft.definitionOfDone = "All focused tests pass"
        draft.challenge = .stretching
        draft.skillConfidence = .capable
        draft.feedbackMechanism = .testsPassing
        draft.selectedDuration = origin == .protocol
            ? store.prescription.minutes
            : (selectedDuration ?? 20)
        draft.phoneSetup = environmentPlan.phoneSetup
        draft.soundContext = environmentPlan.soundContext
        draft.browserScope = environmentPlan.browserScope ?? ""
        draft.confirmedRuleIDs = confirmedRuleIDs
        store.updateFlowSetup(draft)
        XCTAssertTrue(store.startFlowBlock(
            environmentPlan: environmentPlan,
            environmentArm: environmentArm
        ))
        guard case .running(let record) = store.phase,
              let planID = record.flowParticipation?.flowPlanID,
              let plan = store.flowPlan(id: planID) else {
            XCTFail("Expected one canonical running session with Flow participation")
            fatalError("Missing Flow plan")
        }
        return plan
    }

    private func finishAndSaveFlow(
        _ store: ProductStore,
        signal: FlowEngagementSignal,
        actualMinutes: Int = 20,
        endedEarly: Bool = false
    ) {
        store.finishRunning(actualMinutes: actualMinutes, endedEarly: endedEarly)
        store.saveDoneSession(SessionReflection(flowReflection: reflection(for: signal)))
    }

    private func makeParticipation(plan: FlowBlockPlan) -> FlowParticipation {
        FlowParticipation(
            flowBlockID: plan.blockID,
            flowProjectID: plan.projectID,
            flowPlanID: plan.id,
            contextSnapshot: FlowContextSnapshot(
                challengeSkillRelation: plan.challengeSkillRelation,
                environmentPlan: plan.environmentPlan,
                fuelContext: plan.fuelContext,
                capturedAt: plan.createdAt
            ),
            attachedAt: plan.createdAt
        )
    }

    private func makeProgramStore(day: Int, lastDifficulty: Int = 2) -> ProductStore {
        let history: [SessionRecord]
        if day <= 1 {
            history = []
        } else {
            history = (1..<day).map { programDay in
                protocolRecord(
                    day: programDay,
                    date: dateAt(hour: 10, dayOffset: programDay - day),
                    mode: .observe,
                    difficulty: programDay == day - 1 ? lastDifficulty : 2
                )
            }
        }
        let state = ProgramState.migrated(day: day, sessions: history)
        writeV8(
            profile: deepWorkProfile,
            sessions: history,
            programState: state,
            flowState: .empty
        )
        return ProductStore(diagnosisAnswers: [:], defaults: defaults)
    }

    private func protocolRecord(
        day: Int,
        date: Date? = nil,
        mode: TrainingMode,
        difficulty: Int = 2
    ) -> SessionRecord {
        SessionRecord(
            origin: .protocol,
            requestID: UUID(),
            day: day,
            date: date ?? dateAt(hour: 10, dayOffset: day),
            mode: mode,
            targetMinutes: 15,
            actualMinutes: 15,
            elapsedSeconds: 900,
            completed: true,
            endedEarly: false,
            switches: mode == .stay ? 1 : nil,
            difficulty: difficulty,
            energy: 3
        )
    }

    private func writeV8(
        profile: AttentionProfile,
        sessions: [SessionRecord],
        programState: ProgramState,
        flowState: FlowState? = nil,
        flowData: Data? = nil,
        fuelState: FuelState = .empty,
        activeSession: SessionRecord? = nil,
        pendingReflectionSession: SessionRecord? = nil
    ) {
        let encoder = JSONEncoder()
        let payload: [String: Any] = [
            "profile": tryUnwrap(try? encoder.encode(profile)),
            "sessions": tryUnwrap(try? encoder.encode(sessions)),
            "day": programState.currentDay,
            "programState": tryUnwrap(try? encoder.encode(programState)),
            "preparation": tryUnwrap(try? encoder.encode(Optional<EnvironmentPreparation>.none)),
            "personalRules": tryUnwrap(try? encoder.encode(profile.personalRules)),
            "observations": tryUnwrap(try? encoder.encode(profile.observations)),
            "personalLab": tryUnwrap(try? encoder.encode(PersonalLabState.empty)),
            "activeSession": tryUnwrap(try? encoder.encode(activeSession)),
            "pendingReflectionSession": tryUnwrap(try? encoder.encode(pendingReflectionSession)),
            "fuel": tryUnwrap(try? encoder.encode(fuelState)),
            "flow": flowData
                ?? tryUnwrap(try? encoder.encode(flowState ?? .empty)),
        ]
        defaults.set(payload, forKey: "reboot.product.v8")
    }

    private func protectedArm() -> SessionEnvironmentArm {
        SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: UUID(),
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: true,
            phoneLocationSelfReport: "Outside reach"
        )
    }

    private func keptRule() -> PersonalRule {
        PersonalRule(
            title: "Keep the phone outside reach",
            detail: "Move the phone outside reach before focused work.",
            category: .environment,
            matchingContexts: [.stay, .deepWork],
            lifecycle: .kept,
            sourceType: .userCreated,
            confidence: .strong,
            supportingObservations: [],
            contradictingObservations: [],
            recencyStatus: .recent,
            createdDay: 2,
            lastTestedDay: 2,
            timesTested: 0,
            timesKept: 1
        )
    }

    private func doneRecord(_ store: ProductStore) -> SessionRecord {
        guard case .done(let record) = store.phase else {
            XCTFail("Expected done phase")
            fatalError("Missing done record")
        }
        return record
    }

    private func dateAt(hour: Int, dayOffset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15 + dayOffset
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func clearPersistence() {
        for version in 1...8 {
            defaults.removeObject(forKey: "reboot.product.v\(version)")
        }
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
