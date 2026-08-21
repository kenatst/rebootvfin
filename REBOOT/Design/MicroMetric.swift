import SwiftUI

// MARK: - ProgressRing

/// Quiet 90-day progress ring. Coral when real progress exists.
struct ProgressRing: View {
    let progress: Double // 0...1
    var size: CGFloat = 34
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, min(1, progress)))
                .stroke(
                    progress > 0 ? AppColors.coral : AppColors.inkFaint.opacity(0.5),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.reboot(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - MicroMetric

/// Small editorial metric: label above, value below. No invented numbers.
struct MicroMetric: View {
    let label: String
    let value: String
    var accent: Color = AppColors.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .type(.metaLabel)
                .foregroundStyle(AppColors.inkFaint)
            Text(value)
                .type(.calendarMeta)
                .foregroundStyle(accent)
        }
    }
}

// MARK: - FocusSparkline

/// Tiny real-data line of recent focus durations. Only rendered with ≥2 sessions.
struct FocusSparkline: View {
    let points: [FocusLinePoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxMin = max(1, points.map(\.minutes).max() ?? 1)
            let stepX = w / CGFloat(max(1, points.count - 1))

            Path { path in
                for (i, p) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = h - (CGFloat(p.minutes) / CGFloat(maxMin)) * (h - 6) - 3
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(AppColors.coral.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach(Array(points.enumerated()), id: \.element.id) { i, p in
                let x = CGFloat(i) * stepX
                let y = h - (CGFloat(p.minutes) / CGFloat(maxMin)) * (h - 6) - 3
                Circle()
                    .fill(i == points.count - 1 ? AppColors.coral : AppColors.paper)
                    .overlay(Circle().stroke(AppColors.coral.opacity(0.8), lineWidth: 1.2))
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
        .frame(height: 34)
    }
}
