import Foundation

enum DailyGuidanceEngine {

    static func generateGuidance(
        day: Int,
        programStatus: ProgramStatus,
        programPhase: ProgramPhase,
        profile: AttentionProfile,
        sessions: [SessionRecord],
        personalRules: [PersonalRule],
        labExperiments: [PersonalExperiment],
        fuelState: FuelState,
        flowState: FlowState,
        digitalEnvironmentState: DigitalEnvironmentState,
        screenTimeActive: Bool,
        screenTimeAuthorized: Bool,
        isRecovery: Bool,
        guidanceHistory: [GuidanceDecision],
        ownModeState: OwnModeState
    ) -> DailyGuidance {
        let basePrescription = PrescriptionEngine.prescription(
            profile: profile,
            sessions: sessions.filter { $0.origin == .protocol },
            day: day,
            reviews: []
        )

        // 1. Day 1 Natural Baseline
        if day == 1 && !sessions.contains(where: { $0.day == 1 && $0.completed }) {
            let envAct: EnvironmentAction? = nil
            let fuelPr: FuelSamplePrompt? = nil
            let flowOp: FlowOpportunity? = nil
            let expID: UUID? = nil
            return DailyGuidance(
                bottleneck: .starting,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .standardProtocolSession,
                    title: "Observe your natural focus",
                    subtitle: "10 MIN · OBSERVE",
                    targetMinutes: 10,
                    mode: .observe,
                    ctaTitle: "Start Baseline (10 min)"
                ),
                supportingAction: nil,
                sessionPrescription: basePrescription,
                environmentAction: envAct,
                fuelPrompt: fuelPr,
                flowOpportunity: flowOp,
                experimentOpportunityID: expID,
                explanation: "Day 1 establishes your natural baseline without changing your environment or habits.",
                confidence: 1.0,
                evidenceIDs: [],
                suppressedOpportunities: ["Fuel Prompt", "Personal Lab", "Flow Block", "Environment Intervention"],
                generatedAt: Date(),
                isOwnMode: false,
                noInterventionNeeded: false
            )
        }

