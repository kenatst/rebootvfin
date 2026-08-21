import Foundation

/// Seeded product state for QA and debug navigation.
/// Every field is optional; only provided data is applied.
struct QASeed: Codable {
    var profile: AttentionProfile?
    var sessions: [SessionRecord]?
    var day: Int?
    var phase: String?
    var record: SessionRecord?
}

enum QASeeds {
    static let day1 = QASeed(profile: nil, sessions: [], day: 1, phase: nil, record: nil)

    static let stay = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("focus_better", source: .selfReport),
            goals: .known(["focus_better", "deep_work"], source: .selfReport),
            distractors: .known([Distractor.phone, Distractor.social], source: .selfReport),
            reflex: .known(.high, source: .selfReport),
            attentionStability: .known(.low, source: .selfReport),
            returnAfterDistraction: .unknown,
            recall: .unknown,
            depth: .known(.fair, source: .session),
            environment: .known("A desk at home", source: .selfReport),
            flowConditions: .known(["Building or coding"], source: .selfReport),
            energyContext: .unknown,
            focusWindowMinutes: 20
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 6), mode: .observe, targetMinutes: 15, actualMinutes: 14, completed: true, endedEarly: false, firstDistraction: "social", switches: 5, difficulty: 4, energy: nil, environmentActionDone: nil, firstSwitchMinute: 3),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 4), mode: .stay, targetMinutes: 20, actualMinutes: 12, completed: true, endedEarly: true, firstDistraction: "notifications", switches: 6, difficulty: 5, energy: nil, environmentActionDone: nil, firstSwitchMinute: 2),
            SessionRecord(day: 3, date: Date().addingTimeInterval(-86400 * 2), mode: .stay, targetMinutes: 20, actualMinutes: 19, completed: true, endedEarly: false, firstDistraction: "social", switches: 3, difficulty: 3, energy: 3, environmentActionDone: true, firstSwitchMinute: 4),
        ],
        day: 4,
        phase: nil,
        record: nil
    )

    static let recall = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("read_more", source: .selfReport),
            goals: .known(["read_more", "remember_more"], source: .selfReport),
            distractors: .known([Distractor.tabs], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .selfReport),
            returnAfterDistraction: .known(.fair, source: .session),
            recall: .known(.weak, source: .selfReport),
            depth: .known(.fair, source: .session),
            environment: .known("A library", source: .selfReport),
            flowConditions: .known(["Writing"], source: .selfReport),
            energyContext: .known("Early morning", source: .selfReport),
            focusWindowMinutes: 30
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 6), mode: .observe, targetMinutes: 15, actualMinutes: 16, completed: true, endedEarly: false, firstDistraction: "tabs", switches: 2, difficulty: 2, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 5), mode: .recall, targetMinutes: 30, actualMinutes: 27, completed: true, endedEarly: false, firstDistraction: "none", switches: 1, difficulty: 3, energy: 4, environmentActionDone: true, firstSwitchMinute: nil),
            SessionRecord(day: 3, date: Date().addingTimeInterval(-86400 * 3), mode: .recall, targetMinutes: 30, actualMinutes: 30, completed: true, endedEarly: false, firstDistraction: "none", switches: 1, difficulty: 2, energy: 4, environmentActionDone: true, firstSwitchMinute: nil),
            SessionRecord(day: 4, date: Date().addingTimeInterval(-86400 * 1), mode: .stay, targetMinutes: 30, actualMinutes: 25, completed: true, endedEarly: false, firstDistraction: "tabs", switches: 2, difficulty: 2, energy: 3, environmentActionDone: nil, firstSwitchMinute: 6),
        ],
        day: 5,
        phase: nil,
        record: nil
    )

    static let rest = QASeed(
        profile: AttentionProfile(
            primaryGoal: .known("deep_work", source: .selfReport),
            goals: .known(["deep_work"], source: .selfReport),
            distractors: .known([Distractor.internalRestlessness], source: .selfReport),
            reflex: .known(.medium, source: .selfReport),
            attentionStability: .known(.medium, source: .session),
            returnAfterDistraction: .known(.weak, source: .session),
            recall: .unknown,
            depth: .known(.shallow, source: .session),
            environment: .known("An open office", source: .selfReport),
            flowConditions: .unknown,
            energyContext: .unknown,
            focusWindowMinutes: 15
        ),
        sessions: [
            SessionRecord(day: 1, date: Date().addingTimeInterval(-86400 * 3), mode: .observe, targetMinutes: 15, actualMinutes: 15, completed: true, endedEarly: false, firstDistraction: "people", switches: 3, difficulty: 3, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil),
            SessionRecord(day: 2, date: Date().addingTimeInterval(-86400 * 1), mode: .stay, targetMinutes: 15, actualMinutes: 6, completed: true, endedEarly: true, firstDistraction: "internal", switches: 8, difficulty: 5, energy: 1, environmentActionDone: nil, firstSwitchMinute: 1),
        ],
        day: 3,
        phase: nil,
        record: nil
    )

    static let running = QASeed(
        profile: nil,
        sessions: [],
        day: 1,
        phase: "running",
        record: SessionRecord(day: 1, date: Date().addingTimeInterval(-600), mode: .observe, targetMinutes: 15, actualMinutes: 0, completed: false, endedEarly: false, firstDistraction: nil, switches: nil, difficulty: nil, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil)
    )

    static let done = QASeed(
        profile: nil,
        sessions: [],
        day: 1,
        phase: "done",
        record: SessionRecord(day: 1, date: Date().addingTimeInterval(-900), mode: .observe, targetMinutes: 15, actualMinutes: 14, completed: true, endedEarly: false, firstDistraction: nil, switches: nil, difficulty: nil, energy: nil, environmentActionDone: nil, firstSwitchMinute: nil)
    )

    static func named(_ name: String) -> QASeed? {
        switch name {
        case "day1": return day1
        case "stay": return stay
        case "recall": return recall
        case "rest": return rest
        case "running": return running
        case "done": return done
        default: return nil
        }
    }
}
