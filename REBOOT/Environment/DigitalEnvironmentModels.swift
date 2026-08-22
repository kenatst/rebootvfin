import Foundation
import SwiftUI

// MARK: - Core Digital Environment Dimensions

/// The primary digital category that pulls attention away from intentional work.
enum DigitalPull: String, Codable, CaseIterable, Equatable, Identifiable {
    case socialMedia = "socialMedia"
    case messaging = "messaging"
    case shortVideo = "shortVideo"
    case browserTabs = "browserTabs"
    case news = "news"
    case email = "email"
    case games = "games"
    case shopping = "shopping"
    case video = "video"
    case workNotifications = "workNotifications"
    case other = "other"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .socialMedia: return "Social feeds"
        case .messaging: return "Messaging & chats"
        case .shortVideo: return "Short video loops"
        case .browserTabs: return "Open browser tabs"
        case .news: return "News & articles"
        case .email: return "Inbox & email"
        case .games: return "Games"
        case .shopping: return "Shopping & browsing"
        case .video: return "Long video & streaming"
        case .workNotifications: return "Work notifications"
        case .other: return "Other digital pull"
        case .unknown: return "Unknown"
        }
    }

    var tagline: String {
        switch self {
        case .socialMedia: return "Infinite scroll and social updates"
        case .messaging: return "Incoming pings and quick reply reflexes"
        case .shortVideo: return "Rapid short-form algorithmic loops"
        case .browserTabs: return "Too many parallel open surfaces"
        case .news: return "Information checking and headlines"
        case .email: return "Inbox triage during deep blocks"
        case .games: return "Quick gaming sessions during pauses"
        case .shopping: return "Product research and browsing"
        case .video: return "Background videos turning into primary focus"
        case .workNotifications: return "Work communication during focused study"
        case .other: return "Specific custom apps or sites"
        case .unknown: return "Pattern still emerging"
        }
    }
}

/// The psychological or contextual trigger preceding an interruption.
enum InterruptionTrigger: String, Codable, CaseIterable, Equatable, Identifiable {
    case notification = "notification"
    case boredom = "boredom"
    case taskDifficulty = "taskDifficulty"
    case automaticUnlock = "automaticUnlock"
    case socialReflex = "socialReflex"
    case uncertainty = "uncertainty"
    case waiting = "waiting"
    case fatigue = "fatigue"
    case habit = "habit"
    case workRequirement = "workRequirement"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notification: return "Audible or visual ping"
        case .boredom: return "Momentary lull"
        case .taskDifficulty: return "Hit friction or a hard step"
        case .automaticUnlock: return "Automatic phone pickup"
        case .socialReflex: return "Wondering if someone replied"
        case .uncertainty: return "Uncertain what to do next"
        case .waiting: return "Waiting for a build or page load"
        case .fatigue: return "Mental fatigue"
        case .habit: return "Subconscious muscle memory"
        case .workRequirement: return "Legitimate work lookup"
        case .unknown: return "Unknown trigger"
        }
    }
}

/// Physical phone placement relative to the user during focused work.
enum PhoneProximity: String, Codable, CaseIterable, Equatable, Identifiable {
    case inHand = "inHand"
    case onDesk = "onDesk"
    case withinReach = "withinReach"
    case acrossRoom = "acrossRoom"
    case outsideRoom = "outsideRoom"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inHand: return "In hand"
        case .onDesk: return "On desk in line of sight"
        case .withinReach: return "Within arm's reach"
        case .acrossRoom: return "Across the room"
        case .outsideRoom: return "In another room"
        case .unknown: return "Unknown placement"
        }
    }

    var shortLabel: String {
        switch self {
        case .inHand: return "In hand"
        case .onDesk: return "On desk"
        case .withinReach: return "Arm's reach"
        case .acrossRoom: return "Across room"
        case .outsideRoom: return "Other room"
        case .unknown: return "Unknown"
        }
    }

    var frictionRating: Int {
        switch self {
        case .inHand: return 0
        case .onDesk: return 1
        case .withinReach: return 2
        case .acrossRoom: return 3
        case .outsideRoom: return 4
        case .unknown: return 0
        }
    }
}

enum InterruptionPressure: String, Codable, CaseIterable, Equatable {
    case unknown = "unknown"
    case low = "low"
    case moderate = "moderate"
    case high = "high"

