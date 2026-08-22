import Foundation

// MARK: - Sampling state (persisted in v7)

/// Respectful limits: one optional prompt per protocol session at most, and
/// repeated skips make a field quieter — no guilt, no warnings.
struct FuelSamplingLog: Codable, Equatable {
    /// Field raw value → last time a prompt for it was shown.
    var lastPromptAt: [String: Date] = [:]
    /// Field raw value → times the user skipped.
    var skipCounts: [String: Int] = [:]
    /// Field raw value → times the user answered.
    var answeredCounts: [String: Int] = [:]
    /// Calendar day (days since reference date) of the last prompt shown.
    var lastPromptDay: Int = -1

    static let empty = FuelSamplingLog()
}

struct FuelState: Codable, Equatable {
    /// Fuel is optional. Disabling prompts keeps every other system intact.
    var promptsEnabled: Bool = true
    var sampling = FuelSamplingLog()
    /// Pre-session answers waiting to attach to today's next protocol session.
    var pendingCapture: FuelContextSnapshot?

    static let empty = FuelState()

    mutating func recordAnswer(field: FuelContextField, now: Date = Date()) {
        sampling.answeredCounts[field.rawValue, default: 0] += 1
        sampling.lastPromptAt[field.rawValue] = now
        sampling.lastPromptDay = Self.calendarDay(now)
    }

    mutating func recordSkip(field: FuelContextField, now: Date = Date()) {
        sampling.skipCounts[field.rawValue, default: 0] += 1
        sampling.lastPromptAt[field.rawValue] = now
        sampling.lastPromptDay = Self.calendarDay(now)
    }

    static func calendarDay(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: ReferenceDate.date), to: date).day ?? 0
    }
}

/// Fixed anchor so calendar-day gating stays deterministic in tests.
enum ReferenceDate {
    static let date: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()
}

// MARK: - Prompt

struct FuelSampleOption: Equatable, Identifiable {
    var id: String { rawValue }
    var rawValue: String
    var label: String
}

struct FuelSamplePrompt: Equatable, Identifiable {
    var id: String { field.rawValue }
    var field: FuelContextField
    var question: String
    var options: [FuelSampleOption]
    var skipLabel: String = "Skip"
}

// MARK: - Deterministic sampling engine

/// Decides which single unresolved Fuel field (if any) would currently be most
/// useful to sample before a protocol session. Output is zero or one prompt.
enum ContextSamplingEngine {
    struct Inputs {
        var programDay: Int
        var completedProtocolDays: Int
        var phase: ProgramPhaseID
        var isRecoveryPrescribed: Bool
        var promptsEnabled: Bool
        /// An active deliberate Fuel test (walk, no-input break) owns the one
        /// deliberate variable; generic sampling stays silent.
        var activeFuelConditionTest: Bool
        /// An active observational comparison still needs this field. It takes
        /// priority over generic sampling, but remains optional and skippable.
        var preferredField: FuelContextField?
        /// Today's already-captured pending answers (a needed field already
        /// answered must not be asked again).
        var pendingCapture: FuelContextSnapshot?
        var log: FuelSamplingLog
        var now: Date = Date()

        init(
            programDay: Int,
            completedProtocolDays: Int,
            phase: ProgramPhaseID,
            isRecoveryPrescribed: Bool = false,
            promptsEnabled: Bool = true,
            activeFuelConditionTest: Bool = false,
            preferredField: FuelContextField? = nil,
            pendingCapture: FuelContextSnapshot? = nil,
            log: FuelSamplingLog = .empty,
            now: Date = Date()
        ) {
            self.programDay = programDay
            self.completedProtocolDays = completedProtocolDays
            self.phase = phase
            self.isRecoveryPrescribed = isRecoveryPrescribed
            self.promptsEnabled = promptsEnabled
            self.activeFuelConditionTest = activeFuelConditionTest
            self.preferredField = preferredField
            self.pendingCapture = pendingCapture
            self.log = log
            self.now = now
        }
    }

    /// Base cooldown in days between prompts for the same field.
    static let baseFieldCooldownDays: Double = 7
    /// Hard ceiling for the per-field cooldown as skips accumulate.
    static let maxFieldCooldownDays: Double = 28
    /// Days between any prompts while still calibrating (Phase 1 stays minimal).
    static let phaseCooldownDays: [ProgramPhaseID: Double] = [
        .calibrate: 6,
        .controlInput: 3,
        .buildStability: 3,
        .deepen: 3,
        .findConditions: 2,
        .ownSystem: 3,
    ]

