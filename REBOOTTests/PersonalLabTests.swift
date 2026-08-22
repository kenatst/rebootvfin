import XCTest
@testable import REBOOT

@MainActor
final class PersonalLabTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "PersonalLabTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    func testBalancedArmSequencingUsesNormalTestThenTestNormalThenNormalTest() {
        let experiment = activeExperiment()
        XCTAssertEqual(
            experiment.plan.armOrder,
            [
                ExperimentAssignmentSlot(pairIndex: 1, armKind: .normal),
                ExperimentAssignmentSlot(pairIndex: 1, armKind: .test),
                ExperimentAssignmentSlot(pairIndex: 2, armKind: .test),
                ExperimentAssignmentSlot(pairIndex: 2, armKind: .normal),
                ExperimentAssignmentSlot(pairIndex: 3, armKind: .normal),
                ExperimentAssignmentSlot(pairIndex: 3, armKind: .test),
            ]
        )
    }

    func testPairOnlyCompletesWithBothArms() {
        var experiment = activeExperiment()
        experiment.observations.append(observation(experiment, arm: .normal, pair: 1, switches: 5))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertEqual(experiment.observations[0].classification, .usableButUnmatched)

        experiment.observations.append(observation(experiment, arm: .test, pair: 1, switches: 2, hour: 1))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 1)
        XCTAssertEqual(experiment.pairs[0].comparison, .testBetter)
    }

    func testDifferentModesAreNotComparable() {
        var experiment = activeExperiment(template: universalTemplate())
        experiment.observations.append(observation(experiment, arm: .normal, pair: 1, switches: 4, mode: .stay))
        experiment.observations.append(observation(experiment, arm: .test, pair: 1, switches: 2, mode: .recall, hour: 1))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertTrue(experiment.observations.contains { $0.confounds.contains(where: { $0.kind == .differentMode }) })
    }

    func testLargeDurationMismatchIsNotComparable() {
        var experiment = activeExperiment()
        experiment.observations.append(observation(experiment, arm: .normal, pair: 1, switches: 4, duration: 10))
        experiment.observations.append(observation(experiment, arm: .test, pair: 1, switches: 2, duration: 30, hour: 1))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertTrue(experiment.observations.contains { $0.confounds.contains(where: { $0.kind == .durationMismatch }) })
    }

    func testRecoveryObservationIsPreservedButConfounded() {
        var state = PersonalLabState(experiments: [activeExperiment(template: universalTemplate())])
        let experiment = tryUnwrap(state.activeExperiment)
        let participation = participationFor(
            experiment,
            arm: .normal,
            pair: 1,
            recovery: true
        )
        let session = SessionRecord(
            origin: .protocol,
            day: 8,
            date: Date(),
            mode: .nothing,
            targetMinutes: 5,
            actualMinutes: 5,
            completed: true,
            difficulty: 2,
            experimentParticipation: participation
        )
        PersonalLabEngine.record(session: session, sourceEvidenceIDs: [UUID()], in: &state)
        XCTAssertEqual(state.experiments[0].observations.count, 1)
        XCTAssertEqual(state.experiments[0].observations[0].classification, .confounded)
        XCTAssertEqual(state.experiments[0].observations[0].confounds.first?.kind, .recoverySession)
    }

    func testDayOneNeverReceivesExperimentParticipation() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.startExperiment(template: universalTemplate()), .started(store.activeExperiment!.id))
        store.prepareProtocolSession(participatingInLab: true)
        guard case .preparing(let request) = store.phase else { return XCTFail("Expected preparation") }
        XCTAssertNil(request.experimentParticipation)

        store.cancelPreparation()
        store.prepareStandaloneLabSession()
        guard case .today = store.phase else { return XCTFail("Day 1 must not launch a Lab session") }
    }

    func testRecoveryBlocksStandaloneAndFreeTrainingParticipation() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let hard = SessionRecord(
            origin: .protocol,
            day: 1,
            date: Date(),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 3,
            completed: false,
            endedEarly: true,
            difficulty: 5
        )
        store.apply(QASeed(profile: AttentionProfile(), sessions: [hard], day: 2))
        _ = store.startExperiment(template: universalTemplate())
        XCTAssertEqual(store.prescription.mode, .nothing)

        store.prepareFreeTraining(.stay, participatingInLab: true)
        guard case .preparing(let request) = store.phase else { return XCTFail("Expected preparation") }
        XCTAssertNil(request.experimentParticipation)
        store.cancelPreparation()
        store.prepareStandaloneLabSession()
        guard case .today = store.phase else { return XCTFail("Recovery must make Lab wait") }
    }

    func testManualConditionRemainsSelfReportedInSessionSnapshot() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate())
        var request = attachedFreeRequest(store: store)
        request = confirming(request, truth: .userReported)
        store.begin(request: request)
        guard case .running(let session) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(session.origin, .freeTraining)
        XCTAssertEqual(session.experimentParticipation?.conditionSnapshot.truthSource, .userReported)
        XCTAssertEqual(session.environmentVerification, .userReported)
    }

    func testSystemProtectionConditionIsSystemConfirmed() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.sessionProtection)
        var request = TrainingSessionRequest.freeTraining(mode: .stay)
        let experiment = tryUnwrap(store.activeExperiment)
        let eligibility = ExperimentEligibilitySnapshot(
            eligible: true,
            reasons: [],
            mode: .stay,
            targetMinutes: 15,
            recoveryProtected: false,
            ruleExceptionIDs: []
        )
        var participation = tryUnwrap(PersonalLabEngine.participation(for: experiment, request: request, eligibility: eligibility))
        participation.conditionSnapshot.actualDescription = "Selected distractions were protected."
        participation.conditionSnapshot.truthSource = .systemConfirmed
        participation.conditionSnapshot.conditionFollowed = true
        participation.conditionSnapshot.capturedAt = Date()
        request.experimentParticipation = participation
        let arm = SessionEnvironmentArm(
            condition: .protected,
            manualIntervention: nil,
            protectedSelectionID: UUID(),
            protectionOffered: true,
            protectionAccepted: true,
            protectionActivated: true,
            phoneLocationSelfReport: nil
        )
        store.begin(request: request, environment: arm)
        guard case .running(let session) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(session.experimentParticipation?.conditionSnapshot.truthSource, .systemConfirmed)
        XCTAssertEqual(session.environmentVerification, .systemConfirmed)
        XCTAssertEqual(session.environment?.protectionActivated, true)
    }

    func testScreenTimeInterferenceCreatesConfound() {
        var experiment = activeExperiment(template: ExperimentTemplateLibrary.sessionProtection)
        let participation = participationFor(experiment, arm: .normal, pair: 1, truth: .systemConfirmed)
        let snapshot = EnvironmentSnapshot(
            protectionActivated: true,
            environmentCondition: EnvironmentCondition.protectedWindow.rawValue
        )
        let session = SessionRecord(
            origin: .freeTraining,
            day: 4,
            date: Date(),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            switches: 3,
            environment: snapshot,
            experimentParticipation: participation
        )
        var state = PersonalLabState(experiments: [experiment])
        PersonalLabEngine.record(session: session, sourceEvidenceIDs: [UUID()], in: &state)
        experiment = state.experiments[0]
        XCTAssertEqual(experiment.observations[0].classification, .confounded)
        XCTAssertTrue(experiment.observations[0].confounds.contains { $0.kind == .screenTimeInterference })
        XCTAssertEqual(
            experiment.observations[0].classificationReason,
            "A protected window was already active during the Normal condition."
        )
    }

    func testOvernightProtectedWindowUsesTheStartingWeekdayAfterMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tryUnwrap(TimeZone(secondsFromGMT: 0))
        let window = ProtectedWindow(
            name: "Night focus",
            weekdays: [2],
            startMinutes: 22 * 60,
            endMinutes: 2 * 60
        )
        let tuesdayAtOne = tryUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 1
        )))
        let tuesdayAtThree = tryUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 3
        )))

        XCTAssertTrue(EnvironmentStore.hasScheduledProtection(in: [window], at: tuesdayAtOne, calendar: calendar))
        XCTAssertFalse(EnvironmentStore.hasScheduledProtection(in: [window], at: tuesdayAtThree, calendar: calendar))
    }

    func testKeptPersonalRuleConflictRequiresExplicitException() {
        var state = PersonalLabState.empty
        let rule = keptPhoneRule()
        let experiment = PersonalLabEngine.makeExperiment(template: ExperimentTemplateLibrary.phoneDistance)
        XCTAssertEqual(
            PersonalLabEngine.start(experiment, in: &state, rules: [rule]),
            .needsRuleException([rule.id])
        )
        XCTAssertNil(state.activeExperiment)

        let allowed = PersonalLabEngine.start(
            experiment,
            in: &state,
            rules: [rule],
            allowingRuleExceptions: true
        )
        guard case .started = allowed else { return XCTFail("Expected start") }
        XCTAssertEqual(state.activeExperiment?.approvedRuleExceptionIDs, [rule.id])
        XCTAssertEqual(rule.lifecycle, .kept)
    }

    func testOnlyOneExperimentCanBeActive() {
        var state = PersonalLabState.empty
        let first = PersonalLabEngine.makeExperiment(template: ExperimentTemplateLibrary.phoneDistance)
        let second = PersonalLabEngine.makeExperiment(template: ExperimentTemplateLibrary.oneBrowserTask)
        guard case .started(let firstID) = PersonalLabEngine.start(first, in: &state, rules: []) else {
            return XCTFail("Expected first start")
        }
        XCTAssertEqual(
            PersonalLabEngine.start(second, in: &state, rules: []),
            .activeExperimentExists(firstID)
        )
        XCTAssertEqual(state.experiments.filter { $0.status == .active }.count, 1)
    }

    func testCompletedExperimentCannotRepeatWhileAnotherTestIsActive() {
        let store = dayTwoStore()
        var completed = experimentWithPairs([(5, 2), (4, 1), (3, 3)])
        _ = ExperimentResultEngine.finalize(&completed)
        var active = activeExperiment(template: universalTemplate())
        active.id = UUID()
        store.apply(QASeed(
            phase: "lab",
            labState: PersonalLabState(experiments: [completed, active])
        ))

        XCTAssertEqual(store.repeatExperiment(id: completed.id), .activeExperimentExists(active.id))
        XCTAssertEqual(store.labState.experiments.count, 2)
    }

    func testPauseResumeAndAbandonPreserveObservations() {
        var experiment = activeExperiment()
        experiment.observations.append(observation(experiment, arm: .normal, pair: 1, switches: 4))
        var state = PersonalLabState(experiments: [experiment])
        PersonalLabEngine.pause(id: experiment.id, in: &state)
        XCTAssertEqual(state.experiments[0].status, .paused)
        XCTAssertEqual(state.experiments[0].observations.count, 1)
        XCTAssertTrue(PersonalLabEngine.resume(id: experiment.id, in: &state))
        XCTAssertEqual(state.experiments[0].status, .active)
        PersonalLabEngine.abandon(id: experiment.id, in: &state)
        XCTAssertEqual(state.experiments[0].status, .abandoned)
        XCTAssertEqual(state.experiments[0].observations.count, 1)
        XCTAssertNil(state.experiments[0].result)
    }

    func testProtocolExperimentRetainsProtocolOriginAndAdvancesExactlyOnce() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate(primary: .difficulty))
        store.prepareProtocolSession(participatingInLab: true)
        guard case .preparing(var request) = store.phase else { return XCTFail("Expected preparation") }
        request = confirming(request)
        store.begin(request: request)
        guard case .running(let running) = store.phase else { return XCTFail("Expected running") }
        XCTAssertEqual(running.origin, .protocol)
        XCTAssertNotNil(running.experimentParticipation)
        store.finishRunning(actualMinutes: running.targetMinutes, endedEarly: false)
        let done = doneRecord(store)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 0))
        XCTAssertEqual(store.day, 3)
        XCTAssertEqual(store.completedProtocolDays, 2)
        XCTAssertEqual(store.activeExperiment?.observations.count, 1)

        store.phase = .done(done)
        store.saveDoneSession(SessionReflection(difficulty: 2))
        XCTAssertEqual(store.day, 3)
        XCTAssertEqual(store.activeExperiment?.observations.count, 1)
    }

    func testEarlyProtocolExperimentDoesNotAdvanceProgram() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate(primary: .difficulty))
        store.prepareProtocolSession(participatingInLab: true)
        guard case .preparing(var request) = store.phase else { return XCTFail("Expected preparation") }
        request = confirming(request)
        store.begin(request: request)
        store.finishRunning(actualMinutes: 1, endedEarly: true)
        store.saveDoneSession(SessionReflection(difficulty: 5, firstDistraction: "social", switches: 4))
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.completedProtocolDays, 1)
        XCTAssertEqual(store.activeExperiment?.observations.first?.classification, .confounded)
    }

    func testFreeTrainingExperimentDoesNotAdvanceProgram() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate(primary: .difficulty))
        var request = attachedFreeRequest(store: store)
        request = confirming(request)
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.freeTrainingSessions.count, 1)
        XCTAssertEqual(store.activeExperiment?.observations.count, 1)
    }

    func testStandaloneExperimentDoesNotAdvanceProgram() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate(primary: .difficulty))
        store.prepareStandaloneLabSession()
        guard case .preparing(var request) = store.phase else { return XCTFail("Expected preparation") }
        XCTAssertEqual(request.origin, .experiment)
        request = confirming(request)
        store.begin(request: request)
        store.finishRunning(actualMinutes: request.targetMinutes, endedEarly: false)
        store.saveDoneSession(SessionReflection(difficulty: 2, firstDistraction: "none", switches: 1))
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.experimentSessions.count, 1)
    }

    func testDuplicateSessionCannotAttachTwice() {
        var experiment = activeExperiment(template: universalTemplate(primary: .difficulty))
        let participation = participationFor(experiment, arm: .normal, pair: 1)
        let session = SessionRecord(
            origin: .freeTraining,
            day: 4,
            date: Date(),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            difficulty: 2,
            experimentParticipation: participation
        )
        var state = PersonalLabState(experiments: [experiment])
        PersonalLabEngine.record(session: session, sourceEvidenceIDs: [UUID()], in: &state)
        PersonalLabEngine.record(session: session, sourceEvidenceIDs: [UUID()], in: &state)
        experiment = state.experiments[0]
        XCTAssertEqual(experiment.observations.count, 1)
    }

    func testResultCannotFinalizeTwice() {
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        let first = ExperimentResultEngine.finalize(&experiment)
        let second = ExperimentResultEngine.finalize(&experiment)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(experiment.status, .completed)
    }

    func testThreePairsAllTestBetterProducesKeep() {
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        let result = ExperimentResultEngine.finalize(&experiment)
        XCTAssertEqual(result?.state, .keep)
    }

    func testThreePairsAllNormalBetterProducesDrop() {
        var experiment = experimentWithPairs([(2, 5), (1, 4), (2, 3)])
        let result = ExperimentResultEngine.finalize(&experiment)
        XCTAssertEqual(result?.state, .drop)
    }

    func testMixedPairsProduceInconclusive() {
        var experiment = experimentWithPairs([(5, 2), (2, 5), (3, 3)])
        let result = ExperimentResultEngine.finalize(&experiment)
        XCTAssertEqual(result?.state, .inconclusive)
    }

    func testSubstantialConfoundsForceInconclusiveDespiteFavorablePairs() {
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        for index in 0..<4 {
            var excluded = observation(
                experiment,
                arm: .test,
                pair: index % 3 + 1,
                switches: 1,
                hour: 20 + index
            )
            excluded.classification = .confounded
            excluded.classificationReason = "The setup changed during this session."
            excluded.confounds = [ExperimentConfound(
                kind: .conflictingEnvironmentOverride,
                explanation: excluded.classificationReason
            )]
            experiment.observations.append(excluded)
        }

        XCTAssertEqual(ExperimentResultEngine.finalize(&experiment)?.state, .inconclusive)
    }

    func testTwoTestBetterPairsAllowEarlyKeep() {
        var experiment = experimentWithPairs([(5, 2), (4, 1)])
        XCTAssertNil(ExperimentResultEngine.finalize(&experiment, allowEarly: false))
        XCTAssertEqual(ExperimentResultEngine.finalize(&experiment, allowEarly: true)?.state, .keep)
    }

    func testInsufficientPairsProduceNoConclusion() {
        var experiment = experimentWithPairs([(5, 2)])
        XCTAssertNil(ExperimentResultEngine.finalize(&experiment, allowEarly: true))
        XCTAssertNil(experiment.result)
        XCTAssertEqual(experiment.status, .active)
    }

    func testMissingPrimaryMetricIsUnusable() {
        var experiment = activeExperiment()
        var normal = observation(experiment, arm: .normal, pair: 1, switches: 4)
        var test = observation(experiment, arm: .test, pair: 1, switches: 2, hour: 1)
        normal.outcomes = [:]
        test.outcomes = [:]
        experiment.observations = [normal, test]
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertTrue(experiment.observations.allSatisfy { $0.classification == .insufficient })
    }

    func testConfoundedObservationIsExcludedAndRetryCanCompletePair() {
        var experiment = activeExperiment()
        experiment.observations.append(observation(experiment, arm: .normal, pair: 1, switches: 5))
        var confounded = observation(experiment, arm: .test, pair: 1, switches: 1, hour: 1)
        confounded.classification = .confounded
        confounded.confounds = [ExperimentConfound(kind: .conditionNotFollowed, explanation: "Condition not followed.")]
        experiment.observations.append(confounded)
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertEqual(PersonalLabEngine.nextAssignment(for: experiment)?.armKind, .test)

        experiment.observations.append(observation(experiment, arm: .test, pair: 1, switches: 2, hour: 2))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 1)
        XCTAssertEqual(experiment.pairs[0].comparison, .testBetter)
    }

    func testSecondaryOutcomeCannotOverrideDeclaredPrimary() {
        var experiment = activeExperiment()
        var normal = observation(experiment, arm: .normal, pair: 1, switches: 2)
        var test = observation(experiment, arm: .test, pair: 1, switches: 5, hour: 1)
        normal.outcomes[ExperimentOutcomeMetric.startEase.key] = .boolean(false)
        test.outcomes[ExperimentOutcomeMetric.startEase.key] = .boolean(true)
        experiment.observations = [normal, test]
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.pairs[0].comparison, .baselineBetter)
        XCTAssertEqual(experiment.primaryOutcome, .reportedSwitches)
    }

    func testConditionSnapshotDoesNotChangeWhenDefinitionChanges() {
        var experiment = activeExperiment()
        let captured = observation(experiment, arm: .normal, pair: 1, switches: 4)
        experiment.observations = [captured]
        experiment.normalArm.condition.detail = "A changed future definition"
        XCTAssertNotEqual(experiment.normalArm.condition.detail, captured.requestedCondition.requestedDetail)
        XCTAssertEqual(experiment.observations[0].requestedCondition, captured.requestedCondition)
    }

    func testKeepResultDoesNotAutoCreateRule() {
        let store = dayTwoStore()
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        _ = ExperimentResultEngine.finalize(&experiment)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        XCTAssertTrue(store.personalRules.isEmpty)
    }

    func testKeepUserConfirmationCreatesOneLinkedExperimentRuleIdempotently() {
        let store = dayTwoStore()
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        _ = ExperimentResultEngine.finalize(&experiment)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        let first = store.keepExperimentResultAsRule(experimentID: experiment.id)
        let second = store.keepExperimentResultAsRule(experimentID: experiment.id)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(store.personalRules.filter { $0.experimentID == experiment.id }.count, 1)
        XCTAssertEqual(store.personalRules.first?.sourceType, .experiment)
        XCTAssertEqual(store.experiment(id: experiment.id)?.result?.personalRuleID, first?.id)
    }

    func testDropDoesNotAutoRetireKeptRule() {
        let store = dayTwoStore()
        let rule = keptPhoneRule()
        var profile = AttentionProfile()
        profile.personalRules = [rule]
        var experiment = experimentWithPairs([(2, 5), (1, 4), (2, 3)])
        experiment.linkedPersonalRuleID = rule.id
        _ = ExperimentResultEngine.finalize(&experiment)
        store.apply(QASeed(
            profile: profile,
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        XCTAssertEqual(store.personalRules.first?.lifecycle, .kept)
        XCTAssertEqual(store.experiment(id: experiment.id)?.result?.state, .drop)
    }

    func testInconclusiveCannotCreateEvidenceBackedRule() {
        let store = dayTwoStore()
        var experiment = experimentWithPairs([(5, 2), (2, 5), (3, 3)])
        _ = ExperimentResultEngine.finalize(&experiment)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        XCTAssertNil(store.keepExperimentResultAsRule(experimentID: experiment.id))
        XCTAssertTrue(store.personalRules.isEmpty)
    }

    func testDerivedExperimentResultDoesNotDoubleCountEvidenceLedger() {
        let evidenceIDs = [UUID(), UUID(), UUID(), UUID(), UUID(), UUID()]
        var profile = AttentionProfile()
        profile.observations = evidenceIDs.enumerated().map { index, id in
            EvidenceObservation(
                id: id,
                sessionID: UUID(),
                day: index + 2,
                mode: .stay,
                source: .session,
                verificationState: .userReported,
                finding: "Raw session evidence",
                sentiment: "neutral",
                context: .stay
            )
        }
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        for index in experiment.observations.indices {
            experiment.observations[index].sourceEvidenceIDs = [evidenceIDs[index]]
        }
        _ = ExperimentResultEngine.finalize(&experiment)
        let store = dayTwoStore()
        store.apply(QASeed(
            profile: profile,
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        XCTAssertEqual(store.observations.count, 6)
        XCTAssertEqual(Set(store.experiment(id: experiment.id)!.result!.sourceEvidenceIDs), Set(evidenceIDs))
    }

    func testActiveExperimentAndPendingParticipationRestoreFromV6() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: universalTemplate(primary: .difficulty))
        store.prepareFreeTraining(.stay, participatingInLab: true)
        guard case .preparing(let request) = store.phase else { return XCTFail("Expected preparation") }
        XCTAssertNotNil(request.experimentParticipation)

        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(restored.activeExperiment?.id, store.activeExperiment?.id)
        XCTAssertEqual(restored.labState.pendingParticipation?.experimentID, store.activeExperiment?.id)
    }

    func testCompletedResultSurvivesRelaunch() {
        let store = dayTwoStore()
        var experiment = experimentWithPairs([(5, 2), (4, 1), (3, 2)])
        _ = ExperimentResultEngine.finalize(&experiment)
        store.apply(QASeed(
            profile: AttentionProfile(),
            sessions: [dayOneRecord()],
            day: 2,
            labState: PersonalLabState(experiments: [experiment])
        ))
        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(restored.experiment(id: experiment.id)?.result?.state, .keep)
        XCTAssertEqual(restored.experiment(id: experiment.id)?.completePairCount, 3)
    }

    func testCustomExperimentPersists() {
        let store = dayTwoStore()
        let outcome = store.startCustomExperiment(
            question: "Does a written cue help?",
            normal: "Start normally",
            test: "Write one cue",
            mode: .stay,
            primaryOutcome: .difficulty
        )
        guard case .started(let id) = outcome else { return XCTFail("Expected custom start") }
        let restored = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(restored.experiment(id: id)?.origin, .userCreated)
        XCTAssertEqual(restored.experiment(id: id)?.question, "Does a written cue help?")
        XCTAssertEqual(restored.experiment(id: id)?.normalArm.condition.expectedTruthSource, .userReported)
    }

    func testV5MigratesToV6WithEmptyLabAndPreservedProduct() throws {
        clearPersistence()
        let sessions = [dayOneRecord()]
        defaults.set([
            "profile": try JSONEncoder().encode(AttentionProfile(focusWindowMinutes: 15)),
            "sessions": try JSONEncoder().encode(sessions),
            "day": 2,
            "programState": try JSONEncoder().encode(ProgramState.migrated(day: 2, sessions: sessions)),
        ], forKey: "reboot.product.v5")
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.day, 2)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertTrue(store.labState.experiments.isEmpty)
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v6"))
        XCTAssertNil(defaults.object(forKey: "reboot.product.v5"))
    }

    func testCorruptedV6DoesNotRollBackToV5() throws {
        clearPersistence()
        defaults.set([
            "profile": try JSONEncoder().encode(AttentionProfile()),
            "sessions": try JSONEncoder().encode([dayOneRecord()]),
            "day": 2,
        ], forKey: "reboot.product.v5")
        defaults.set([
            "profile": Data("corrupt".utf8),
            "sessions": Data("corrupt".utf8),
            "day": 14,
            "personalLab": Data("corrupt".utf8),
        ], forKey: "reboot.product.v6")
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.labState.experiments.isEmpty)
        XCTAssertNotEqual(store.day, 2, "A present v6 must never roll back to older state")
    }

    func testSuggestionEngineIsEvidenceBasedAndLimitedToThree() {
        var profile = AttentionProfile(
            primaryGoal: .known("deep_work", source: .selfReport),
            distractors: .known([Distractor.phone, Distractor.tabs, Distractor.people], source: .selfReport)
        )
        profile.environmentEvidence = EnvironmentEvidence(screenTimeConnected: true, hasSelection: true)
        let sessions = (0..<6).map { index in
            SessionRecord(
                origin: .protocol,
                day: index + 2,
                date: Date().addingTimeInterval(Double(index) * 3_600),
                mode: .stay,
                targetMinutes: 15,
                actualMinutes: 15,
                completed: true,
                firstDistraction: index.isMultiple(of: 2) ? "social" : "tabs",
                switches: 4,
                difficulty: 3
            )
        }
        let suggestions = PersonalLabEngine.suggestions(
            profile: profile,
            sessions: sessions,
            rules: [],
            state: .empty,
            screenTimeAvailable: true
        )
        XCTAssertLessThanOrEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.contains { $0.template.id == ExperimentTemplateLibrary.phoneDistance.id })
        XCTAssertTrue(suggestions.contains { $0.template.id == ExperimentTemplateLibrary.oneBrowserTask.id })
    }

    func testNinetyDaySimulationWithLabAndRuleKeepsProgramSemantics() {
        let store = ProductStore(
            diagnosisAnswers: ["primary_goal": ["deep_work"], "breaker": ["phone"]],
            defaults: defaults
        )
        var experimentID: UUID?
        var didCreateRule = false

        while store.programStatus == .active {
            drainRequiredFlow(store)
            guard store.programStatus == .active,
                  var request = store.protocolRequest() else { continue }

            if store.day == 2, experimentID == nil {
                let outcome = store.startExperiment(template: universalTemplate(primary: .difficulty))
                if case .started(let id) = outcome { experimentID = id }
            }

            if store.activeExperiment != nil {
                store.prepareProtocolSession(participatingInLab: true)
                guard case .preparing(let prepared) = store.phase else { return XCTFail("Expected prepared protocol") }
                request = confirming(prepared)
            }

            store.begin(request: request)
            guard case .running(let running) = store.phase else { return XCTFail("Expected running") }
            store.finishRunning(actualMinutes: running.targetMinutes, endedEarly: false)
            let isTest = running.experimentParticipation?.armKind == .test
            store.saveDoneSession(SessionReflection(
                difficulty: isTest ? 1 : 4,
                firstDistraction: isTest ? "none" : "social",
                switches: isTest ? 1 : 4,
                startedEasier: isTest
            ))

            if let experimentID,
               store.experiment(id: experimentID)?.result?.state == .keep,
               !didCreateRule {
                XCTAssertFalse(store.personalRules.contains { $0.experimentID == experimentID })
                XCTAssertNotNil(store.keepExperimentResultAsRule(experimentID: experimentID))
                didCreateRule = true
            }
            XCTAssertLessThanOrEqual(store.day, 90)
        }

        drainRequiredFlow(store)
        XCTAssertEqual(store.day, 90)
        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertNil(store.protocolRequest())
        XCTAssertTrue(didCreateRule)
        XCTAssertEqual(store.personalRules.filter { $0.experimentID == experimentID }.count, 1)
        XCTAssertEqual(store.experiment(id: tryUnwrap(experimentID))?.result?.state, .keep)
        XCTAssertEqual(store.observations.count, store.sessions.count, "Derived Lab results must not add duplicate ledger evidence")
    }

    // MARK: - Helpers

    private func activeExperiment(
        template: ExperimentTemplate = ExperimentTemplateLibrary.phoneDistance
    ) -> PersonalExperiment {
        var experiment = PersonalLabEngine.makeExperiment(template: template)
        experiment.status = .active
        return experiment
    }

    private func universalTemplate(
        primary: ExperimentOutcomeMetric = .reportedSwitches
    ) -> ExperimentTemplate {
        ExperimentTemplate(
            id: "universal.\(primary.key)",
            shortTitle: "Universal fixture",
            question: "Does this condition look more useful?",
            rationale: "Deterministic test fixture.",
            normalCondition: ExperimentCondition(id: "fixture.normal", title: "Normal", detail: "Use the normal setup."),
            testCondition: ExperimentCondition(id: "fixture.test", title: "Test", detail: "Use the test setup."),
            eligibleModes: TrainingMode.allCases,
            preferredDuration: 15,
            primaryOutcome: primary,
            secondaryOutcomes: [.startEase],
            ruleDraft: ExperimentRuleDraft(
                title: "Use the tested setup",
                detail: "Use the tested setup for focused work.",
                category: .taskSetup,
                contexts: [.stay]
            )
        )
    }

    private func observation(
        _ experiment: PersonalExperiment,
        arm: ExperimentArmKind,
        pair: Int,
        switches: Int,
        mode: TrainingMode = .stay,
        duration: Int = 15,
        hour: Int = 0
    ) -> ExperimentObservation {
        let experimentArm = experiment.arm(for: arm)
        var snapshot = ExperimentConditionSnapshot.pending(experimentArm.condition)
        snapshot.actualDescription = experimentArm.condition.detail
        snapshot.truthSource = .userReported
        snapshot.conditionFollowed = true
        snapshot.capturedAt = Date().addingTimeInterval(Double(hour) * 3_600)
        return ExperimentObservation(
            experimentID: experiment.id,
            sessionID: UUID(),
            armID: experimentArm.id,
            armKind: arm,
            pairIndex: pair,
            requestedCondition: snapshot,
            mode: mode,
            targetMinutes: duration,
            actualMinutes: duration,
            completed: true,
            endedEarly: false,
            outcomes: [ExperimentOutcomeMetric.reportedSwitches.key: .integer(switches)],
            classification: .usableButUnmatched,
            classificationReason: "Waiting for the matching condition.",
            confounds: [],
            sourceEvidenceIDs: [UUID()],
            date: Date().addingTimeInterval(Double(hour) * 3_600)
        )
    }

    private func experimentWithPairs(_ values: [(normal: Int, test: Int)]) -> PersonalExperiment {
        var experiment = activeExperiment()
        for (offset, value) in values.enumerated() {
            let pair = offset + 1
            experiment.observations.append(observation(
                experiment,
                arm: .normal,
                pair: pair,
                switches: value.normal,
                hour: offset * 2
            ))
            experiment.observations.append(observation(
                experiment,
                arm: .test,
                pair: pair,
                switches: value.test,
                hour: offset * 2 + 1
            ))
        }
        ExperimentComparisonEngine.updateComparability(&experiment)
        return experiment
    }

    private func participationFor(
        _ experiment: PersonalExperiment,
        arm: ExperimentArmKind,
        pair: Int,
        recovery: Bool = false,
        truth: ExperimentTruthSource = .userReported
    ) -> ExperimentParticipation {
        let experimentArm = experiment.arm(for: arm)
        var snapshot = ExperimentConditionSnapshot.pending(experimentArm.condition)
        snapshot.actualDescription = experimentArm.condition.detail
        snapshot.truthSource = truth
        snapshot.conditionFollowed = true
        snapshot.capturedAt = Date()
        return ExperimentParticipation(
            experimentID: experiment.id,
            armID: experimentArm.id,
            armKind: arm,
            pairIndex: pair,
            conditionSnapshot: snapshot,
            eligibilitySnapshot: ExperimentEligibilitySnapshot(
                eligible: true,
                reasons: [],
                mode: .stay,
                targetMinutes: 15,
                recoveryProtected: recovery,
                ruleExceptionIDs: []
            ),
            assignmentReason: "Test fixture"
        )
    }

    private func confirming(
        _ request: TrainingSessionRequest,
        truth: ExperimentTruthSource = .userReported
    ) -> TrainingSessionRequest {
        var request = request
        guard var participation = request.experimentParticipation else { return request }
        participation.conditionSnapshot.actualDescription = participation.conditionSnapshot.requestedDetail
        participation.conditionSnapshot.truthSource = truth
        participation.conditionSnapshot.conditionFollowed = true
        participation.conditionSnapshot.capturedAt = Date()
        request.experimentParticipation = participation
        return request
    }

    private func attachedFreeRequest(store: ProductStore) -> TrainingSessionRequest {
        store.prepareFreeTraining(.stay, participatingInLab: true)
        guard case .preparing(let request) = store.phase else {
            XCTFail("Expected preparation")
            fatalError("Expected preparation")
        }
        return request
    }

    private func dayTwoStore() -> ProductStore {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let session = dayOneRecord()
        store.apply(QASeed(profile: AttentionProfile(), sessions: [session], day: 2))
        return store
    }

    private func dayOneRecord() -> SessionRecord {
        SessionRecord(
            origin: .protocol,
            requestID: UUID(),
            day: 1,
            date: Date().addingTimeInterval(-86_400),
            mode: .observe,
            targetMinutes: 15,
            actualMinutes: 15,
            elapsedSeconds: 900,
            completed: true,
            firstDistraction: "social",
            switches: 3,
            difficulty: 3
        )
    }

    private func keptPhoneRule() -> PersonalRule {
        PersonalRule(
            title: "Keep phone outside reach during focused work",
            detail: "Move the phone outside reach before STAY.",
            category: .environment,
            matchingContexts: [.stay],
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
            XCTFail("Expected done")
            fatalError("Expected done")
        }
        return record
    }

    private func drainRequiredFlow(_ store: ProductStore) {
        var shouldContinue = true
        while shouldContinue {
            switch store.phase {
            case .weeklyReview:
                store.skipWeeklyReviewQuestions()
            case .phaseTransition:
                store.acknowledgePhaseTransition()
            case .programCompletion:
                store.acknowledgeProgramCompletion()
            default:
                shouldContinue = false
            }
        }
    }

    private func clearPersistence() {
        for key in (1...6).map({ "reboot.product.v\($0)" }) {
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
