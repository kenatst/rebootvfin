import Foundation

/// Localization entry point. Keys are the canonical English source strings;
/// missing translations fall back to readable English by design.
///
/// REBOOT voice rules for translators live in APPSTORE/metadata; the five
/// product languages are EN, FR, ES, DE, IT (see Localizable.xcstrings).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Formatted variant: `L("DAY %03d / 090", day)` style.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}