    var displayLabel: String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low pressure"
        case .moderate: return "Moderate pressure"
        case .high: return "High pressure"
        }
    }
}

enum EnvironmentControlLevel: String, Codable, CaseIterable, Equatable {
    case unknown = "unknown"
    case weak = "weak"
    case developing = "developing"
    case strong = "strong"

    var displayLabel: String {
        switch self {
        case .unknown: return "Measuring"
        case .weak: return "Needs structure"
        case .developing: return "Developing control"
        case .strong: return "Resilient environment"
        }
    }
}

enum ProtectionTolerance: String, Codable, CaseIterable, Equatable {
    case unknown = "unknown"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayLabel: String {
        switch self {
        case .unknown: return "Untested"
        case .low: return "Prefers manual friction"
        case .medium: return "Tolerates session shields"
        case .high: return "Comfortable with strict boundaries"
        }
    }
}

enum FrictionLevel: String, Codable, CaseIterable, Equatable {
    case unknown = "unknown"
    case low = "low"
    case moderate = "moderate"
    case high = "high"

    var displayLabel: String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low friction"
        case .moderate: return "Moderate friction"
        case .high: return "High friction"
        }
    }
}

// MARK: - Evidence-Backed Dimension Model

/// Generic dimension wrapper that binds any discrete environment signal to real evidence.
struct EnvironmentDimension<Value: Codable & Equatable>: Codable, Equatable {
    var value: Value
    var confidence: Double
    var evidenceCount: Int
    var sources: [EvidenceSource]
    var lastUpdated: Date?
    var trend: EnvironmentTrend

    init(
        value: Value,
        confidence: Double = 0.0,
        evidenceCount: Int = 0,
        sources: [EvidenceSource] = [],
        lastUpdated: Date? = nil,
        trend: EnvironmentTrend = .unknown
    ) {
        self.value = value
        self.confidence = max(0.0, min(1.0, confidence))
        self.evidenceCount = evidenceCount
        self.sources = sources
        self.lastUpdated = lastUpdated
        self.trend = trend
    }

    var isKnown: Bool {
        evidenceCount > 0 && confidence > 0.1
    }

    static func unknown(defaultVal: Value) -> EnvironmentDimension<Value> {
        EnvironmentDimension(value: defaultVal, confidence: 0.0, evidenceCount: 0, sources: [], lastUpdated: nil, trend: .unknown)
    }
}

// MARK: - Digital Environment Profile

struct DigitalEnvironmentProfile: Codable, Equatable {
    var primaryDigitalPull: EnvironmentDimension<DigitalPull>
    var triggerType: EnvironmentDimension<InterruptionTrigger>
    var phoneProximity: EnvironmentDimension<PhoneProximity>
    var interruptionPressure: EnvironmentDimension<InterruptionPressure>
    var environmentControl: EnvironmentDimension<EnvironmentControlLevel>
    var protectionTolerance: EnvironmentDimension<ProtectionTolerance>
    var startingFriction: EnvironmentDimension<FrictionLevel>
    var returnFriction: EnvironmentDimension<FrictionLevel>

    init(
        primaryDigitalPull: EnvironmentDimension<DigitalPull> = .unknown(defaultVal: .unknown),
        triggerType: EnvironmentDimension<InterruptionTrigger> = .unknown(defaultVal: .unknown),
        phoneProximity: EnvironmentDimension<PhoneProximity> = .unknown(defaultVal: .unknown),
        interruptionPressure: EnvironmentDimension<InterruptionPressure> = .unknown(defaultVal: .unknown),
        environmentControl: EnvironmentDimension<EnvironmentControlLevel> = .unknown(defaultVal: .unknown),
        protectionTolerance: EnvironmentDimension<ProtectionTolerance> = .unknown(defaultVal: .unknown),
        startingFriction: EnvironmentDimension<FrictionLevel> = .unknown(defaultVal: .unknown),
        returnFriction: EnvironmentDimension<FrictionLevel> = .unknown(defaultVal: .unknown)
    ) {
        self.primaryDigitalPull = primaryDigitalPull
        self.triggerType = triggerType
        self.phoneProximity = phoneProximity
        self.interruptionPressure = interruptionPressure
        self.environmentControl = environmentControl
        self.protectionTolerance = protectionTolerance
        self.startingFriction = startingFriction
        self.returnFriction = returnFriction
    }

