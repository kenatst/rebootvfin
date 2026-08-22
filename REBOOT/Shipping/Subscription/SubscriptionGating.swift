import Foundation

enum SubscriptionGating {

    // MARK: - Program Gating

    /// Day 1 Baseline is always 100% free to allow users to experience REBOOT and establish a baseline.
    /// Days 2..90 require active premium subscription.
    static func isProgramDayAccessible(day: Int, status: SubscriptionStatus) -> Bool {
        if day <= 1 {
            return true
        }
        return status.isPremium
    }

    // MARK: - Feature Gating

    static func isDailyGuidanceAccessible(day: Int, status: SubscriptionStatus) -> Bool {
        if day <= 1 {
            return true
        }
        return status.isPremium
    }

    static func isFlowLabAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    static func isPersonalLabAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    static func isFuelIntelligenceAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    static func isDigitalEnvironmentAutomationAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    static func isOperatingManualAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    static func isOwnModeAccessible(status: SubscriptionStatus) -> Bool {
        status.isPremium
    }

    /// Free training modes available on free tier: OBSERVE and NOTHING.
    static func isTrainingModeAccessible(mode: TrainingMode, status: SubscriptionStatus) -> Bool {
        if status.isPremium { return true }
        return mode == .observe || mode == .nothing
    }

    // MARK: - Data Integrity (Never Lock Existing Local User Data)

    /// Historical session data, personal rules created, and profile summaries are ALWAYS accessible
    /// even if the user's subscription expires.
    static func isHistoricalDataReadable(status: SubscriptionStatus) -> Bool {
        true
    }
}
