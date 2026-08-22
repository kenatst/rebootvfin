import Foundation

enum AttentionOperatingManualEngine {

    static func generateManual(
        sessions: [SessionRecord],
        interruptionEvents: [InterruptionEvent],
        personalRules: [PersonalRule],
        labExperiments: [PersonalExperiment],
        fuelState: FuelState,
        flowState: FlowState,
        digitalEnvironmentState: DigitalEnvironmentState,
        profile: AttentionProfile,
        reviews: [WeeklyReviewRecord] = []
    ) -> AttentionOperatingManual {
        let protocolSessions = sessions.filter { $0.origin == .protocol }
        let totalDays = Set(protocolSessions.map(\.day)).count
        let totalSess = sessions.count

        return AttentionOperatingManual(
            generatedAt: Date(),
            lastUpdated: Date(),
            totalProtocolDays: totalDays,
            totalSessions: totalSess,
            howIStartBest: deriveHowIStartBest(sessions: sessions, rules: personalRules, profile: profile),
            myMostCommonBreakers: deriveMyMostCommonBreakers(events: interruptionEvents, digitalState: digitalEnvironmentState, sessions: sessions),
            myReturnStrategy: deriveMyReturnStrategy(sessions: protocolSessions, events: interruptionEvents, profile: profile),
            myFocusWindow: deriveMyFocusWindow(sessions: sessions, profile: profile),
            myDigitalEnvironment: deriveMyDigitalEnvironment(digitalState: digitalEnvironmentState, events: interruptionEvents),
            myDeepWorkConditions: deriveMyDeepWorkConditions(sessions: sessions, flowState: flowState, rules: personalRules),
            myRecallStrategy: deriveMyRecallStrategy(sessions: sessions),
            myEnergyAndContext: deriveMyEnergyAndContext(sessions: sessions, fuelState: fuelState),
            myFlowConditions: deriveMyFlowConditions(flowState: flowState, sessions: sessions),
            myPersonalRules: deriveMyPersonalRules(rules: personalRules),
            whatRebootStillDoesNotKnow: deriveWhatRebootStillDoesNotKnow(
                sessions: sessions,
                fuelState: fuelState,
                flowState: flowState,
                digitalState: digitalEnvironmentState,
                experiments: labExperiments
            )
        )
    }

    // MARK: - 1. How I Start Best

    private static func deriveHowIStartBest(sessions: [SessionRecord], rules: [PersonalRule], profile: AttentionProfile) -> ManualItem {
        let prepared = sessions.filter { $0.environmentActionDone == true }
        let normal = sessions.filter { $0.environmentActionDone != true }

        let preparedRate = prepared.isEmpty ? 0.0 : Double(prepared.filter(\.completed).count) / Double(prepared.count)
        let normalRate = normal.isEmpty ? 0.0 : Double(normal.filter(\.completed).count) / Double(normal.count)

        // Observed comparison first — but only with enough comparable sessions.
        if prepared.count >= 4, normal.count >= 2, preparedRate > normalRate + 0.15 {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "Sessions started after an explicit environment setup have completed more often than the rest (\(Int(preparedRate * 100))% vs \(Int(normalRate * 100))%).",
                maturity: prepared.count >= 8 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(prepared.count) prepared starts vs \(normal.count) without",
                observationCount: prepared.count + normal.count,
                lastUpdated: Date()
            )
        }

