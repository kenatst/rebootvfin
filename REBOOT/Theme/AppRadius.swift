import CoreGraphics

/// Semantic corner-radius scale. Cards pick by hierarchy level, never ad hoc:
/// hero surfaces 30–40, primary 24–30, secondary 18–24, utility 14–18.
enum AppRadius {
    static let card: CGFloat = 28               // .paper-card / choice radius
    static let hero: CGFloat = 34
    static let primary: CGFloat = 26
    static let secondary: CGFloat = 20
    static let utility: CGFloat = 16
}
