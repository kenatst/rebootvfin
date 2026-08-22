import Foundation

// MARK: - Fuel dimensions (all self-reported, all optional, unknown stays unknown)

enum FuelEnergyLevel: String, Codable, CaseIterable, Equatable {
    case low, okay, high

    var label: String {
        switch self {
        case .low: return "Low"
        case .okay: return "Okay"
        case .high: return "High"
        }
    }
}

enum FuelSleepQuality: String, Codable, CaseIterable, Equatable {
    case rough, normal, good

    var label: String {
        switch self {
        case .rough: return "Rough"
        case .normal: return "Normal"
        case .good: return "Good"
        }
    }
}

enum FuelSleepDurationBand: String, Codable, CaseIterable, Equatable {
    case short, usual, long, unknown

    var label: String {
        switch self {
        case .short: return "Short"
        case .usual: return "Usual"
        case .long: return "Long"
        case .unknown: return "Not sure"
        }
    }
}

enum FuelCaffeineRecency: String, Codable, CaseIterable, Equatable {
    case noneRecently, earlier, recently

    var label: String {
        switch self {
        case .noneRecently: return "None recently"
        case .earlier: return "Earlier"
        case .recently: return "Recently"
        }
    }
}

enum FuelMealTiming: String, Codable, CaseIterable, Equatable {
    case beforeUsualMeal, recentlyAte, betweenMeals

    var label: String {
        switch self {
        case .beforeUsualMeal: return "Before a usual meal"
        case .recentlyAte: return "Recently ate"
        case .betweenMeals: return "Between meals"
        }
    }
}

enum FuelSatiety: String, Codable, CaseIterable, Equatable {
    case hungry, neutral, comfortablyFull, veryFull

    var label: String {
        switch self {
        case .hungry: return "Hungry"
        case .neutral: return "Neutral"
        case .comfortablyFull: return "Comfortably full"
        case .veryFull: return "Very full"
        }
    }
}

enum FuelHydrationFeeling: String, Codable, CaseIterable, Equatable {
    case thirsty, fine, notSure

    var label: String {
        switch self {
        case .thirsty: return "Thirsty"
        case .fine: return "Fine"
        case .notSure: return "Not sure"
        }
    }
}

enum FuelMovementContext: String, Codable, CaseIterable, Equatable {
    case mostlyStill
    case activeEarlier
    case shortWalkBefore

    var label: String {
        switch self {
        case .mostlyStill: return "Mostly still"
        case .activeEarlier: return "Active earlier"
        case .shortWalkBefore: return "Short walk before"
        }
    }
}

enum FuelBreakState: String, Codable, CaseIterable, Equatable {
    case fresh, workedForAWhile, returningFromBreak

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .workedForAWhile: return "Worked for a while"
        case .returningFromBreak: return "Returning from a break"
        }
    }
}

enum FuelBreakType: String, Codable, CaseIterable, Equatable {
    case noInput, walk, conversation, screenFeed, other

    var label: String {
        switch self {
        case .noInput: return "No-input break"
        case .walk: return "Walk"
        case .conversation: return "Conversation"
        case .screenFeed: return "Screen / feed"
        case .other: return "Other"
        }
    }
}

enum FuelTaskContext: String, Codable, CaseIterable, Equatable {
    case focusedWork, study, reading, writing, creative, admin, coding, other

    var label: String {
        switch self {
        case .focusedWork: return "Focused work"
        case .study: return "Study"
        case .reading: return "Reading"
        case .writing: return "Writing"
        case .creative: return "Creative"
        case .admin: return "Admin"
        case .coding: return "Coding / building"
        case .other: return "Other"
        }
    }
}

/// Derived automatically from the session timestamp — never asked.
enum FuelDaypart: String, Codable, CaseIterable, Equatable {
    case morning, afternoon, evening, late

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .late: return "Late"
        }
    }

    static func derive(from date: Date, calendar: Calendar = .current) -> FuelDaypart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5...11: return .morning
        case 12...16: return .afternoon
        case 17...21: return .evening
        default: return .late
        }
    }
}

// MARK: - Capture source (manual provenance; HealthKit is a future provider)

enum FuelCaptureSource: String, Codable, Equatable {
    case manual

    var label: String {
        switch self {
        case .manual: return "Self-reported"
        }
    }
}

// MARK: - Addressable fields

