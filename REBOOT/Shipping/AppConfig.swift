import Foundation

/// Centralized commercial and application configuration for REBOOT.
/// Centralizes product identifiers, legal link placeholders, support contacts, and version metadata.
enum AppConfig {
    static let appName = "REBOOT"
    static let bundleID = "com.kenatst.reboot"
    static let appGroupID = "group.com.kenatst.reboot"

    // MARK: - StoreKit Product Identifiers
    static let monthlyProductID = "reboot.monthly"
    static let yearlyProductID = "reboot.yearly"
    static let allProductIDs = [monthlyProductID, yearlyProductID]

    // MARK: - Support & Legal Placeholders
    static let supportEmail = "support@rebootattention.com"
    static let privacyPolicyURL = URL(string: "https://rebootattention.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://rebootattention.com/terms")!
    static let websiteURL = URL(string: "https://rebootattention.com")!

    // MARK: - Version & Build Metadata
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var fullVersionString: String {
        "Version \(appVersion) (\(appBuild))"
    }

    // MARK: - Non-Medical Integrity Statement
    static let medicalDisclaimer = """
    REBOOT is an attention training protocol and personal operating manual designed to help users build sustained focus and reduce digital distraction. It is not a medical device, nor is it intended to diagnose, treat, prevent, or cure ADHD or any other clinical condition.
    """
}
