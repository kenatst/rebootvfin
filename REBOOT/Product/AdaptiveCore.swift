import Foundation

// MARK: - Evidence

/// Where a piece of profile knowledge comes from. Unknown stays unknown.
enum EvidenceSource: String, Codable, Equatable {
    case selfReport
    case observed
    case session
    case repeated

    var label: String {
        switch self {
        case .selfReport: return "self-reported"
        case .observed: return "observed"
        case .session: return "from a session"
        case .repeated: return "repeated evidence"
        }
    }
}

/// A profile dimension that is either honestly unknown or backed by a source.
enum Knowledge<Value: Codable & Equatable>: Codable, Equatable {
    case unknown
    case known(Value, source: EvidenceSource)

    var value: Value? {
        if case .known(let value, _) = self { return value }
        return nil
    }

    var source: EvidenceSource? {
        if case .known(_, let source) = self { return source }
        return nil
    }

    var isKnown: Bool { value != nil }
}

// MARK: - Levels

enum ReflexLevel: String, Codable, Equatable { case low, medium, high }
enum StabilityLevel: String, Codable, Equatable { case low, medium, high }
enum ReturnLevel: String, Codable, Equatable { case weak, fair, strong }
enum RecallLevel: String, Codable, Equatable { case weak, fair, strong }
enum DepthLevel: String, Codable, Equatable { case shallow, fair, deep }

// MARK: - Attention Profile

struct AttentionProfile: Codable, Equatable {
    var primaryGoal: Knowledge<String> = .unknown
    var goals: Knowledge<[String]> = .unknown
    var distractors: Knowledge<[String]> = .unknown
    var reflex: Knowledge<ReflexLevel> = .unknown
    var attentionStability: Knowledge<StabilityLevel> = .unknown
    var returnAfterDistraction: Knowledge<ReturnLevel> = .unknown
    var recall: Knowledge<RecallLevel> = .unknown
    var depth: Knowledge<DepthLevel> = .unknown
    var environment: Knowledge<String> = .unknown
    var flowConditions: Knowledge<[String]> = .unknown
    var energyContext: Knowledge<String> = .unknown
    /// Digital-environment evidence (Screen Time / manual interventions).
    var environmentEvidence: EnvironmentEvidence?

    /// Derived focus window in minutes from diagnosis or sessions.
    var focusWindowMinutes: Int? = nil

    var knownDimensions: Int {
        let dims: [Bool] = [
            primaryGoal.isKnown, goals.isKnown, distractors.isKnown, reflex.isKnown,
            attentionStability.isKnown, returnAfterDistraction.isKnown, recall.isKnown,
            depth.isKnown, environment.isKnown, flowConditions.isKnown, energyContext.isKnown,
        ]
        return dims.filter { $0 }.count
    }
}

// MARK: - Training Modes

enum TrainingMode: String, Codable, CaseIterable, Equatable {
    case stay = "STAY"
    case recall = "RECALL"
    case explain = "EXPLAIN"
    case nothing = "NOTHING"
    case observe = "OBSERVE"

    var display: String {
        switch self {
        case .stay: return "Stay"
        case .recall: return "Recall"
        case .explain: return "Explain"
        case .nothing: return "Rest"
        case .observe: return "Observe"
        }
    }

    var tagline: String {
        switch self {
        case .stay: return "Sustained attention"
        case .recall: return "Return & memory"
        case .explain: return "Active recall"
        case .nothing: return "Recovery"
        case .observe: return "Baseline"
        }
    }
}

// MARK: - Session

struct SessionRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: Int
    var date: Date
    var mode: TrainingMode
    var targetMinutes: Int
    var actualMinutes: Int
    var completed: Bool
    var endedEarly: Bool = false
    var firstDistraction: String?
    var switches: Int?
    var difficulty: Int?
    var energy: Int?
    var environmentActionDone: Bool?

    /// Minutes into the session when the first switch was noticed, if remembered.
    var firstSwitchMinute: Int?

    /// What actually happened in the digital environment during the session.
    var environment: EnvironmentSnapshot?
}

// MARK: - Prescription

struct DailyPrescription: Codable, Equatable {
    var day: Int
    var mode: TrainingMode
    var minutes: Int
    var headline: String
    var sentence: String
    var goal: String
    var reason: String
    var action: String
    var actionFallback: String
    var environmentChange: String?
    var adaptationReason: String
    /// Optional environment intervention (friction ladder 0–4).
    var environmentAction: EnvironmentAction?

