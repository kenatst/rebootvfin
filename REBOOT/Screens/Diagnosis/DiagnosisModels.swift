import Foundation

/// REBOOT's initial diagnosis. Purpose: establish just enough honest priors to
/// make Day 1 relevant — everything else is learned from behavior over the 90
/// days. Answers initialize hypotheses; they never become permanent identity.
///
/// Every question must change a real decision downstream (mode selection,
/// duration prior, environment setup, or editorial framing). Questions whose
/// answers REBOOT learns more accurately through sessions were removed.
struct QuestionOption: Identifiable, Equatable, Hashable {
    let value: String
    let label: String

    var id: String { value }
}

enum QuestionKind {
    case single
    case multi
}

struct Question: Identifiable {
    let id: String
    let kind: QuestionKind
    let title: String
    let hint: String?
    let options: [QuestionOption]?
    let optionsFrom: ((Answers) -> [QuestionOption])?
    let when: ((Answers) -> Bool)?
    let unknownLabel: String?

    init(
        id: String,
        kind: QuestionKind,
        title: String,
        hint: String? = nil,
        options: [QuestionOption]? = nil,
        optionsFrom: ((Answers) -> [QuestionOption])? = nil,
        when: ((Answers) -> Bool)? = nil,
        unknownLabel: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.hint = hint
        self.options = options
        self.optionsFrom = optionsFrom
        self.when = when
        self.unknownLabel = unknownLabel
    }
}

typealias Answers = [String: [String]]

enum DiagnosisModels {
    static let UNKNOWN = "__unknown__"

    // MARK: Goals

    /// What would feel meaningfully different 90 days from now.
    /// Values feed `PrescriptionEngine.selectMode` goal weighting directly.
    static let goals: [QuestionOption] = [
        .init(value: "deep_work", label: "Work deeply for longer"),
        .init(value: "scroll_less", label: "Stop compulsive checking"),
        .init(value: "focus_better", label: "Stay with one thing"),
        .init(value: "study_better", label: "Study without drifting"),
        .init(value: "read_more", label: "Read with full attention"),
        .init(value: "remember_more", label: "Remember what I consume"),
        .init(value: "finish_tasks", label: "Finish difficult tasks"),
        .init(value: "calmer_phone", label: "A calmer relationship with my phone"),
    ]

    static let goalLabel: [String: String] = Dictionary(
        uniqueKeysWithValues: goals.map { ($0.value, $0.label) }
    )

    // MARK: Use case (what the focused time is for)

    static let useCaseLabels: [String: String] = [
        "studying": "Studying",
        "creative": "Creative work",
        "professional": "Professional deep work",
        "reading": "Reading & learning",
        "building": "Building & coding",
        "general": "Attention in general",
    ]

    // MARK: Questions

