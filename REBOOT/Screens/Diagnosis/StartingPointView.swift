import SwiftUI

/// "Your starting point" — the report that closes the diagnosis.
///
/// It shows what the user told REBOOT as honest priors, and names what REBOOT
/// will replace them with through observation. Nothing here is a verdict.
struct StartingPointView: View {
    @ObservedObject var state: AppState

    private var answers: Answers { state.answers }
    private var primary: String {
        if DiagnosisModels.isUnknown("primary", answers),
           let only = answers["goals"]?.first, answers["goals"]?.count == 1 {
            return DiagnosisModels.goalLabel[only] ?? "Not chosen yet"
        }
        return DiagnosisModels.answerLabels("primary", answers).first ?? "Not chosen yet"
    }
    private var hardest: String {
        DiagnosisModels.isUnknown("hardest", answers)
            ? "Still unclear — Day 1 watches for it"
            : (DiagnosisModels.answerLabels("hardest", answers).first ?? "")
    }
    private var breaker: String {
        DiagnosisModels.isUnknown("breaker", answers)
            ? "Not identified yet"
            : (DiagnosisModels.answerLabels("breaker", answers).first ?? "")
    }
    private var window: String {
        if DiagnosisModels.isUnknown("focus_window", answers) { return "Unmeasured" }
        let value = answers["focus_window"]?.first ?? ""
        return Self.focusCopy[value] ?? "Unmeasured"
    }
    private var returning: String {
        DiagnosisModels.isUnknown("return_ability", answers)
            ? "Unmeasured"
            : (DiagnosisModels.answerLabels("return_ability", answers).first ?? "")
    }

    private static let focusCopy: [String: String] = [
        "lt5": "Under 5 min",
        "5_15": "5 – 15 minutes",
        "15_30": "15 – 30 minutes",
        "30_60": "30 – 60 minutes",
        "usually_60_plus": "60+ minutes",
        "gt60": "60+ minutes",
    ]

