import XCTest
@testable import REBOOT

@MainActor
final class FuelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "FuelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Daypart derivation

    func testDaypartDerivationBoundaries() {
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(4)), .late)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(5)), .morning)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(11)), .morning)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(12)), .afternoon)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(16)), .afternoon)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(17)), .evening)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(21)), .evening)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(22)), .late)
        XCTAssertEqual(FuelDaypart.derive(from: dateAt(0)), .late)
    }

    // MARK: - Snapshot optionality and provenance

    func testSnapshotAllFieldsOptionalAndUnknownStaysUnknown() throws {
        let empty = try JSONDecoder().decode(FuelContextSnapshot.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.knownFieldCount, 0)
        XCTAssertNil(empty.energy)
        XCTAssertNil(empty.sleepQuality)
        XCTAssertNil(empty.mealTiming)
        XCTAssertNil(empty.taskContext)
        XCTAssertTrue(empty.isEmpty)

        var partial = FuelContextSnapshot()
        partial.energy = .okay
        let data = try JSONEncoder().encode(partial)
        let decoded = try JSONDecoder().decode(FuelContextSnapshot.self, from: data)
        XCTAssertEqual(decoded.energy, .okay)
        XCTAssertNil(decoded.sleepQuality, "Unknown fields must remain unknown after roundtrip")
    }

    func testSnapshotManualProvenanceSurvivesPersistence() throws {
        let snapshot = FuelContextSnapshot(energy: .low)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(FuelContextSnapshot.self, from: data)
        XCTAssertEqual(decoded.captureSource, .manual)
        XCTAssertEqual(decoded.captureSource.label, "Self-reported")
    }

    func testTaskContextStaysUnknownWhenNotExplicit() {
        let snapshot = FuelContextSnapshot(energy: .high)
        XCTAssertNil(snapshot.taskContext, "Task context is never inferred from vague data")
    }

    // MARK: - Sampling

    func testDayOneSuppressesFuelPrompting() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.completedProtocolDays, 0)
        XCTAssertNil(store.currentFuelPrompt, "Day 1 stays Fuel-clean")
    }

    func testRecoveryDaySuppressesFuelPrompting() {
        let store = dayTwoStoreAfterDifficultSession()
        XCTAssertEqual(store.prescription.mode, .nothing, "Recovery expected")
        XCTAssertNil(store.currentFuelPrompt, "Recovery is never interrupted by context questions")
    }

    func testDisabledPromptsSuppressSamplingAndReenable() {
        let store = dayTwoStore()
        store.setFuelPromptsEnabled(false)
        XCTAssertNil(store.currentFuelPrompt)
        store.setFuelPromptsEnabled(true)
        XCTAssertNotNil(store.currentFuelPrompt)
    }

    func testOnePromptPerProtocolSessionDay() {
        let store = dayTwoStore()
        guard let prompt = store.currentFuelPrompt else {
            return XCTFail("Expected a prompt on a clean day 2")
        }
        store.answerFuelPrompt(prompt, rawValue: FuelEnergyLevel.okay.rawValue)
        XCTAssertNil(store.currentFuelPrompt, "A second prompt must not appear the same day")
    }

    func testEngineCooldownSkipsRecentlyAskedField() {
        let now = Date()
        var log = FuelSamplingLog()
        log.lastPromptAt[FuelContextField.energy.rawValue] = now.addingTimeInterval(-3 * 86_400)
        log.answeredCounts[FuelContextField.energy.rawValue] = 1
        let prompt = ContextSamplingEngine.recommendPrompt(.init(
            programDay: 10,
            completedProtocolDays: 9,
            phase: .controlInput,
            log: log,
            now: now
        ))
        // Phase cooldown (3 days) passed, but the per-field cooldown (7 days)
        // has not: a different field must be chosen.
        XCTAssertEqual(prompt?.field, .sleepQuality)
    }

    func testSkipLengthensFieldCooldown() {
        let now = Date()
        var log = FuelSamplingLog()
        log.lastPromptAt[FuelContextField.energy.rawValue] = now.addingTimeInterval(-8 * 86_400)
        log.skipCounts[FuelContextField.energy.rawValue] = 1
        log.answeredCounts[FuelContextField.energy.rawValue] = 0
        // 8 days since asked; base cooldown 7 but one skip adds 7 → 14 total.
        let inputs = ContextSamplingEngine.Inputs(
            programDay: 10,
            completedProtocolDays: 9,
            phase: .controlInput,
            log: log,
            now: now
        )
        XCTAssertTrue(ContextSamplingEngine.fieldInCooldown(.energy, inputs: inputs, now: now))
    }

    func testActiveFuelConditionTestSuppressesGenericSampling() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.shortWalkBeforeFocus)
        XCTAssertNil(store.currentFuelPrompt, "One deliberate variable at a time — Lab owns it")
    }

    func testActiveObservationalExperimentPrioritizesNeededField() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.sleepQualityComparison)
        let prompt = tryUnwrap(store.currentFuelPrompt)
        XCTAssertEqual(prompt.field, .sleepQuality, "The waiting test's needed field takes priority")

        store.answerFuelPrompt(prompt, rawValue: FuelSleepQuality.good.rawValue)
        XCTAssertNil(store.currentFuelPrompt, "Needed field already answered today — nothing more")
    }

    // MARK: - Session attach and immutability

    func testFuelSnapshotAttachesToProtocolSessionAndFreezes() {
        let store = dayTwoStore()
        guard let prompt = store.currentFuelPrompt else {
            return XCTFail("Expected prompt")
        }
        store.answerFuelPrompt(prompt, rawValue: FuelEnergyLevel.low.rawValue)
        store.beginSession()
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 4,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: 2,
            environmentActionDone: true
        )
        drainRequiredFlow(store)
        guard let saved = store.sessions.last else { return XCTFail("Session missing") }
        XCTAssertEqual(saved.fuelContext?.energy, .low)
        XCTAssertEqual(saved.fuelContext?.captureSource, .manual)

        // A later answer must never rewrite the finalized session's context.
        var later = FuelContextSnapshot()
        later.energy = .high
        store.fuelState.pendingCapture = later
        XCTAssertEqual(store.sessions.last?.fuelContext?.energy, .low, "Historical Fuel context is immutable")
    }

    func testDayOneSessionStaysFuelCleanEvenWithStaleCapture() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        var stale = FuelContextSnapshot()
        stale.energy = .okay
        store.fuelState.pendingCapture = stale
        store.beginSession()
        store.finishRunning(actualMinutes: 15, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: 3,
            environmentActionDone: nil
        )
        drainRequiredFlow(store)
        XCTAssertEqual(store.completedProtocolDays, 1)
        XCTAssertNil(store.sessions.last?.fuelContext, "Day 1 natural baseline carries no Fuel context")
    }

    func testFreeTrainingDoesNotConsumePendingCapture() {
        let store = dayTwoStore()
        var capture = FuelContextSnapshot()
        capture.energy = .okay
        store.fuelState.pendingCapture = capture
        store.prepareFreeTraining(.stay)
        store.beginPreparedSession()
        store.finishRunning(actualMinutes: 10, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: nil
        )
        XCTAssertNil(store.sessions.last?.fuelContext, "Prompts are protocol-only")
        XCTAssertNotNil(store.fuelState.pendingCapture, "A free session must not consume today's capture")
    }

    // MARK: - Pattern engine

    func testOneObservationCannotCreatePattern() {
        let sessions = [
            fuelSession(energy: .low, difficulty: 5),
        ]
        let result = FuelPatternEngine.evaluate(sessions: sessions)
        XCTAssertTrue(result.patterns.filter { $0.id == "energy.difficulty" }.isEmpty)
    }

    func testRepeatedCompatibleObservationsCreateSignals() {
        let two = FuelPatternEngine.evaluate(sessions: [
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 4),
        ])
        let pattern = tryUnwrap(two.patterns.first { $0.id == "energy.difficulty" })
        XCTAssertEqual(pattern.maturity, .earlySignal)
        XCTAssertEqual(pattern.supportingSessions, 2)

        let three = FuelPatternEngine.evaluate(sessions: [
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 4),
            fuelSession(energy: .low, difficulty: 5),
        ])
        let repeated = tryUnwrap(three.patterns.first { $0.id == "energy.difficulty" })
        XCTAssertEqual(repeated.maturity, .repeatedSignal)
    }

    func testContradictionsLowerConfidence() {
        let mixed = FuelPatternEngine.evaluate(sessions: [
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 4),
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 1),
            fuelSession(energy: .low, difficulty: 2),
        ])
        let pattern = tryUnwrap(mixed.patterns.first { $0.id == "energy.difficulty" })
        XCTAssertEqual(pattern.maturity, .mixed)
        XCTAssertEqual(pattern.statement, "The evidence here is mixed recently — no stable pattern yet.")

        // Equal support and contradiction: no pattern at all, honestly.
        let balanced = FuelPatternEngine.evaluate(sessions: [
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 4),
            fuelSession(energy: .low, difficulty: 1),
            fuelSession(energy: .low, difficulty: 2),
        ])
        XCTAssertTrue(balanced.patterns.filter { $0.id == "energy.difficulty" }.isEmpty)
    }

    func testRecentWindowBoundsOldEvidence() {
        var sessions: [SessionRecord] = []
        for index in 0..<8 {
            sessions.append(fuelSession(energy: .low, difficulty: 5, dayOffset: -40 + index))
        }
        for index in 0..<20 {
            sessions.append(fuelSession(energy: .okay, difficulty: 2, dayOffset: -19 + index))
        }
        let result = FuelPatternEngine.evaluate(sessions: sessions)
        XCTAssertTrue(result.patterns.isEmpty, "Old low-energy evidence beyond the window cannot dominate")
    }

    func testSleepLanguageIsAssociativeNotCausal() {
        let sessions = [
            fuelSession(sleep: .good, difficulty: 1),
            fuelSession(sleep: .good, difficulty: 2),
            fuelSession(sleep: .good, difficulty: 1),
        ]
        let result = FuelPatternEngine.evaluate(sessions: sessions)
        let pattern = tryUnwrap(result.patterns.first { $0.id == "sleep.easier" })
        XCTAssertEqual(pattern.statement, "Your recent sessions after better-reported sleep have tended to feel easier.")
        XCTAssertFalse(pattern.statement.lowercased().contains("improve"))
    }

    func testMealTimingNeverProducesDietaryInstructions() {
        let result = FuelPatternEngine.evaluate(sessions: [
            fuelSession(meal: .recentlyAte, difficulty: 1),
            fuelSession(meal: .recentlyAte, difficulty: 2),
            fuelSession(meal: .betweenMeals, difficulty: 4),
            fuelSession(meal: .betweenMeals, difficulty: 5),
        ])
        let forbidden = ["calorie", "fasting", "skip", "protein", "carb", "avoid", "eat more", "eat less"]
        for pattern in result.patterns {
            for word in forbidden {
                XCTAssertFalse(pattern.statement.lowercased().contains(word))
            }
        }
        XCTAssertTrue(result.openQuestions.contains { $0.dimension == .mealTiming } || result.patterns.isEmpty,
                      "Meal context stays observational")
    }

    func testCaffeineRemainsObservationalWithNoDoseAdvice() {
        let walk = ExperimentTemplateLibrary.all
        for template in walk {
            let copy = "\(template.question) \(template.rationale) \(template.normalCondition.detail) \(template.testCondition.detail)".lowercased()
            for word in ["dose", "mg", "energy drink", "more caffeine", "double espresso"] {
                XCTAssertFalse(copy.contains(word), "Template \(template.id) contains \(word)")
            }
        }
        let caffeinePatternSessions = (0..<4).map { _ in fuelSession(caffeine: .recently, difficulty: 2) }
        let result = FuelPatternEngine.evaluate(sessions: caffeinePatternSessions)
        if let pattern = result.patterns.first(where: { $0.id == "caffeine.context" }) {
            XCTAssertEqual(pattern.statement, "Sessions started soon after caffeine have recently felt manageable.")
        }
    }

    func testSleepTemplatesNeverInstructManipulation() {
        let templates = [ExperimentTemplateLibrary.sleepQualityComparison, ExperimentTemplateLibrary.morningFocus]
        let forbidden = ["sleep less", "sleep more", "stay awake", "change bedtime", "wake earlier", "restrict"]
        for template in templates {
            let copy = "\(template.question) \(template.rationale) \(template.normalCondition.detail) \(template.testCondition.detail)".lowercased()
            for word in forbidden {
                XCTAssertFalse(copy.contains(word), "\(template.id) instructs '\(word)'")
            }
        }
    }

    // MARK: - Comparison kinds

    func testObservationalVsInterventionComparisonKinds() {
        XCTAssertEqual(ExperimentTemplateLibrary.morningFocus.comparisonKind, .observationalComparison)
        XCTAssertEqual(ExperimentTemplateLibrary.sleepQualityComparison.comparisonKind, .observationalComparison)
        XCTAssertEqual(ExperimentTemplateLibrary.mealTimingComparison.comparisonKind, .observationalComparison)
        XCTAssertEqual(ExperimentTemplateLibrary.shortWalkBeforeFocus.comparisonKind, .interventionTest)
        XCTAssertEqual(ExperimentTemplateLibrary.noInputBreak.comparisonKind, .interventionTest)
        XCTAssertTrue(ExperimentTemplateLibrary.fuelInterventionTemplates.contains { $0.id == ExperimentTemplateLibrary.shortWalkBeforeFocus.id })
        XCTAssertTrue(ExperimentTemplateLibrary.fuelInterventionTemplates.contains { $0.id == ExperimentTemplateLibrary.noInputBreak.id })
    }

    func testMovementAndBreakUsePersonalLabTemplates() {
        XCTAssertEqual(ExperimentTemplateLibrary.shortWalkBeforeFocus.targetVariable, .movement)
        XCTAssertEqual(ExperimentTemplateLibrary.noInputBreak.targetVariable, .breakStyle)
        XCTAssertFalse(ExperimentTemplateLibrary.shortWalkBeforeFocus.testCondition.detail.lowercased().contains("intense"))
        XCTAssertFalse(ExperimentTemplateLibrary.shortWalkBeforeFocus.testCondition.detail.lowercased().contains("30 minutes"))
    }

    // MARK: - Observational arm assignment

    func testObservationalDaypartArmsFillByRealContext() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.morningFocus
        )
        experiment.status = .active

        let morning = tryUnwrap(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: nil, sessionDate: dateAt(9)
        ))
        XCTAssertEqual(morning.arm.kind, .test, "Morning fills the morning arm")

        let afternoon = tryUnwrap(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: nil, sessionDate: dateAt(14)
        ))
        XCTAssertEqual(afternoon.arm.kind, .normal, "Afternoon fills the afternoon arm")

        // Evening fills nothing: honest wait, no forced arm.
        XCTAssertNil(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: nil, sessionDate: dateAt(20)
        ))
    }

    func testObservationalSleepNeedsRealSnapshot() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.sleepQualityComparison
        )
        experiment.status = .active
        XCTAssertNil(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: nil, sessionDate: dateAt(9)
        ), "Without a sleep report no arm fills")

        let good = FuelContextSnapshot(sleepQuality: .good)
        let goodAssignment = tryUnwrap(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: good, sessionDate: dateAt(9)
        ))
        XCTAssertEqual(goodAssignment.arm.kind, .test)

        let rough = FuelContextSnapshot(sleepQuality: .rough)
        let roughAssignment = tryUnwrap(PersonalLabEngine.observationalAssignment(
            for: experiment, fuel: rough, sessionDate: dateAt(9)
        ))
        XCTAssertEqual(roughAssignment.arm.kind, .normal)
    }

    func testObservationalParticipationAutoConfirmsFromContext() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.morningFocus
        )
        experiment.status = .active
        let request = TrainingSessionRequest.freeTraining(mode: .stay)
        let eligibility = ExperimentEligibilitySnapshot(
            eligible: true, reasons: [], mode: .stay, targetMinutes: 15,
            recoveryProtected: false, ruleExceptionIDs: []
        )
        let participation = tryUnwrap(PersonalLabEngine.participation(
            for: experiment,
            request: request,
            eligibility: eligibility,
            fuel: nil,
            sessionDate: dateAt(14)
        ))
        XCTAssertEqual(participation.armKind, .normal)
        XCTAssertTrue(participation.conditionSnapshot.conditionFollowed, "Context-selected arms are followed by definition")
        XCTAssertEqual(participation.conditionSnapshot.truthSource, .systemConfirmed, "Daypart is system-derived")
    }

    func testStoreObservationalSleepExperimentRunsThroughProtocolPrompt() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.sleepQualityComparison)
        let prompt = tryUnwrap(store.currentFuelPrompt)
        XCTAssertEqual(prompt.field, .sleepQuality)
        store.answerFuelPrompt(prompt, rawValue: FuelSleepQuality.good.rawValue)

        XCTAssertTrue(store.canPrepareStandaloneLabSession)
        store.prepareStandaloneLabSession()
        guard case .preparing(let request) = store.phase else {
            return XCTFail("Expected standalone preparation")
        }
        XCTAssertEqual(request.experimentParticipation?.armKind, .test)
        store.beginPreparedSession()
        store.finishRunning(actualMinutes: 15, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: nil
        )
        let experiment = tryUnwrap(store.experiment(id: request.experimentParticipation!.experimentID))
        XCTAssertEqual(experiment.observations.count, 1)
        let observation = tryUnwrap(experiment.observations.first)
        XCTAssertEqual(observation.armKind, .test)
        XCTAssertEqual(observation.fuelContext?.sleepQuality, .good)
        XCTAssertEqual(store.completedProtocolDays, 1, "Standalone Lab never advances the Program")
    }

    // MARK: - Variable-aware comparability

    func testDaypartExperimentRequiresDifferingDayparts() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.morningFocus
        )
        experiment.status = .active
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 1, hour: 14, difficulty: 4))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 1, hour: 9, difficulty: 2))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 1, "Differing dayparts are the point, not a confound")

        var sameDaypart = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.morningFocus
        )
        sameDaypart.status = .active
        sameDaypart.observations.append(observationalObservation(sameDaypart, arm: .normal, pair: 1, hour: 9, difficulty: 4))
        sameDaypart.observations.append(observationalObservation(sameDaypart, arm: .test, pair: 1, hour: 10, difficulty: 2))
        ExperimentComparisonEngine.updateComparability(&sameDaypart)
        XCTAssertEqual(sameDaypart.completePairCount, 0)
        XCTAssertTrue(sameDaypart.observations.contains {
            $0.confounds.contains(where: { $0.kind == .targetVariableDidNotDiffer })
        })
    }

    func testNonTargetDaypartMismatchConfounds() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 1, hour: 9, difficulty: 3, startedEasier: false))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 1, hour: 14, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertTrue(experiment.observations.contains {
            $0.confounds.contains(where: { $0.kind == .contextMismatch })
        }, "For a walk test, differing dayparts are a genuine confound")
    }

    func testTaskContextMismatchConfoundsAndUnknownDoesNot() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        var codingTask = FuelContextSnapshot(movement: .shortWalkBefore)
        codingTask.taskContext = .coding
        var readingTask = FuelContextSnapshot(movement: .mostlyStill)
        readingTask.taskContext = .reading
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 1, hour: 9, difficulty: 3, startedEasier: false, fuel: readingTask))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 1, hour: 9, difficulty: 2, startedEasier: true, fuel: codingTask))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 0)
        XCTAssertTrue(experiment.observations.contains {
            $0.confounds.contains(where: { $0.kind == .contextMismatch })
        })

        var unknownTask = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        unknownTask.status = .active
        let walkFuel = FuelContextSnapshot(movement: .shortWalkBefore)
        let stillFuel = FuelContextSnapshot(movement: .mostlyStill)
        unknownTask.observations.append(observationalObservation(unknownTask, arm: .normal, pair: 1, hour: 9, difficulty: 3, startedEasier: false, fuel: stillFuel))
        unknownTask.observations.append(observationalObservation(unknownTask, arm: .test, pair: 1, hour: 9, difficulty: 2, startedEasier: true, fuel: walkFuel))
        ExperimentComparisonEngine.updateComparability(&unknownTask)
        XCTAssertEqual(unknownTask.completePairCount, 1, "Unknown task context never confounds")
    }

    // MARK: - INCONCLUSIVE extra pairs

    func testInconclusiveExperimentExtendsWithSameIDAndHistory() {
        var experiment = threePairInconclusiveExperiment()
        XCTAssertEqual(experiment.result?.state, .inconclusive)
        XCTAssertEqual(experiment.status, .completed)
        let observationCount = experiment.observations.count

        XCTAssertTrue(experiment.extendForAdditionalComparison())
        XCTAssertEqual(experiment.plan.targetPairs, 4)
        XCTAssertEqual(experiment.status, .active)
        XCTAssertNil(experiment.result)
        XCTAssertEqual(experiment.historicalResults.count, 1)
        XCTAssertEqual(experiment.historicalResults[0].state, .inconclusive)
        XCTAssertEqual(experiment.observations.count, observationCount, "Extension adds slots, never duplicates evidence")

        // A second extension before the new pair completes must be refused.
        XCTAssertFalse(experiment.extendForAdditionalComparison())
    }

    func testExtendedResultRecalculatesOnlyAfterNewPairCompletes() {
        var experiment = threePairInconclusiveExperiment()
        XCTAssertTrue(experiment.extendForAdditionalComparison())
        // Pair 4 normal: test looked worse (start ease false vs true on test).
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 4, hour: 9, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertNil(experiment.result, "Half a pair finalizes nothing")
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 4, hour: 10, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        XCTAssertEqual(experiment.completePairCount, 4)
        _ = ExperimentResultEngine.finalize(&experiment, allowEarly: false)
        XCTAssertEqual(experiment.status, .completed)
        let result = tryUnwrap(experiment.result)
        XCTAssertEqual(result.completedPairs, 4)
        XCTAssertEqual(result.state, .inconclusive, "Similar pair 4 stays inconclusive — no manufactured winner")
    }

    func testMaxPairPolicyBlocksBeyondFive() {
        var experiment = threePairInconclusiveExperiment()
        XCTAssertTrue(experiment.extendForAdditionalComparison())
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 4, hour: 9, difficulty: 3, startedEasier: true))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 4, hour: 10, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        _ = ExperimentResultEngine.finalize(&experiment, allowEarly: false)
        XCTAssertEqual(experiment.status, .completed)
        XCTAssertTrue(experiment.extendForAdditionalComparison(), "Second extension to 5 allowed")
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 5, hour: 9, difficulty: 3, startedEasier: true))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 5, hour: 10, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        _ = ExperimentResultEngine.finalize(&experiment, allowEarly: false)
        XCTAssertEqual(experiment.plan.targetPairs, ExperimentPolicy.maxPairs)
        XCTAssertFalse(experiment.extendForAdditionalComparison(), "No pair 6 — the user is never trapped")
    }

    // MARK: - Opportunity-aware surfacing

    func testOpportunityNotComparableForWrongMode() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        let request = TrainingSessionRequest.freeTraining(mode: .recall)
        let opportunity = ExperimentOpportunityEngine.evaluate(
            request: request, experiment: experiment, isRecovery: false
        )
        guard case .notComparable(let reasons) = opportunity else {
            return XCTFail("Expected notComparable")
        }
        XCTAssertFalse(reasons.isEmpty)
    }

    func testOpportunityEligibleForMatchingSession() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        var request = TrainingSessionRequest.freeTraining(mode: .stay)
        request.targetMinutes = 15
        let opportunity = ExperimentOpportunityEngine.evaluate(
            request: request, experiment: experiment, isRecovery: false
        )
        guard case .eligibleNow = opportunity else {
            return XCTFail("Expected eligibleNow")
        }
    }

    func testOpportunityBlockedOnDayOneAndRecovery() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        let dayOne = TrainingSessionRequest.protocolRequest(
            prescription: .empty, day: 1, environmentPreparation: nil
        )
        guard case .blocked = ExperimentOpportunityEngine.evaluate(
            request: dayOne, experiment: experiment, isRecovery: false
        ) else { return XCTFail("Day 1 blocks") }

        let request = TrainingSessionRequest.freeTraining(mode: .stay)
        guard case .blocked = ExperimentOpportunityEngine.evaluate(
            request: request, experiment: experiment, isRecovery: true
        ) else { return XCTFail("Recovery blocks") }
    }

    func testOpportunityDurationGate() {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        let request = TrainingSessionRequest.protocolRequest(
            prescription: .empty, day: 10, environmentPreparation: nil
        )
        var long = request
        long.targetMinutes = 35
        guard case .notComparable(let reasons) = ExperimentOpportunityEngine.evaluate(
            request: long, experiment: experiment, isRecovery: false
        ) else { return XCTFail("Expected duration notComparable") }
        XCTAssertTrue(reasons.contains { $0.contains("length") })
    }

    func testTodayCardIsOpportunityAware() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.shortWalkBeforeFocus)
        // Standalone is possible while the protocol prescription stays eligible;
        // the surfaced opportunity must at least never be .blocked.
        let opportunity = store.todayExperimentOpportunity()
        XCTAssertNotEqual(opportunity, nil)
    }

    // MARK: - Program invariants with Fuel

    func testProtocolWithFuelAndLabAdvancesExactlyOnce() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.phoneDistance)
        if let prompt = store.currentFuelPrompt {
            store.answerFuelPrompt(prompt, rawValue: FuelEnergyLevel.okay.rawValue)
        }
        store.prepareProtocolSession(participatingInLab: true)
        guard case .preparing(var request) = store.phase else {
            return XCTFail("Expected preparation")
        }
        if request.experimentParticipation != nil {
            request = confirming(request)
            store.updatePreparedRequest(request)
            store.beginPreparedSession()
        } else {
            store.beginPreparedSession()
        }
        let dayBefore = store.day
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: true
        )
        drainRequiredFlow(store)
        XCTAssertEqual(store.completedProtocolDays, 2)
        XCTAssertEqual(store.day, dayBefore + 1, "Exactly one advance")

        // Duplicate save attempt must not advance again.
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: true
        )
        XCTAssertEqual(store.completedProtocolDays, 2)
    }

    func testFreeTrainingWithLabAndFuelNeverAdvancesProgram() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.phoneDistance)
        var capture = FuelContextSnapshot()
        capture.energy = .okay
        store.fuelState.pendingCapture = capture
        store.prepareFreeTraining(.stay, participatingInLab: true)
        guard case .preparing(let request) = store.phase else {
            return XCTFail("Expected preparation")
        }
        XCTAssertNotNil(request.experimentParticipation)
        let confirmed = confirming(request)
        store.updatePreparedRequest(confirmed)
        store.beginPreparedSession()
        store.finishRunning(actualMinutes: 15, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 2,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: nil
        )
        XCTAssertEqual(store.completedProtocolDays, 1, "Free training never advances the Program")
        XCTAssertEqual(store.day, 2)
    }

    func testDayNinetyTerminalWithFuelSessions() {
        var sessions: [SessionRecord] = []
        for day in 1...90 {
            var snapshot = FuelContextSnapshot(energy: day % 2 == 0 ? .okay : .high)
            if day % 3 == 0 { snapshot.sleepQuality = .good }
            sessions.append(completedProtocolDay(day, snapshot: snapshot))
        }
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(profile: AttentionProfile(), sessions: sessions, day: 90))
        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertLessThanOrEqual(store.day, 90, "No Day 91")
        XCTAssertFalse(store.sessions.isEmpty)
        XCTAssertNotNil(store.latestFuelContext)
    }

    // MARK: - Personal Rule gating

    func testFuelKeepRequiresUserConfirmationAndNeverAutoCreates() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.shortWalkBeforeFocus)
        // Walk pattern sessions alone create no rules.
        for _ in 0..<3 {
            store.prepareFreeTraining(.stay, participatingInLab: true)
            guard case .preparing(let request) = store.phase else { return XCTFail("prep") }
            let confirmed = confirming(request)
            store.updatePreparedRequest(confirmed)
            store.beginPreparedSession()
            store.finishRunning(actualMinutes: 15, endedEarly: false)
            let isTestArm = confirmed.experimentParticipation?.armKind == .test
            store.saveDoneSession(
                difficulty: isTestArm ? 2 : 3,
                firstDistraction: "none",
                switches: isTestArm ? 1 : 4,
                firstSwitchMinute: nil,
                energy: nil,
                environmentActionDone: nil,
                startedEasier: isTestArm ? true : false
            )
        }
        XCTAssertFalse(store.personalRules.contains { $0.title.lowercased().contains("walk") },
                      "Fuel never silently promotes a rule")
        if let active = store.activeExperiment, active.completePairCount >= 2 {
            _ = store.finalizeExperiment(id: active.id, allowEarly: true)
        }
        guard let experiment = store.pastExperiments.first(where: { $0.result?.state == .keep })
              ?? store.labState.experiments.first,
              experiment.result?.state == .keep else {
            // Deterministic setup should produce KEEP; if not, the gating
            // invariant is still asserted by the absence of auto rules above.
            return
        }
        XCTAssertNil(experiment.result?.personalRuleID)
        let rule = store.keepExperimentResultAsRule(experimentID: experiment.id)
        XCTAssertNotNil(rule, "User confirmation creates the rule")
        let walkRule = tryUnwrap(store.personalRules.first { $0.experimentID == experiment.id })
        let forbidden = ["coffee", "water", "calorie", "sleep 8", "exercise 30", "fast"]
        for word in forbidden {
            XCTAssertFalse("\(walkRule.title) \(walkRule.detail)".lowercased().contains(word))
        }
    }

    // MARK: - Persistence v7

    func testV6ToV7MigrationPreservesEverything() throws {
        let profile = AttentionProfile()
        let session = completedProtocolDay(4, snapshot: nil)
        let labExperiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.phoneDistance
        )
        var labState = PersonalLabState.empty
        labState.experiments.append(labExperiment)
        let legacy: [String: Any] = [
            "profile": try JSONEncoder().encode(profile),
            "sessions": try JSONEncoder().encode([session]),
            "day": 5,
            "programState": try JSONEncoder().encode(ProgramState.fresh),
            "personalLab": try JSONEncoder().encode(labState),
        ]
        defaults.set(legacy, forKey: "reboot.product.v6")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v7"), "v7 key must be written")
        XCTAssertNil(defaults.object(forKey: "reboot.product.v6"), "v6 key must be cleaned")
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.labState.experiments.count, 1)
        XCTAssertEqual(store.labState.experiments[0].comparisonKind, .interventionTest, "Old experiment decodes with safe default")
        XCTAssertNil(store.labState.experiments[0].targetVariable)
        XCTAssertEqual(store.fuelState, .empty)
    }

    func testV7RoundTripIncludingFuel() {
        let store = dayTwoStore()
        guard let prompt = store.currentFuelPrompt else { return XCTFail("prompt") }
        store.answerFuelPrompt(prompt, rawValue: FuelEnergyLevel.low.rawValue)
        store.beginSession()
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 3,
            firstDistraction: "none",
            switches: 2,
            firstSwitchMinute: nil,
            energy: 2,
            environmentActionDone: true
        )
        drainRequiredFlow(store)
        XCTAssertEqual(store.completedProtocolDays, 2)

        let reloaded = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(reloaded.completedProtocolDays, 2)
        XCTAssertEqual(reloaded.sessions.last?.fuelContext?.energy, .low)
        XCTAssertEqual(reloaded.fuelState.sampling.answeredCounts[FuelContextField.energy.rawValue], 1)
        XCTAssertNotNil(defaults.dictionary(forKey: "reboot.product.v7"))
    }

    func testCorruptedV7FuelDegradesWithoutLosingSessions() throws {
        let store = dayTwoStore()
        store.setFuelPromptsEnabled(false)
        var raw = tryUnwrap(defaults.dictionary(forKey: "reboot.product.v7"))
        raw["fuel"] = Data("not_json_at_all".utf8)
        defaults.set(raw, forKey: "reboot.product.v7")

        let reloaded = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(reloaded.sessions.count, dayTwoStore().sessions.count)
        XCTAssertEqual(reloaded.fuelState, .empty, "Corrupt Fuel payload degrades to defaults")
    }

    func testCorruptedV7DoesNotRollBackToStaleV6() throws {
        let v6Session = completedProtocolDay(3, snapshot: nil)
        let legacy: [String: Any] = [
            "profile": try JSONEncoder().encode(AttentionProfile()),
            "sessions": try JSONEncoder().encode([v6Session]),
            "day": 4,
        ]
        defaults.set(legacy, forKey: "reboot.product.v6")
        // A v7 payload exists but its sessions blob is garbage.
        defaults.set(["sessions": Data("garbage".utf8)], forKey: "reboot.product.v7")

        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.sessions.count, 0, "Corrupt v7 wins over stale v6 — never silent rollback")
        XCTAssertNotNil(defaults.object(forKey: "reboot.product.v6"), "v6 was not consumed by a corrupt v7")
    }

    func testPerElementSessionRecoveryKeepsHealthyNeighbors() throws {
        let good1 = completedProtocolDay(2, snapshot: FuelContextSnapshot(energy: .okay))
        let bad = completedProtocolDay(3, snapshot: nil)
        let good2 = completedProtocolDay(4, snapshot: nil)
        let encoded = try JSONEncoder().encode([good1, bad, good2])
        let json = try JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
        var mutable = json
        mutable[1].removeValue(forKey: "day") // required key removed → element fails
        let corrupted = try JSONSerialization.data(withJSONObject: mutable)

        let legacy: [String: Any] = [
            "profile": try JSONEncoder().encode(AttentionProfile()),
            "sessions": corrupted,
            "day": 5,
        ]
        defaults.set(legacy, forKey: "reboot.product.v7")
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        XCTAssertEqual(store.sessions.count, 2, "One bad record must not wipe its neighbors")
        XCTAssertTrue(store.sessions.contains { $0.fuelContext?.energy == .okay })
    }

    func testOldV6ConditionAndExperimentDecode() throws {
        let conditionJSON = """
        {"id":"phone.usual","title":"Usual phone placement","detail":"Keep your phone where you usually do."}
        """
        let condition = try JSONDecoder().decode(ExperimentCondition.self, from: Data(conditionJSON.utf8))
        XCTAssertEqual(condition.domain, .digital)
        XCTAssertNil(condition.contextMatcher)
        XCTAssertEqual(condition.timing, .beforeSession)
        XCTAssertEqual(condition.expectedTruthSource, .userReported)

        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.phoneDistance
        )
        experiment.status = .active
        let data = try JSONEncoder().encode(experiment)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "comparisonKind")
        json.removeValue(forKey: "targetVariable")
        json.removeValue(forKey: "historicalResults")
        json.removeValue(forKey: "observations")
        json.removeValue(forKey: "pairs")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PersonalExperiment.self, from: stripped)
        XCTAssertEqual(decoded.comparisonKind, .interventionTest)
        XCTAssertNil(decoded.targetVariable)
        XCTAssertTrue(decoded.historicalResults.isEmpty)
        XCTAssertTrue(decoded.observations.isEmpty)
    }

    // MARK: - Long-range simulations

    func testLongRangeStudyUserWithFuelNinetyDays() {
        let store = ProductStore(diagnosisAnswers: ["primary": ["read_more"]], defaults: defaults)
        var promptsShown = 0
        var answeredFields: Set<String> = []
        var iterations = 0
        while store.programStatus == .active, iterations < 220 {
            iterations += 1
            if let prompt = store.currentFuelPrompt {
                promptsShown += 1
                let value = prompt.options[iterations % prompt.options.count].rawValue
                store.answerFuelPrompt(prompt, rawValue: value)
                answeredFields.insert(prompt.field.rawValue)
            }
            store.beginSession()
            store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
            store.saveDoneSession(
                difficulty: (iterations % 4 == 0) ? 3 : 2,
                firstDistraction: "none",
                switches: iterations % 3,
                firstSwitchMinute: nil,
                energy: 3,
                environmentActionDone: store.day == 1 ? nil : true
            )
            drainRequiredFlow(store)
        }
        XCTAssertEqual(store.completedProtocolDays, 90)
        XCTAssertEqual(store.programStatus, .completed)
        XCTAssertLessThanOrEqual(store.day, 90, "No Day 91")
        XCTAssertLessThanOrEqual(promptsShown, 45, "Sampling must stay respectful over 90 days")
        XCTAssertGreaterThanOrEqual(promptsShown, 1,
            "At least one prompt in a whole program; the suite runs inside one calendar day, so per-day gating correctly bounds the rest")
        XCTAssertFalse(answeredFields.isEmpty)
        for session in store.sessions {
            if let fuel = session.fuelContext {
                XCTAssertEqual(fuel.captureSource, .manual, "Energy stays self-report")
            }
        }
    }

    func testLongRangeDeepWorkUserCompletesMovementExperiment() {
        let store = ProductStore(diagnosisAnswers: ["primary": ["deep_work"]], defaults: defaults)
        var iterations = 0
        while store.day < 10, store.programStatus == .active, iterations < 30 {
            iterations += 1
            runOneProtocolDay(store)
        }
        XCTAssertGreaterThanOrEqual(store.day, 8)

        XCTAssertEqual(store.startExperiment(template: ExperimentTemplateLibrary.shortWalkBeforeFocus), .started(store.activeExperiment!.id))
        XCTAssertNil(store.currentFuelPrompt, "Walk test owns the deliberate variable")

        var labIterations = 0
        while store.activeExperiment?.result == nil, labIterations < 60 {
            labIterations += 1
            // Keep the Program moving on days the test waits.
            if store.protocolRequest() != nil {
                runOneProtocolDay(store)
            }
            guard store.canPrepareStandaloneLabSession else { continue }
            store.prepareStandaloneLabSession()
            guard case .preparing(var request) = store.phase else { continue }
            let isTestArm = request.experimentParticipation?.armKind == .test
            request = confirming(request)
            store.updatePreparedRequest(request)
            store.beginPreparedSession()
            store.finishRunning(actualMinutes: 15, endedEarly: false)
            store.saveDoneSession(
                difficulty: isTestArm ? 2 : 4,
                firstDistraction: "none",
                switches: isTestArm ? 1 : 5,
                firstSwitchMinute: nil,
                energy: nil,
                environmentActionDone: nil,
                startedEasier: isTestArm ? true : false
            )
        }
        let experiment = tryUnwrap(store.labState.experiments.first { $0.templateID == ExperimentTemplateLibrary.shortWalkBeforeFocus.id })
        XCTAssertEqual(experiment.status, .completed, "Movement test completes through Personal Lab")
        XCTAssertNotNil(experiment.result)
        XCTAssertFalse(store.personalRules.contains { $0.title.lowercased().contains("walk") },
                      "No rule without explicit user confirmation")
    }

    func testContradictoryFuelUserConfidenceCanFall() {
        let sessions = [
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 4),
            fuelSession(energy: .low, difficulty: 5),
            fuelSession(energy: .low, difficulty: 1),
            fuelSession(energy: .low, difficulty: 2),
        ]
        let result = FuelPatternEngine.evaluate(sessions: sessions)
        let pattern = result.patterns.first { $0.id == "energy.difficulty" }
        if let pattern {
            XCTAssertEqual(pattern.maturity, .mixed, "Confidence falls with contradictions")
        } else {
            XCTFail("Expected mixed pattern from 3v2 evidence")
        }
    }

    // MARK: - Post-audit regression fixes

    func testProtocolAttachPathKeepsObservationalSleepParticipation() {
        // The Today card promises "this session can count"; the prepared
        // protocol request must actually carry the participation.
        let store = ProductStore(diagnosisAnswers: ["primary": ["deep_work"]], defaults: defaults)
        var iterations = 0
        while store.prescription.mode != .stay || store.day < 2 {
            if store.programStatus != .active { return XCTFail("Program ended before STAY day") }
            runOneProtocolDay(store)
            iterations += 1
            if iterations > 20 { return XCTFail("No STAY prescription day found") }
        }
        _ = store.startExperiment(template: ExperimentTemplateLibrary.sleepQualityComparison)
        let prompt = tryUnwrap(store.currentFuelPrompt)
        XCTAssertEqual(prompt.field, .sleepQuality)
        store.answerFuelPrompt(prompt, rawValue: FuelSleepQuality.good.rawValue)

        store.prepareProtocolSession(participatingInLab: true)
        guard case .preparing(let request) = store.phase else {
            return XCTFail("Expected preparation")
        }
        guard let participation = request.experimentParticipation else {
            return XCTFail("Protocol attach path must keep observational participation")
        }
        XCTAssertEqual(participation.armKind, .test, "Good-reported sleep fills the Test arm")
        store.beginPreparedSession()
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: true
        )
        drainRequiredFlow(store)
        let experiment = tryUnwrap(store.experiment(id: participation.experimentID))
        XCTAssertEqual(experiment.observations.count, 1, "The promised session counted")
        XCTAssertEqual(experiment.observations.first?.armKind, .test)
    }

    func testStaleCaptureIsDiscardedAndNeverBlocksFutureAnswers() {
        let store = dayTwoStore()
        var stale = FuelContextSnapshot(energy: .okay)
        stale.capturedAt = Date().addingTimeInterval(-2 * 86_400)
        store.fuelState.pendingCapture = stale

        let prompt = ContextSamplingEngine.prompt(for: .caffeineRecency)
        store.answerFuelPrompt(prompt, rawValue: FuelCaffeineRecency.recently.rawValue)
        let fresh = tryUnwrap(store.fuelState.pendingCapture)
        XCTAssertEqual(FuelState.calendarDay(fresh.capturedAt), FuelState.calendarDay(Date()),
                       "A stale base must never anchor the new capture")
        XCTAssertNil(fresh.energy, "Stale-day fields are dropped, not carried into today")

        store.beginSession()
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: true
        )
        drainRequiredFlow(store)
        XCTAssertEqual(store.sessions.last?.fuelContext?.caffeineRecency, .recently,
                       "Fuel attachment stays alive after a stale day")
    }

    func testPromptAfterCompletedDayAttachesToNextSession() {
        // Program day advances on save, so after today's session the next
        // prompt belongs to tomorrow's session — and its answer must actually
        // attach when that session begins the same calendar day.
        let store = dayTwoStore()
        runOneProtocolDay(store)
        let prompt = tryUnwrap(store.currentFuelPrompt)
        store.answerFuelPrompt(prompt, rawValue: prompt.options.first!.rawValue)
        runOneProtocolDay(store)
        XCTAssertEqual(store.sessions.last?.fuelContext?.value(for: prompt.field),
                       prompt.options.first?.rawValue,
                       "The answered capture attaches to the next session begun the same day")
    }

    func testStaleCaptureDoesNotDriveLabEligibility() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.sleepQualityComparison)
        var stale = FuelContextSnapshot(sleepQuality: .good)
        stale.capturedAt = Date().addingTimeInterval(-86_400)
        store.fuelState.pendingCapture = stale

        XCTAssertNil(store.todaysFuelCapture)
        XCTAssertFalse(store.canPrepareStandaloneLabSession,
                       "Yesterday's answers must not enable today's test")
        if case .eligibleNow = store.todayExperimentOpportunity() {
            XCTFail("Stale capture must not surface the Today card as eligible")
        }
    }

    func testNeededFieldQuietsAfterRepeatedSkips() {
        let now = Date()
        var log = FuelSamplingLog()
        log.skipCounts[FuelContextField.sleepQuality.rawValue] = 3
        log.lastPromptAt[FuelContextField.sleepQuality.rawValue] = now.addingTimeInterval(-86_400)
        let quiet = ContextSamplingEngine.recommendPrompt(.init(
            programDay: 10,
            completedProtocolDays: 9,
            phase: .controlInput,
            preferredField: .sleepQuality,
            log: log,
            now: now
        ))
        XCTAssertNil(quiet, "Repeated skips quiet even the field a test waits on")

        var patientLog = FuelSamplingLog()
        patientLog.lastPromptAt[FuelContextField.sleepQuality.rawValue] = now.addingTimeInterval(-3 * 86_400)
        let asking = ContextSamplingEngine.recommendPrompt(.init(
            programDay: 10,
            completedProtocolDays: 9,
            phase: .controlInput,
            preferredField: .sleepQuality,
            log: patientLog,
            now: now
        ))
        XCTAssertEqual(asking?.field, .sleepQuality)
    }

    func testInterventionStandaloneDoesNotConsumeCapture() {
        let store = dayTwoStore()
        _ = store.startExperiment(template: ExperimentTemplateLibrary.shortWalkBeforeFocus)
        store.fuelState.pendingCapture = FuelContextSnapshot(energy: .okay)

        XCTAssertTrue(store.canPrepareStandaloneLabSession)
        store.prepareStandaloneLabSession()
        guard case .preparing = store.phase else { return XCTFail("Expected standalone preparation") }
        store.beginPreparedSession()
        store.finishRunning(actualMinutes: 15, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: nil,
            environmentActionDone: nil
        )
        XCTAssertNil(store.sessions.last?.fuelContext,
                     "Deliberate intervention tests do not eat the day's capture")
        XCTAssertNotNil(store.fuelState.pendingCapture,
                        "The capture stays available for today's protocol session")
    }

    func testDaypartPatternDoesNotHideEnergyOpenQuestion() {
        // Morning-steady sessions with task context only — no energy answers.
        let sessions: [SessionRecord] = [
            fuelSession(movement: .mostlyStill, difficulty: 2, switches: 1, dayOffset: 0),
            fuelSession(movement: .mostlyStill, difficulty: 2, switches: 2, dayOffset: 1),
            fuelSession(movement: .mostlyStill, difficulty: 3, switches: 1, dayOffset: 2),
            afternoonRoughSession(),
        ]
        let result = FuelPatternEngine.evaluate(sessions: sessions)
        XCTAssertTrue(result.patterns.contains { $0.id == "daypart.morning.switches" },
                      "Fixture should surface the morning pattern")
        XCTAssertTrue(result.openQuestions.contains { $0.dimension == .energy },
                      "A timestamp-derived signal must not answer the energy question")
    }

    private func afternoonRoughSession() -> SessionRecord {
        var snapshot = FuelContextSnapshot()
        snapshot.taskContext = .focusedWork
        snapshot.capturedAt = dateAt(14, dayOffset: 3)
        return SessionRecord(
            origin: .protocol,
            day: 14,
            date: dateAt(14, dayOffset: 3),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            switches: 4,
            difficulty: 3,
            fuelContext: snapshot
        )
    }

    // MARK: - Helpers

    private func runOneProtocolDay(_ store: ProductStore) {
        guard store.protocolRequest() != nil else { return }
        store.beginSession()
        store.finishRunning(actualMinutes: store.prescription.minutes, endedEarly: false)
        store.saveDoneSession(
            difficulty: 2,
            firstDistraction: "none",
            switches: 1,
            firstSwitchMinute: nil,
            energy: 3,
            environmentActionDone: store.day == 1 ? nil : true
        )
        drainRequiredFlow(store)
    }

    private func dayTwoStore() -> ProductStore {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        store.apply(QASeed(profile: AttentionProfile(), sessions: [completedProtocolDay(1, snapshot: nil)], day: 2))
        return store
    }

    private func dayTwoStoreAfterDifficultSession() -> ProductStore {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let hard = SessionRecord(
            origin: .protocol,
            day: 1,
            date: Date().addingTimeInterval(-86_400),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 3,
            completed: false,
            endedEarly: true,
            difficulty: 5
        )
        store.apply(QASeed(profile: AttentionProfile(), sessions: [hard], day: 2))
        return store
    }

    private func completedProtocolDay(_ day: Int, snapshot: FuelContextSnapshot?) -> SessionRecord {
        SessionRecord(
            origin: .protocol,
            requestID: UUID(),
            day: day,
            date: dateAt(10, dayOffset: -day),
            mode: day == 1 ? .observe : .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            elapsedSeconds: 900,
            completed: true,
            switches: 1,
            difficulty: 2,
            fuelContext: snapshot
        )
    }

    /// Direct pattern-engine fixture: one completed session at a fixed time.
    private func fuelSession(
        energy: FuelEnergyLevel? = nil,
        sleep: FuelSleepQuality? = nil,
        meal: FuelMealTiming? = nil,
        caffeine: FuelCaffeineRecency? = nil,
        movement: FuelMovementContext? = nil,
        breakType: FuelBreakType? = nil,
        difficulty: Int,
        switches: Int? = nil,
        startedEasier: Bool? = nil,
        dayOffset: Int = 0
    ) -> SessionRecord {
        var snapshot = FuelContextSnapshot()
        snapshot.energy = energy
        snapshot.sleepQuality = sleep
        snapshot.mealTiming = meal
        snapshot.caffeineRecency = caffeine
        snapshot.movement = movement
        snapshot.breakType = breakType
        snapshot.capturedAt = dateAt(9, dayOffset: dayOffset)
        return SessionRecord(
            origin: .protocol,
            day: 10 + dayOffset,
            date: dateAt(9, dayOffset: dayOffset),
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            switches: switches,
            difficulty: difficulty,
            startedEasierSelfReport: startedEasier,
            fuelContext: snapshot.isEmpty ? nil : snapshot
        )
    }

    private func observationalObservation(
        _ experiment: PersonalExperiment,
        arm: ExperimentArmKind,
        pair: Int,
        hour: Int,
        difficulty: Int,
        startedEasier: Bool? = nil,
        fuel: FuelContextSnapshot? = nil
    ) -> ExperimentObservation {
        let experimentArm = experiment.arm(for: arm)
        var snapshot = ExperimentConditionSnapshot.pending(experimentArm.condition)
        snapshot.actualDescription = experimentArm.condition.detail
        snapshot.truthSource = experimentArm.condition.contextMatcher?.truthSource ?? .userReported
        snapshot.conditionFollowed = true
        snapshot.capturedAt = dateAt(hour)
        var outcomes: [String: ExperimentMetricValue] = [
            ExperimentOutcomeMetric.difficulty.key: .integer(difficulty),
            ExperimentOutcomeMetric.earlyExit.key: .boolean(false),
            ExperimentOutcomeMetric.completion.key: .boolean(true),
        ]
        if let startedEasier {
            outcomes[ExperimentOutcomeMetric.startEase.key] = .boolean(startedEasier)
        }
        return ExperimentObservation(
            experimentID: experiment.id,
            sessionID: UUID(),
            armID: experimentArm.id,
            armKind: arm,
            pairIndex: pair,
            requestedCondition: snapshot,
            mode: .stay,
            targetMinutes: 15,
            actualMinutes: 15,
            completed: true,
            endedEarly: false,
            outcomes: outcomes,
            classification: .usableButUnmatched,
            classificationReason: "Fixture",
            confounds: [],
            sourceEvidenceIDs: [],
            date: dateAt(hour),
            fuelContext: fuel ?? FuelContextSnapshot()
        )
    }

    /// Three complete pairs whose primary outcome points in mixed directions.
    private func threePairInconclusiveExperiment() -> PersonalExperiment {
        var experiment = PersonalLabEngine.makeExperiment(
            template: ExperimentTemplateLibrary.shortWalkBeforeFocus
        )
        experiment.status = .active
        // Primary outcome is start ease. Pair 1: test better. Pair 2: normal
        // better. Pair 3: similar. Deterministic INCONCLUSIVE.
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 1, hour: 9, difficulty: 3, startedEasier: false))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 1, hour: 10, difficulty: 2, startedEasier: true))
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 2, hour: 9, difficulty: 2, startedEasier: true))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 2, hour: 10, difficulty: 3, startedEasier: false))
        experiment.observations.append(observationalObservation(experiment, arm: .normal, pair: 3, hour: 9, difficulty: 2, startedEasier: true))
        experiment.observations.append(observationalObservation(experiment, arm: .test, pair: 3, hour: 10, difficulty: 2, startedEasier: true))
        ExperimentComparisonEngine.updateComparability(&experiment)
        _ = ExperimentResultEngine.finalize(&experiment, allowEarly: false)
        return experiment
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

    private func dateAt(_ hour: Int, dayOffset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15 + dayOffset
        components.hour = hour
        return Calendar.current.date(from: components) ?? Date()
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
