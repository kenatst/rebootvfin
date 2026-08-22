import Foundation

// MARK: - Digital Environment Profile Engine

enum DigitalEnvironmentProfileEngine {
    /// Pure functional calculation deriving an honest DigitalEnvironmentProfile from real evidence.
    static func deriveProfile(
        history: [SessionRecord],
        events: [InterruptionEvent],
        checkIns: [DigitalCheckInResponse],
        currentProfile: DigitalEnvironmentProfile = DigitalEnvironmentProfile(),
        diagnosisDistractors: [String]? = nil
    ) -> DigitalEnvironmentProfile {
        var profile = currentProfile

        // 1. Primary Digital Pull
        profile.primaryDigitalPull = derivePrimaryPull(
            history: history,
            events: events,
            checkIns: checkIns,
            diagnosisDistractors: diagnosisDistractors
        )

        // 2. Trigger Type
        profile.triggerType = deriveTriggerType(
            events: events,
            checkIns: checkIns
        )

        // 3. Phone Proximity
        profile.phoneProximity = derivePhoneProximity(
            history: history,
            events: events,
            checkIns: checkIns
        )

        // 4. Interruption Pressure
        profile.interruptionPressure = deriveInterruptionPressure(
            history: history,
            events: events
        )

        // 5. Environment Control Level
        profile.environmentControl = deriveEnvironmentControl(
            history: history,
            events: events
        )

        // 6. Protection Tolerance
        profile.protectionTolerance = deriveProtectionTolerance(
            history: history
        )

        // 7. Starting Friction
        profile.startingFriction = deriveStartingFriction(
            history: history
        )

        // 8. Return Friction
        profile.returnFriction = deriveReturnFriction(
            history: history,
            events: events
        )

        return profile
    }

