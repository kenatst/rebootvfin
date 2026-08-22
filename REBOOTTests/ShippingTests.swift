import XCTest
@testable import REBOOT

@MainActor
final class ShippingTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "reboot.shipping.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "reboot.shipping.tests.\(UUID().uuidString)")
        defaults = nil
        super.tearDown()
    }

    // MARK: - 1. Subscription Status & Entitlement Transitions

    func testSubscriptionStatusTransitions() {
        let freeStatus: SubscriptionStatus = .free
        XCTAssertFalse(freeStatus.isPremium)
        XCTAssertFalse(freeStatus.isTrial)
        XCTAssertEqual(freeStatus.displayLabel, "REBOOT Free")
        XCTAssertNil(freeStatus.formattedExpiry)

        let trialDate = Date().addingTimeInterval(7 * 86400)
        let trialStatus: SubscriptionStatus = .subscribed(productId: "reboot.yearly", expiresAt: trialDate, isTrial: true)
        XCTAssertTrue(trialStatus.isPremium)
        XCTAssertTrue(trialStatus.isTrial)
        XCTAssertEqual(trialStatus.displayLabel, "7-Day Free Trial")
        XCTAssertNotNil(trialStatus.formattedExpiry)

        let subDate = Date().addingTimeInterval(30 * 86400)
        let subStatus: SubscriptionStatus = .subscribed(productId: "reboot.monthly", expiresAt: subDate, isTrial: false)
        XCTAssertTrue(subStatus.isPremium)
        XCTAssertFalse(subStatus.isTrial)
        XCTAssertEqual(subStatus.displayLabel, "REBOOT Premium")

        let graceStatus: SubscriptionStatus = .gracePeriod(productId: "reboot.monthly", expiresAt: subDate)
        XCTAssertTrue(graceStatus.isPremium)

        let expiredDate = Date().addingTimeInterval(-86400)
        let expiredStatus: SubscriptionStatus = .expired(productId: "reboot.monthly", expiredAt: expiredDate)
        XCTAssertFalse(expiredStatus.isPremium)
        XCTAssertTrue(expiredStatus.formattedExpiry?.contains("Expired") ?? false)

        let revokedStatus: SubscriptionStatus = .revoked(productId: "reboot.yearly", revokedAt: expiredDate)
        XCTAssertFalse(revokedStatus.isPremium)
    }

    // MARK: - 2. Day 1 Free Baseline Gating

    func testDayOneAlwaysFreeRegardlessOfSubscription() {
        // Free tier can access Day 1
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 1, status: .free))
        XCTAssertTrue(SubscriptionGating.isDailyGuidanceAccessible(day: 1, status: .free))

        // Expired tier can access Day 1
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 1, status: .expired(productId: "reboot.monthly", expiredAt: Date())))
    }

    // MARK: - 3. Program Days 2..90 Require Premium

    func testProgramDaysTwoThroughNinetyGatedOnPremium() {
        // Free tier cannot access Day 2..90
        XCTAssertFalse(SubscriptionGating.isProgramDayAccessible(day: 2, status: .free))
        XCTAssertFalse(SubscriptionGating.isProgramDayAccessible(day: 15, status: .free))
        XCTAssertFalse(SubscriptionGating.isProgramDayAccessible(day: 90, status: .free))

        // Premium tier can access Day 2..90
        let premium: SubscriptionStatus = .subscribed(productId: "reboot.yearly", expiresAt: Date().addingTimeInterval(86400), isTrial: false)
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 2, status: premium))
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 15, status: premium))
        XCTAssertTrue(SubscriptionGating.isProgramDayAccessible(day: 90, status: premium))
    }

    // MARK: - 4. Subsystem Feature Gating

    func testSubsystemFeatureGating() {
        let free: SubscriptionStatus = .free
        let premium: SubscriptionStatus = .subscribed(productId: "reboot.yearly", expiresAt: Date().addingTimeInterval(86400), isTrial: false)

        XCTAssertFalse(SubscriptionGating.isFlowLabAccessible(status: free))
        XCTAssertTrue(SubscriptionGating.isFlowLabAccessible(status: premium))

        XCTAssertFalse(SubscriptionGating.isPersonalLabAccessible(status: free))
        XCTAssertTrue(SubscriptionGating.isPersonalLabAccessible(status: premium))

        XCTAssertFalse(SubscriptionGating.isFuelIntelligenceAccessible(status: free))
        XCTAssertTrue(SubscriptionGating.isFuelIntelligenceAccessible(status: premium))

        XCTAssertFalse(SubscriptionGating.isDigitalEnvironmentAutomationAccessible(status: free))
        XCTAssertTrue(SubscriptionGating.isDigitalEnvironmentAutomationAccessible(status: premium))

        XCTAssertFalse(SubscriptionGating.isOperatingManualAccessible(status: free))
        XCTAssertTrue(SubscriptionGating.isOperatingManualAccessible(status: premium))
    }

    // MARK: - 5. Training Modes Free vs Premium Access

    func testTrainingModesFreeVsPremiumAccess() {
        let free: SubscriptionStatus = .free
        let premium: SubscriptionStatus = .subscribed(productId: "reboot.yearly", expiresAt: Date().addingTimeInterval(86400), isTrial: false)

        // Free allows OBSERVE and NOTHING
        XCTAssertTrue(SubscriptionGating.isTrainingModeAccessible(mode: .observe, status: free))
        XCTAssertTrue(SubscriptionGating.isTrainingModeAccessible(mode: .nothing, status: free))

        // Free gates STAY, RECALL, EXPLAIN
        XCTAssertFalse(SubscriptionGating.isTrainingModeAccessible(mode: .stay, status: free))
        XCTAssertFalse(SubscriptionGating.isTrainingModeAccessible(mode: .recall, status: free))
        XCTAssertFalse(SubscriptionGating.isTrainingModeAccessible(mode: .explain, status: free))

        // Premium unlocks all modes
        for mode in TrainingMode.allCases {
            XCTAssertTrue(SubscriptionGating.isTrainingModeAccessible(mode: mode, status: premium))
        }
    }

    // MARK: - 6. Data Never Locked on Expiration

    func testDataPreservedOnExpiration() {
        let expiredStatus: SubscriptionStatus = .expired(productId: "reboot.yearly", expiredAt: Date().addingTimeInterval(-86400))

        // Existing local data remains readable
        XCTAssertTrue(SubscriptionGating.isHistoricalDataReadable(status: expiredStatus))
    }

    // MARK: - 7. Offline Cached Entitlement

    func testOfflineCachedEntitlementResilience() {
        let futureDate = Date().addingTimeInterval(30 * 86400)
        let validCache = CachedEntitlement(
            status: .subscribed(productId: "reboot.yearly", expiresAt: futureDate, isTrial: false),
            cachedAt: Date(),
            productId: "reboot.yearly",
            expirationDate: futureDate
        )
        XCTAssertTrue(validCache.isValidForOfflineUse)

        let farPastDate = Date().addingTimeInterval(-100 * 86400)
        let expiredCache = CachedEntitlement(
            status: .expired(productId: "reboot.monthly", expiredAt: farPastDate),
            cachedAt: farPastDate,
            productId: "reboot.monthly",
            expirationDate: farPastDate
        )
        XCTAssertFalse(expiredCache.isValidForOfflineUse)
    }

    // MARK: - 8. Notification Preferences & Serialization

    func testNotificationPreferencesSerialization() {
        var prefs = NotificationPreferences()
        prefs.dailyPracticeEnabled = true
        prefs.focusWindowAlertsEnabled = true
        prefs.weeklyReviewAlertsEnabled = true

        let data = try? JSONEncoder().encode(prefs)
        XCTAssertNotNil(data)

        let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data!)
        XCTAssertEqual(decoded, prefs)
        XCTAssertTrue(decoded?.dailyPracticeEnabled ?? false)
        XCTAssertTrue(decoded?.focusWindowAlertsEnabled ?? false)
    }

    // MARK: - 9. Restart Program Preserves History

    func testRestartProgramPreservesHistoricalSessions() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let record = SessionRecord(day: 1, date: Date(), mode: .observe, targetMinutes: 10, actualMinutes: 10, completed: true)
        store.apply(QASeed(sessions: [record], day: 15))

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.day, 15)

        store.restartProgram()

        // Day resets to 1, but sessions archive remains intact
        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.programState.status, .active)
    }

    // MARK: - 10. Erase All Data Resets Everything

    func testEraseAllDataResetsEverything() {
        let store = ProductStore(diagnosisAnswers: [:], defaults: defaults)
        let appState = AppState()
        appState.patch(phase: .today, screen: 3, step: 2, answers: ["q1": ["a1"]])

        let record = SessionRecord(day: 1, date: Date(), mode: .observe, targetMinutes: 10, actualMinutes: 10, completed: true)
        store.apply(QASeed(sessions: [record], day: 20))

        XCTAssertFalse(store.sessions.isEmpty)
        XCTAssertEqual(appState.phase, .today)

        store.reset()
        appState.reset()

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.day, 1)
        XCTAssertEqual(appState.phase, .cinematic)
    }
}