    static let empty = DailyPrescription(
        day: 1,
        mode: .observe,
        minutes: 15,
        headline: "Work normally.",
        sentence: "We're measuring how you work today — nothing to change yet.",
        goal: "One normal focus block.",
        reason: "We need a real baseline before changing anything.",
        action: "Work normally today — this is your baseline.",
        actionFallback: "If you can't work normally, just do 5 focused minutes.",
        environmentChange: nil,
        adaptationReason: "No sessions yet — first observation.",
        environmentAction: nil
    )
}

// MARK: - Distractor helpers

enum Distractor {
    static let phone = "phone"
    static let social = "social"
    static let notifications = "notifications"
    static let tabs = "tabs"
    static let people = "people"
    static let internalRestlessness = "internal"

    static func fromDiagnosis(_ answers: Answers) -> [String] {
        var out: [String] = []
        for value in answers["breaker"] ?? [] {
            switch value {
            case "notifications": out.append(notifications)
            case "social": out.append(social)
            case "messages": out.append(notifications)
            case "restlessness": out.append(internalRestlessness)
            case "people": out.append(people)
            case "tabs": out.append(tabs)
            default: break
            }
        }
        if answers["social_app"]?.isEmpty == false {
            out.append(social)
        }
        if answers["phone_place"]?.isEmpty == false {
            out.append(phone)
        }
        return Array(Set(out))
    }

    static func action(for top: String) -> String {
        switch top {
        case phone: return "Leave your phone outside the room."
        case social: return "Leave your phone outside the room."
        case notifications: return "Silence notifications and move your phone out of reach."
        case tabs: return "Close every tab except the one you need."
        case people: return "Find a quiet room, or put on headphones."
        case internalRestlessness: return "Clear your desk — put one task in front of you."
        default: return "Work normally today — this is your baseline."
        }
    }

    static func fallback(for top: String) -> String {
        switch top {
        case phone, social: return "If you can't leave it behind, put it face-down and silenced."
        case notifications: return "If you can't silence everything, use airplane mode for the block."
        case tabs: return "If you need the other tabs, park them in a reading list first."
        case people: return "If there's no quiet room, pick the least noisy corner."
        case internalRestlessness: return "If the desk can't be cleared, just start — the first minute counts."
        default: return "If you can't work normally, just do 5 focused minutes."
        }
    }
}

// MARK: - Profile Builder (diagnosis → profile)

enum ProfileBuilder {
    static func build(from answers: Answers) -> AttentionProfile {
        var profile = AttentionProfile()
        let src = EvidenceSource.selfReport

        if let primary = answers["primary"]?.first {
            profile.primaryGoal = .known(primary, source: src)
        }
        if let goals = answers["goals"], !goals.isEmpty {
            profile.goals = .known(goals, source: src)
        }
        let distractors = Distractor.fromDiagnosis(answers)
        if !distractors.isEmpty {
            profile.distractors = .known(distractors, source: src)
        }

        switch answers["focus_window"]?.first {
        case "lt5":
            profile.focusWindowMinutes = 10
            profile.reflex = .known(.high, source: src)
            profile.attentionStability = .known(.low, source: src)
        case "5_15":
            profile.focusWindowMinutes = 15
            profile.reflex = .known(.medium, source: src)
            profile.attentionStability = .known(.low, source: src)
        case "15_30":
            profile.focusWindowMinutes = 20
            profile.reflex = .known(.medium, source: src)
            profile.attentionStability = .known(.medium, source: src)
        case "30_60":
            profile.focusWindowMinutes = 30
            profile.reflex = .known(.low, source: src)
            profile.attentionStability = .known(.medium, source: src)
        case "gt60":
            profile.focusWindowMinutes = 45
            profile.reflex = .known(.low, source: src)
            profile.attentionStability = .known(.high, source: src)
        default:
            profile.focusWindowMinutes = 15
        }

        switch answers["reading"]?.first {
        case "reread", "drift", "forget":
            profile.recall = .known(.weak, source: src)
        case "screen_only":
            profile.recall = .known(.fair, source: src)
        default:
            break
        }

        if let target = answers["recall_target"]?.first {
            profile.recall = .known(.fair, source: src)
            _ = target
        }

        if let environment = answers["environment"]?.first {
            profile.environment = .known(environment, source: src)
        }
        if let energy = answers["energy"]?.first {
            profile.energyContext = .known(energy, source: src)
        }
        if let flow = answers["absorption"], !flow.isEmpty {
            profile.flowConditions = .known(flow, source: src)
        }
        if let absorption = answers["absorption"], absorption.count >= 2 {
            profile.depth = .known(.fair, source: src)
        } else if answers["absorption"]?.isEmpty == false {
            profile.depth = .known(.shallow, source: src)
        }

        return profile
    }
}