    private static func derivePrimaryPull(
        history: [SessionRecord],
        events: [InterruptionEvent],
        checkIns: [DigitalCheckInResponse],
        diagnosisDistractors: [String]?
    ) -> EnvironmentDimension<DigitalPull> {
        var pullCounts: [DigitalPull: Int] = [:]
        var sources: [EvidenceSource] = []

        // From interruption events
        for event in events where event.digitalCategory != .unknown {
            pullCounts[event.digitalCategory, default: 0] += 1
            if !sources.contains(.observed) { sources.append(.observed) }
        }

        // From check-ins
        for checkIn in checkIns {
            if let pull = checkIn.pull, pull != .unknown {
                pullCounts[pull, default: 0] += 1
                if !sources.contains(.selfReport) { sources.append(.selfReport) }
            }
        }

        // From session first distractions
        for session in history {
            if let dist = session.firstDistraction, !dist.isEmpty, dist.lowercased() != "none" {
                let mapped = mapStringToPull(dist)
                if mapped != .unknown {
                    pullCounts[mapped, default: 0] += 1
                    if !sources.contains(.session) { sources.append(.session) }
                }
            }
        }

        // From diagnosis (if no session evidence yet)
        if pullCounts.isEmpty, let distractors = diagnosisDistractors {
            for dist in distractors {
                let mapped = mapStringToPull(dist)
                if mapped != .unknown {
                    pullCounts[mapped, default: 0] += 1
                    if !sources.contains(.selfReport) { sources.append(.selfReport) }
                }
            }
        }

        guard let top = pullCounts.max(by: { $0.value < $1.value }), top.value > 0 else {
            return .unknown(defaultVal: .unknown)
        }

        let total = pullCounts.values.reduce(0, +)
        let count = top.value
        let confidence = min(1.0, Double(count) / 4.0)
        let source: [EvidenceSource] = count >= 3 ? [.repeated] : sources

        return EnvironmentDimension(
            value: top.key,
            confidence: confidence,
            evidenceCount: total,
            sources: source,
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveTriggerType(
        events: [InterruptionEvent],
        checkIns: [DigitalCheckInResponse]
    ) -> EnvironmentDimension<InterruptionTrigger> {
        var counts: [InterruptionTrigger: Int] = [:]
        var sources: [EvidenceSource] = []

        for event in events where event.trigger != .unknown {
            counts[event.trigger, default: 0] += 1
            if !sources.contains(.observed) { sources.append(.observed) }
        }

        for checkIn in checkIns {
            if let trigger = checkIn.trigger, trigger != .unknown {
                counts[trigger, default: 0] += 1
                if !sources.contains(.selfReport) { sources.append(.selfReport) }
            }
        }

        guard let top = counts.max(by: { $0.value < $1.value }), top.value > 0 else {
            return .unknown(defaultVal: .unknown)
        }

        let total = counts.values.reduce(0, +)
        let count = top.value
        let confidence = min(1.0, Double(count) / 3.0)

        return EnvironmentDimension(
            value: top.key,
            confidence: confidence,
            evidenceCount: total,
            sources: count >= 3 ? [.repeated] : sources,
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func derivePhoneProximity(
        history: [SessionRecord],
        events: [InterruptionEvent],
        checkIns: [DigitalCheckInResponse]
    ) -> EnvironmentDimension<PhoneProximity> {
        var counts: [PhoneProximity: Int] = [:]
        var sources: [EvidenceSource] = []

        for event in events where event.phonePosition != .unknown {
            counts[event.phonePosition, default: 0] += 1
            if !sources.contains(.observed) { sources.append(.observed) }
        }

        for checkIn in checkIns {
            if let prox = checkIn.phonePosition, prox != .unknown {
                counts[prox, default: 0] += 1
                if !sources.contains(.selfReport) { sources.append(.selfReport) }
            }
        }

        for session in history {
            if let loc = session.environment?.phoneLocationSelfReport, !loc.isEmpty {
                let mapped = mapStringToProximity(loc)
                if mapped != .unknown {
                    counts[mapped, default: 0] += 1
                    if !sources.contains(.session) { sources.append(.session) }
                }
            }
        }

        guard let top = counts.max(by: { $0.value < $1.value }), top.value > 0 else {
            return .unknown(defaultVal: .unknown)
        }

        let total = counts.values.reduce(0, +)
        let count = top.value
        let confidence = min(1.0, Double(count) / 3.0)

        return EnvironmentDimension(
            value: top.key,
            confidence: confidence,
            evidenceCount: total,
            sources: count >= 3 ? [.repeated] : sources,
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveInterruptionPressure(
        history: [SessionRecord],
        events: [InterruptionEvent]
    ) -> EnvironmentDimension<InterruptionPressure> {
        let relevantSessions = history.filter { ($0.switches ?? 0) > 0 || $0.completed }
        guard !relevantSessions.isEmpty || !events.isEmpty else {
            return .unknown(defaultVal: .unknown)
        }

        let totalSwitches = relevantSessions.compactMap(\.switches).reduce(0, +) + events.count
        let sessionCount = max(1, relevantSessions.count)
        let avgSwitches = Double(totalSwitches) / Double(sessionCount)

        let pressure: InterruptionPressure
        if avgSwitches >= 4.0 {
            pressure = .high
        } else if avgSwitches >= 1.5 {
            pressure = .moderate
        } else {
            pressure = .low
        }

        let confidence = min(1.0, Double(sessionCount) / 5.0)

        return EnvironmentDimension(
            value: pressure,
            confidence: confidence,
            evidenceCount: sessionCount,
            sources: [.session],
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveEnvironmentControl(
        history: [SessionRecord],
        events: [InterruptionEvent]
    ) -> EnvironmentDimension<EnvironmentControlLevel> {
        guard history.count >= 2 else {
            return .unknown(defaultVal: .unknown)
        }

        let actionsDone = history.filter { $0.environmentActionDone == true || $0.environment?.protectionActivated == true }.count
        let actionsAttempted = history.filter { $0.environmentActionDone != nil || $0.environment?.protectionOffered == true }.count
        let completedUninterrupted = history.filter { $0.completed && ($0.switches ?? 0) <= 1 }.count

        let control: EnvironmentControlLevel
        if actionsAttempted > 0, Double(actionsDone) / Double(actionsAttempted) >= 0.7 && completedUninterrupted >= history.count / 2 {
            control = .strong
        } else if actionsDone >= 1 || completedUninterrupted >= 1 {
            control = .developing
        } else {
            control = .weak
        }

        let confidence = min(1.0, Double(history.count) / 5.0)

        return EnvironmentDimension(
            value: control,
            confidence: confidence,
            evidenceCount: history.count,
            sources: [.session],
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveProtectionTolerance(
        history: [SessionRecord]
    ) -> EnvironmentDimension<ProtectionTolerance> {
        let protectedSessions = history.filter { $0.environment?.protectionActivated == true }
        guard !protectedSessions.isEmpty else {
            return .unknown(defaultVal: .unknown)
        }

        let completed = protectedSessions.filter { $0.completed && !$0.endedEarly }.count
        let earlyExits = protectedSessions.filter(\.endedEarly).count

        let tolerance: ProtectionTolerance
        if earlyExits >= 2 {
            tolerance = .low
        } else if completed >= 2 {
            tolerance = .high
        } else {
            tolerance = .medium
        }

        let confidence = min(1.0, Double(protectedSessions.count) / 3.0)

        return EnvironmentDimension(
            value: tolerance,
            confidence: confidence,
            evidenceCount: protectedSessions.count,
            sources: protectedSessions.count >= 3 ? [.repeated] : [.session],
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveStartingFriction(
        history: [SessionRecord]
    ) -> EnvironmentDimension<FrictionLevel> {
        let recent = Array(history.suffix(6))
        guard !recent.isEmpty else {
            return .unknown(defaultVal: .unknown)
        }

        let highDiffCount = recent.filter { ($0.difficulty ?? 0) >= 4 }.count
        let easierCount = recent.filter { $0.startedEasierSelfReport == true }.count

        let level: FrictionLevel
        if highDiffCount >= 2 && easierCount == 0 {
            level = .high
        } else if highDiffCount == 0 || easierCount >= 2 {
            level = .low
        } else {
            level = .moderate
        }

        return EnvironmentDimension(
            value: level,
            confidence: min(1.0, Double(recent.count) / 4.0),
            evidenceCount: recent.count,
            sources: [.session],
            lastUpdated: Date(),
            trend: .stable
        )
    }

    private static func deriveReturnFriction(
        history: [SessionRecord],
        events: [InterruptionEvent]
    ) -> EnvironmentDimension<FrictionLevel> {
        let sessionsWithSwitches = history.filter { ($0.switches ?? 0) > 0 }
        guard !sessionsWithSwitches.isEmpty || !events.isEmpty else {
            return .unknown(defaultVal: .unknown)
        }

        let abandonedSwitches = sessionsWithSwitches.filter(\.endedEarly).count + events.filter(\.earlyExit).count
        let total = sessionsWithSwitches.count + events.count

        let level: FrictionLevel
        if Double(abandonedSwitches) / Double(max(1, total)) >= 0.5 {
            level = .high
        } else if abandonedSwitches == 0 {
            level = .low
        } else {
            level = .moderate
        }

        return EnvironmentDimension(
            value: level,
            confidence: min(1.0, Double(total) / 4.0),
            evidenceCount: total,
            sources: [.session],
            lastUpdated: Date(),
            trend: .stable
        )
    }

    static func mapStringToPull(_ str: String) -> DigitalPull {
        let s = str.lowercased()
        if s.contains("social") || s.contains("instagram") || s.contains("twitter") || s.contains("x") || s.contains("tiktok") || s.contains("reddit") {
            return .socialMedia
        }
        if s.contains("message") || s.contains("chat") || s.contains("whatsapp") || s.contains("telegram") || s.contains("slack") {
            return .messaging
        }
        if s.contains("reel") || s.contains("shorts") || s.contains("video_loop") {
            return .shortVideo
        }
        if s.contains("tab") || s.contains("browser") || s.contains("chrome") || s.contains("safari") {
            return .browserTabs
        }
        if s.contains("news") || s.contains("article") || s.contains("feed") {
            return .news
        }
        if s.contains("email") || s.contains("mail") || s.contains("inbox") {
            return .email
        }
        if s.contains("game") || s.contains("gaming") {
            return .games
        }
        if s.contains("shop") || s.contains("amazon") {
            return .shopping
        }
        if s.contains("youtube") || s.contains("video") || s.contains("netflix") {
            return .video
        }
        if s.contains("notification") || s.contains("work") {
            return .workNotifications
        }
        return .unknown
    }

    static func mapStringToProximity(_ str: String) -> PhoneProximity {
        let s = str.lowercased()
        if s.contains("hand") { return .inHand }
        if s.contains("desk") { return .onDesk }
        if s.contains("reach") || s.contains("arm") { return .withinReach }
        if s.contains("across") { return .acrossRoom }
        if s.contains("room") || s.contains("outside") || s.contains("other") { return .outsideRoom }
        return .unknown
    }
}

// MARK: - Friction Ladder Engine

enum FrictionLadderEngine {
    static let level0Observe = 0
    static let level1RemoveCue = 1
    static let level2Distance = 2
    static let level3FocusMode = 3
    static let level4ShieldProtection = 4

    /// Pure function selecting the lowest effective friction level supported by evidence.
    static func selectLevel(
        profile: DigitalEnvironmentProfile,
        envEvidence: EnvironmentEvidence?,
        history: [SessionRecord],
        cooldownLog: InterventionCooldownLog,
        fuel: FuelContextSnapshot?,
        currentDay: Int,
        mode: TrainingMode
    ) -> Int {
        // Day 1 is always natural observation baseline
        if currentDay <= 1 { return level0Observe }

        // Observe mode does not apply forced physical constraints
        if mode == .observe || mode == .nothing { return level0Observe }

        // If user is experiencing high fatigue / low energy, do not escalate friction
        if let fuel = fuel, fuel.energy == .low {
            return level1RemoveCue
        }

        guard let env = envEvidence else {
            return level1RemoveCue
        }

        // Repeated early exits from session protection → DE-ESCALATE to manual friction
        if env.protectionEarlyExits >= 2 || profile.protectionTolerance.value == .low {
            return level1RemoveCue
        }

        // If manual friction works well repeatedly → stay low, do not escalate
        if env.manualInterventionsTotal >= 2,
           env.manualInterventionsSuccessful >= env.manualInterventionsTotal / 2 {
            return level1RemoveCue
        }

        // If unrestricted sessions show low switches → stay with light touch
        if env.bestCondition == .unrestricted, let avg = env.bestConditionAvgSwitches, avg <= 2 {
            return level1RemoveCue
        }

        // Check if level 4 / session protection is on cooldown
        let protectionCoolingDown = cooldownLog.isCoolingDown(actionKind: EnvironmentActionKind.protectSelectedDistractions.rawValue)

        // Session protection: requires Screen Time connected, selection made, manual tried, and no cooldown
        if env.screenTimeConnected, env.hasSelection, env.manualInterventionsTotal >= 2, !protectionCoolingDown {
            return level4ShieldProtection
        }

        // Distance: phone in hand / on desk with high switches
        if profile.phoneProximity.value == .inHand || profile.phoneProximity.value == .onDesk {
            return level2Distance
        }

        return level1RemoveCue
    }

    /// Makes the appropriate concrete EnvironmentAction for the given level.
    static func makeAction(
        level: Int,
        profile: DigitalEnvironmentProfile,
        minutes: Int
    ) -> EnvironmentAction? {
        switch level {
        case level0Observe:
            return nil
        case level1RemoveCue:
            let topPull = profile.primaryDigitalPull.value
            if topPull == .browserTabs {
                return EnvironmentAction(
                    kind: .singleTaskBrowser,
                    title: "Close every tab except your active task.",
                    detail: "Low-friction setup — no shielding.",
                    level: level,
                    minutes: nil
                )
            }
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: "Turn phone face down or silence notifications.",
                detail: "Low-friction setup — no shielding.",
                level: level,
                minutes: nil
            )
        case level2Distance:
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: "Place phone outside arm's reach for this session.",
                detail: "Physical boundary — makes starting easier.",
                level: level,
                minutes: nil
            )
        case level3FocusMode:
            return EnvironmentAction(
                kind: .protectedWindow,
                title: "Turn on Focus Mode for this block.",
                detail: "Mutes non-urgent notifications during your session.",
                level: level,
                minutes: minutes
            )
        case level4ShieldProtection:
            return EnvironmentAction(
                kind: .protectSelectedDistractions,
                title: "Protect this session.",
                detail: "Shields your selected distractions for \(minutes) minutes.",
                level: level,
                minutes: minutes
            )
        default:
            return nil
        }
    }
}

// MARK: - Focus Window Suggestion Engine

enum FocusWindowSuggestionEngine {
    /// Analyzes completed history to identify recurring high-performance time windows.
    /// Requires at least 2 strong sessions in the same daypart bracket. Never infers from a single session.
    static func suggestWindow(
        from history: [SessionRecord],
        existingWindows: [FocusWindow]
    ) -> FocusWindow? {
        let completed = history.filter { $0.completed && ($0.switches ?? 0) <= 1 }
        guard completed.count >= 2 else { return nil }

        let calendar = Calendar.current
        var bracketCounts: [Int: [SessionRecord]] = [:] // key = start hour bracket (e.g. 9 for 9-11)

        for session in completed {
            let hour = calendar.component(.hour, from: session.date)
            let bracket = (hour / 2) * 2 // 8, 10, 14, 16 etc.
            bracketCounts[bracket, default: []].append(session)
        }

        guard let topBracket = bracketCounts.filter({ $0.value.count >= 2 }).max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }

        let startH = topBracket.key
        let startMins = startH * 60
        let endMins = (startH + 2) * 60

        // Check if an existing window already overlaps
        let alreadyCovered = existingWindows.contains { w in
            abs(w.startMinutes - startMins) <= 60
        }

        guard !alreadyCovered else { return nil }

        let bracketName: String
        if startH < 12 {
            bracketName = "Morning Focus"
        } else if startH < 17 {
            bracketName = "Afternoon Focus"
        } else {
            bracketName = "Evening Focus"
        }

        return FocusWindow(
            name: bracketName,
            weekdays: [2, 3, 4, 5, 6],
            startMinutes: startMins,
            endMinutes: endMins,
            linkedTaskContext: "Deep Work",
            protectionPreference: .protectedWindow,
            phoneRule: .outsideRoom,
            notificationRule: "Focus Mode",
            selectionID: nil,
            enabled: true
        )
    }
}

// MARK: - Digital Reset Missions Library

enum DigitalResetMissionLibrary {
    static let allMissions: [DigitalResetMission] = [
        DigitalResetMission(
            day: 5,
            title: "Notification Audit",
            rationale: "Badges and banners create involuntary attention residue even when unread.",
            instruction: "Open Settings > Notifications. Turn off lock screen banners and red badge icons for your top 3 non-human notification sources (shopping, news, games)."
        ),
        DigitalResetMission(
            day: 12,
            title: "Home Screen Friction",
            rationale: "Apps you open on reflex are hardest to resist when they sit one tap away.",
            instruction: "Move your most frequent reflex app off your first home screen page and into the App Library or a secondary folder."
        ),
        DigitalResetMission(
            day: 20,
            title: "Single Tab Threshold",
            rationale: "Parallel open tabs scatter working memory and encourage aimless switching.",
            instruction: "Before starting your next work block, close or bookmark every tab except the single active task surface."
        ),
        DigitalResetMission(
            day: 35,
            title: "Physical Parking Spot",
            rationale: "Keeping the device in peripheral vision consumes micro-attention.",
            instruction: "Designate a physical phone parking spot across the room or behind your monitor for all deep sessions today."
        ),
        DigitalResetMission(
            day: 48,
            title: "The Five-Minute Wait Test",
            rationale: "Micro-boredom is the primary gateway to reflex digital switching.",
            instruction: "Next time you wait for a meeting, elevator, or code build today, observe the urge to unlock without acting on it for 5 minutes."
        ),
        DigitalResetMission(
            day: 62,
            title: "Focus Window Defense",
            rationale: "A recurring protected block removes daily friction negotiations.",
            instruction: "Set up and protect a 2-hour recurring Focus Window on your device calendar this week."
        ),
        DigitalResetMission(
            day: 75,
            title: "Phone Distance Comparison",
            rationale: "Test whether physical distance reduces task restart friction.",
            instruction: "Complete one session with your phone on the desk, and another with your phone in a different room. Notice the difference in return friction."
        ),
        DigitalResetMission(
            day: 85,
            title: "Lifelong Environment Blueprint",
            rationale: "Consolidate your discovered personal environment rules for long-term mastery.",
            instruction: "Review your kept Digital Rules and confirmed Focus Windows. Ensure they match your ongoing daily work style."
        )
    ]

    static func mission(forDay day: Int) -> DigitalResetMission? {
        allMissions.first { $0.day == day }
    }
}

// MARK: - Digital Check-In Engine

enum DigitalCheckInEngine {
    static func shouldPrompt(session: SessionRecord) -> Bool {
        // Only prompt if switches occurred or environment action was performed
        let hadSwitches = (session.switches ?? 0) > 0
        let hadAction = session.environmentActionDone == true || session.environment?.protectionActivated == true
        return hadSwitches || hadAction
    }
}
