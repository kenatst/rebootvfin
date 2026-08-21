import Foundation

// MARK: - Friction ladder

/// Intensity model 0–4. The engine always prefers the LOWEST level supported by
/// evidence — more restrictive is never "better" on its own.
enum FrictionLadder {
    static let observeOnly = 0
    static let manualFriction = 1
    static let protectSession = 2
    static let recurringWindow = 3
    static let thresholdRule = 4

    /// Choose the lowest appropriate level from real evidence.
    static func chooseLevel(env: EnvironmentEvidence?, distractorKnown: Bool) -> Int {
        guard distractorKnown else { return observeOnly }
        guard let env else { return manualFriction }

        // Repeated early exits → reduce intensity.
        if env.protectionEarlyExits >= 2 {
            return manualFriction
        }

        // Manual friction repeatedly works → stay low, never escalate.
        if env.manualInterventionsTotal >= 1,
           env.manualInterventionsSuccessful >= env.manualInterventionsTotal / 2,
           env.manualInterventionsTotal >= 2 {
            return manualFriction
        }

        // Good outcomes without protection → do not prescribe protection.
        if env.bestCondition == .unrestricted,
           let avg = env.bestConditionAvgSwitches,
           avg <= 2 {
            return manualFriction
        }

        // Threshold approved and in use → highest level is legitimate.
        if env.thresholdApproved, env.evidenceCount >= 3 {
            return thresholdRule
        }

        // Several protected sessions completed comfortably → reusable intervention.
        if env.protectedSessionsCompleted >= 5, env.earlyExitRate < 0.3 {
            return recurringWindow
        }

        // Manual friction has been tried and is not working, user opted into
        // Screen Time and selected activities → session protection is appropriate.
        if env.screenTimeConnected, env.hasSelection, env.manualInterventionsTotal >= 2 {
            return protectSession
        }

        return manualFriction
    }

    /// The engine may still WANT session protection before the user connects;
    /// the UI then offers "Connect Screen Time" instead of a protection switch.
    static func wantsSessionProtection(env: EnvironmentEvidence?) -> Bool {
        guard let env else { return false }
        if env.protectionEarlyExits >= 2 { return false }
        return env.manualInterventionsTotal >= 2 && env.manualInterventionsSuccessful < env.manualInterventionsTotal
    }
}

// MARK: - Environment action factory

enum EnvironmentActionFactory {
    static func action(level: Int, topDistractor: String?, minutes: Int, env: EnvironmentEvidence?) -> EnvironmentAction? {
        switch level {
        case FrictionLadder.observeOnly:
            return nil
        case FrictionLadder.manualFriction:
            let top = topDistractor ?? Distractor.internalRestlessness
            if top == Distractor.tabs {
                return EnvironmentAction(
                    kind: .singleTaskBrowser,
                    title: "Close every tab except the one you need.",
                    detail: "Low-friction experiment — no shielding.",
                    level: level,
                    minutes: nil
                )
            }
            return EnvironmentAction(
                kind: .manualPhoneAway,
                title: Distractor.action(for: top),
                detail: "Low-friction experiment — no shielding.",
                level: level,
                minutes: nil
            )
        case FrictionLadder.protectSession:
            return EnvironmentAction(
                kind: .protectSelectedDistractions,
                title: "Protect this session.",
                detail: "Protect your selected distractions for \(minutes) minutes.",
                level: level,
                minutes: minutes
            )
        case FrictionLadder.recurringWindow:
            return EnvironmentAction(
                kind: .protectedWindow,
                title: "Protect your study window.",
                detail: "Your approved windows already cover this — reuse one today.",
                level: level,
                minutes: minutes
            )
        case FrictionLadder.thresholdRule:
            return EnvironmentAction(
                kind: .thresholdRule,
                title: "Protect after 20 minutes of scrolling.",
                detail: "Your approved threshold applies today.",
                level: level,
                minutes: minutes
            )
        default:
            return nil
        }
    }
}

// MARK: - Evidence updater (session → profile environment evidence)

