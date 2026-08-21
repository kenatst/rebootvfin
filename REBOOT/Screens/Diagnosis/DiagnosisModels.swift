import Foundation

/// Port of `src/lib/reboot-diagnosis.ts` — same questions, branching, labels and
/// UNKNOWN semantics.
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

    static let goals: [QuestionOption] = [
        .init(value: "scroll_less", label: "Scroll less"),
        .init(value: "focus_better", label: "Focus better"),
        .init(value: "deep_work", label: "Deep work"),
        .init(value: "study_better", label: "Study better"),
        .init(value: "read_more", label: "Read more"),
        .init(value: "remember_more", label: "Remember more"),
        .init(value: "build_flow", label: "Build Flow"),
        .init(value: "phone_less", label: "Use my phone less"),
    ]

    static let goalLabel: [String: String] = Dictionary(
        uniqueKeysWithValues: goals.map { ($0.value, $0.label) }
    )

    static let questions: [Question] = [
        Question(
            id: "goals",
            kind: .multi,
            title: "Why are you here?",
            hint: "Choose everything that feels true. You can pick several.",
            options: goals
        ),
        Question(
            id: "primary",
            kind: .single,
            title: "If REBOOT could change only one, which matters most?",
            hint: "This becomes your primary goal. Everything else adapts around it.",
            optionsFrom: { answers in
                let picked = answers["goals"] ?? []
                let list = picked.isEmpty ? goals.map(\.value) : picked
                return list.map { value in
                    QuestionOption(value: value, label: goalLabel[value] ?? value)
                }
            }
        ),
        Question(
            id: "breaker",
            kind: .single,
            title: "What breaks your attention most often?",
            hint: "The one that happens most, not the worst one.",
            options: [
                .init(value: "notifications", label: "Notifications"),
                .init(value: "social", label: "Social apps"),
                .init(value: "messages", label: "Messages & email"),
                .init(value: "restlessness", label: "Internal restlessness"),
                .init(value: "people", label: "People & noise around me"),
                .init(value: "tabs", label: "My own open tabs"),
            ],
            unknownLabel: "I don't know yet"
        ),
        Question(
            id: "social_app",
            kind: .single,
            title: "Which app pulls you back the most?",
            options: [
                .init(value: "tiktok", label: "TikTok"),
                .init(value: "instagram", label: "Instagram"),
                .init(value: "youtube", label: "YouTube"),
                .init(value: "x", label: "X / Twitter"),
                .init(value: "reddit", label: "Reddit"),
                .init(value: "messaging", label: "Messaging apps"),
            ],
            when: { has($0, "goals", "scroll_less", "phone_less") || has($0, "breaker", "social", "notifications") },
            unknownLabel: "Not sure"
        ),
        Question(
            id: "phone_place",
            kind: .single,
            title: "Where is your phone while you work?",
            options: [
                .init(value: "in_hand", label: "In my hand"),
                .init(value: "on_desk", label: "On the desk, face up"),
                .init(value: "face_down", label: "On the desk, face down"),
                .init(value: "pocket", label: "In a pocket or bag"),
                .init(value: "another_room", label: "In another room"),
            ],
            when: { has($0, "goals", "scroll_less", "phone_less") },
            unknownLabel: "It varies"
        ),
        Question(
            id: "focus_window",
            kind: .single,
            title: "How long do you stay with one thing before switching?",
            hint: "Your honest average, not your best day.",
            options: [
                .init(value: "lt5", label: "Under 5 minutes"),
                .init(value: "5_15", label: "5 – 15 minutes"),
                .init(value: "15_30", label: "15 – 30 minutes"),
                .init(value: "30_60", label: "30 – 60 minutes"),
                .init(value: "gt60", label: "More than an hour"),
            ],
            unknownLabel: "I've never measured it"
        ),
        Question(
            id: "work_break",
            kind: .single,
            title: "Where does the work actually fall apart?",
            options: [
                .init(value: "starting", label: "Starting"),
                .init(value: "staying", label: "Staying in it"),
                .init(value: "returning", label: "Coming back after a break"),
                .init(value: "finishing", label: "Finishing"),
                .init(value: "choosing", label: "Choosing what to work on"),
            ],
            when: { ["focus_better", "deep_work", "study_better", "build_flow"].contains(primary($0)) },
            unknownLabel: "I don't know yet"
        ),
        Question(
            id: "reading",
            kind: .single,
            title: "What happens when you read?",
            options: [
                .init(value: "reread", label: "I reread the same lines"),
                .init(value: "drift", label: "I drift off after a page"),
                .init(value: "forget", label: "I finish but forget it"),
                .init(value: "never_start", label: "I rarely start"),
                .init(value: "screen_only", label: "I only read on a screen"),
            ],
            when: { has($0, "goals", "read_more", "study_better", "remember_more") },
            unknownLabel: "Not sure"
        ),
        Question(
            id: "recall_target",
            kind: .single,
            title: "What do you most want to hold on to?",
            options: [
                .init(value: "course", label: "Course material"),
                .init(value: "books", label: "Books & long reads"),
                .init(value: "work", label: "Work knowledge"),
                .init(value: "language", label: "A language"),
                .init(value: "ideas", label: "My own ideas"),
            ],
            when: { has($0, "goals", "remember_more", "study_better") },
            unknownLabel: "Not sure"
        ),
        Question(
            id: "environment",
            kind: .single,
            title: "Where do you usually try to work?",
            options: [
                .init(value: "home_desk", label: "A desk at home"),
                .init(value: "shared_home", label: "A shared space at home"),
                .init(value: "office", label: "An open office"),
                .init(value: "cafe", label: "Cafés & public spaces"),
                .init(value: "library", label: "A library"),
                .init(value: "moving", label: "Wherever I happen to be"),
            ],
            unknownLabel: "It changes daily"
        ),
        Question(
            id: "energy",
            kind: .single,
            title: "When is your attention naturally best?",
            options: [
                .init(value: "early", label: "Early morning"),
                .init(value: "morning", label: "Mid-morning"),
                .init(value: "afternoon", label: "Afternoon"),
                .init(value: "evening", label: "Evening"),
                .init(value: "night", label: "Late night"),
            ],
            unknownLabel: "I haven't noticed a pattern"
        ),
        Question(
            id: "absorption",
            kind: .multi,
            title: "When do you lose track of time?",
            hint: "These are the conditions REBOOT will try to reproduce.",
            options: [
                .init(value: "coding", label: "Building or coding"),
                .init(value: "writing", label: "Writing"),
                .init(value: "music", label: "Playing music"),
                .init(value: "sport", label: "Sport & movement"),
                .init(value: "games", label: "Games"),
                .init(value: "drawing", label: "Drawing or making"),
                .init(value: "conversation", label: "A good conversation"),
                .init(value: "nature", label: "Outside, walking"),
            ],
            unknownLabel: "It doesn't happen much anymore"
        ),
        Question(
            id: "flow_exit",
            kind: .single,
            title: "What usually pulls you out of Flow?",
            options: [
                .init(value: "interrupt", label: "Someone interrupts me"),
                .init(value: "hard", label: "The task gets too hard"),
                .init(value: "easy", label: "The task gets boring"),
                .init(value: "check", label: "I check something 'quickly'"),
                .init(value: "tired", label: "Energy drops"),
            ],
            when: { has($0, "goals", "build_flow") || primary($0) == "build_flow" },
            unknownLabel: "I don't know yet"
        ),
        Question(
            id: "session_target",
            kind: .single,
            title: "What would a good deep-work session look like?",
            options: [
                .init(value: "25", label: "25 focused minutes"),
                .init(value: "45", label: "45 focused minutes"),
                .init(value: "90", label: "90 focused minutes"),
                .init(value: "two_blocks", label: "Two blocks in one day"),
            ],
            unknownLabel: "I'd rather REBOOT decide"
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
}
