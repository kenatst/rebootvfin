import Foundation

/// DailyGuidance turns every subsystem into ONE decision for today:
/// what to do, why, and nothing else.
///
/// Selection rules:
/// - Recovery outranks everything except Day 1 (a tired user cannot compare arms).
/// - Bottlenecks need minimum evidence before they can steer; diagnosis priors
///   alone never select a bottleneck after the first week of sessions.
/// - Hysteresis: a new bottleneck must beat the incumbent with clear evidence,
///   otherwise Today stays stable instead of oscillating day to day.
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
        let protocolSessions = sessions.filter { $0.origin == .protocol }
        let basePrescription = PrescriptionEngine.prescription(
            profile: profile,
            sessions: protocolSessions,
            day: day,
            reviews: []
        )

        // 1. Day 1 Natural Baseline — untouched by any subsystem.
        if day == 1 && !protocolSessions.contains(where: { $0.day == 1 && $0.completed }) {
            return DailyGuidance(
                bottleneck: .starting,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .standardProtocolSession,
                    title: L("Observe your natural focus"),
                    subtitle: L("15 MIN · OBSERVE"),
                    targetMinutes: 15,
                    mode: .observe,
                    ctaTitle: L("Start baseline")
                ),
                supportingAction: nil,
                sessionPrescription: basePrescription,
                environmentAction: nil,
                fuelPrompt: nil,
                flowOpportunity: nil,
                experimentOpportunityID: nil,
                explanation: L("Day 1 measures how you normally work. Nothing about your environment changes yet."),
                confidence: 1.0,
                evidenceIDs: [],
                suppressedOpportunities: ["Fuel Prompt", "Personal Lab", "Flow Block", "Environment Intervention"],
                generatedAt: Date(),
                isOwnMode: false,
                noInterventionNeeded: false
            )
        }

        // 2. Recovery Priority — protected from rules, tests and flow.
        if isRecovery {
            var recoveryPrescription = basePrescription
            recoveryPrescription.mode = .nothing
            recoveryPrescription.minutes = 5
            return DailyGuidance(
                bottleneck: .recovery,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .recoverySession,
                    title: L("Give your mind less to react to."),
                    subtitle: L("5 MIN · NOTHING"),
                    targetMinutes: 5,
                    mode: .nothing,
                    ctaTitle: L("Begin reset")
                ),
                supportingAction: nil,
                sessionPrescription: recoveryPrescription,
                environmentAction: nil,
                fuelPrompt: nil,
                flowOpportunity: nil,
                experimentOpportunityID: nil,
                explanation: L("Your last session felt hard. Today is lighter on purpose — that is how load stays survivable."),
                confidence: 0.95,
                evidenceIDs: [],
                suppressedOpportunities: ["Flow Block", "Personal Lab", "Fuel Prompt"],
                generatedAt: Date(),
                isOwnMode: false,
                noInterventionNeeded: false
            )
        }

        // 3. Post-90 Own Mode. Self-directed: one suggestion, or an explicit
        // "no intervention needed" day. Never an endless curriculum.
        if programStatus == .completed || day > 90 || ownModeState.active {
            return ownModeGuidance(
                ownModeState: ownModeState,
                sessions: sessions,
                profile: profile,
                prescription: basePrescription
            )
        }

        // 4. Bottleneck selection with evidence floors + anti-oscillation.
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

        let envAction = resolveEnvironmentAction(
            bottleneck: bottleneck,
            personalRules: personalRules,
            digitalEnvironment: digitalEnvironmentState,
            screenTimeActive: screenTimeActive,
            screenTimeAuthorized: screenTimeAuthorized,
            basePrescription: basePrescription
        )

        // Fuel sampling: suppressed under an active Flow block; otherwise the
        // canonical single optional prompt for today's protocol session.
        var fuelPrompt: FuelSamplePrompt? = nil
        var suppressed: [String] = []
        let activeFlowProject = flowState.projects.first(where: { $0.status == .active })
        let canDoFlow = activeFlowProject != nil && (bottleneck == .flowConditions || bottleneck == .depth)

        if canDoFlow {
            suppressed.append("Fuel Prompt (suppressed by active Flow block)")
        } else {
            fuelPrompt = ContextSamplingEngine.recommendPrompt(.init(
                programDay: day,
                completedProtocolDays: protocolSessions.filter(\.completed).count,
                phase: programPhase.id,
                isRecoveryPrescribed: false,
                promptsEnabled: fuelState.promptsEnabled,
                activeFuelConditionTest: false,
                preferredField: nil,
                pendingCapture: todaysCapture(fuelState),
                log: fuelState.sampling
            ))
        }

        let targetMinutes: Int
        if bottleneck == .energyContext {
            targetMinutes = min(15, max(5, basePrescription.minutes))
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
            title = proj.title
            subtitle = "\(targetMinutes) MIN · STAY · REAL PROJECT"
            ctaTitle = "Start project block"
            flowOpportunity = FlowOpportunity(
                projectID: proj.id,
                projectTitle: proj.title,
                recommendedMinutes: targetMinutes,
                whyNow: "This phase looks for the conditions around your deeper work."
            )
        } else {
            primaryKind = .standardProtocolSession
            title = basePrescription.headline
            subtitle = "\(targetMinutes) MIN · \(basePrescription.mode.display.uppercased())"
            ctaTitle = "Start \(targetMinutes)-minute session"
        }

        // Supporting action: at most one.
        var supportingAction: DailyGuidanceSecondaryAction? = nil
        if primaryKind != .projectFlowBlock, let proj = activeFlowProject {
            supportingAction = DailyGuidanceSecondaryAction(
                title: L("Use your real project: \(proj.title)"),
                actionType: "flow",
                identifier: proj.id.uuidString
            )
        } else if let activeExp = labExperiments.first(where: { $0.status == .active }) {
            supportingAction = DailyGuidanceSecondaryAction(
                title: L("Today counts toward: \(activeExp.testArm.condition.title)"),
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
            experimentOpportunityID: labExperiments.first(where: { $0.status == .active })?.id,
            explanation: explanation,
            confidence: 0.88,
            evidenceIDs: [],
            suppressedOpportunities: suppressed,
            generatedAt: Date(),
            isOwnMode: false,
            noInterventionNeeded: false
        )
    }

    // MARK: - Own Mode

    /// Own Mode alternates between a light suggestion and an honest
    /// "nothing needed today". The quiet day is the feature.
    private static func ownModeGuidance(
        ownModeState: OwnModeState,
        sessions: [SessionRecord],
        profile: AttentionProfile,
        prescription: DailyPrescription
    ) -> DailyGuidance {
        let calendar = Calendar.current
        // A deliberately quiet day roughly every third calendar day. The
        // "nothing needed today" state is the feature, not a failure state.
        var quietDay = false
        if let last = ownModeState.lastGuidanceDate {
            quietDay = calendar.component(.day, from: last) % 3 == 0
        }
        // Never quiet before the user has any completed practice to stand on.
        let hasAnyCompletedPractice = sessions.contains {
            $0.completed && ($0.origin == .protocol || $0.origin == .freeTraining)
        }

        if quietDay && hasAnyCompletedPractice {
            return DailyGuidance(
                bottleneck: .independence,
                primaryAction: DailyGuidancePrimaryAction(
                    kind: .ownModeSession,
                    title: L("Nothing needs adjusting today."),
                    subtitle: L("NO INTERVENTION"),
                    targetMinutes: 0,
                    mode: .stay,
                    ctaTitle: ""
                ),
                supportingAction: nil,
                sessionPrescription: prescription,
                environmentAction: nil,
                fuelPrompt: nil,
                flowOpportunity: nil,
                experimentOpportunityID: nil,
                explanation: L("Your system is running itself. Train if you want to — REBOOT has nothing to add today."),
                confidence: 1.0,
                evidenceIDs: [],
                suppressedOpportunities: [],
                generatedAt: Date(),
                isOwnMode: true,
                noInterventionNeeded: true
            )
        }

        let duration = ownModeState.preferredDurations.first ?? 25
        return DailyGuidance(
            bottleneck: .independence,
            primaryAction: DailyGuidancePrimaryAction(
                kind: .ownModeSession,
                title: L("You know how you start best."),
                subtitle: L("\(duration) MIN · STAY · SELF-DIRECTED"),
                targetMinutes: duration,
                mode: .stay,
                ctaTitle: L("Start focus block")
            ),
            supportingAction: DailyGuidanceSecondaryAction(
                title: L("Open your Operating Manual"),
                actionType: "manual",
                identifier: nil
            ),
            sessionPrescription: prescription,
            environmentAction: nil,
            fuelPrompt: nil,
            flowOpportunity: nil,
            experimentOpportunityID: nil,
            explanation: L("You own your attention system now. REBOOT suggests; you decide."),
            confidence: 1.0,
            evidenceIDs: [],
            suppressedOpportunities: [],
            generatedAt: Date(),
            isOwnMode: true,
            noInterventionNeeded: false
        )
    }

    // MARK: - Bottleneck Selection

    /// Today's unconsumed capture, if it belongs to this calendar day.
    private static func todaysCapture(_ fuelState: FuelState) -> FuelContextSnapshot? {
        guard let capture = fuelState.pendingCapture,
              FuelState.calendarDay(capture.capturedAt) == FuelState.calendarDay(Date()) else {
            return nil
        }
        return capture
    }

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
        let lastBottleneck = history.last?.bottleneck
        let recentProtocol = sessions.filter { $0.origin == .protocol }.suffix(4)

        func evidence(_ bottleneck: AttentionBottleneck) -> Int {
            switch bottleneck {
            case .digitalPull:
                guard digitalEnvironment.profile.primaryDigitalPull.value != .unknown else { return 0 }
                return digitalEnvironment.profile.primaryDigitalPull.evidenceCount
            case .recall:
                let recallSessions = recentProtocol.filter { $0.mode == .recall }
                let weakRecalls = recallSessions.filter { $0.evidence?.recall?.selfAssessment == .little }
                return weakRecalls.count
            case .returnStrategy:
                // Sessions where switching happened at all give the signal.
                return recentProtocol.filter { ($0.switches ?? 0) >= 1 }.count
            case .starting:
                let earlyEnds = recentProtocol.filter { $0.endedEarly && ($0.elapsedSeconds < 10 * 60) }
                return earlyEnds.count
            case .stability:
                return recentProtocol.filter { $0.completed }.count
            default:
                return 0
            }
        }

        // Hard overrides first — these states are not negotiable.

        // An active experiment needs comparable sessions to resolve.
        if labExperiments.contains(where: { $0.status == .active }) {
            return .uncertaintyExperiment
        }

        // Low energy shortens today regardless of anything else.
        let recentEnergy = fuelState.pendingCapture?.energy ?? sessions.last?.fuelContext?.energy
        if recentEnergy == .low {
            return .energyContext
        }

        // Flow readiness: only once a project actually has repeated blocks.
        if flowState.projects.contains(where: { $0.status == .active && $0.recentBlockIDs.count >= 2 }),
           currentDay >= 61 {
            return .flowConditions
        }

        // Candidate ranking with minimum-evidence floors.
        let candidates: [(AttentionBottleneck, Int)] = [
            (.digitalPull, evidence(.digitalPull)),
            (.recall, evidence(.recall)),
            (.returnStrategy, evidence(.returnStrategy)),
            (.starting, evidence(.starting)),
        ]
        let qualified = candidates
            .filter { $0.1 >= 2 }
            .sorted { $0.1 > $1.1 }

        if let winner = qualified.first {
            // Hysteresis: keep the incumbent unless another candidate has
            // strictly more evidence behind it. Prevents day-to-day flapping.
            if let previous = lastBottleneck,
               previous != winner.0,
               let incumbentScore = qualified.first(where: { $0.0 == previous })?.1,
               incumbentScore >= winner.1 {
                return previous
            }
            return winner.0
        }

        // Default: stability — the through-line of the whole curriculum.
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
        // Priority 1: a kept environmental rule the user chose.
        if let keptRule = personalRules.first(where: { $0.isActivelyInfluencing && $0.category == .environment }) {
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: keptRule.title,
                detail: keptRule.detail,
                level: 1,
                minutes: nil
            )
        }

        // Priority 2: observed digital pull with enough evidence behind it.
        if bottleneck == .digitalPull,
           digitalEnvironment.profile.primaryDigitalPull.value != .unknown,
           digitalEnvironment.profile.primaryDigitalPull.evidenceCount >= 3 {
            let pull = digitalEnvironment.profile.primaryDigitalPull.value
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: L("Keep your phone outside arm's reach"),
                detail: "Your sessions point at \(pull.displayName) as the strongest pull. Distance acts before willpower has to.",
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
            return "Recent sessions ended shortly after starting. Today protects the first ten minutes above all else."
        case .stability:
            return "Focus holds once you're in. Today extends the stretch instead of changing the setup."
        case .digitalPull:
            return "Your sessions keep breaking toward the same digital pull. The setup handles it before willpower has to."
        case .returnStrategy:
            return "Switching happened recently — that's normal. What matters is coming back to the same task quickly."
        case .recall:
            return "Recent recall attempts lost most of the material. Today closes the source sooner and asks for more."
        case .depth:
            return "You are ready to stay with something harder. Depth comes from difficulty held longer."
        case .energyContext:
            return "Reported energy is low today. The session gets shorter so quality doesn't have to."
        case .environment:
            return "Physical setup shapes how long attention holds before the first pull."
        case .flowConditions:
            return "This phase looks for the conditions around your deeper work. A real project is the cleanest probe."
        case .uncertaintyExperiment:
            return "Today compares one specific condition against your normal, so the question resolves with real sessions."
        case .recovery:
            return "A short reset after a demanding session keeps tomorrow comparable to today."
        case .independence:
            return "Self-directed focus in Own Mode. You set the conditions; REBOOT records what happens."
        }
    }
}
