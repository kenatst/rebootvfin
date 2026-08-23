import SwiftUI

/// The signature REBOOT screen — one coherent editorial prescription, not a dashboard.
///
/// Hierarchy is fixed: DAY/PHASE eyebrow → serif headline → MODE · MINUTES →
/// why (one sentence) → before-you-start only when real → unmistakable CTA →
/// at most one supporting action → quiet evidence strip.
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
    /// Phase title with the trailing period trimmed — titles are sentences,
    /// eyebrows are not.
    private var phaseTitle: String {
        product.currentProgramPhase.title.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        topMetadata
                        headline
                            .padding(.top, 24)
                        modeSubtitle
                            .padding(.top, 14)
                        whyThisToday
                            .padding(.top, 20)

                        if let envAction = guidance.environmentAction, !product.hasCompletedCurrentProtocol {
                            beforeYouStart(envAction: envAction)
                                .padding(.top, 32)
                        } else if let fuelPrompt = guidance.fuelPrompt, !product.hasCompletedCurrentProtocol {
                            FuelPromptCard(product: product, prompt: fuelPrompt)
                                .padding(.top, 32)
                        }

                        primaryActionArea
                            .padding(.top, 32)

                        if let supporting = guidance.supportingAction, !product.hasCompletedCurrentProtocol {
                            supportingActionRow(supporting: supporting)
                                .padding(.top, 16)
                        }

                        evidenceStrip
                            .padding(.top, 40)

                        footer
                            .padding(.top, 40)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
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

    /// Day over phase, stacked — long phase names never truncate against the
    /// progress ring.
    private var topMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(isCompleted ? L("OWN MODE") : String(format: "DAY %03d / 090", product.day))
                    .font(Font(AppTypography.plusJakarta(size: 12, weight: 700)))
                    .tracking(2)
                    .foregroundStyle(AppColors.coral)
                Spacer()
                ProgressRing(progress: isCompleted ? 1.0 : product.programProgress)
                    .accessibilityLabel(isCompleted ? L("90 protocol days complete") : L("%d of %d program days completed", product.completedProtocolDays, 90))
            }
            if !isCompleted {
                Text(phaseTitle.uppercased())
                    .font(Font(AppTypography.plusJakarta(size: 12, weight: 600)))
                    .tracking(2)
                    .foregroundStyle(AppColors.inkFaint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    // MARK: - Headline + Mode Subtitle

    private var headline: some View {
        EditorialHeadline(text: guidance.primaryAction.title)
            .frame(maxWidth: 360, alignment: .leading)
    }

    private var modeSubtitle: some View {
        Text(guidance.primaryAction.subtitle)
            .font(Font(AppTypography.plusJakarta(size: 13, weight: 700)))
            .tracking(1.5)
            .foregroundStyle(AppColors.coral)
    }

    // MARK: - Why This Today

    private var whyThisToday: some View {
        Text(guidance.explanation)
            .type(.todaySentence)
            .foregroundStyle(AppColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 360, alignment: .leading)
    }

    // MARK: - Before You Start

    /// A flat editorial block on the paper — setup is an instruction, not a card.
    private func beforeYouStart(envAction: EnvironmentAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: L("BEFORE YOU START"), color: AppColors.coral)
            Text(envAction.title)
                .type(.heroGoal)
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            if envAction.detail != envAction.title {
                Text(envAction.detail)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                Button(action: { product.completeRequiredAction(done: true) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text(L("Done — I'm set up"))
                    }
                    .type(.smallLink)
                    .foregroundStyle(product.environmentPreparation?.outcome == .completed ? AppColors.paper : AppColors.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(product.environmentPreparation?.outcome == .completed ? AppColors.ink : AppColors.ink.opacity(0.08))
                    .clipShape(Capsule())
                }

                Button(action: {
                    product.completeRequiredAction(done: false, refusalReason: L("Not feasible today"))
                }) {
                    Text(L("Can't today"))
                        .type(.smallLink)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.statusTint)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
    }

    // MARK: - Primary CTA

    @ViewBuilder
    private var primaryActionArea: some View {
        if isCompleted {
            OwnModeTodayCard(
                guidance: guidance,
                onManual: { showManual = true },
                onStart: { startPrimaryAction() }
            )
        } else if product.hasCompletedCurrentProtocol {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.coral)
                Text(L("Today's session is complete."))
                    .type(.heroGoal)
                    .foregroundStyle(AppColors.ink)
                Spacer()
            }
            .padding(20)
            .background(AppColors.paperRaised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
            .accessibilityElement(children: .combine)
        } else if !guidance.primaryAction.ctaTitle.isEmpty {
            PrimaryPillButton(
                title: guidance.primaryAction.ctaTitle,
                symbol: guidance.primaryAction.kind == .projectFlowBlock ? "arrow.up.forward.app" : "play.fill"
            ) {
                startPrimaryAction()
            }
        } else {
            // Quiet-day state in Own Mode handled by OwnModeTodayCard above;
            // this fallback keeps a disabled program honest without inventing UI.
            HStack(spacing: 10) {
                Image(systemName: "leaf")
                    .foregroundStyle(AppColors.inkFaint)
                Text(guidance.primaryAction.title)
                    .type(.heroGoal)
                    .foregroundStyle(AppColors.inkSoft)
                Spacer()
            }
            .padding(20)
            .background(AppColors.paperRaised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.secondary, style: .continuous))
            .accessibilityElement(children: .combine)
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

    /// A quiet editorial row — no icon spam, no nested card.
    private func supportingActionRow(supporting: DailyGuidanceSecondaryAction) -> some View {
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
            HStack(spacing: 8) {
                Text(supporting.title)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.coral)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(L("Opens the suggested destination"))
    }

    // MARK: - Evidence Strip

    /// One quiet editorial line — "RECENT PATTERN · 22 min average focus ·
    /// Return: strong" — with a whisper of sparkline. Metrics never compete
    /// with the prescription above.
    @ViewBuilder
    private var evidenceStrip: some View {
        if product.sessions.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                MetaLabel(text: L("RECENT PATTERN"))
                HStack(alignment: .center, spacing: 14) {
                    Text("\(averageMinutes) \(L("min")) · \(L("Return")): \(returnTrend)")
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                    FocusSparkline(points: product.focusHistory)
                        .frame(maxWidth: 90)
                        .opacity(0.75)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 4)
        } else {
            Text(product.sessions.count == 1
                 ? L("One session recorded. REBOOT is still learning your patterns.")
                 : L("Nothing measured yet — Day 1 starts the record."))
                .type(.footnote)
                .foregroundStyle(AppColors.inkFaint)
        }
    }

    private var averageMinutes: String {
        let vals = product.sessions.map(\.actualMinutes)
        guard !vals.isEmpty else { return "—" }
        return "\(vals.reduce(0, +) / vals.count) min"
    }

    private var returnTrend: String {
        switch product.profile.returnAfterDistraction.value {
        case .strong: return L("Strong")
        case .fair: return L("Fair")
        case .weak: return L("Weak")
        case nil: return "—"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text(
            isCompleted
                ? L("Your Attention Operating Manual remains alive and evolving.")
                : L("What happens today changes what comes next.")
        )
        .type(.footnote)
        .foregroundStyle(AppColors.inkFaint)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Own Mode's Today content. The page headline already carries the message,
/// so this renders ONE actionable surface — no duplicated hero card, no
/// repeated copy.
struct OwnModeTodayCard: View {
    let guidance: DailyGuidance
    var onManual: () -> Void
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: L("TODAY'S SUGGESTION"), color: AppColors.coral)

            if guidance.noInterventionNeeded {
                // Quiet day IS the hero — nothing else competes with it.
                Text(L("Nothing needs adjusting today."))
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                Text(L("Your recent pattern is stable. Use REBOOT if you want to train, test, or review."))
                    .type(.todaySentence)
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                QuietTextButton(title: L("Open Operating Manual")) { onManual() }
                    .padding(.top, 14)
            } else {
                Text(guidance.primaryAction.title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                Text(guidance.primaryAction.subtitle)
                    .type(.footnote)
                    .tracking(1)
                    .foregroundStyle(AppColors.coral)
                    .padding(.top, 8)
                PrimaryPillButton(title: guidance.primaryAction.ctaTitle, symbol: "play.fill") {
                    onStart()
                }
                .padding(.top, 18)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.paperRaised.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .appShadow(.soft)
    }
}

/// Quiet text-level secondary action with consistent hit target.
struct QuietTextButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .type(.smallLink)
                .foregroundStyle(AppColors.inkSoft)
                .underline()
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(L("Opens the Attention Operating Manual"))
    }
}