    /// Priors the report renders as rows. Goals and primary live in their own
    /// card; everything else maps to one honest line.
    private var knownRows: [(label: String, value: String)] {
        var rows: [(String, String)] = []
        if !DiagnosisModels.isUnknown("hardest", answers) {
            rows.append(("Hardest part", hardest))
        }
        rows.append(("Main breaker", breaker))
        rows.append(("Focus window", window))
        rows.append(("Returning after distraction", returning))
        if !DiagnosisModels.isUnknown("switch_response", answers) {
            rows.append(("When it gets hard", DiagnosisModels.answerLabels("switch_response", answers).first ?? ""))
        }
        if !DiagnosisModels.isUnknown("use_case", answers) {
            rows.append(("Work that matters now", DiagnosisModels.answerLabels("use_case", answers).first ?? ""))
        }
        if !DiagnosisModels.isUnknown("best_time", answers) {
            rows.append(("Best hours", DiagnosisModelss.bestTimeLabel(answers["best_time"]?.first)))
        }
        return rows.filter { !$0.1.isEmpty }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardStack) {
                    header
                    primaryGoalCard
                    statGrid
                    knownCard
                    learnCard
                    statusCard
                    actions
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, max(AppSpacing.safeTopMin, geo.safeAreaInsets.top))
                .padding(.bottom, max(AppSpacing.safeBottomMin, geo.safeAreaInsets.bottom))
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea()
        }
        .background(AppColors.paper)
    }

    private var header: some View {
        Reveal(delay: 0) {
            VStack(alignment: .leading, spacing: 0) {
                MetaLabel(text: "Reboot / Calibration")
                Text("Your starting point.", style: .reportTitle)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, AppSpacing.sm)
                Text(
                    "This is not a verdict. It is where REBOOT starts — and the first week begins replacing these answers with what actually happens.",
                    style: .reportBody
                )
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, AppSpacing.xs)
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
        }
    }

    private var primaryGoalCard: some View {
        Reveal(delay: 0.08) {
            PaperSurface(shadow: .lift, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "You told reboot", color: AppColors.coral)
                    Text(primary, style: .cardTitle)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 8)
                    if (answers["goals"]?.count ?? 0) > 1 {
                        FlowPills(
                            labels: DiagnosisModels.answerLabels("goals", answers).filter { $0 != primary },
                            pill: Pill.goal
                        )
                        .padding(.top, AppSpacing.sm)
                    }
                }
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
        }
    }

    private var statGrid: some View {
        HStack(alignment: .top, spacing: AppSpacing.gridGap) {
            Reveal(delay: 0.14) {
                StatCard(label: "Hardest part", value: hardest, accent: AppColors.coral)
            }
            Reveal(delay: 0.18) {
                StatCard(label: "Focus window", value: window, accent: AppColors.cyan)
            }
        }
        .frame(maxWidth: AppSpacing.contentMaxWidth)
    }

    private var knownCard: some View {
        Reveal(delay: 0.30) {
            PaperSurface(shadow: .soft, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "What you told us")
                    VStack(spacing: 14) {
                        ForEach(knownRows, id: \.label) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 24) {
                                Text(row.label, style: .hint)
                                    .foregroundStyle(AppColors.inkSoft)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(row.value, style: .statValue)
                                    .foregroundStyle(AppColors.ink)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
        }
    }

    private var learnCard: some View {
        Reveal(delay: 0.36) {
            PaperSurface(shadow: .soft, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 10) {
                    MetaLabel(text: "What reboot will learn instead")
                    Text("Your real focus window, measured across sessions.", style: .hint)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("Whether the phone actually pulls you, or something else does.", style: .hint)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("How quickly you return — and what makes returning easier.", style: .hint)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("Which conditions hold your deeper work.", style: .hint)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("None of these stay fixed. Observed evidence outweighs every answer above.", style: .hint)
                        .foregroundStyle(AppColors.inkFaint)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
        }
    }

    private var statusCard: some View {
        Reveal(delay: 0.42) {
            HStack(spacing: 12) {
                PulsingDot()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status: Calibrating", style: .choiceLabel)
                        .foregroundStyle(AppColors.ink)
                    Text("Day 1 of 90 · your plan adapts as REBOOT observes you", style: .hint)
                        .foregroundStyle(AppColors.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, AppSpacing.screenPadding)
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
            .background(AppColors.statusTint)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .appShadow(.soft)
        }
    }

    private var actions: some View {
        Reveal(delay: 0.5) {
            VStack(spacing: 12) {
                PrimaryButton(title: "Start day one") {
                    state.patch(phase: .today)
                }
                    .frame(maxWidth: AppSpacing.contentMaxWidth)

                Button(action: { state.reset() }) {
                    Text("Retake the diagnosis", style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)
                        .padding(.vertical, 8)
                }

                Text(
                    "REBOOT trains attention behaviors. It doesn't diagnose anything or measure your brain.",
                    style: .footnote
                )
                .foregroundStyle(AppColors.inkFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private enum DiagnosisModelss {
    static func bestTimeLabel(_ value: String?) -> String {
        switch value {
        case "early": return "Early morning"
        case "morning": return "Mid-morning"
        case "afternoon": return "Afternoon"
        case "evening": return "Evening"
        case "night": return "Late night"
        default: return ""
        }
    }
}

/// Compact chip flow used by goal cards.
struct FlowPills: View {
    let labels: [String]
    let pill: (String) -> Pill

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                pill(label)
            }
        }
    }
}

/// Simple left-aligned wrapping layout for chips (flex-wrap equivalent).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let itemProposal = width.isFinite
            ? ProposedViewSize(width: width, height: nil)
            : .unspecified
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(itemProposal)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x)
        }
        return CGSize(width: min(width, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let itemProposal = ProposedViewSize(width: bounds.width, height: nil)
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(itemProposal)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        PaperSurface(shadow: .soft, padding: AppSpacing.statPadding) {
            VStack(alignment: .leading, spacing: 8) {
                MetaLabel(text: label, color: accent)
                Text(value, style: .statValue)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Coral pulsing status dot.
struct PulsingDot: View {
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.coral)
                .frame(width: 10, height: 10)
                .scaleEffect(pulsing ? 2.1 : 1)
                .opacity(pulsing ? 0 : 0.6)
            Circle()
                .fill(AppColors.coral)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}