/// Fields Fuel can know about. Daypart is intentionally absent: it is always
/// derived from the session timestamp and never prompted.
enum FuelContextField: String, Codable, CaseIterable, Equatable, Hashable {
    case energy
    case sleepQuality
    case sleepDurationBand
    case caffeineRecency
    case mealTiming
    case satiety
    case movement
    case breakState
    case breakType
    case hydrationFeeling
    case taskContext

    var label: String {
        switch self {
        case .energy: return "Energy"
        case .sleepQuality: return "Sleep"
        case .sleepDurationBand: return "Sleep length"
        case .caffeineRecency: return "Caffeine"
        case .mealTiming: return "Meal timing"
        case .satiety: return "Fullness"
        case .movement: return "Movement"
        case .breakState: return "Break state"
        case .breakType: return "Break type"
        case .hydrationFeeling: return "Hydration"
        case .taskContext: return "Task type"
        }
    }

    /// Every field may be sampled through one optional prompt. None is ever
    /// required; skipping is always a complete answer.
    var promptable: Bool { true }
}

// MARK: - Snapshot

/// A pre-session context snapshot. Every field is optional: a snapshot with
/// one answered field is complete and honest. Historical snapshots attached
/// to saved sessions are never rewritten later.
///
/// Precedence note: `energy` here is PRE-session self-reported context
/// (Low/Okay/High). `SessionRecord.energy` is the separate POST-session
/// reflection scale (1–5). The two are intentionally distinct and never
/// overwrite each other.
struct FuelContextSnapshot: Codable, Equatable {
    var energy: FuelEnergyLevel?
    var sleepQuality: FuelSleepQuality?
    var sleepDurationBand: FuelSleepDurationBand?
    var caffeineRecency: FuelCaffeineRecency?
    var mealTiming: FuelMealTiming?
    var satiety: FuelSatiety?
    var movement: FuelMovementContext?
    var breakState: FuelBreakState?
    var breakType: FuelBreakType?
    var hydrationFeeling: FuelHydrationFeeling?
    var taskContext: FuelTaskContext?
    var captureSource: FuelCaptureSource = .manual
    var capturedAt: Date = Date()

    var knownFieldCount: Int {
        let values: [EquatableVoid?] = [
            energy.map(EquatableVoid.init),
            sleepQuality.map(EquatableVoid.init),
            sleepDurationBand.map(EquatableVoid.init),
            caffeineRecency.map(EquatableVoid.init),
            mealTiming.map(EquatableVoid.init),
            satiety.map(EquatableVoid.init),
            movement.map(EquatableVoid.init),
            breakState.map(EquatableVoid.init),
            breakType.map(EquatableVoid.init),
            hydrationFeeling.map(EquatableVoid.init),
            taskContext.map(EquatableVoid.init),
        ]
        return values.compactMap { $0 }.count
    }

    var isEmpty: Bool { knownFieldCount == 0 }

    enum CodingKeys: String, CodingKey {
        case energy, sleepQuality, sleepDurationBand, caffeineRecency, mealTiming
        case satiety, movement, breakState, breakType, hydrationFeeling, taskContext
        case captureSource, capturedAt
    }

    init(
        energy: FuelEnergyLevel? = nil,
        sleepQuality: FuelSleepQuality? = nil,
        sleepDurationBand: FuelSleepDurationBand? = nil,
        caffeineRecency: FuelCaffeineRecency? = nil,
        mealTiming: FuelMealTiming? = nil,
        satiety: FuelSatiety? = nil,
        movement: FuelMovementContext? = nil,
        breakState: FuelBreakState? = nil,
        breakType: FuelBreakType? = nil,
        hydrationFeeling: FuelHydrationFeeling? = nil,
        taskContext: FuelTaskContext? = nil,
        captureSource: FuelCaptureSource = .manual,
        capturedAt: Date = Date()
    ) {
        self.energy = energy
        self.sleepQuality = sleepQuality
        self.sleepDurationBand = sleepDurationBand
        self.caffeineRecency = caffeineRecency
        self.mealTiming = mealTiming
        self.satiety = satiety
        self.movement = movement
        self.breakState = breakState
        self.breakType = breakType
        self.hydrationFeeling = hydrationFeeling
        self.taskContext = taskContext
        self.captureSource = captureSource
        self.capturedAt = capturedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        energy = try? values.decodeIfPresent(FuelEnergyLevel.self, forKey: .energy)
        sleepQuality = try? values.decodeIfPresent(FuelSleepQuality.self, forKey: .sleepQuality)
        sleepDurationBand = try? values.decodeIfPresent(FuelSleepDurationBand.self, forKey: .sleepDurationBand)
        caffeineRecency = try? values.decodeIfPresent(FuelCaffeineRecency.self, forKey: .caffeineRecency)
        mealTiming = try? values.decodeIfPresent(FuelMealTiming.self, forKey: .mealTiming)
        satiety = try? values.decodeIfPresent(FuelSatiety.self, forKey: .satiety)
        movement = try? values.decodeIfPresent(FuelMovementContext.self, forKey: .movement)
        breakState = try? values.decodeIfPresent(FuelBreakState.self, forKey: .breakState)
        breakType = try? values.decodeIfPresent(FuelBreakType.self, forKey: .breakType)
        hydrationFeeling = try? values.decodeIfPresent(FuelHydrationFeeling.self, forKey: .hydrationFeeling)
        taskContext = try? values.decodeIfPresent(FuelTaskContext.self, forKey: .taskContext)
        captureSource = (try? values.decodeIfPresent(FuelCaptureSource.self, forKey: .captureSource)) ?? .manual
        capturedAt = (try? values.decodeIfPresent(Date.self, forKey: .capturedAt)) ?? Date()
    }