// MARK: - Prescription Engine

enum PrescriptionEngine {
    static func prescription(profile: AttentionProfile, sessions: [SessionRecord], day: Int) -> DailyPrescription {
        let day = min(day, 90)
        let goal = profile.primaryGoal.value
        let distractors = profile.distractors.value ?? []
        let focus = profile.focusWindowMinutes ?? 15
        let last = sessions.last

        // 1. Baseline
        if sessions.isEmpty {
            return baseline(day: day, focus: focus)
        }

        // 2. Recovery after a hard session (never twice in a row)
        let previousWasRest = sessions.dropLast().last?.mode == .nothing
        if let difficulty = last?.difficulty, difficulty >= 4, !previousWasRest {
            return rest(day: day)
        }

        // 3. Memory goals rotate between RECALL / EXPLAIN / STAY
        let memoryGoals: Set<String> = ["read_more", "remember_more", "study_better"]
        if let goal, memoryGoals.contains(goal) {
            return memoryPrescription(goal: goal, profile: profile, sessions: sessions, day: day)
        }

        // 4. Distraction-led STAY with environment change
        if !distractors.isEmpty {
            return stayPrescription(profile: profile, sessions: sessions, day: day, distractors: distractors)
        }

        // 5. Flow goal
        if goal == "build_flow" {
            return flowPrescription(profile: profile, sessions: sessions, day: day)
        }

        // 6. Default STAY
        return stayPrescription(profile: profile, sessions: sessions, day: day, distractors: [])
    }

    private static func baseline(day: Int, focus: Int) -> DailyPrescription {
        DailyPrescription(
            day: day,
            mode: .observe,
            minutes: 15,
            headline: "Work normally.",
            sentence: "We're measuring how you work today — nothing to change yet.",
            goal: "One normal focus block.",
            reason: "A real baseline comes before any change.",
            action: "Work normally today — this is your baseline.",
            actionFallback: "If you can't work normally, just do 5 focused minutes.",
            environmentChange: nil,
            adaptationReason: "No sessions yet — first observation.",
            environmentAction: nil,
        )
    }

    private static func rest(day: Int) -> DailyPrescription {
        DailyPrescription(
            day: day,
            mode: .nothing,
            minutes: 10,
            headline: "Give your mind less to react to.",
            sentence: "Yesterday felt hard. Recovery is part of the plan.",
            goal: "A short, easy block.",
            reason: "Your last session was demanding — we're lowering the load.",
            action: "A short walk, or 10 easy minutes on one thing.",
            actionFallback: "If even that feels like too much, skip it — the program waits.",
            environmentChange: nil,
            adaptationReason: "Difficulty ≥ 4 on the previous session.",
            environmentAction: nil
        )
    }

    private static func memoryPrescription(goal: String, profile: AttentionProfile, sessions: [SessionRecord], day: Int) -> DailyPrescription {
        let focus = profile.focusWindowMinutes ?? 15
        let slot = day % 3
        let recallKnown = profile.recall.isKnown
        let recall = profile.recall.value

        // EXPLAIN once recall has a fair footing and on slot 2.
        if slot == 2, sessions.count >= 3, recall != .weak {
            return DailyPrescription(
                day: day,
                mode: .explain,
                minutes: focus,
                headline: "Explain it simply.",
                sentence: "Teaching it out loud is the fastest way to keep it.",
                goal: "Explain one idea from what you're studying.",
                reason: "You wanted to hold on to more — explaining builds memory.",
                action: "After the block, explain one idea out loud for 2 minutes.",
                actionFallback: "If explaining feels strange, write three sentences instead.",
                environmentChange: environmentChange(for: profile),
                adaptationReason: "Memory goal + three completed sessions.",
                environmentAction: nil
            )
        }

        if slot == 1 || !recallKnown || recall == .weak {
            return DailyPrescription(
                day: day,
                mode: .recall,
                minutes: focus,
                headline: "Close it. Recall it.",
                sentence: "Finishing is only half of memory — bringing it back is the rest.",
                goal: "Read, then recall without looking.",
                reason: "You told us recall matters most to you right now.",
                action: "Close the source and write down what you remember.",
                actionFallback: "If nothing comes back, one sentence is enough.",
                environmentChange: environmentChange(for: profile),
                adaptationReason: "Primary goal targets reading and memory.",
                environmentAction: nil
            )
        }

        return stayPrescription(profile: profile, sessions: sessions, day: day, distractors: profile.distractors.value ?? [])
    }

