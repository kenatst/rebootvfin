import SwiftUI

struct AttentionOperatingManualView: View {
    let manual: AttentionOperatingManual
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        
                        manualSection(item: manual.howIStartBest)
                        manualSection(item: manual.myMostCommonBreakers)
                        manualSection(item: manual.myReturnStrategy)
                        manualSection(item: manual.myFocusWindow)
                        manualSection(item: manual.myDigitalEnvironment)
                        manualSection(item: manual.myDeepWorkConditions)
                        manualSection(item: manual.myRecallStrategy)
                        manualSection(item: manual.myEnergyAndContext)
                        manualSection(item: manual.myFlowConditions)

                        rulesSection
                        unknownsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Operating Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: manual.exportAsText(),
                        subject: Text("REBOOT Attention Operating Manual"),
                        message: Text("Here is my evidence-backed Attention Operating Manual, built in REBOOT.")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: "Operating Manual", color: AppColors.coral)
            Text("You know your attention now.")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(AppColors.ink)
            Text("Grounded in \(manual.totalProtocolDays) protocol days and \(manual.totalSessions) sessions. Every line keeps its evidence; unknowns stay unknown. The manual keeps learning after Day 90.")
                .type(.heroReason)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    // MARK: - Standard Section

    private func manualSection(item: ManualItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.sectionTitle, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                maturityPill(item.maturity)
            }

            PaperCard(radius: 20, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.statement)
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)

                    Divider().opacity(0.3)

                    HStack {
                        Text(item.evidenceSource)
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)
                        Spacer()
                        if let n = item.observationCount, n > 0 {
                            Text("n=\(n)")
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Personal Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MY PERSONAL RULES", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            if manual.myPersonalRules.isEmpty {
                PaperCard(radius: 20, padding: 18) {
                    Text("No personal rules kept yet. Complete experiments in Personal Lab to establish evidence-backed rules.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(manual.myPersonalRules) { rule in
                        PaperCard(radius: 18, padding: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(rule.statement)
                                        .type(.heroGoal)
                                        .foregroundStyle(AppColors.ink)
                                    Spacer()
                                    maturityPill(rule.maturity)
                                }
                                Text(rule.evidenceSource)
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkFaint)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unknowns Section

    private var unknownsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT I STILL DON'T KNOW", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            VStack(spacing: 10) {
                ForEach(manual.whatRebootStillDoesNotKnow) { unknown in
                    PaperCard(radius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(AppColors.coral)
                                Text(unknown.statement)
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                            }
                            Text(unknown.evidenceSource)
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkFaint)
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func maturityPill(_ maturity: ManualMaturity) -> some View {
        Text(maturity.displayLabel)
            .type(.smallLink)
            .foregroundStyle(maturity == .repeatedSignal ? AppColors.ink : AppColors.coral)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((maturity == .repeatedSignal ? AppColors.ink : AppColors.coral).opacity(0.12))
            .clipShape(Capsule())
    }
}
