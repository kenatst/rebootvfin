import SwiftUI

/// Port of `StartingPoint.tsx` — the Craft-style "Your starting point" report
/// that ends the diagnosis. "Start day one" is intentionally inert (web parity;
/// Today is out of scope for this step).
struct StartingPointView: View {
    @ObservedObject var state: AppState

    private var answers: Answers { state.answers }
    private var primary: String {
        DiagnosisModels.answerLabels("primary", answers).first ?? "Not chosen yet"
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
    private var absorption: [String] {
        DiagnosisModels.isUnknown("absorption", answers)
            ? []
            : DiagnosisModels.answerLabels("absorption", answers)
    }

    private static let focusCopy: [String: String] = [
        "lt5": "Under 5 minutes",
        "5_15": "5 – 15 minutes",
        "15_30": "15 – 30 minutes",
        "30_60": "30 – 60 minutes",
        "gt60": "60+ minutes",
    ]

    private var knownRows: [(label: String, value: String)] {
        DiagnosisModels.visibleQuestions(answers)
            .filter { !DiagnosisModels.isUnknown($0.id, answers) && !["goals", "primary"].contains($0.id) }
            .map { q in
                (label: Self.shortLabels[q.id] ?? q.title, value: DiagnosisModels.answerLabels(q.id, answers).joined(separator: ", "))
            }
    }

    private var unknowns: [String] {
        DiagnosisModels.visibleQuestions(answers)
            .filter { DiagnosisModels.isUnknown($0.id, answers) }
            .map { Self.unknownCopy[$0.id] ?? $0.title }
    }

    private static let shortLabels: [String: String] = [
        "breaker": "Main breaker",
        "social_app": "Strongest pull",
        "phone_place": "Phone placement",
        "focus_window": "Focus window",
        "work_break": "Breaking point",
        "reading": "Reading pattern",
        "recall_target": "Recall target",
        "environment": "Environment",
        "energy": "Best hours",
        "absorption": "Absorption",
        "flow_exit": "Flow exit",
        "session_target": "Session target",
    ]

    private static let unknownCopy: [String: String] = [
        "breaker": "Which interruption actually costs you the most",
        "social_app": "Which app pulls hardest, in real numbers",
        "phone_place": "How phone placement changes your sessions",
        "focus_window": "Your true focus window, measured",
        "work_break": "Where the work breaks down",
        "reading": "How you read under load",
        "recall_target": "What you most need to retain",
        "environment": "Which environment performs best",
        "energy": "Your real energy curve across the day",
        "absorption": "The conditions that absorb you",
        "flow_exit": "What ends your Flow",
        "session_target": "The session length that fits you",
        "goals": "Your goals",
        "primary": "Your primary goal",
    ]

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardStack) {
                    header
                    primaryGoalCard
                    statGrid
                    absorptionCard
                    if !knownRows.isEmpty {
                        knownCard
                    }
                    unknownCard
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
                Text("Your starting point", style: .reportTitle)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, AppSpacing.sm)
                Text(
                    "Built from what you told us. The first week will replace these answers with what actually happens.",
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
                    MetaLabel(text: "Primary goal", color: AppColors.coral)
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
                StatCard(label: "Main breaker", value: breaker, accent: AppColors.coral)
            }
            Reveal(delay: 0.18) {
                StatCard(label: "Focus window", value: window, accent: AppColors.cyan)
            }
        }
        .frame(maxWidth: AppSpacing.contentMaxWidth)
    }

    private var absorptionCard: some View {
        Reveal(delay: 0.24) {
            PaperSurface(shadow: .soft, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "Absorption context")
                    if absorption.isEmpty {
                        Text(
                            "Nothing reliable yet — REBOOT will look for it in your sessions.",
                            style: .hint
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 8)
                    } else {
                        FlowPills(labels: absorption, pill: Pill.absorption)
                            .padding(.top, 12)
                    }
                }
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth, alignment: .leading)
        }
    }

    private var knownCard: some View {
        Reveal(delay: 0.30) {
            PaperSurface(shadow: .soft, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "What we know")
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

    private var unknownCard: some View {
        Reveal(delay: 0.36) {
            PaperSurface(shadow: .soft, padding: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "Unknown dimensions")
                    if unknowns.isEmpty {
                        Text(
                            "Nothing missing — we'll still verify everything through practice.",
                            style: .hint
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(unknowns, id: \.self) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(AppColors.inkFaint)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 8.8)
                                    Text(item, style: .hint)
                                        .foregroundStyle(AppColors.inkSoft)
                                }
                            }
                        }
                        .padding(.top, AppSpacing.sm)
                    }
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
                    "REBOOT artwork is metaphorical. Nothing here measures your brain, dopamine or any biological state.",
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

/// Compact chip flow used by goal / absorption cards.
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
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
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
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
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

/// Coral pulsing status dot (web `animate-ping`).
struct PulsingDot: View {
    @State private var pulsing = false

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
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}
