import Foundation

/// Port of `src/lib/reboot-content.ts` — same copy, same order, same artwork.
struct CineScreen: Identifiable {
    let id: Int
    let imageName: String
    let meta: String
    let title: String
    let body: String
    let secondary: String?
    let stages: [String]?
    let cta: String
    let ghost: String?
    /// Vertical artwork anchor (web `object-position`). Horizontal is always centered.
    let focusY: Double
}

enum CinematicContent {
    static let screens: [CineScreen] = [
        CineScreen(
            id: 1,
            imageName: "page1",
            meta: "REBOOT / 01",
            title: L("Your attention is being pulled apart."),
            body: L("Every notification, feed and interruption asks for the same thing: switch."),
            secondary: L("And what you repeat becomes easier to repeat."),
            stages: nil,
            cta: L("See what's happening"),
            ghost: nil,
            focusY: 0.22
        ),
        CineScreen(
            id: 2,
            imageName: "page2",
            meta: "REBOOT / 02",
            title: L("You're training yourself to switch."),
            body: L("Open. Scroll. Check. Change. Repeat."),
            secondary: L("The problem isn't that you've lost attention. Your environment keeps rewarding the opposite behaviour."),
            stages: nil,
            cta: L("Cut the noise"),
            ghost: nil,
            focusY: 0.20
        ),
        CineScreen(
            id: 3,
            imageName: "page3",
            meta: "REBOOT / 03",
            title: L("Attention is a skill."),
            body: L("Staying with one thing, returning after distraction and rebuilding what you learned can all be trained."),
            secondary: L("REBOOT starts by measuring how you work today."),
            stages: nil,
            cta: L("Build my baseline"),
            ghost: nil,
            focusY: 0.18
        ),
        CineScreen(
            id: 4,
            imageName: "page4",
            meta: "REBOOT / 04",
            title: L("Less input. More depth."),
            body: L("We'll change the conditions around you, train sustained attention, improve recall and help you design real deep-work sessions."),
            secondary: L("No miracle. No dopamine detox. Just deliberate practice and better conditions."),
            stages: nil,
            cta: L("Show me the protocol"),
            ghost: nil,
            focusY: 0.16
        ),
        CineScreen(
            id: 5,
            imageName: "page5",
            meta: "REBOOT / 05",
            title: L("90 days. Built around you."),
            body: L("REBOOT learns from your sessions, experiments, environment, energy and Flow conditions — then adapts what comes next."),
            secondary: L("No streak to protect. Miss a day and the program simply waits."),
            stages: [L("Observe"), L("Adapt"), L("Own it")],
            cta: L("One last thing"),
            ghost: nil,
            focusY: 0.14
        ),
        CineScreen(
            id: 6,
            imageName: "page6",
            meta: "DAY 001 / 090",
            title: L("Rebuild your attention."),
            body: L("The first week is calibration. We start with what you tell us, then REBOOT learns from what actually happens."),
            secondary: nil,
            stages: nil,
            cta: L("Begin REBOOT"),
            ghost: L("Not now"),
            focusY: 0.18
        ),
    ]
}
