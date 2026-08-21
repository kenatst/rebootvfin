import SwiftUI

/// Fade + rise reveal used everywhere (cine text, diagnosis options, report cascade).
/// Web equivalent: `motion.div` with opacity 0→1 and y 8–14→0.
struct Reveal<Content: View>: View {
    var offset: CGFloat = 12
    var delay: Double = 0
    var duration: Double = AppMotion.textReveal
    @State private var appeared = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : offset)
            .animation(.reboot(duration: duration, delay: delay), value: appeared)
            .onAppear { appeared = true }
            .onDisappear { appeared = false }
    }
}