    private static func stayPrescription(profile: AttentionProfile, sessions: [SessionRecord], day: Int, distractors: [String]) -> DailyPrescription {
        let focus = profile.focusWindowMinutes ?? 15
        let reflex = profile.reflex.value
        let stability = profile.attentionStability.value
        let top = topDistractor(distractors, profile: profile)
        let env = profile.environmentEvidence
        let level = FrictionLadder.chooseLevel(env: env, distractorKnown: !distractors.isEmpty)
        let environmentAction = EnvironmentActionFactory.action(
            level: level,
            topDistractor: top,
            minutes: focus,
            env: env
        )

        let headline: String
        let sentence: String
        let reason: String
        if reflex == .high || stability == .low {
            headline = "Make switching harder."
            sentence = "The urge to switch is strongest at the start — we're making it expensive."
            reason = "You reported a short focus window and frequent switching."
        } else if sessions.count >= 2, profile.returnAfterDistraction.value == .weak {
            headline = "Return faster."
            sentence = "Distraction happens — the skill is coming back quickly."
            reason = "Returning after distraction is still the weakest link."
        } else {
            headline = "Stay with it."
            sentence = "One task, one block, no rearrangement."
            reason = "Sustained attention is the foundation of everything else."
        }

        let action = top.flatMap { Distractor.action(for: $0) } ?? Distractor.action(for: Distractor.internalRestlessness)
        let fallback = top.flatMap { Distractor.fallback(for: $0) } ?? Distractor.fallback(for: Distractor.internalRestlessness)

        return DailyPrescription(
            day: day,
            mode: .stay,
            minutes: focus,
            headline: headline,
            sentence: sentence,
            goal: "Hold one task for \(focus) minutes.",
            reason: reason,
            action: action,
            actionFallback: fallback,
            environmentChange: environmentChange(for: profile),
            adaptationReason: "STAY prescription driven by goal, distractors and observed stability.",
            environmentAction: environmentAction
        )
    }

    private static func flowPrescription(profile: AttentionProfile, sessions: [SessionRecord], day: Int) -> DailyPrescription {
        let focus = profile.focusWindowMinutes ?? 20
        return DailyPrescription(
            day: day,
            mode: .stay,
            minutes: focus,
            headline: "Find the seam.",
            sentence: "You lose track of time in the right conditions — today we look for them.",
            goal: "One block in your best conditions.",
            reason: "You want Flow — first we find where it already happens.",
            action: "Set up the conditions you told us absorb you.",
            actionFallback: "If the conditions aren't available, pick the closest hour.",
            environmentChange: environmentChange(for: profile),
            adaptationReason: "Flow goal — mapping absorption conditions.",
            environmentAction: nil
        )
    }

    private static func topDistractor(_ distractors: [String], profile: AttentionProfile) -> String? {
        let order = [Distractor.phone, Distractor.social, Distractor.notifications, Distractor.tabs, Distractor.people, Distractor.internalRestlessness]
        for d in order where distractors.contains(d) {
            return d
        }
        return distractors.first
    }

    private static func environmentChange(for profile: AttentionProfile) -> String? {
        let distractors = profile.distractors.value ?? []
        if distractors.contains(Distractor.phone) || distractors.contains(Distractor.social) {
            return "Phone in another room."
        }
        if distractors.contains(Distractor.notifications) {
            return "All notifications silenced."
        }
        if distractors.contains(Distractor.tabs) {
            return "One tab only."
        }
        if distractors.contains(Distractor.people) {
            return "Headphones on."
        }
        return nil
    }
}

// MARK: - Profile Updater (session → profile)