    func value(for field: FuelContextField) -> String? {
        switch field {
        case .energy: return energy?.rawValue
        case .sleepQuality: return sleepQuality?.rawValue
        case .sleepDurationBand: return sleepDurationBand?.rawValue
        case .caffeineRecency: return caffeineRecency?.rawValue
        case .mealTiming: return mealTiming?.rawValue
        case .satiety: return satiety?.rawValue
        case .movement: return movement?.rawValue
        case .breakState: return breakState?.rawValue
        case .breakType: return breakType?.rawValue
        case .hydrationFeeling: return hydrationFeeling?.rawValue
        case .taskContext: return taskContext?.rawValue
        }
    }

    func with(field: FuelContextField, rawValue: String) -> FuelContextSnapshot {
        var snapshot = self
        switch field {
        case .energy: snapshot.energy = FuelEnergyLevel(rawValue: rawValue)
        case .sleepQuality: snapshot.sleepQuality = FuelSleepQuality(rawValue: rawValue)
        case .sleepDurationBand: snapshot.sleepDurationBand = FuelSleepDurationBand(rawValue: rawValue)
        case .caffeineRecency: snapshot.caffeineRecency = FuelCaffeineRecency(rawValue: rawValue)
        case .mealTiming: snapshot.mealTiming = FuelMealTiming(rawValue: rawValue)
        case .satiety: snapshot.satiety = FuelSatiety(rawValue: rawValue)
        case .movement: snapshot.movement = FuelMovementContext(rawValue: rawValue)
        case .breakState: snapshot.breakState = FuelBreakState(rawValue: rawValue)
        case .breakType: snapshot.breakType = FuelBreakType(rawValue: rawValue)
        case .hydrationFeeling: snapshot.hydrationFeeling = FuelHydrationFeeling(rawValue: rawValue)
        case .taskContext: snapshot.taskContext = FuelTaskContext(rawValue: rawValue)
        }
        return snapshot
    }

    /// Qualitative daypart derived from the capture timestamp.
    var daypart: FuelDaypart { FuelDaypart.derive(from: capturedAt) }

    /// Short summary lines for restrained display, e.g. "Energy · Okay".
    var summaryLines: [String] {
        var lines: [String] = []
        if let energy { lines.append("Energy · \(energy.label)") }
        if let sleepQuality { lines.append("Sleep · \(sleepQuality.label)") }
        if let caffeineRecency { lines.append("Caffeine · \(caffeineRecency.label)") }
        if let mealTiming { lines.append("Meals · \(mealTiming.label)") }
        if let movement { lines.append("Movement · \(movement.label)") }
        if let breakState { lines.append("Break · \(breakState.label)") }
        return lines
    }
}

private struct EquatableVoid: Equatable {
    init<T>(_ value: T) {}
}

// MARK: - Provider abstraction

/// Fuel never assumes all context must come from forms forever. A provider
/// resolves fields; the manual provider resolves only what the user answered.
/// A future HealthContextProvider can resolve fields without prompting.
protocol FuelContextProviding {
    var id: String { get }
    var displayName: String { get }
    /// Fields this provider can resolve without asking the user.
    func autoResolvedFields() -> [FuelContextField]
}

struct ManualFuelContextProvider: FuelContextProviding {
    let id = "manual"
    let displayName = "Self-reported"

    func autoResolvedFields() -> [FuelContextField] { [] }
}