    var knownDimensionsCount: Int {
        var count = 0
        if primaryDigitalPull.isKnown && primaryDigitalPull.value != .unknown { count += 1 }
        if triggerType.isKnown && triggerType.value != .unknown { count += 1 }
        if phoneProximity.isKnown && phoneProximity.value != .unknown { count += 1 }
        if interruptionPressure.isKnown && interruptionPressure.value != .unknown { count += 1 }
        if environmentControl.isKnown && environmentControl.value != .unknown { count += 1 }
        if protectionTolerance.isKnown && protectionTolerance.value != .unknown { count += 1 }
        if startingFriction.isKnown && startingFriction.value != .unknown { count += 1 }
        if returnFriction.isKnown && returnFriction.value != .unknown { count += 1 }
        return count
    }

    var matureSignals: [String] {
        var signals: [String] = []
        if primaryDigitalPull.confidence >= 0.5 && primaryDigitalPull.value != .unknown {
            signals.append("Primary pull: \(primaryDigitalPull.value.displayName.lowercased())")
        }
        if triggerType.confidence >= 0.5 && triggerType.value != .unknown {
            signals.append("Main trigger: \(triggerType.value.displayName.lowercased())")
        }
        if phoneProximity.confidence >= 0.5 && phoneProximity.value != .unknown {
            signals.append("Usual proximity: \(phoneProximity.value.shortLabel.lowercased())")
        }
        if environmentControl.confidence >= 0.5 && environmentControl.value != .unknown {
            signals.append("Control: \(environmentControl.value.displayLabel.lowercased())")
        }
        if protectionTolerance.confidence >= 0.5 && protectionTolerance.value != .unknown {
            signals.append("Boundary tolerance: \(protectionTolerance.value.displayLabel.lowercased())")
        }
        return signals
    }

    var openQuestions: [String] {
        var questions: [String] = []
        if !primaryDigitalPull.isKnown || primaryDigitalPull.value == .unknown {
            questions.append("What is your strongest recurring digital distraction?")
        }
        if !phoneProximity.isKnown || phoneProximity.value == .unknown {
            questions.append("Does keeping your phone outside reach reduce starting friction?")
        }
        if !protectionTolerance.isKnown || protectionTolerance.value == .unknown {
            questions.append("Do active session shields feel helpful or restrictive?")
        }
        if !triggerType.isKnown || triggerType.value == .unknown {
            questions.append("What triggers your first switch away from a task?")
        }
        return questions
    }
}

// MARK: - Interruption Evidence Model

struct InterruptionEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var timestamp: Date
    var sessionID: UUID
    var programDay: Int
    var mode: TrainingMode
    var taskContext: String?
    var trigger: InterruptionTrigger
    var digitalCategory: DigitalPull
    var isIntentional: Bool
    var phonePosition: PhoneProximity
    var screenTimeProtectionState: Bool
    var firstSwitchTiming: FirstSwitchTiming?
    var switchCount: Int
    var returnObserved: Bool
    var earlyExit: Bool
    var userExplanation: String?
    var environmentCondition: String?
    var truthSource: EnvironmentVerificationState

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: UUID,
        programDay: Int,
        mode: TrainingMode,
        taskContext: String? = nil,
        trigger: InterruptionTrigger = .unknown,
        digitalCategory: DigitalPull = .unknown,
        isIntentional: Bool = false,
        phonePosition: PhoneProximity = .unknown,
        screenTimeProtectionState: Bool = false,
        firstSwitchTiming: FirstSwitchTiming? = nil,
        switchCount: Int = 1,
        returnObserved: Bool = false,
        earlyExit: Bool = false,
        userExplanation: String? = nil,
        environmentCondition: String? = nil,
        truthSource: EnvironmentVerificationState = .userReported
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.programDay = programDay
        self.mode = mode
        self.taskContext = taskContext
        self.trigger = trigger
        self.digitalCategory = digitalCategory
        self.isIntentional = isIntentional
        self.phonePosition = phonePosition
        self.screenTimeProtectionState = screenTimeProtectionState
        self.firstSwitchTiming = firstSwitchTiming
        self.switchCount = switchCount
        self.returnObserved = returnObserved
        self.earlyExit = earlyExit
        self.userExplanation = userExplanation
        self.environmentCondition = environmentCondition
        self.truthSource = truthSource
    }
}