    static let questions: [Question] = [
        Question(
            id: "goals",
            kind: .multi,
            title: "What would feel meaningfully different 90 days from now?",
            hint: "Choose everything that feels true.",
            options: goals
        ),
        Question(
            id: "hardest",
            kind: .single,
            title: "Which part feels hardest right now?",
            hint: "The honest one, not the most admirable one.",
            options: [
                .init(value: "starting", label: "Getting started"),
                .init(value: "staying", label: "Staying with one thing"),
                .init(value: "resisting_checking", label: "Resisting the urge to check"),
                .init(value: "returning", label: "Returning after an interruption"),
                .init(value: "remembering", label: "Remembering what I just read or watched"),
                .init(value: "slowing_noise", label: "Quieting mental noise"),
            ],
            unknownLabel: "Not sure yet"
        ),
        Question(
            id: "breaker",
            kind: .single,
            title: "Where does your attention break most?",
            hint: "Where the break actually happens, not what bothers you most.",
            options: [
                .init(value: "phone", label: "The phone"),
                .init(value: "notifications", label: "Notifications"),
                .init(value: "social", label: "Social apps"),
                .init(value: "tabs", label: "Browser tabs"),
                .init(value: "thoughts", label: "My own thoughts"),
                .init(value: "people", label: "People around me"),
                .init(value: "fatigue", label: "Tiredness"),
            ],
            unknownLabel: "Unclear"
        ),
        Question(
            id: "primary",
            kind: .single,
            title: "And if only one of these could fully change, which one?",
            hint: "This becomes the direction everything else adapts around.",
            optionsFrom: { answers in
                let picked = answers["goals"] ?? []
                return picked.map { value in
                    QuestionOption(value: value, label: goalLabel[value] ?? value)
                }
            },
            when: { ($0["goals"]?.count ?? 0) > 1 }
        ),
        Question(
            id: "focus_window",
            kind: .single,
            title: "When you start something demanding, how long before you usually feel pulled away?",
            hint: "A typical day, not your best one.",
            options: [
                .init(value: "lt5", label: "Under 5 minutes"),
                .init(value: "5_15", label: "5 – 15 minutes"),
                .init(value: "15_30", label: "15 – 30 minutes"),
                .init(value: "30_60", label: "30 – 60 minutes"),
                .init(value: "usually_60_plus", label: "Usually past an hour"),
            ],
            unknownLabel: "Depends heavily on the task"
        ),
        Question(
            id: "switch_response",
            kind: .single,
            title: "When the work becomes uncomfortable, what usually happens?",
            options: [
                .init(value: "check_phone", label: "I check my phone"),
                .init(value: "open_other", label: "I open something else"),
                .init(value: "keep_going_shallow", label: "I keep going, but it loses depth"),
                .init(value: "mind_wanders", label: "My mind wanders off"),
                .init(value: "abandon", label: "I abandon the task"),
            ],
            unknownLabel: "It varies"
        ),
        Question(
            id: "return_ability",
            kind: .single,
            title: "After getting distracted, what usually happens next?",
            options: [
                .init(value: "quick_return", label: "I come back fairly quickly"),
                .init(value: "effortful_return", label: "Returning takes real effort"),
                .init(value: "drift_elsewhere", label: "I drift into something else instead"),
                .init(value: "abandon_original", label: "The original task is usually lost"),
            ],
            unknownLabel: "It varies"
        ),
        Question(
            id: "use_case",
            kind: .single,
            title: "What kind of work matters most right now?",
            hint: "REBOOT uses your real material, so it helps to know what it is.",
            options: [
                .init(value: "studying", label: "Studying"),
                .init(value: "creative", label: "Creative work"),
                .init(value: "professional", label: "Professional deep work"),
                .init(value: "reading", label: "Reading & learning"),
                .init(value: "building", label: "Building & coding"),
            ],
            unknownLabel: "A bit of everything"
        ),
        Question(
            id: "best_time",
            kind: .single,
            title: "When does your attention naturally feel best?",
            options: [
                .init(value: "early", label: "Early morning"),
                .init(value: "morning", label: "Mid-morning"),
                .init(value: "afternoon", label: "Afternoon"),
                .init(value: "evening", label: "Evening"),
                .init(value: "night", label: "Late night"),
            ],
            unknownLabel: "No pattern I've noticed"
        ),
    ]

    // MARK: - Branching helpers

    static func has(_ answers: Answers, _ key: String, _ values: String...) -> Bool {
        let picked = answers[key] ?? []
        return values.contains { picked.contains($0) }
    }

    static func primary(_ answers: Answers) -> String {
        answers["primary"]?.first ?? ""
    }

    static func visibleQuestions(_ answers: Answers) -> [Question] {
        questions.filter { q in
            guard let when = q.when else { return true }
            return when(answers)
        }
    }

    static func optionsFor(_ q: Question, _ answers: Answers) -> [QuestionOption] {
        var base = q.optionsFrom?(answers) ?? q.options ?? []
        if let unknownLabel = q.unknownLabel {
            base.append(.init(value: UNKNOWN, label: unknownLabel))
        }
        return base
    }

    static func labelOf(_ q: Question, _ value: String, _ answers: Answers) -> String {
        optionsFor(q, answers).first { $0.value == value }?.label ?? value
    }

    static func answerLabels(_ id: String, _ answers: Answers) -> [String] {
        guard let q = questions.first(where: { $0.id == id }) else { return [] }
        let values = answers[id] ?? []
        return values.map { labelOf(q, $0, answers) }
    }

    static func isUnknown(_ id: String, _ answers: Answers) -> Bool {
        let v = answers[id] ?? []
        return v.isEmpty || v.contains(UNKNOWN)
    }

    // MARK: - Legacy answer compatibility

    /// Maps removed legacy question ids onto their closest modern equivalent so
    /// state restored from an earlier install still renders in the report.
    static let legacyAliases: [String: String] = [
        "work_break": "hardest",
        "session_target": "focus_window",
    ]
}
