import Foundation
import UserNotifications

// MARK: - Notification Preferences

struct NotificationPreferences: Codable, Equatable {
    var dailyPracticeEnabled: Bool = false
    var dailyPracticeTime: Date = defaultPracticeTime()
    var focusWindowAlertsEnabled: Bool = false
    var weeklyReviewAlertsEnabled: Bool = false

    private static func defaultPracticeTime() -> Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Notification Service

@MainActor
final class NotificationService: ObservableObject {
    @Published var preferences: NotificationPreferences
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private static let storageKey = "reboot.notifications.preferences.v1"

    static let dailyPracticeIdentifier = "reboot.notification.daily_practice"
    static let focusWindowIdentifier = "reboot.notification.focus_window"
    static let weeklyReviewIdentifier = "reboot.notification.weekly_review"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.preferences = saved
        } else {
            self.preferences = NotificationPreferences()
        }

        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Preferences Management & Scheduling

    func updatePreferences(_ newPreferences: NotificationPreferences) {
        self.preferences = newPreferences
        if let data = try? JSONEncoder().encode(newPreferences) {
            defaults.set(data, forKey: Self.storageKey)
        }
        syncScheduledNotifications()
    }

    func syncScheduledNotifications() {
        center.removeAllPendingNotificationRequests()

        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        // 1. Daily Practice Notification
        if preferences.dailyPracticeEnabled {
            scheduleDailyPracticeNotification()
        }

        // 2. Weekly Review Notification
        if preferences.weeklyReviewAlertsEnabled {
            scheduleWeeklyReviewNotification()
        }
    }

    private func scheduleDailyPracticeNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("Today's Attention Practice")
        content.body = L("Your focus session is ready. Take a few uninterrupted minutes to practice.")
        content.sound = .default

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: preferences.dailyPracticeTime)
        let minute = calendar.component(.minute, from: preferences.dailyPracticeTime)

        var triggerComponents = DateComponents()
        triggerComponents.hour = hour
        triggerComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyPracticeIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule daily practice notification: \(error)")
            }
        }
    }

    private func scheduleWeeklyReviewNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("Weekly Attention Review")
        content.body = L("A new weekly summary is available. See what REBOOT learned about your focus patterns.")
        content.sound = .default

        // Trigger on Sunday at 18:00
        var triggerComponents = DateComponents()
        triggerComponents.weekday = 1 // Sunday
        triggerComponents.hour = 18
        triggerComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.weeklyReviewIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule weekly review notification: \(error)")
            }
        }
    }

    // MARK: - Focus Window Upcoming Alert

    func scheduleFocusWindowAlert(title: String, startsInMinutes: Int) {
        guard preferences.focusWindowAlertsEnabled else { return }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = L("Focus Window Starting Soon")
        content.body = L("\"\(title)\" starts in \(startsInMinutes) minutes. Prepare your physical space.")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(60, startsInMinutes * 60)), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.focusWindowIdentifier).\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Erase-all support: removes scheduled notifications and the stored
    /// preferences, returning to the pre-permission-preference state. The OS
    /// notification authorization itself is an Apple grant and is left alone.
    func eraseAllData() {
        cancelAll()
        preferences = NotificationPreferences()
        defaults.removeObject(forKey: Self.storageKey)
    }
}