// MARK: - Focus Windows (Scheduled Protected Calendar Windows)

struct FocusWindow: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var weekdays: Set<Int> // 1 = Sunday ... 7 = Saturday
    var startMinutes: Int // Minutes from midnight (e.g. 9 * 60 = 540)
    var endMinutes: Int // Minutes from midnight (e.g. 11 * 60 = 660)
    var linkedTaskContext: String?
    var protectionPreference: EnvironmentCondition
    var phoneRule: PhoneProximity?
    var notificationRule: String?
    var selectionID: UUID?
    var enabled: Bool
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        weekdays: Set<Int> = [2, 3, 4, 5, 6], // Mon-Fri
        startMinutes: Int = 9 * 60,
        endMinutes: Int = 11 * 60,
        linkedTaskContext: String? = nil,
        protectionPreference: EnvironmentCondition = .protectedWindow,
        phoneRule: PhoneProximity? = .outsideRoom,
        notificationRule: String? = "Focus mode",
        selectionID: UUID? = nil,
        enabled: Bool = true,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.weekdays = weekdays
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.linkedTaskContext = linkedTaskContext
        self.protectionPreference = protectionPreference
        self.phoneRule = phoneRule
        self.notificationRule = notificationRule
        self.selectionID = selectionID
        self.enabled = enabled
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var timeRangeString: String {
        let startH = startMinutes / 60
        let startM = startMinutes % 60
        let endH = endMinutes / 60
        let endM = endMinutes % 60
        return String(format: "%02d:%02d – %02d:%02d", startH, startM, endH, endM)
    }

    var weekdaysString: String {
        if weekdays.count == 7 { return "Every day" }
        if weekdays == Set([2, 3, 4, 5, 6]) { return "Weekdays" }
        if weekdays == Set([1, 7]) { return "Weekends" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().map { names[max(0, min(6, $0 - 1))] }.joined(separator: ", ")
    }

    func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else { return false }
        let mins = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if startMinutes <= endMinutes {
            return (startMinutes..<endMinutes).contains(mins)
        }
        return mins >= startMinutes || mins < endMinutes
    }
}

// MARK: - Pre-Session Setup Contract

struct PreSessionContract: Codable, Equatable {
    var phonePosition: PhoneProximity?
    var browserScope: String?
    var notificationsProtected: Bool
    var finishLineDefined: Bool
    var customCommitment: String?
    var completed: Bool

    init(
        phonePosition: PhoneProximity? = nil,
        browserScope: String? = nil,
        notificationsProtected: Bool = false,
        finishLineDefined: Bool = false,
        customCommitment: String? = nil,
        completed: Bool = false
    ) {
        self.phonePosition = phonePosition
        self.browserScope = browserScope
        self.notificationsProtected = notificationsProtected
        self.finishLineDefined = finishLineDefined
        self.customCommitment = customCommitment
        self.completed = completed
    }

    static let standard = PreSessionContract(
        phonePosition: .outsideRoom,
        browserScope: "One tab only",
        notificationsProtected: true,
        finishLineDefined: true,
        customCommitment: nil,
        completed: false
    )
}

// MARK: - Intervention Cooldown & Fatigue Log

struct InterventionCooldownLog: Codable, Equatable {
    var offeredCounts: [String: Int] = [:]
    var acceptedCounts: [String: Int] = [:]
    var rejectedCounts: [String: Int] = [:]
    var lastOfferedDates: [String: Date] = [:]
    var lastAcceptedDates: [String: Date] = [:]
    var lastFailedDates: [String: Date] = [:]
    var declinedReasons: [String: [String: Int]] = [:]

    init() {}

    mutating func recordOffer(actionKind: String, date: Date = Date()) {
        offeredCounts[actionKind, default: 0] += 1
        lastOfferedDates[actionKind] = date
    }

    mutating func recordAccept(actionKind: String, date: Date = Date()) {
        acceptedCounts[actionKind, default: 0] += 1
        lastAcceptedDates[actionKind] = date
    }

    mutating func recordDecline(actionKind: String, reason: String, date: Date = Date()) {
        rejectedCounts[actionKind, default: 0] += 1
        lastFailedDates[actionKind] = date
        var reasons = declinedReasons[actionKind, default: [:]]
        reasons[reason, default: 0] += 1
        declinedReasons[actionKind] = reasons
    }

