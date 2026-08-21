import SwiftUI

/// The signature REBOOT screen — one editorial composition, not a dashboard.
struct TodayView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var showWhy = false
    @State private var showReset = false
    @State private var showConnect = false
    @State private var showActivityPicker = false

    private var prescription: DailyPrescription { product.prescription }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        metadata
                        headline
                        sentence
                        TodayHero(product: product)
                            .padding(.top, 34)
                        RealWorldActionCard(product: product, environmentStore: environmentStore)
                            .padding(.top, 18)
                        if prescription.mode == .nothing {
                            resetEntry
                                .padding(.top, 14)
                        }
                        whyPill
                            .padding(.top, 18)
                        microData
                            .padding(.top, 28)
                        insight
                            .padding(.top, 18)
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
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-qaShowConnect") {
                showConnect = true
            }
            if ProcessInfo.processInfo.arguments.contains("-qaShowPicker") {
                showActivityPicker = true
            }
#endif
        }
    }

    // MARK: - Top metadata

    private var metadata: some View {
        HStack(spacing: 12) {
            MetaLabel(text: String(format: "Day %03d / 090", product.day))
            GlassPill(
                text: product.isCalibrating ? "Calibrating" : prescription.mode.display.uppercased(),
                tint: product.isCalibrating ? AppColors.coral : AppColors.ink
            )
            Spacer()
            ProgressRing(progress: Double(product.day) / 90.0)
        }
    }

    // MARK: - Headline + sentence

    private var headline: some View {
        EditorialHeadline(text: prescription.headline)
            .padding(.top, 24)
            .frame(maxWidth: 360, alignment: .leading)
    }

    private var sentence: some View {
        Text(prescription.sentence, style: .todaySentence)
            .foregroundStyle(AppColors.inkSoft)
            .padding(.top, 14)
            .frame(maxWidth: 360, alignment: .leading)
    }

    // MARK: - Why this?

    private var whyPill: some View {
        Button {
            showWhy = true
        } label: {
            GlassPill(text: "Why this?", symbol: "questionmark.circle", tint: AppColors.ink, paddingH: 16, paddingV: 10)
        }
        .buttonStyle(PressScaleStyle())
    }

    private var resetEntry: some View {
        Button {
            showReset = true
        } label: {
            GlassPill(text: "Reset the environment", symbol: "arrow.counterclockwise", tint: AppColors.ink)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - Micro data (real only)

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

    // MARK: - Insight

    private var insight: some View {
        InsightCard(insight: product.insights.first ?? "REBOOT is still learning this.")
    }

    // MARK: - Footer

    private var footer: some View {
        Text("What happens today changes what comes next.")
            .type(.footnote)
            .foregroundStyle(AppColors.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
