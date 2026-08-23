import Foundation

/// Rules governing when REBOOT may present the paywall by itself.
///
/// Canonical conversion journey (non-negotiable):
/// onboarding → diagnosis → initial profile → Day 1 baseline → first genuine
/// insight → contextual premium continuation → Days 2–90.
///
/// REBOOT never auto-presents during onboarding, diagnosis, before Day 1,
/// on cold launch, on tab selection, or repeatedly after dismissal.
enum PaywallRules {

    /// After the user dismisses an automatic presentation, REBOOT waits this
    /// long before ever auto-presenting again. Deliberate entries from
    /// Settings or a premium action are never blocked.
    static let automaticCooldown: TimeInterval = 48 * 60 * 60

    static let lastAutomaticPresentationKey = "reboot.paywall.autoPresented.v1"

    /// May REBOOT auto-present the paywall right now? Used ONLY for the two
    /// legitimate automatic moments: the post-Day-1 continuation offer and a
    /// premium action attempt. Settings entries bypass this entirely.
    static func mayPresentAutomatically(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard let last = defaults.object(forKey: lastAutomaticPresentationKey) as? Date else {
            return true
        }
        return now.timeIntervalSince(last) >= automaticCooldown
    }

    /// Records that an automatic presentation happened (or was dismissed),
    /// starting the cooldown window.
    static func recordAutomaticPresentation(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        defaults.set(now, forKey: lastAutomaticPresentationKey)
    }
}