    func isCoolingDown(actionKind: String, now: Date = Date(), cooldownDays: Int = 3) -> Bool {
        guard let lastFailed = lastFailedDates[actionKind] else { return false }
        let rejectedCount = rejectedCounts[actionKind, default: 0]
        if rejectedCount >= 2 {
            let elapsedHours = now.timeIntervalSince(lastFailed) / 3600.0
            return elapsedHours < Double(cooldownDays * 24)
        }
        return false
    }
}

// MARK: - App Limit Guidance

enum AppLimitStatus: String, Codable, Equatable {
    case offered = "offered"
    case acceptedScreenTime = "acceptedScreenTime"
    case acceptedManual = "acceptedManual"
    case declined = "declined"
    case completed = "completed"
}

struct AppLimitGuidance: Codable, Identifiable, Equatable {
    var id: UUID
    var pull: DigitalPull
    var durationMinutes: Int
    var status: AppLimitStatus
    var failureReason: String?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        pull: DigitalPull,
        durationMinutes: Int = 20,
        status: AppLimitStatus = .offered,
        failureReason: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.pull = pull
        self.durationMinutes = durationMinutes
        self.status = status
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

// MARK: - Digital Reset Missions (Curriculum Milestones)

struct DigitalResetMission: Codable, Identifiable, Equatable {
    var id: UUID
    var day: Int
    var title: String
    var rationale: String
    var instruction: String
    var completed: Bool
    var completedAt: Date?
    var reflection: String?

    init(
        id: UUID = UUID(),
        day: Int,
        title: String,
        rationale: String,
        instruction: String,
        completed: Bool = false,
        completedAt: Date? = nil,
        reflection: String? = nil
    ) {
        self.id = id
        self.day = day
        self.title = title
        self.rationale = rationale
        self.instruction = instruction
        self.completed = completed
        self.completedAt = completedAt
        self.reflection = reflection
    }
}

// MARK: - Digital Check-In Response

struct DigitalCheckInResponse: Codable, Equatable {
    var pull: DigitalPull?
    var trigger: InterruptionTrigger?
    var phonePosition: PhoneProximity?
    var wasIntentional: Bool?
    var startedEasierWithProtection: Bool?
    var neededAppForTask: Bool?
    var returnedToTask: Bool?
    var notes: String?

    init(
        pull: DigitalPull? = nil,
        trigger: InterruptionTrigger? = nil,
        phonePosition: PhoneProximity? = nil,
        wasIntentional: Bool? = nil,
        startedEasierWithProtection: Bool? = nil,
        neededAppForTask: Bool? = nil,
        returnedToTask: Bool? = nil,
        notes: String? = nil
    ) {
        self.pull = pull
        self.trigger = trigger
        self.phonePosition = phonePosition
        self.wasIntentional = wasIntentional
        self.startedEasierWithProtection = startedEasierWithProtection
        self.neededAppForTask = neededAppForTask
        self.returnedToTask = returnedToTask
        self.notes = notes
    }
}

// MARK: - Complete Digital Environment State Container

struct DigitalEnvironmentState: Codable, Equatable {
    var profile: DigitalEnvironmentProfile
    var focusWindows: [FocusWindow]
    var interruptionEvents: [InterruptionEvent]
    var interventionLog: InterventionCooldownLog
    var appLimitGuidances: [AppLimitGuidance]
    var resetMissions: [DigitalResetMission]
    var activeContract: PreSessionContract?
    var startRitualEnabled: Bool

    init(
        profile: DigitalEnvironmentProfile = DigitalEnvironmentProfile(),
        focusWindows: [FocusWindow] = [],
        interruptionEvents: [InterruptionEvent] = [],
        interventionLog: InterventionCooldownLog = InterventionCooldownLog(),
        appLimitGuidances: [AppLimitGuidance] = [],
        resetMissions: [DigitalResetMission] = [],
        activeContract: PreSessionContract? = nil,
        startRitualEnabled: Bool = true
    ) {
        self.profile = profile
        self.focusWindows = focusWindows
        self.interruptionEvents = interruptionEvents
        self.interventionLog = interventionLog
        self.appLimitGuidances = appLimitGuidances
        self.resetMissions = resetMissions
        self.activeContract = activeContract
        self.startRitualEnabled = startRitualEnabled
    }

    static let empty = DigitalEnvironmentState()
}
