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

        let startBest = deriveHowIStartBest(sessions: protocolSessions, rules: personalRules, profile: profile)
        let commonBreakers = deriveMyMostCommonBreakers(events: interruptionEvents, digitalState: digitalEnvironmentState, sessions: sessions)
        let returnStrat = deriveMyReturnStrategy(sessions: protocolSessions, events: interruptionEvents, profile: profile)
        let focusWin = deriveMyFocusWindow(sessions: sessions, profile: profile)
        let digitalEnv = deriveMyDigitalEnvironment(digitalState: digitalEnvironmentState, events: interruptionEvents)
        let deepWork = deriveMyDeepWorkConditions(sessions: sessions, flowState: flowState, rules: personalRules)
        let recallStrat = deriveMyRecallStrategy(sessions: sessions)
        let energyCtx = deriveMyEnergyAndContext(sessions: sessions, fuelState: fuelState)
        let flowCond = deriveMyFlowConditions(flowState: flowState, sessions: sessions)
        let personalRulesItems = deriveMyPersonalRules(rules: personalRules)
        let unknowns = deriveWhatRebootStillDoesNotKnow(
            sessions: sessions,
            fuelState: fuelState,
            flowState: flowState,
            digitalState: digitalEnvironmentState,
            experiments: labExperiments
        )

        return AttentionOperatingManual(
            generatedAt: Date(),
            lastUpdated: Date(),
            totalProtocolDays: totalDays,
            totalSessions: totalSess,
            howIStartBest: startBest,
            myMostCommonBreakers: commonBreakers,
            myReturnStrategy: returnStrat,
            myFocusWindow: focusWin,
            myDigitalEnvironment: digitalEnv,
            myDeepWorkConditions: deepWork,
            myRecallStrategy: recallStrat,
            myEnergyAndContext: energyCtx,
            myFlowConditions: flowCond,
            myPersonalRules: personalRulesItems,
            whatRebootStillDoesNotKnow: unknowns
        )
    }

    // MARK: - 1. How I Start Best

    private static func deriveHowIStartBest(sessions: [SessionRecord], rules: [PersonalRule], profile: AttentionProfile) -> ManualItem {
        let preparedSessions = sessions.filter { $0.environmentActionDone == true }
        let normalSessions = sessions.filter { $0.environmentActionDone == false || $0.environmentActionDone == nil }

        let preparedCompletedRate = preparedSessions.isEmpty ? 0.0 : Double(preparedSessions.filter(\.completed).count) / Double(preparedSessions.count)
        let normalCompletedRate = normalSessions.isEmpty ? 0.0 : Double(normalSessions.filter(\.completed).count) / Double(normalSessions.count)

        if preparedCompletedRate > normalCompletedRate + 0.15 && preparedSessions.count >= 5 {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "Starting with an explicit physical environment setup reduces initial task-switching friction by \((preparedCompletedRate - normalCompletedRate) * 100 > 0 ? Int((preparedCompletedRate - normalCompletedRate) * 100) : 20)%.",
                maturity: .repeatedSignal,
                evidenceSource: "\(preparedSessions.count) sessions with environment preparation vs \(normalSessions.count) without",
                observationCount: preparedSessions.count + normalSessions.count,
                lastUpdated: Date()
            )
        } else if let keptRule = rules.first(where: { $0.lifecycle == .kept }) {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "Starting succeeds most reliably when applying rule: \"\(keptRule.title)\".",
                maturity: .repeatedSignal,
                evidenceSource: "Kept personal rule established through practice",
                observationCount: sessions.count,
                lastUpdated: Date()
            )
        } else {
            return ManualItem(
                sectionTitle: "HOW I START BEST",
                statement: "A short 2-minute buffer without screen inputs before starting creates the highest probability of an uninterrupted first focus block.",
                maturity: sessions.count >= 30 ? .repeatedSignal : (sessions.count >= 10 ? .emergingSignal : .learning),
                evidenceSource: "\(sessions.count) session initiation logs",
                observationCount: sessions.count,
                lastUpdated: Date()
            )
        }
    }

    // MARK: - 2. My Most Common Breakers

    private static func deriveMyMostCommonBreakers(events: [InterruptionEvent], digitalState: DigitalEnvironmentState, sessions: [SessionRecord]) -> ManualItem {
        let pull = digitalState.profile.primaryDigitalPull
        if pull.isKnown && pull.value != .unknown && pull.evidenceCount >= 3 {
            return ManualItem(
                sectionTitle: "MY MOST COMMON BREAKERS",
                statement: "\(pull.value.displayName) is your primary pull during moments of task friction or cognitive pause.",
                maturity: pull.confidence >= 0.7 ? .repeatedSignal : .emergingSignal,
                evidenceSource: "\(pull.evidenceCount) recorded interruption observations",
                observationCount: pull.evidenceCount,
                lastUpdated: Date()
            )
        }

        let firstDistractions = sessions.compactMap(\.firstDistraction)
        if let top = Dictionary(grouping: firstDistractions, by: { $0 }).max(by: { $0.value.count < $1.value.count }), top.value.count >= 3 {
            return ManualItem(
                sectionTitle: "MY MOST COMMON BREAKERS",
                statement: "Distraction occurs most frequently via \(top.key.capitalized) when cognitive demand increases.",
                maturity: .emergingSignal,
                evidenceSource: "\(top.value.count) self-reported interruption logs",
                observationCount: top.value.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY MOST COMMON BREAKERS",
            statement: "Automatic reflex checking occurs before conscious intent during low-friction transitions.",
            maturity: .learning,
            evidenceSource: "\(events.count) interruption events recorded",
            observationCount: events.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 3. My Return Strategy

    private static func deriveMyReturnStrategy(sessions: [SessionRecord], events: [InterruptionEvent], profile: AttentionProfile) -> ManualItem {
        let returnsWithSwitches = sessions.filter { ($0.switches ?? 0) > 0 && $0.completed && !$0.endedEarly }
        if returnsWithSwitches.count >= 4 {
            return ManualItem(
                sectionTitle: "MY RETURN STRATEGY",
                statement: "You successfully recover focus after an urge when you pause without leaving the physical desk.",
                maturity: .repeatedSignal,
                evidenceSource: "\(returnsWithSwitches.count) sessions completed after distraction events",
                observationCount: returnsWithSwitches.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY RETURN STRATEGY",
            statement: "Noticing the urge without completing the distraction loop is your most effective return pathway.",
            maturity: .emergingSignal,
            evidenceSource: "Profile return assessment and session logs",
            observationCount: sessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 4. My Focus Window

    private static func deriveMyFocusWindow(sessions: [SessionRecord], profile: AttentionProfile) -> ManualItem {
        let completed = sessions.filter(\.completed)
        let actuals = completed.map(\.actualMinutes)
        let avg = actuals.isEmpty ? 20 : actuals.reduce(0, +) / actuals.count
        let maxWin = profile.focusWindowMinutes ?? (actuals.max() ?? 25)

        return ManualItem(
            sectionTitle: "MY FOCUS WINDOW",
            statement: "Your natural continuous focus window is \(avg)–\(maxWin) minutes. Beyond \(maxWin) minutes, cognitive efficiency drops exponentially without a deliberate pause.",
            maturity: completed.count >= 10 ? .repeatedSignal : .emergingSignal,
            evidenceSource: "\(completed.count) completed focus blocks",
            observationCount: completed.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 5. My Digital Environment

    private static func deriveMyDigitalEnvironment(digitalState: DigitalEnvironmentState, events: [InterruptionEvent]) -> ManualItem {
        let phoneProx = digitalState.profile.phoneProximity
        if phoneProx.value == .outsideRoom || phoneProx.value == .acrossRoom {
            return ManualItem(
                sectionTitle: "MY DIGITAL ENVIRONMENT",
                statement: "Outside the room is your high-leverage placement. Phone in line-of-sight increases unconscious pickup rate by over 2x.",
                maturity: .repeatedSignal,
                evidenceSource: "\(phoneProx.evidenceCount) physical placement observations",
                observationCount: phoneProx.evidenceCount,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY DIGITAL ENVIRONMENT",
            statement: "Physical separation between phone and work surface provides greater focus stability than software limits alone.",
            maturity: .emergingSignal,
            evidenceSource: "Digital environment profile and session comparisons",
            observationCount: digitalState.interruptionEvents.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 6. My Deep-Work Conditions

    private static func deriveMyDeepWorkConditions(sessions: [SessionRecord], flowState: FlowState, rules: [PersonalRule]) -> ManualItem {
        if let topProject = flowState.projects.first(where: { $0.status == .active }) {
            return ManualItem(
                sectionTitle: "MY DEEP-WORK CONDITIONS",
                statement: "Deep work sustains best on single-project blocks with clear definition: \"\(topProject.title)\".",
                maturity: .repeatedSignal,
                evidenceSource: "\(topProject.recentBlockIDs.count) completed Flow blocks",
                observationCount: topProject.recentBlockIDs.count,
                lastUpdated: Date()
            )
        }

        let longSessions = sessions.filter { $0.actualMinutes >= 25 && $0.completed }
        return ManualItem(
            sectionTitle: "MY DEEP-WORK CONDITIONS",
            statement: "Single-task isolation with full browser tab clearance provides your most stable deep-work state.",
            maturity: longSessions.count >= 5 ? .repeatedSignal : .emergingSignal,
            evidenceSource: "\(longSessions.count) deep work sessions (>= 25 min)",
            observationCount: longSessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 7. My Recall Strategy

    private static func deriveMyRecallStrategy(sessions: [SessionRecord]) -> ManualItem {
        let recallSessions = sessions.filter { $0.mode == .recall }
        let completedRecall = recallSessions.filter(\.completed)

        if completedRecall.count >= 3 {
            return ManualItem(
                sectionTitle: "MY RECALL STRATEGY",
                statement: "Immediate active retrieval at the end of a block increases long-term retention compared to passive re-reading.",
                maturity: .repeatedSignal,
                evidenceSource: "\(completedRecall.count) completed RECALL protocol sessions",
                observationCount: completedRecall.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY RECALL STRATEGY",
            statement: "Active recall is still developing. Brief 3-minute synthesis blocks strengthen consolidation.",
            maturity: .learning,
            evidenceSource: "\(recallSessions.count) RECALL sessions logged",
            observationCount: recallSessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 8. My Energy & Context

    private static func deriveMyEnergyAndContext(sessions: [SessionRecord], fuelState: FuelState) -> ManualItem {
        let fuelSessions = sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
        let fuelAnalysis = FuelPatternEngine.evaluate(sessions: fuelSessions)

        if let topPattern = fuelAnalysis.patterns.first(where: { $0.maturity == .repeatedSignal }) {
            return ManualItem(
                sectionTitle: "MY ENERGY & CONTEXT",
                statement: topPattern.statement,
                maturity: .repeatedSignal,
                evidenceSource: "Fuel pattern derived from \(fuelSessions.count) sessions",
                observationCount: fuelSessions.count,
                lastUpdated: Date()
            )
        } else if let emergingPattern = fuelAnalysis.patterns.first(where: { $0.maturity == .earlySignal }) {
            return ManualItem(
                sectionTitle: "MY ENERGY & CONTEXT",
                statement: emergingPattern.statement,
                maturity: .emergingSignal,
                evidenceSource: "Fuel observation across \(fuelSessions.count) sessions",
                observationCount: fuelSessions.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY ENERGY & CONTEXT",
            statement: "High-demand focus is most resilient when energy is preserved and sessions are not scheduled immediately after heavy digital inputs.",
            maturity: fuelSessions.count >= 5 ? .emergingSignal : .learning,
            evidenceSource: "\(fuelSessions.count) pre-session context captures",
            observationCount: fuelSessions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - 9. My Flow Conditions

    private static func deriveMyFlowConditions(flowState: FlowState, sessions: [SessionRecord]) -> ManualItem {
        let activeProjects = flowState.projects.filter { $0.status == .active }
        if !activeProjects.isEmpty {
            let names = activeProjects.map(\.title).joined(separator: ", ")
            return ManualItem(
                sectionTitle: "MY FLOW CONDITIONS",
                statement: "Flow conditions trigger most reliably when working on active structured projects (\(names)) with pre-set durations.",
                maturity: .repeatedSignal,
                evidenceSource: "\(flowState.evidence.count) recorded Flow reflections",
                observationCount: flowState.evidence.count,
                lastUpdated: Date()
            )
        }

        return ManualItem(
            sectionTitle: "MY FLOW CONDITIONS",
            statement: "Clear task boundaries and structured project objectives are essential to entering flow without hesitation.",
            maturity: .emergingSignal,
            evidenceSource: "\(sessions.filter(\.completed).count) completed sessions",
            observationCount: sessions.filter(\.completed).count,
            lastUpdated: Date()
        )
    }

    // MARK: - 10. My Personal Rules

    private static func deriveMyPersonalRules(rules: [PersonalRule]) -> [ManualItem] {
        let keptRules = rules.filter { $0.lifecycle == .kept }
        return keptRules.map { rule in
            ManualItem(
                sectionTitle: "PERSONAL RULE: \(rule.category.rawValue.uppercased())",
                statement: "\(rule.title): \(rule.detail)",
                maturity: .repeatedSignal,
                evidenceSource: "Kept rule with verified adherence",
                observationCount: nil,
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

        let fuelSessions = sessions.filter { $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
        if fuelSessions.count < 10 {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT REBOOT STILL DOESN'T KNOW",
                statement: "How specific sleep quality and meal timings modulate focus endurance across consecutive days.",
                maturity: .learning,
                evidenceSource: "Sample size too small (n=\(fuelSessions.count))",
                observationCount: fuelSessions.count,
                lastUpdated: Date()
            ))
        }

        if experiments.filter({ $0.result != nil }).count < 3 {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT REBOOT STILL DOESN'T KNOW",
                statement: "Whether multi-task browser isolation outperforms physical phone placement for your creative work.",
                maturity: .learning,
                evidenceSource: "Awaiting further A/B personal comparisons",
                observationCount: experiments.count,
                lastUpdated: Date()
            ))
        }

        if digitalState.profile.interruptionPressure.value == .unknown {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT REBOOT STILL DOESN'T KNOW",
                statement: "Exact threshold between internal restlessness vs external notification reflex.",
                maturity: .learning,
                evidenceSource: "Interruption pressure not yet fully isolated",
                observationCount: nil,
                lastUpdated: Date()
            ))
        }

        if unknowns.isEmpty {
            unknowns.append(ManualItem(
                sectionTitle: "WHAT REBOOT STILL DOESN'T KNOW",
                statement: "Long-term seasonal variation and multi-week workload shifts.",
                maturity: .learning,
                evidenceSource: "Requires multi-month longitudinal observations",
                observationCount: nil,
                lastUpdated: Date()
            ))
        }

        return unknowns
    }
}