    static func recommendPrompt(_ inputs: Inputs) -> FuelSamplePrompt? {
        guard inputs.promptsEnabled else { return nil }
        // Day 1 is sacred: no Fuel prompting before a natural baseline exists.
        guard inputs.completedProtocolDays >= 1, inputs.programDay > 1 else { return nil }
        // Recovery is authoritative and never interrupted by context questions.
        guard !inputs.isRecoveryPrescribed else { return nil }
        // One deliberate variable at a time when Lab owns a Fuel condition.
        guard !inputs.activeFuelConditionTest else { return nil }
        // At most one prompt per protocol session (≈ one per calendar day).
        guard inputs.log.lastPromptDay < FuelState.calendarDay(inputs.now) else { return nil }

        // An active observational comparison needs one specific field; the
        // generic per-field cooldown must not block what the test waits on.
        // Repeated skips still quiet it — respect wins over impatience.
        if let needed = inputs.preferredField,
           inputs.pendingCapture?.value(for: needed) == nil {
            if let lastShown = inputs.log.lastPromptAt[needed.rawValue] {
                let skips = Double(inputs.log.skipCounts[needed.rawValue] ?? 0)
                let neededCooldown = min(2.0 + skips * 2.0, 7.0)
                if inputs.now.timeIntervalSince(lastShown) < neededCooldown * 86_400 {
                    return nil
                }
            }
            return prompt(for: needed)
        }

        let lastPrompt = inputs.log.lastPromptAt.values.max()
        if let lastPrompt {
            let cooldown = phaseCooldownDays[inputs.phase] ?? 3
            guard inputs.now.timeIntervalSince(lastPrompt) >= cooldown * 86_400 else { return nil }
        }

        let candidates = FuelContextField.allCases.filter { field in
            field.promptable && !fieldInCooldown(field, inputs: inputs)
        }
        guard let field = candidates.min(by: { lhs, rhs in
            let lhsCount = inputs.log.answeredCounts[lhs.rawValue] ?? 0
            let rhsCount = inputs.log.answeredCounts[rhs.rawValue] ?? 0
            if lhsCount != rhsCount { return lhsCount < rhsCount }
            return order(lhs) < order(rhs)
        }) else { return nil }
        return prompt(for: field)
    }

    static func fieldInCooldown(_ field: FuelContextField, inputs: Inputs, now: Date = Date()) -> Bool {
        guard let lastShown = inputs.log.lastPromptAt[field.rawValue] else { return false }
        let skips = Double(inputs.log.skipCounts[field.rawValue] ?? 0)
        let answers = Double(inputs.log.answeredCounts[field.rawValue] ?? 0)
        var cooldown = baseFieldCooldownDays + skips * 7
        if answers >= 8 { cooldown = max(cooldown, maxFieldCooldownDays) }
        cooldown = min(cooldown, maxFieldCooldownDays)
        return now.timeIntervalSince(lastShown) < cooldown * 86_400
    }

    /// Deterministic preference order among equally-sampled fields.
    private static func order(_ field: FuelContextField) -> Int {
        switch field {
        case .energy: return 0
        case .sleepQuality: return 1
        case .mealTiming: return 2
        case .caffeineRecency: return 3
        case .movement: return 4
        case .breakState: return 5
        case .hydrationFeeling: return 6
        case .satiety: return 7
        case .breakType: return 8
        case .sleepDurationBand: return 9
        case .taskContext: return 10
        }
    }

    static func prompt(for field: FuelContextField) -> FuelSamplePrompt {
        switch field {
        case .energy:
            return FuelSamplePrompt(
                field: .energy,
                question: "How's your energy right now?",
                options: FuelEnergyLevel.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .sleepQuality:
            return FuelSamplePrompt(
                field: .sleepQuality,
                question: "How did sleep feel?",
                options: FuelSleepQuality.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .sleepDurationBand:
            return FuelSamplePrompt(
                field: .sleepDurationBand,
                question: "Sleep length compared to usual?",
                options: FuelSleepDurationBand.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .caffeineRecency:
            return FuelSamplePrompt(
                field: .caffeineRecency,
                question: "Any caffeine recently?",
                options: FuelCaffeineRecency.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .mealTiming:
            return FuelSamplePrompt(
                field: .mealTiming,
                question: "Where are you relative to a meal?",
                options: FuelMealTiming.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .satiety:
            return FuelSamplePrompt(
                field: .satiety,
                question: "How full do you feel?",
                options: FuelSatiety.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .movement:
            return FuelSamplePrompt(
                field: .movement,
                question: "Movement before this session?",
                options: FuelMovementContext.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .breakState:
            return FuelSamplePrompt(
                field: .breakState,
                question: "Starting fresh or returning?",
                options: FuelBreakState.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .breakType:
            return FuelSamplePrompt(
                field: .breakType,
                question: "If you took a break, what kind?",
                options: FuelBreakType.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .hydrationFeeling:
            return FuelSamplePrompt(
                field: .hydrationFeeling,
                question: "How's your thirst?",
                options: FuelHydrationFeeling.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        case .taskContext:
            return FuelSamplePrompt(
                field: .taskContext,
                question: "What kind of work is this?",
                options: FuelTaskContext.allCases.map { FuelSampleOption(rawValue: $0.rawValue, label: $0.label) }
            )
        }
    }
}