enum ProfileUpdater {
    static func apply(session: SessionRecord, sessionCount: Int, to profile: inout AttentionProfile) {
        let src: EvidenceSource = sessionCount >= 2 ? .repeated : .session

        // Stability: inferred from switches + difficulty
        if let switches = session.switches {
            let level: StabilityLevel = switches <= 1 ? .high : (switches <= 3 ? .medium : .low)
            if let current = profile.attentionStability.value {
                let merged = merge(current, with: level)
                profile.attentionStability = .known(merged, source: src)
            } else {
                profile.attentionStability = .known(level, source: src)
            }
        }

        // Reflex: first distraction presence
        if let first = session.firstDistraction, first != "none" {
            if let current = profile.reflex.value {
                let merged = current == .high || session.switches ?? 0 >= 4 ? ReflexLevel.high : current
                profile.reflex = .known(merged, source: src)
            } else {
                profile.reflex = .known(session.switches ?? 0 >= 4 ? .high : .medium, source: src)
            }
        } else if session.firstDistraction == "none" {
            if let current = profile.reflex.value {
                profile.reflex = .known(current == .low ? .low : .medium, source: src)
            } else {
                profile.reflex = .known(.low, source: src)
            }
        }

        // Return: completed with few switches → fair/strong
        if session.completed {
            let level: ReturnLevel = (session.switches ?? 9) <= 1 ? .strong : ((session.switches ?? 9) <= 4 ? .fair : .weak)
            if let current = profile.returnAfterDistraction.value {
                profile.returnAfterDistraction = .known(merge(current, with: level), source: src)
            } else {
                profile.returnAfterDistraction = .known(level, source: src)
            }
        }

        // Depth: completed + low difficulty suggests fair depth
        if let difficulty = session.difficulty, session.completed {
            let level: DepthLevel = difficulty <= 2 ? .deep : (difficulty <= 3 ? .fair : .shallow)
            if let current = profile.depth.value {
                profile.depth = .known(merge(current, with: level), source: src)
            } else {
                profile.depth = .known(level, source: src)
            }
        }

        // Recall: a completed RECALL session is real evidence
        if session.mode == .recall, session.completed {
            profile.recall = .known(.fair, source: src)
        }

        // Focus window: actual duration is observed evidence
        if let window = profile.focusWindowMinutes {
            profile.focusWindowMinutes = max(window, session.actualMinutes)
        } else {
            profile.focusWindowMinutes = session.actualMinutes
        }
    }

    private static func merge(_ a: StabilityLevel, with b: StabilityLevel) -> StabilityLevel {
        let order: [StabilityLevel] = [.low, .medium, .high]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }

    private static func merge(_ a: ReturnLevel, with b: ReturnLevel) -> ReturnLevel {
        let order: [ReturnLevel] = [.weak, .fair, .strong]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }

    private static func merge(_ a: DepthLevel, with b: DepthLevel) -> DepthLevel {
        let order: [DepthLevel] = [.shallow, .fair, .deep]
        let ia = order.firstIndex(of: a) ?? 1
        let ib = order.firstIndex(of: b) ?? 1
        return order[(ia + ib) / 2]
    }
}

// MARK: - Insights

enum InsightEngine {
    static func insights(profile: AttentionProfile, sessions: [SessionRecord]) -> [String] {
        guard sessions.count >= 2 else { return [] }
        var out: [String] = []

        let withAction = sessions.filter { $0.environmentActionDone == true }
        let withoutAction = sessions.filter { $0.environmentActionDone == false }
        if !withAction.isEmpty, !withoutAction.isEmpty {
            let avgWith = withAction.map(\.actualMinutes).reduce(0, +) / withAction.count
            let avgWithout = withoutAction.map(\.actualMinutes).reduce(0, +) / withoutAction.count
            if avgWith > avgWithout + 3 {
                out.append("You complete more sessions when your phone is away.")
            }
        }

        let earlySwitches = sessions.filter { ($0.firstSwitchMinute ?? 99) <= 5 }
        if earlySwitches.count >= 2, sessions.count >= 2 {
            out.append("Your first switches usually happen early.")
        }

        let recallSessions = sessions.filter { $0.mode == .recall }
        let staySessions = sessions.filter { $0.mode == .stay }
        if let recallAvg = average(recallSessions.map(\.difficulty)),
           let stayAvg = average(staySessions.map(\.difficulty)),
           recallAvg > stayAvg + 0.5 {
            out.append("Recall feels harder than sustained focus.")
        }

        return Array(out.prefix(2))
    }

    private static func average(_ values: [Int?]) -> Double? {
        let vals = values.compactMap { $0 }
        guard !vals.isEmpty else { return nil }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }
}

// MARK: - Focus line data (real only)

struct FocusLinePoint: Identifiable {
    let id = UUID()
    let minutes: Int
}

enum FocusHistory {
    static func points(sessions: [SessionRecord]) -> [FocusLinePoint] {
        sessions.suffix(7).map { FocusLinePoint(minutes: $0.actualMinutes) }
    }
}
