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
        .init(value: "deep_work", label: L("Work deeply for longer")),
        .init(value: "scroll_less", label: L("Stop compulsive checking")),
        .init(value: "focus_better", label: L("Stay with one thing")),
        .init(value: "study_better", label: L("Study without drifting")),
        .init(value: "read_more", label: L("Read with full attention")),
        .init(value: "remember_more", label: L("Remember what I consume")),
        .init(value: "finish_tasks", label: L("Finish difficult tasks")),
        .init(value: "calmer_phone", label: L("A calmer relationship with my phone")),
    ]

    static let goalLabel: [String: String] = Dictionary(
        uniqueKeysWithValues: goals.map { ($0.value, $0.label) }
    )

    // MARK: Use case (what the focused time is for)

    static let useCaseLabels: [String: String] = [
        "studying": L("Studying"),
        "creative": L("Creative work"),
        "professional": L("Professional deep work"),
        "reading": L("Reading & learning"),
        "building": L("Building & coding"),
        "general": L("Attention in general"),
    ]

    // MARK: Questions

    static let questions: [Question] = [
        Question(
            id: "goals",
            kind: .multi,
            title: L("What would feel meaningfully different 90 days from now?"),
            hint: L("Choose everything that feels true."),
            options: goals
        ),
        Question(
            id: "hardest",
            kind: .single,
            title: L("Which part feels hardest right now?"),
            hint: L("The honest one, not the most admirable one."),
            options: [
                .init(value: "starting", label: L("Getting started")),
                .init(value: "staying", label: L("Staying with one thing")),
                .init(value: "resisting_checking", label: L("Resisting the urge to check")),
                .init(value: "returning", label: L("Returning after an interruption")),
                .init(value: "remembering", label: L("Remembering what I just read or watched")),
                .init(value: "slowing_noise", label: L("Quieting mental noise")),
            ],
            unknownLabel: L("Not sure yet")
        ),
        Question(
            id: "breaker",
            kind: .single,
            title: L("Where does your attention break most?"),
            hint: L("Where the break actually happens, not what bothers you most."),
            options: [
                .init(value: "phone", label: L("The phone")),
                .init(value: "notifications", label: L("Notifications")),
                .init(value: "social", label: L("Social apps")),
                .init(value: "tabs", label: L("Browser tabs")),
                .init(value: "thoughts", label: L("My own thoughts")),
                .init(value: "people", label: L("People around me")),
                .init(value: "fatigue", label: L("Tiredness")),
            ],
            unknownLabel: L("Unclear")
        ),
        Question(
            id: "primary",
            kind: .single,
            title: L("And if only one of these could fully change, which one?"),
            hint: L("This becomes the direction everything else adapts around."),
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
            title: L("When you start something demanding, how long before you usually feel pulled away?"),
            hint: L("A typical day, not your best one."),
            options: [
                .init(value: "lt5", label: L("Under 5 minutes")),
                .init(value: "5_15", label: L("5 – 15 minutes")),
                .init(value: "15_30", label: L("15 – 30 minutes")),
                .init(value: "30_60", label: L("30 – 60 minutes")),
                .init(value: "usually_60_plus", label: L("Usually past an hour")),
            ],
            unknownLabel: L("Depends heavily on the task")
        ),
        Question(
            id: "switch_response",
            kind: .single,
            title: L("When the work becomes uncomfortable, what usually happens?"),
            options: [
                .init(value: "check_phone", label: L("I check my phone")),
                .init(value: "open_other", label: L("I open something else")),
                .init(value: "keep_going_shallow", label: L("I keep going, but it loses depth")),
                .init(value: "mind_wanders", label: L("My mind wanders off")),
                .init(value: "abandon", label: L("I abandon the task")),
            ],
            unknownLabel: L("It varies")
        ),
        Question(
            id: "return_ability",
            kind: .single,
            title: L("After getting distracted, what usually happens next?"),
            options: [
                .init(value: "quick_return", label: L("I come back fairly quickly")),
                .init(value: "effortful_return", label: L("Returning takes real effort")),
                .init(value: "drift_elsewhere", label: L("I drift into something else instead")),
                .init(value: "abandon_original", label: L("The original task is usually lost")),
            ],
            unknownLabel: L("It varies")
        ),
        Question(
            id: "use_case",
            kind: .single,
            title: L("What kind of work matters most right now?"),
            hint: L("REBOOT uses your real material, so it helps to know what it is."),
            options: [
                .init(value: "studying", label: L("Studying")),
                .init(value: "creative", label: L("Creative work")),
                .init(value: "professional", label: L("Professional deep work")),
                .init(value: "reading", label: L("Reading & learning")),
                .init(value: "building", label: L("Building & coding")),
            ],
            unknownLabel: L("A bit of everything")
        ),
        Question(
            id: "best_time",
            kind: .single,
            title: L("When does your attention naturally feel best?"),
            options: [
                .init(value: "early", label: L("Early morning")),
                .init(value: "morning", label: L("Mid-morning")),
                .init(value: "afternoon", label: L("Afternoon")),
                .init(value: "evening", label: L("Evening")),
                .init(value: "night", label: L("Late night")),
            ],
            unknownLabel: L("No pattern I've noticed")
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
