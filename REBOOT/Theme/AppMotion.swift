import SwiftUI

/// Motion tokens — exact timings/easings from the web. See DESIGN_MAPPING.md section 6.
enum AppMotion {
    static let artworkCrossfade: Double = 0.78
    static let textReveal: Double = 0.58
    static let textRevealDelay: Double = 0.16
    static let questionDuration: Double = 0.42
    static let choiceDuration: Double = 0.36
    static let choiceStagger: Double = 0.03
    static let choiceStaggerBase: Double = 0.05
    static let progressDuration: Double = 0.5
    static let reportDuration: Double = 0.55
    static let pressDuration: Double = 0.2
    static let selectMorph: Double = 0.2
    static let singleAdvanceSettle: Double = 0.22
    static let dissolveTotal: Double = 1.5
    static let dissolveHalo: Double = 1.15
    static let dissolvePaperDelay: Double = 0.62
    static let dissolvePaper: Double = 0.72
    static let dissolveWordDelay: Double = 0.95
    static let dissolveWord: Double = 0.6
    static let breatheCycle: Double = 6.5

    /// Reduced-motion substitute duration (web uses 0.2).
    static let reduced: Double = 0.2
}

extension Animation {
    static func reboot(duration: Double, delay: Double = 0) -> Animation {
        .timingCurve(0.22, 0.9, 0.24, 1, duration: duration)
            .delay(delay)
    }
}
