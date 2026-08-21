import SwiftUI

/// Port of `Dissolve.tsx`: the red halo collapses to a bright point, paper
/// floods in, "Clarity." appears — then the diagnosis begins at 1.5s.
struct DissolveView: View {
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// QA harness: lets screenshot runs stretch the dissolve so the animation
    /// frames can be captured reliably after cold-start first-frame delays.
    private var totalDuration: Double {
        if let raw = ProcessInfo.processInfo.arguments.valueAfter("-qaDissolve"),
           let seconds = Double(raw) {
            return seconds
        }
        return AppMotion.dissolveTotal
    }

    private struct HaloValues {
        var scale: CGFloat = 1.1
        var opacity: Double = 0.85
    }

    var body: some View {
        ZStack {
            AppColors.void

            if !reduceMotion {
                halo
            }

            Rectangle()
                .fill(AppColors.paper)
                .opacity(paperVisible ? 1 : 0)
                .animation(
                    .reboot(duration: AppMotion.dissolvePaper).delay(AppMotion.dissolvePaperDelay),
                    value: paperVisible
                )

            Text("Clarity.", style: .clarity)
                .foregroundStyle(AppColors.ink)
                .opacity(wordVisible ? 1 : 0)
                .offset(y: wordVisible ? 0 : 10)
                .animation(
                    .reboot(duration: AppMotion.dissolveWord).delay(AppMotion.dissolveWordDelay),
                    value: wordVisible
                )
        }
        .ignoresSafeArea()
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .milliseconds(500))
            } else {
                try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
            }
            onDone()
        }
    }

    @State private var paperVisible = false
    @State private var wordVisible = false

    private var halo: some View {
        GeometryReader { geo in
            let vmin = min(geo.size.width, geo.size.height)
            KeyframeAnimator(initialValue: HaloValues(), trigger: 0) { value in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.signal.mix(with: .white, by: 0.6),
                                AppColors.signal.opacity(0.30),
                                AppColors.signal.opacity(0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: vmin * 0.21
                        )
                    )
                    .frame(width: vmin * 0.42, height: vmin * 0.42)
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.1, duration: 0.483)
                    CubicKeyframe(0.12, duration: 0.483)
                    CubicKeyframe(26, duration: 0.667)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(0.85, duration: 0.483)
                    CubicKeyframe(1.0, duration: 0.483)
                    CubicKeyframe(0.0, duration: 0.667)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.72).delay(AppMotion.dissolvePaperDelay)) {
                paperVisible = true
            }
            withAnimation(.easeOut(duration: AppMotion.dissolveWord).delay(AppMotion.dissolveWordDelay)) {
                wordVisible = true
            }
        }
    }
}

extension Color {
    /// `color-mix(in oklab, self pct, other)` approximation via linear interpolation.
    func mix(with other: Color, by fraction: CGFloat) -> Color {
        Color(
            red: redComponent * (1 - fraction) + other.redComponent * fraction,
            green: greenComponent * (1 - fraction) + other.greenComponent * fraction,
            blue: blueComponent * (1 - fraction) + other.blueComponent * fraction
        )
    }

    private var redComponent: Double {
        let ui = UIColor(self)
        var r: CGFloat = 0
        ui.getRed(&r, green: nil, blue: nil, alpha: nil)
        return Double(r)
    }

    private var greenComponent: Double {
        let ui = UIColor(self)
        var g: CGFloat = 0
        ui.getRed(nil, green: &g, blue: nil, alpha: nil)
        return Double(g)
    }

    private var blueComponent: Double {
        let ui = UIColor(self)
        var b: CGFloat = 0
        ui.getRed(nil, green: nil, blue: &b, alpha: nil)
        return Double(b)
    }
}
