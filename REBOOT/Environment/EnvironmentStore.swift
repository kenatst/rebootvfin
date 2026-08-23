import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Device-side Screen Time state. Everything stays local; activity tokens are
/// never logged and never converted to app identities.
@MainActor
final class EnvironmentStore: ObservableObject {
    @Published private(set) var capability: EnvironmentCapability = .unavailable
    @Published private(set) var selection: ProtectedSelection?
    @Published private(set) var windows: [ProtectedWindow] = []
    @Published private(set) var thresholdApproved = false
    @Published private(set) var observations: [EnvironmentObservation] = []
    @Published private(set) var activeSessionProtection = false

    private let provider: DigitalEnvironmentProvider = AppleScreenTimeProvider()
    private let center = DeviceActivityCenter()
    private static let storageKey = "reboot.environment.v1"

    var isConnected: Bool { capability.canProtect }

    var hasActiveProtectionNow: Bool {
        if activeSessionProtection { return true }
        return Self.hasScheduledProtection(in: windows, at: Date(), calendar: .current)
    }

    static func hasScheduledProtection(
        in windows: [ProtectedWindow],
        at now: Date,
        calendar: Calendar
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: now)
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return windows.contains { window in
            guard window.enabled else { return false }
            if window.startMinutes <= window.endMinutes {
                return window.weekdays.contains(weekday)
                    && (window.startMinutes..<window.endMinutes).contains(minutes)
            }
            if minutes >= window.startMinutes {
                return window.weekdays.contains(weekday)
            }
            guard minutes < window.endMinutes,
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
            let previousWeekday = calendar.component(.weekday, from: previousDay)
            return window.weekdays.contains(previousWeekday)
        }
    }

    init() {
        load()
        if activeSessionProtection {
            // Never silently extend a restriction after an interrupted session.
            provider.removeProtection()
            activeSessionProtection = false
            persist()
        }
        refreshCapability()
    }

    func refreshCapability() {
        provider.refreshCapability()
        capability = provider.capability
    }

    // MARK: - Connection

    func requestAuthorization() async -> EnvironmentCapability {
        capability = await provider.requestAuthorization()
        return capability
    }

    func saveSelection(_ familySelection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(familySelection) else { return }
        let meta = ProtectedSelection(
            data: data,
            hasApplications: !familySelection.applicationTokens.isEmpty,
            hasCategories: !familySelection.categoryTokens.isEmpty,
            hasWebDomains: !familySelection.webDomainTokens.isEmpty
        )
        selection = meta
        persist()
    }

    func clearSelection() {
        selection = nil
        persist()
    }

    // MARK: - Session protection

    func applySessionProtection() -> Bool {
        guard let selection else { return false }
        let ok = provider.apply(selection: selection)
        if ok {
            activeSessionProtection = true
            persist()
        }
        return ok
    }

    func removeSessionProtection() {
        provider.removeProtection()
        activeSessionProtection = false
        persist()
    }

    // MARK: - Threshold approval (single minimal rule)

    func setThresholdApproved(_ approved: Bool) {
        thresholdApproved = approved
        windows.forEach { upsertMonitoring(for: $0) }
        persist()
    }

    // MARK: - Windows

    func upsertWindow(_ window: ProtectedWindow) {
        if let idx = windows.firstIndex(where: { $0.id == window.id }) {
            windows[idx] = window
        } else {
            windows.append(window)
        }
        upsertMonitoring(for: window)
        persist()
    }

    func deleteWindow(_ window: ProtectedWindow) {
        windows.removeAll { $0.id == window.id }
        center.stopMonitoring([DeviceActivityName(window.deviceActivityName)])
        persist()
    }

    private func upsertMonitoring(for window: ProtectedWindow) {
        guard window.enabled, let selectionData = selection?.data,
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) else {
            center.stopMonitoring([DeviceActivityName(window.deviceActivityName)])
            return
        }

        // One weekly-repeating schedule per selected weekday (Calendar: 1 = Sunday).
        for weekday in window.weekdays.sorted() {
            let name = DeviceActivityName("\(window.deviceActivityName).\(weekday)")
            var start = DateComponents()
            start.hour = window.startMinutes / 60
            start.minute = window.startMinutes % 60
            start.weekday = weekday
            var end = DateComponents()
            end.hour = window.endMinutes / 60
            end.minute = window.endMinutes % 60
            end.weekday = weekday
            let schedule = DeviceActivitySchedule(
                intervalStart: start,
                intervalEnd: end,
                repeats: true
            )
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            if thresholdApproved {
                var threshold = DateComponents()
                threshold.minute = 20
                events[DeviceActivityEvent.Name("reboot.threshold.daily")] = DeviceActivityEvent(
                    applications: decoded.applicationTokens,
                    categories: decoded.categoryTokens,
                    webDomains: decoded.webDomainTokens,
                    threshold: threshold
                )
            }
            do {
                try center.startMonitoring(name, during: schedule, events: events)
            } catch {
                // Entitlement/profile missing or unsupported region: stay silent,
                // REBOOT keeps working with manual interventions.
            }
        }
    }

    // MARK: - Threshold event ingestion (from the monitor extension, app group)

    func ingestThresholdEvents() {
        guard let url = sharedContainerURL?.appendingPathComponent("threshold-events.json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([ThresholdEventRecord].self, from: data) else {
            return
        }
        for event in events where !observations.contains(where: { $0.date == event.date }) {
            observations.append(
                EnvironmentObservation(
                    date: event.date,
                    condition: .threshold,
                    minutes: 0,
                    completed: false,
                    endedEarly: false,
                    difficulty: nil,
                    switches: nil,
                    startedEasier: nil
                )
            )
        }
        persist()
    }

    func appendObservation(_ observation: EnvironmentObservation) {
        observations.append(observation)
        persist()
    }

    /// Erase-all support: stops every scheduled DeviceActivity monitor, removes
    /// any active protection, clears the shared threshold-event file and wipes
    /// this store's persisted state. Screen Time authorization itself is an OS
    /// grant and cannot be revoked by the app.
    func eraseAllData() {
        provider.removeProtection()
        activeSessionProtection = false
        let names = windows.map { DeviceActivityName($0.deviceActivityName) }
        if !names.isEmpty {
            center.stopMonitoring(names)
        }
        windows = []
        selection = nil
        thresholdApproved = false
        observations = []
        if let url = sharedContainerURL?.appendingPathComponent("threshold-events.json") {
            try? FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        refreshCapability()
    }

    var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kenatst.reboot")
    }

    // MARK: - Persistence

    private func load() {
        guard let raw = UserDefaults.standard.dictionary(forKey: Self.storageKey),
              let data = raw["selection"] as? Data,
              let selection = try? JSONDecoder().decode(ProtectedSelection.self, from: data) else {
            return
        }
        self.selection = selection
        if let windowsData = raw["windows"] as? Data,
           let windows = try? JSONDecoder().decode([ProtectedWindow].self, from: windowsData) {
            self.windows = windows
        }
        thresholdApproved = (raw["thresholdApproved"] as? Bool) ?? false
        activeSessionProtection = (raw["activeSessionProtection"] as? Bool) ?? false
        if let obsData = raw["observations"] as? Data,
           let observations = try? JSONDecoder().decode([EnvironmentObservation].self, from: obsData) {
            self.observations = observations
        }
    }

    private func persist() {
        let payload: [String: Any] = [
            "selection": (try? JSONEncoder().encode(selection)) ?? Data(),
            "windows": (try? JSONEncoder().encode(windows)) ?? Data(),
            "thresholdApproved": thresholdApproved,
            "observations": (try? JSONEncoder().encode(observations)) ?? Data(),
            "activeSessionProtection": activeSessionProtection,
        ]
        UserDefaults.standard.set(payload, forKey: Self.storageKey)
    }
}

/// Minimal shared record written by the Device Activity monitor extension.
/// Contains only our own event names and timestamps — never Apple tokens.
struct ThresholdEventRecord: Codable, Equatable {
    var name: String
    var date: Date
}
