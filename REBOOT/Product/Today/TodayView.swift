import SwiftUI

/// The signature REBOOT screen — one coherent editorial prescription, not a dashboard.
struct TodayView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    var subscriptionStore: SubscriptionStore? = nil
    @State private var showWhy = false
    @State private var showReset = false
    @State private var showConnect = false
    @State private var showActivityPicker = false
    @State private var showManual = false
    @State private var showPaywall = false

    private var guidance: DailyGuidance { product.dailyGuidance }
    private var isCompleted: Bool { product.programStatus == .completed }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        topMetadata
                        headline
                        modeSubtitle
                        whyThisToday
                        
                        if let envAction = guidance.environmentAction, !product.hasCompletedCurrentProtocol {
                            beforeYouStartCard(envAction: envAction)
                                .padding(.top, 24)
                        } else if let fuelPrompt = guidance.fuelPrompt, !product.hasCompletedCurrentProtocol {
                            FuelPromptCard(product: product, prompt: fuelPrompt)
                                .padding(.top, 24)
                        }

                        primaryActionArea
                            .padding(.top, 28)

                        if let supporting = guidance.supportingAction, !product.hasCompletedCurrentProtocol {
                            supportingActionCard(supporting: supporting)
                                .padding(.top, 14)
                        }

                        whyThisButton
                            .padding(.top, 20)

                        microData
                            .padding(.top, 28)
                        
                        footer
                            .padding(.top, 38)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 8)
                    .padding(.bottom, 150)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showWhy) {
            AdaptiveDisclosureSheet(product: product)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showReset) {
            DigitalResetView(product: product, environmentStore: environmentStore)
        }
        .sheet(isPresented: $showConnect) {
            ScreenTimeExplainerSheet(environmentStore: environmentStore)
        }
        .sheet(isPresented: $showActivityPicker) {
            ActivitySelectionSheet(environmentStore: environmentStore)
        }
        .sheet(isPresented: $showManual) {
            AttentionOperatingManualView(manual: product.operatingManual)
        }
        .sheet(isPresented: $showPaywall) {
            if let subscriptionStore {
                PaywallView(subscriptionStore: subscriptionStore)
            } else {
                PaywallView(subscriptionStore: SubscriptionStore())
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-qaPaywall") {
                showPaywall = true
            }
        }
    }

    // MARK: - Top Metadata

    private var topMetadata: some View {
        HStack(spacing: 12) {
            MetaLabel(
                text: isCompleted
                    ? "Own Mode"
                    : String(format: "Day %03d / 090", product.day),
                color: AppColors.coral
            )
            GlassPill(
                text: isCompleted
                    ? "Complete"
                    : product.isCalibrating
                        ? "Calibrating"
                        : product.currentProgramPhase.title
                            .trimmingCharacters(in: CharacterSet(charactersIn: ".")),
                tint: isCompleted || product.isCalibrating
                    ? AppColors.coral
                    : AppColors.ink
            )
            Spacer()
            ProgressRing(progress: isCompleted ? 1.0 : product.programProgress)
                .accessibilityLabel(isCompleted ? "90 protocol days complete" : "\(product.completedProtocolDays) of 90 program days completed")
        }
    }

    // MARK: - Headline + Mode Subtitle

    private var headline: some View {
        EditorialHeadline(text: guidance.primaryAction.title)
            .padding(.top, 20)
            .frame(maxWidth: 360, alignment: .leading)
    }

    private var modeSubtitle: some View {
        Text(guidance.primaryAction.subtitle)
            .font(Font(AppTypography.plusJakarta(size: 13, weight: 600)))
            .foregroundStyle(AppColors.coral)
            .tracking(1.5)
            .padding(.top, 10)
    }

    // MARK: - Why This Today

    private var whyThisToday: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHY THIS TODAY")
                .font(Font(AppTypography.plusJakarta(size: 11, weight: 600)))
                .foregroundStyle(AppColors.inkFaint)
                .tracking(1.2)
            Text(guidance.explanation)
                .type(.heroReason)
                .foregroundStyle(AppColors.inkSoft)
        }
        .padding(.top, 14)
        .frame(maxWidth: 360, alignment: .leading)
    }

    // MARK: - Before You Start

    private func beforeYouStartCard(envAction: EnvironmentAction) -> some View {
        PaperCard(radius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MetaLabel(text: "BEFORE YOU START", color: AppColors.coral)
                    Spacer()
                    if product.environmentPreparation?.outcome == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.coral)
                    }
                }
                Text(envAction.title)
                    .type(.heroGoal)
                    .foregroundStyle(AppColors.ink)
                Text(envAction.detail)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)

                HStack(spacing: 12) {
                    Button(action: {
                        product.completeRequiredAction(done: true)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Ready")
                        }
                        .type(.smallLink)
                        .foregroundStyle(product.environmentPreparation?.outcome == .completed ? AppColors.paper : AppColors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(product.environmentPreparation?.outcome == .completed ? AppColors.ink : AppColors.ink.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Button(action: {
                        product.completeRequiredAction(done: false, refusalReason: "Not feasible right now")
                    }) {
                        Text("Skip setup")
                            .type(.smallLink)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Primary CTA

    private var primaryActionArea: some View {
        Group {
            if isCompleted {
                OwnModeTodayCard(
                    guidance: guidance,
                    onManual: { showManual = true },
                    onStart: { startPrimaryAction() }
                )
            } else if product.hasCompletedCurrentProtocol {
                PaperCard(radius: 24, padding: 18) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.coral)
                        Text("Today's protocol session is complete.")
                            .type(.heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                    }
                }
            } else if !guidance.primaryAction.ctaTitle.isEmpty {
                PrimaryPillButton(
                    title: guidance.primaryAction.ctaTitle,
                    symbol: guidance.primaryAction.kind == .projectFlowBlock ? "arrow.up.forward.app" : "play.fill"
                ) {
                    startPrimaryAction()
                }
            } else {
                PaperCard(radius: 24, padding: 18) {
                    HStack {
                        Image(systemName: "leaf")
                            .foregroundStyle(AppColors.inkFaint)
                        Text(guidance.primaryAction.title)
                            .type(.heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                    }
                }
            }
        }
    }

    private func startPrimaryAction() {
        guard SubscriptionGating.isProgramDayAccessible(day: product.day, status: subscriptionStore?.status ?? .free) else {
            showPaywall = true
            return
        }

        if guidance.primaryAction.kind == .projectFlowBlock, let flow = guidance.flowOpportunity {
            _ = product.beginFlowSetup(projectID: flow.projectID, origin: .protocol)
        } else {
            product.prepareProtocolSession()
        }
    }

    // MARK: - Optional Secondary Action

    private func supportingActionCard(supporting: DailyGuidanceSecondaryAction) -> some View {
        Button(action: {
            switch supporting.actionType {
            case "flow":
                product.openFlowLab(origin: .protocol)
            case "experiment":
                product.tab = .profile
            case "manual":
                showManual = true
            default:
                break
            }
        }) {
            PaperCard(radius: 18, padding: 14) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.coral)
                    Text(supporting.title)
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - Why This Button

    private var whyThisButton: some View {
        Button {
            showWhy = true
        } label: {
            GlassPill(text: "Why this?", symbol: "questionmark.circle", tint: AppColors.ink, paddingH: 16, paddingV: 10)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - Micro Data

    private var microData: some View {
        Group {
            if product.sessions.count >= 2 {
                LiquidCard(radius: 26, padding: 18) {
                    HStack(alignment: .center, spacing: 20) {
                        MicroMetric(label: "Focus", value: averageMinutes)
                        FocusSparkline(points: product.focusHistory)
                            .frame(maxWidth: .infinity)
                        MicroMetric(label: "Return", value: returnTrend, accent: AppColors.coral)
                    }
                }
            } else {
                LiquidCard(radius: 26, padding: 18) {
                    HStack(spacing: 20) {
                        MicroMetric(label: "Status", value: "Learning", accent: AppColors.coral)
                        MicroMetric(label: "Sessions", value: product.sessions.count == 1 ? "1 session" : "0 sessions")
                        Spacer()
                        Text("Not enough data yet")
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    private var averageMinutes: String {
        let vals = product.sessions.map(\.actualMinutes)
        guard !vals.isEmpty else { return "—" }
        return "\(vals.reduce(0, +) / vals.count) min"
    }

    private var returnTrend: String {
        switch product.profile.returnAfterDistraction.value {
        case .strong: return "Strong"
        case .fair: return "Fair"
        case .weak: return "Weak"
        case nil: return "—"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text(
            isCompleted
                ? "Your Attention Operating Manual remains alive and evolving."
                : "What happens today changes what comes next."
        )
        .type(.footnote)
        .foregroundStyle(AppColors.inkFaint)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Own Mode's Today card. Two honest states: a light self-directed suggestion,
/// or a deliberate quiet day. Never an endless curriculum.
struct OwnModeTodayCard: View {
    let guidance: DailyGuidance
    var onManual: () -> Void
    var onStart: () -> Void

    var body: some View {
        PaperCard(radius: 28, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                if guidance.noInterventionNeeded {
                    Text("Nothing needs adjusting today.")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text(guidance.explanation)
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)

                    HStack(spacing: 12) {
                        PrimaryPillButton(title: "Open Operating Manual", symbol: "book.pages") {
                            onManual()
                        }
                    }
                } else {
                    Text(guidance.primaryAction.title)
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text(guidance.explanation)
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)

                    HStack(spacing: 12) {
                        PrimaryPillButton(
                            title: guidance.primaryAction.ctaTitle,
                            symbol: "play.fill"
                        ) {
                            onStart()
                        }
                    }
                }
            }
        }
    }
}