        // 2. Recovery Priority
        if isRecovery {
            var recoveryPrescription = basePrescription
            recoveryPrescription.mode = .nothing
            recoveryPrescription.minutes = 5
            let envAct: EnvironmentAction? = nil
            let fuelPr: FuelSamplePrompt? = nil
            let flowOp: FlowOpportunity? = nil
            let expID: UUID? = nil
            return DailyGuidance(
                bottleneck: .recovery,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .recoverySession,
                    title: "Protected Reset",
                    subtitle: "5 MIN · NOTHING",
                    targetMinutes: 5,
                    mode: .nothing,
                    ctaTitle: "Begin Reset (5 min)"
                ),
                supportingAction: nil,
                sessionPrescription: recoveryPrescription,
                environmentAction: envAct,
                fuelPrompt: fuelPr,
                flowOpportunity: flowOp,
                experimentOpportunityID: expID,
                explanation: "Focus showed friction recently. A short reset restores attention without fatigue.",
                confidence: 0.95,
                evidenceIDs: [],
                suppressedOpportunities: ["Flow Block", "Personal Lab", "Fuel Prompt"],
                generatedAt: Date(),
                isOwnMode: false,
                noInterventionNeeded: false
            )
        }

        // 3. Post-90 Own Mode
        if programStatus == .completed || day > 90 || ownModeState.active {
            let duration = ownModeState.preferredDurations.first ?? 25
            let envAct: EnvironmentAction? = nil
            let fuelPr: FuelSamplePrompt? = nil
            let flowOp: FlowOpportunity? = nil
            let expID: UUID? = nil
            return DailyGuidance(
                bottleneck: .independence,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .ownModeSession,
                    title: "Self-Directed Focus",
                    subtitle: "\(duration) MIN · STAY",
                    targetMinutes: duration,
                    mode: .stay,
                    ctaTitle: "Start Focus (\(duration) min)"
                ),
                supportingAction: DailyGuidanceSecondaryAction(
                    title: "Review Operating Manual",
                    actionType: "manual",
                    identifier: nil
                ),
                sessionPrescription: basePrescription,
                environmentAction: envAct,
                fuelPrompt: fuelPr,
                flowOpportunity: flowOp,
                experimentOpportunityID: expID,
                explanation: "You own your attention system now. REBOOT supports your practice without imposing a curriculum.",
                confidence: 1.0,
                evidenceIDs: [],
                suppressedOpportunities: [],
                generatedAt: Date(),
                isOwnMode: true,
                noInterventionNeeded: true
            )
        }

        // 4. Bottleneck Detection with Anti-Oscillation Hysteresis
        let bottleneck = selectBottleneck(
            sessions: sessions,
            profile: profile,
            digitalEnvironment: digitalEnvironmentState,
            fuelState: fuelState,
            flowState: flowState,
            labExperiments: labExperiments,
            history: guidanceHistory,
            currentDay: day
        )

        // Environment action selection (Kept rules > Friction ladder)
        let envAction = resolveEnvironmentAction(
            bottleneck: bottleneck,
            personalRules: personalRules,
            digitalEnvironment: digitalEnvironmentState,
            screenTimeActive: screenTimeActive,
            screenTimeAuthorized: screenTimeAuthorized,
            basePrescription: basePrescription
        )

        // Fuel sampling (Suppressed if Flow project block is active to avoid overload)
        var fuelPrompt: FuelSamplePrompt? = nil
        var suppressed: [String] = []

        let activeFlowProject = flowState.projects.first(where: { $0.status == .active })
        let canDoFlow = activeFlowProject != nil && (bottleneck == .flowConditions || bottleneck == .depth)

        if canDoFlow {
            suppressed.append("Fuel Prompt (suppressed by active Flow block)")
        } else {
            fuelPrompt = ContextSamplingEngine.recommendPrompt(.init(
                programDay: day,
                completedProtocolDays: sessions.filter { $0.origin == .protocol && $0.completed }.count,
                phase: programPhase.id,
                isRecoveryPrescribed: false,
                promptsEnabled: fuelState.promptsEnabled,
                activeFuelConditionTest: false,
                preferredField: nil,
                pendingCapture: nil,
                log: fuelState.sampling
            ))
        }

        // Action Kind and Primary CTA
        let targetMinutes: Int
        if bottleneck == .energyContext {
            // Energy is low: modulate target duration down
            targetMinutes = min(15, basePrescription.minutes)
        } else {
            targetMinutes = basePrescription.minutes
        }

        let primaryKind: GuidancePrimaryActionKind
        let title: String
        let subtitle: String
        let ctaTitle: String
        var flowOpportunity: FlowOpportunity? = nil

        if canDoFlow, let proj = activeFlowProject {
            primaryKind = .projectFlowBlock
            title = "Flow Block: \(proj.title)"
            subtitle = "\(targetMinutes) MIN · STAY"
            ctaTitle = "Start Project Block (\(targetMinutes) min)"
            flowOpportunity = FlowOpportunity(
                projectID: proj.id,
                projectTitle: proj.title,
                recommendedMinutes: targetMinutes,
                whyNow: "Optimal conditions for sustained build work."
            )
        } else {
            primaryKind = .standardProtocolSession
            title = basePrescription.goal.isEmpty ? "Stay with one demanding task" : basePrescription.goal
            subtitle = "\(targetMinutes) MIN · \(basePrescription.mode.display.uppercased())"
            ctaTitle = "Start (\(targetMinutes) min)"
        }

        // Supporting action (at most one)
        var supportingAction: DailyGuidanceSecondaryAction? = nil
        if primaryKind != .projectFlowBlock && activeFlowProject != nil {
            supportingAction = DailyGuidanceSecondaryAction(
                title: "Use real project: \(activeFlowProject!.title)",
                actionType: "flow",
                identifier: activeFlowProject!.id.uuidString
            )
        } else if let activeExp = labExperiments.first(where: { $0.status == .active }) {
            supportingAction = DailyGuidanceSecondaryAction(
                title: "Test variable: \(activeExp.testArm.condition.title)",
                actionType: "experiment",
                identifier: activeExp.id.uuidString
            )
        }

        let explanation = generateExplanation(
            bottleneck: bottleneck,
            primaryKind: primaryKind,
            targetMinutes: targetMinutes,
            envAction: envAction
        )

        let expID = labExperiments.first(where: { $0.status == .active })?.id

        return DailyGuidance(
            bottleneck: bottleneck,
            primaryAction: DailyGuidancePrimaryAction(
                kind: primaryKind,
                title: title,
                subtitle: subtitle,
                targetMinutes: targetMinutes,
                mode: basePrescription.mode,
                ctaTitle: ctaTitle
            ),
            supportingAction: supportingAction,
            sessionPrescription: basePrescription,
            environmentAction: envAction,
            fuelPrompt: fuelPrompt,
            flowOpportunity: flowOpportunity,
            experimentOpportunityID: expID,
            explanation: explanation,
            confidence: 0.88,
            evidenceIDs: [],
            suppressedOpportunities: suppressed,
            generatedAt: Date(),
            isOwnMode: false,
            noInterventionNeeded: false
        )
    }

    // MARK: - Bottleneck Selection

    private static func selectBottleneck(
        sessions: [SessionRecord],
        profile: AttentionProfile,
        digitalEnvironment: DigitalEnvironmentState,
        fuelState: FuelState,
        flowState: FlowState,
        labExperiments: [PersonalExperiment],
        history: [GuidanceDecision],
        currentDay: Int
    ) -> AttentionBottleneck {
        // Check recent history for anti-oscillation
        let lastBottleneck = history.last?.bottleneck

        // 1. Digital Pull
        if digitalEnvironment.profile.primaryDigitalPull.isKnown &&
           digitalEnvironment.profile.primaryDigitalPull.value != .unknown &&
           digitalEnvironment.profile.primaryDigitalPull.confidence >= 0.6 {
            return .digitalPull
        }

        // 2. Flow Readiness
        if flowState.projects.contains(where: { $0.status == .active && $0.recentBlockIDs.count >= 2 }) {
            return .flowConditions
        }

        // 3. Energy Context
        let recentEnergy = fuelState.pendingCapture?.energy ?? sessions.last?.fuelContext?.energy
        if recentEnergy == .low {
            return .energyContext
        }

        // 4. Lab Experiment
        if labExperiments.contains(where: { $0.status == .active }) {
            return .uncertaintyExperiment
        }

        // 5. Recall
        let recentProtocols = sessions.filter { $0.origin == .protocol }
        if recentProtocols.count >= 4 && recentProtocols.suffix(3).allSatisfy({ $0.mode == .stay && $0.completed }) {
            return .recall
        }

        // 6. Stability with anti-oscillation
        if let lastBottleneck, lastBottleneck == .stability {
            return .stability
        }

        return .stability
    }

    // MARK: - Environment Action Resolution

    private static func resolveEnvironmentAction(
        bottleneck: AttentionBottleneck,
        personalRules: [PersonalRule],
        digitalEnvironment: DigitalEnvironmentState,
        screenTimeActive: Bool,
        screenTimeAuthorized: Bool,
        basePrescription: DailyPrescription
    ) -> EnvironmentAction? {
        // Priority 1: Kept Personal Rule matching context
        if let keptRule = personalRules.first(where: { $0.lifecycle == .kept && $0.category == .environment }) {
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: keptRule.title,
                detail: keptRule.detail,
                level: 1,
                minutes: nil
            )
        }

        // Priority 2: Digital Environment V2 recommendation
        if bottleneck == .digitalPull {
            let primaryPull = digitalEnvironment.profile.primaryDigitalPull.value
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: "Keep phone outside arm's reach",
                detail: "Physical distance weakens \(primaryPull == .unknown ? "digital" : primaryPull.displayName) urges before they start.",
                level: 1,
                minutes: nil
            )
        }

        return basePrescription.environmentAction
    }

    // MARK: - Explanation Generation

    private static func generateExplanation(
        bottleneck: AttentionBottleneck,
        primaryKind: GuidancePrimaryActionKind,
        targetMinutes: Int,
        envAction: EnvironmentAction?
    ) -> String {
        switch bottleneck {
        case .starting:
            return "Starting is the critical threshold today. Build momentum with one short uninterrupted block."
        case .stability:
            return "Recent sessions show focus holds well once started. Today extends your continuity."
        case .digitalPull:
            return "Digital pulls were observed during recent sessions. Setting your environment first protects your focus."
        case .returnStrategy:
            return "Urges are natural. Today trains noticing distraction and immediately returning."
        case .recall:
            return "Testing active recall solidifies cognitive retention from prior work."
        case .depth:
            return "You are ready for deeper sustained focus. Stay with one hard problem."
        case .energyContext:
            return "Your reported energy is low today. Duration is dialed down so quality stays high."
        case .environment:
            return "Physical environment conditions directly shape your initial switch threshold."
        case .flowConditions:
            return "Conditions match your optimal flow state. Applying focus directly to your real project."
        case .uncertaintyExperiment:
            return "Today compares one specific condition to verify what actually improves your focus."
        case .recovery:
            return "A short reset restores neural baseline without building fatigue."
        case .independence:
            return "Self-directed focus in Own Mode. You set your own conditions."
        }
    }
}