enum EnvironmentUpdater {
    /// Updates the profile Environment dimension honestly from a session outcome.
    static func apply(
        session: SessionRecord,
        observation: EnvironmentObservation,
        to evidence: inout EnvironmentEvidence?
    ) {
        var env = evidence ?? EnvironmentEvidence()
        env.evidenceCount += 1
        env.updatedAt = Date()
        env.source = env.evidenceCount >= 2 ? .repeated : .session

        let success = observation.completed && !observation.endedEarly

        switch observation.condition {
        case .unrestricted:
            if let switches = observation.switches {
                if let best = env.bestConditionAvgSwitches {
                    env.bestConditionAvgSwitches = (best + Double(switches)) / 2
                } else {
                    env.bestConditionAvgSwitches = Double(switches)
                }
                env.bestCondition = .unrestricted
            }
        case .phoneAway, .singleTaskBrowser:
            env.manualInterventionsTotal += 1
            if success && (observation.switches ?? 9) <= 3 {
                env.manualInterventionsSuccessful += 1
            }
        case .protected:
            if success {
                env.protectedSessionsCompleted += 1
            } else if observation.endedEarly {
                env.protectionEarlyExits += 1
            }
        case .protectedWindow:
            if success {
                env.protectedSessionsCompleted += 1
            }
        case .threshold:
            break
        }

        // Trend: compare latest switches to the best-condition baseline.
        if let switches = observation.switches, let baseline = env.bestConditionAvgSwitches {
            if Double(switches) < baseline * 0.8 {
                env.trend = .improving
            } else if Double(switches) > baseline * 1.3 {
                env.trend = .declining
            } else {
                env.trend = .stable
            }
        }

        env.confidence = min(1, Double(env.evidenceCount) / 6.0)
        env.state = stateLabel(env)
        evidence = env
    }

    static func stateLabel(_ env: EnvironmentEvidence) -> String? {
        guard env.evidenceCount > 0 else { return nil }
        if env.protectionEarlyExits >= 2 { return "protection felt restrictive" }
        if env.protectedSessionsCompleted >= 2, env.earlyExitRate < 0.5 { return "protected sessions feel comfortable" }
        if env.manualInterventionsSuccessful >= 1 { return "manual friction helps" }
        return "environment still being measured"
    }

    /// Mark the device facts that legitimately shape the ladder.
    static func updateDeviceFacts(
        screenTimeConnected: Bool,
        hasSelection: Bool,
        hasApprovedWindows: Bool,
        thresholdApproved: Bool,
        evidence: inout EnvironmentEvidence?
    ) {
        var env = evidence ?? EnvironmentEvidence()
        env.screenTimeConnected = screenTimeConnected
        env.hasSelection = hasSelection
        env.hasApprovedWindows = hasApprovedWindows
        env.thresholdApproved = thresholdApproved
        env.updatedAt = Date()
        evidence = env
    }
}

// MARK: - Insight copy (cautious wording only)

enum EnvironmentInsight {
    static func from(_ env: EnvironmentEvidence?) -> String? {
        guard let env, env.evidenceCount >= 2 else { return nil }
        if env.protectedSessionsCompleted >= 2, env.earlyExitRate < 0.5 {
            return "Your recent protected sessions have involved fewer reported switches."
        }
        if env.protectionEarlyExits >= 2 {
            return "Protection may have felt too restrictive — we'll ease back."
        }
        if env.manualInterventionsSuccessful >= 1 {
            return "Small environment changes appear to help you start."
        }
        return nil
    }

    static func whyToday(_ env: EnvironmentEvidence?, distractor: String?) -> String? {
        guard let env, env.evidenceCount >= 1 else {
            guard let distractor else { return nil }
            return "You identified \(distractor) as a common interruption. We're testing whether a little friction makes returning easier."
        }
        if env.protectedSessionsCompleted >= 2 {
            return "Recent protected sessions have gone comfortably — we're keeping the same light touch."
        }
        return "Early signal — worth testing."
    }
}

// MARK: - Observation factory (condition + outcome kept separate)

enum EnvironmentObservationFactory {
    static func observation(from record: SessionRecord) -> EnvironmentObservation? {
        guard let env = record.environment else { return nil }
        let condition = EnvironmentCondition(rawValue: env.environmentCondition ?? "") ?? .unrestricted
        return EnvironmentObservation(
            date: record.date,
            condition: condition,
            minutes: record.actualMinutes,
            completed: record.completed,
            endedEarly: record.endedEarly,
            difficulty: record.difficulty,
            switches: record.switches,
            startedEasier: env.startedEasierSelfReport
        )
    }
}