        if let keptRule = rules.first(where: { $0.lifecycle == .kept && $0.category == .environment }) {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "You chose to keep one starting rule: \(keptRule.title.lowercased()). It is applied before your focused blocks.",
                maturity: keptRule.confidence == .strong ? .repeatedSignal : .emergingSignal,
                evidenceSource: keptRule.sourceType.displayLabel,
                observationCount: max(keptRule.timesTested, 1),
                lastUpdated: Date()
            )
        }

        // Honest unknown until evidence exists.
        if sessions.count < 3 {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "Still learning how you start best. A few more sessions will show whether a setup ritual helps.",
                maturity: .learning,
                evidenceSource: "Only \(sessions.count) sessions recorded so far",
                observationCount: sessions.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "HOW I START BEST",
            statement: "No clear difference between prepared and unprepared starts yet. The comparison continues.",
            maturity: .learning,
            evidenceSource: "\(prepared.count) prepared vs \(normal.count) unprepared starts — not enough separation",
            observationCount: sessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 2. My Most Common Breakers

    private static func deriveMyMostCommonBreakers(events: [InterruptionEvent], digitalState: DigitalEnvironmentState, sessions: [SessionRecord]) -> ManualItem {
        // Observed digital pull from the environment engine.
        let pull = digitalState.profile.primaryDigitalPull
        if pull.isKnown && pull.value != .unknown && pull.evidenceCount >= 3 {
            return ManualItem(
                sectionTitle: "WHAT BREAKS MY ATTENTION",
                statement: "\(pull.value.displayName) is your most observed pull during moments of friction or pause.",
                maturity: pull.evidenceCount >= 6 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(pull.evidenceCount) observed interruption events",
                observationCount: pull.evidenceCount,
                lastUpdated: Date()
            )
        }

        // Self-reported first distractions across sessions.
        let firstDistractions = sessions.compactMap(\.firstDistraction).filter { $0 != "none" && $0 != "forgot" }
        if let top = Dictionary(grouping: firstDistractions, by: { $0 }).max(by: { $0.value.count < $1.value.count }),
           top.value.count >= 2 {
            let name = top.key == Distractor.internalRestlessness ? "internal restlessness" : top.key
            return ManualItem(
                sectionTitle: "WHAT BREAKS MY ATTENTION",
                statement: "In your own session reports, \(name) came up most often as the first thing that pulled you away.",
                maturity: top.value.count >= 4 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(top.value.count) self-reported first distractions",
                observationCount: top.value.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "WHAT BREAKS MY ATTENTION",
            statement: "Still learning what breaks your attention most. Keep answering the two honest questions after each session.",
            maturity: .learning,
            evidenceSource: sessions.isEmpty ? "No sessions yet" : "No repeated breaker in \(sessions.count) sessions",
            observationCount: events.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 3. How I Return

    private static func deriveMyReturnStrategy(sessions: [SessionRecord], events: [InterruptionEvent], profile: AttentionProfile) -> ManualItem {
        let switchedAndCompleted = sessions.filter { ($0.switches ?? 0) >= 1 && $0.completed && !$0.endedEarly }
        let switchedTotal = sessions.filter { ($0.switches ?? 0) >= 1 }

        // Returning after switching and still finishing is real evidence.
        if switchedTotal.count >= 4, switchedAndCompleted.count >= switchedTotal.count / 2 {
            return ManualItem(
                sectionTitle: "HOW I RETURN",
                statement: "When you notice a switch, you usually come back to the same task and finish the block. Switching has not been failing you.",
                maturity: switchedAndCompleted.count >= 6 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(switchedAndCompleted.count) of \(switchedTotal.count) sessions finished after reported switches",
                observationCount: switchedTotal.count,
                lastUpdated: Date()
            )
        }

        if let level = profile.returnAfterDistraction.value, level == .weak, sessions.count >= 2 {
            return ManualItem(
                sectionTitle: "HOW I RETURN",
                statement: "Returning after distraction looks like your hardest skill right now. Sessions practice the return itself — noticing, then coming back to the same task.",
                maturity: .learning,
                evidenceSource: "Your starting-point answer, not yet re-tested by many sessions",
                observationCount: switchedTotal.count,
                lastUpdated: Date()
            )
        }

        if switchedTotal.isEmpty, !sessions.isEmpty {
            return ManualItem(
                sectionTitle: "HOW I RETURN",
                statement: "Few switches reported so far — either attention holds well, or switches go unnoticed. Both are worth watching.",
                maturity: .learning,
                evidenceSource: "\(sessions.count) sessions, none with a reported switch",
                observationCount: sessions.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "HOW I RETURN",
            statement: "Still learning how you return. More sessions with reported switches will make this concrete.",
            maturity: .learning,
            evidenceSource: "\(switchedTotal.count) sessions with reported switches",
            observationCount: switchedTotal.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 4. My Focus Window

    private static func deriveMyFocusWindow(sessions: [SessionRecord], profile: AttentionProfile) -> ManualItem {
        let completed = sessions.filter(\.completed)
        guard completed.count >= 3 else {
            let prior = profile.focusWindowMinutes.map { "\($0) minutes (from your starting point)" } ?? "unknown"
            return ManualItem(
                sectionTitle: "MY FOCUS WINDOW",
                statement: "Your focus window looks like \(prior). REBOOT is measuring the real window across completed blocks.",
                maturity: .learning,
                evidenceSource: "Starting-point answer; \(completed.count) completed sessions so far",
                observationCount: completed.count,
                lastUpdated: Date()
            )
        }

        let actuals = completed.map(\.actualMinutes).sorted()
        let median = actuals[actuals.count / 2]
        let best = actuals.max() ?? median

        return ManualItem(
            sectionTitle: "MY FOCUS WINDOW",
            statement: "A typical completed block lasts about \(median) minutes; your longest so far is \(best). Durations grow only when several comparable sessions support it.",
            maturity: completed.count >= 10 ? .repeatedSignal : .emergingSignal,
            evidenceSource: "\(completed.count) completed focus blocks",
            observationCount: completed.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 5. My Digital Environment

    private static func deriveMyDigitalEnvironment(digitalState: DigitalEnvironmentState, events: [InterruptionEvent]) -> ManualItem {
        let prox = digitalState.profile.phoneProximity
        if prox.isKnown && prox.value != .unknown && prox.evidenceCount >= 3 {
            let placement = prox.value == .outsideRoom
                ? "outside the room"
                : prox.value.displayName.lowercased()
            return ManualItem(
                sectionTitle: "MY DIGITAL ENVIRONMENT",
                statement: "Your phone is most often \(placement) during focused work, based on what your sessions recorded.",
                maturity: prox.evidenceCount >= 6 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(prox.evidenceCount) placement observations",
                observationCount: prox.evidenceCount,
                lastUpdated: Date()
            )
        }

        if let accepted = optionalAcceptedInterventions(digitalState), accepted > 0 {
            return ManualItem(
                sectionTitle: "MY DIGITAL ENVIRONMENT",
                statement: "Environment setups have been confirmed before \(accepted) focused block\(accepted == 1 ? "" : "s").",
                maturity: accepted >= 3 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "Confirmed environment actions across sessions",
                observationCount: accepted,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY DIGITAL ENVIRONMENT",
            statement: "Still learning how your physical and digital setup affects sessions. A few comparable sessions will tell.",
            maturity: .learning,
            evidenceSource: "Not enough placement or protection observations yet",
            observationCount: events.count,
            lastUpdated: Date()
        )
    }

    private static func optionalAcceptedInterventions(_ state: DigitalEnvironmentState) -> Int? {
        let total = state.interventionLog.acceptedCounts.values.reduce(0, +)
        return total > 0 ? total : nil
    }

    // MARK: - 6. How I Work Deeply

    private static func deriveMyDeepWorkConditions(sessions: [SessionRecord], flowState: FlowState, rules: [PersonalRule]) -> ManualItem {
        // Flow conditions are the honest source for deep-work knowledge.
        let patterns = FlowConditionEngine.evaluate(state: flowState)
        if let top = patterns.first(where: { !$0.supportingEvidenceIDs.isEmpty }) {
            return ManualItem(
                sectionTitle: "HOW I WORK DEEPLY",
                statement: top.statement,
                maturity: top.supportingEvidenceIDs.count >= 3 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(top.supportingEvidenceIDs.count) Flow block reflections agree",
                observationCount: top.supportingEvidenceIDs.count,
                lastUpdated: Date()
            )
        }

        if let project = flowState.projects.first(where: { $0.status == .active }), project.recentBlockIDs.count >= 2 {
            return ManualItem(
                sectionTitle: "HOW I WORK DEEPLY",
                statement: "Deep work sustains best so far on single-project blocks with a defined finish line — \"\(project.title)\" has carried your longest stretches.",
                maturity: .emergingSignal,
                evidenceSource: "\(project.recentBlockIDs.count) Flow blocks on this project",
                observationCount: project.recentBlockIDs.count,
                lastUpdated: Date()
            )
        }

        let longCompleted = sessions.filter { $0.completed && $0.actualMinutes >= 20 && $0.origin != .flow }
        if longCompleted.count >= 3 {
            return ManualItem(
                sectionTitle: "HOW I WORK DEEPLY",
                statement: "Your deepest blocks share one pattern: one task, one visible stopping point. That is the only deep-work condition your sessions have confirmed so far.",
                maturity: longCompleted.count >= 6 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(longCompleted.count) longer completed blocks",
                observationCount: longCompleted.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "HOW I WORK DEEPLY",
            statement: "Still learning your deeper-work conditions. Real projects and longer blocks will surface them.",
            maturity: .learning,
            evidenceSource: "No repeated deep-work condition in \(sessions.count) sessions",
            observationCount: longCompleted.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 7. My Recall Strategy

    private static func deriveMyRecallStrategy(sessions: [SessionRecord]) -> ManualItem {
        let recall = sessions.filter { $0.mode == .recall }
        let assessments = recall.compactMap { $0.evidence?.recall?.selfAssessment }

        guard !recall.isEmpty else {
            return ManualItem(
                sectionTitle: "MY RECALL STRATEGY",
                statement: "No recall practice recorded yet. When the program prescribes it, read, close the source, and reconstruct what remains.",
                maturity: .learning,
                evidenceSource: "Zero recall sessions logged",
                observationCount: 0,
                lastUpdated: Date()
            )
        }

        let someOrMost = assessments.filter { $0 == .some || $0 == .most }.count
        if assessments.count >= 3 {
            let ratioText = "\(someOrMost) of \(assessments.count)"
            return ManualItem(
                sectionTitle: "MY RECALL STRATEGY",
                statement: "In \(ratioText) recall sessions, at least some material came back without the source. Closing the source earlier tends to sharpen what returns.",
                maturity: assessments.count >= 5 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(assessments.count) honest self-assessments",
                observationCount: assessments.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY RECALL STRATEGY",
            statement: "Recall practice has started (\(recall.count) session\(recall.count == 1 ? "" : "s")). Not enough assessments yet to say what works for you.",
            maturity: .learning,
            evidenceSource: "\(assessments.count) self-assessments so far",
            observationCount: recall.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 8. My Energy Context

    private static func deriveMyEnergyAndContext(sessions: [SessionRecord], fuelState: FuelState) -> ManualItem {
        let fuelSessions = sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
        guard !fuelSessions.isEmpty else {
            return ManualItem(
                sectionTitle: "MY ENERGY CONTEXT",
                statement: "Energy may matter here. There isn't enough evidence yet — Fuel asks one optional question before some sessions.",
                maturity: .learning,
                evidenceSource: "No session carries context yet",
                observationCount: 0,
                lastUpdated: Date()
            )
        }

        let analysis = FuelPatternEngine.evaluate(sessions: fuelSessions)
        if let pattern = analysis.patterns.first {
            return ManualItem(
                sectionTitle: "MY ENERGY CONTEXT",
                statement: pattern.statement,
                maturity: pattern.maturity == .repeatedSignal ? .repeatedSignal : .emergingSignal,
                evidenceSource: "Pattern across \(fuelSessions.count) context-linked sessions",
                observationCount: fuelSessions.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY ENERGY CONTEXT",
            statement: "Context has been captured \(fuelSessions.count) times, but no stable pattern has emerged — that is an honest result, not a failure.",
            maturity: .learning,
            evidenceSource: "\(fuelSessions.count) captures, no consistent signal",
            observationCount: fuelSessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 9. My Flow Conditions

    private static func deriveMyFlowConditions(flowState: FlowState, sessions: [SessionRecord]) -> ManualItem {
        let evidence = flowState.evidence
        guard evidence.count >= 3 else {
            return ManualItem(
                sectionTitle: "MY FLOW CONDITIONS",
                statement: "Still learning which conditions support your deeper work. Flow Lab reads each real block's reflection to find them.",
                maturity: .learning,
                evidenceSource: evidence.isEmpty
                    ? "No Flow blocks reflected on yet"
                    : "Only \(evidence.count) Flow reflections so far",
                observationCount: evidence.count,
                lastUpdated: Date()
            )
        }

        let patterns = FlowConditionEngine.evaluate(state: flowState)
        if let top = patterns.first(where: { !$0.supportingEvidenceIDs.isEmpty }) {
            return ManualItem(
                sectionTitle: "MY FLOW CONDITIONS",
                statement: top.statement,
                maturity: top.supportingEvidenceIDs.count >= 3 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(top.supportingEvidenceIDs.count) supporting Flow reflections",
                observationCount: evidence.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY FLOW CONDITIONS",
            statement: "\(evidence.count) Flow blocks reflected on, no consistent condition yet. Mixed results are still results.",
            maturity: .mixed,
            evidenceSource: "\(evidence.count) reflections, contradictory signals",
            observationCount: evidence.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 10. My Personal Rules

    private static func deriveMyPersonalRules(rules: [PersonalRule]) -> [ManualItem] {
        rules
            .filter { $0.lifecycle == .kept }
            .map { rule in
                ManualItem(
                    sectionTitle: "PERSONAL RULE · \(rule.category.rawValue.uppercased())",
                    statement: "\(rule.title) — \(rule.detail)",
                    maturity: rule.confidence == .strong || rule.timesTested >= 3 ? .repeatedSignal : .emergingSignal,
                    evidenceSource: rule.sourceType.displayLabel,
                    observationCount: rule.timesTested > 0 ? rule.timesTested : nil,
                    lastUpdated: Date()
                )
            }
    }

    // MARK: - 11. What REBOOT Still Doesn't Know

    private static func deriveWhatRebootStillDoesNotKnow(
        sessions: [SessionRecord],
        fuelState: FuelState,
        flowState: FlowState,
        digitalState: DigitalEnvironmentState,
        experiments: [PersonalExperiment]
    ) -> [ManualItem] {
        var unknowns: [ManualItem] = []

        let fuelLinked = sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
        if fuelLinked.count < 10 {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT I STILL DON'T KNOW",
                statement: "How sleep, meals and movement shape your focus across consecutive days.",
                maturity: .learning,
                evidenceSource: fuelLinked.isEmpty
                    ? "No context-linked sessions yet"
                    : "Only \(fuelLinked.count) context-linked sessions",
                observationCount: fuelLinked.count,
                lastUpdated: Date()
            ))
        }

        if experiments.filter({ $0.result != nil }).count < 3 {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT I STILL DON'T KNOW",
                statement: "Which environment change actually helps most — distance, protection, or a cleared desk. Personal Lab resolves it one comparison at a time.",
                maturity: .learning,
                evidenceSource: "\(experiments.filter { $0.result != nil }.count) completed comparisons",
                observationCount: experiments.count,
                lastUpdated: Date()
            ))
        }

        if flowState.evidence.count < 3 {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT I STILL DON'T KNOW",
                statement: "The conditions that hold your deepest work — challenge, feedback, duration, sound.",
                maturity: .learning,
                evidenceSource: flowState.evidence.isEmpty
                    ? "No Flow reflections yet"
                    : "Only \(flowState.evidence.count) Flow reflections",
                observationCount: flowState.evidence.count,
                lastUpdated: Date()
            ))
        }

        if digitalState.profile.primaryDigitalPull.value == nil
            || digitalState.profile.primaryDigitalPull.value == .unknown {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT I STILL DON'T KNOW",
                statement: "Whether external pulls or internal restlessness actually breaks attention more often.",
                maturity: .learning,
                evidenceSource: "Digital pull not yet isolated from session evidence",
                observationCount: digitalState.interruptionEvents.count,
                lastUpdated: Date()
            ))
        }

        if unknowns.isEmpty {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT I STILL DON'T KNOW",
                statement: "How these patterns hold over months, seasons and changing workloads. The manual keeps learning after Day 90.",
                maturity: .learning,
                evidenceSource: "Longer horizons need longer observation",
                observationCount: nil,
                lastUpdated: Date()
            ))
        }

        return unknowns
    }
}
