import Foundation

/// Single source of truth for legal/operator-facing configuration.
///
/// IMPORTANT: values marked OPERATOR INPUT carry placeholder tokens that MUST
/// be replaced before App Store submission. See COMPLIANCE/OPERATOR_INPUT_REQUIRED.md.
/// Do not scatter URLs or support contacts across other files — everything
/// user-facing resolves through here.
enum LegalConfiguration {

    // MARK: - Operator identity (OPERATOR INPUT REQUIRED)

    /// Legal entity operating REBOOT. Placeholder until the operator confirms
    /// the registered name.
    static let legalEntity = "{{LEGAL_ENTITY_REQUIRED}}"

    /// Support contact. Replace with the production mailbox before release.
    static let supportEmail = "support@rebootattention.com"

    /// Governing jurisdiction for the Terms. Requires counsel confirmation.
    static let governingJurisdiction = "{{GOVERNING_JURISDICTION_REQUIRED}}"

    // MARK: - Document URLs (OPERATOR INPUT REQUIRED)

    /// Hosted privacy policy. Until production hosting exists, in-app viewers
    /// render the bundled document; this URL is used for App Store Connect and
    /// must resolve publicly before submission.
    static let privacyPolicyURL = URL(string: "https://rebootattention.com/privacy")!

    static let termsOfServiceURL = URL(string: "https://rebootattention.com/terms")!

    static let websiteURL = URL(string: "https://rebootattention.com")!

    // MARK: - Document versions

    /// Bump when the policy text changes; acknowledgement (if stored) records
    /// this version, never a bare boolean.
    static let privacyPolicyVersion = "1.0"

    static let termsVersion = "1.0"

    static let legalLastUpdated = "August 2026"
}
