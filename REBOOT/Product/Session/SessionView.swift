import SwiftUI

/// Full-screen session: one quiet timer, no dashboard, no metrics.
struct SessionView: View {
    @ObservedObject var product: ProductStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                VStack(spacing: 0) {
                    Spacer()

                    if case .running(let record) = product.phase {
                        MetaLabel(text: record.mode.display.uppercased(), color: AppColors.coral)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(elapsedText(from: record.date, at: context.date))
                                .font(Font(AppTypography.plusJakarta(size: 64, weight: 300)))
                                .kerning(-2.4)
                                .foregroundStyle(AppColors.ink)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .padding(.top, 14)

                        Text("Target: \(record.targetMinutes) min", style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 8)

                        Text(record.mode == .observe ? "Work the way you usually do." : "One task. No rearrangement.")
                            .type(.heroReason)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 24)
                    }

                    Spacer()

                    PrimaryPillButton(title: "Finish", symbol: "checkmark") {
                        finish(early: false)
                    }

                    Button {
                        finish(early: true)
                    } label: {
                        Text("End early", style: .smallLink)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.vertical, 10)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, max(20, geo.safeAreaInsets.top) + 8)
                .padding(.bottom, max(28, geo.safeAreaInsets.bottom) + 12)
            }
            .ignoresSafeArea()
        }
    }

    private func finish(early: Bool) {
        guard case .running(let record) = product.phase else { return }
        let minutes = max(1, Int(Date().timeIntervalSince(record.date) / 60))
        product.finishRunning(actualMinutes: minutes, endedEarly: early)
    }

    private func elapsedText(from start: Date, at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
