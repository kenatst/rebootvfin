import SwiftUI

/// The Attention Operating Manual: a typeset personal document, not a stack
/// of cards. Chapters sit directly on the paper, separated by hairlines,
/// with quiet evidence metadata under each statement.
struct AttentionOperatingManualView: View {
    let manual: AttentionOperatingManual
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.paper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        chapter(manual.howIStartBest)
                        chapter(manual.myMostCommonBreakers)
                        chapter(manual.myReturnStrategy)
                        chapter(manual.myFocusWindow)
                        chapter(manual.myDigitalEnvironment)
                        chapter(manual.myDeepWorkConditions)
                        chapter(manual.myRecallStrategy)
                        chapter(manual.myEnergyAndContext)
                        chapter(manual.myFlowConditions)

                        rulesChapter
                        unknownsChapter
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Operating Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.paper.opacity(0.9), for: .navigationBar)
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
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "ATTENTION OPERATING MANUAL", color: AppColors.coral)
            Text("You know your attention now.")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Text("Grounded in \(manual.totalProtocolDays) protocol days and \(manual.totalSessions) sessions. Every line keeps its evidence; unknowns stay unknown. The manual keeps learning after Day 90.")
                .type(.reportBody)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(.vertical, 28)
    }

    // MARK: - Chapter (one manual item, no card)

    private func chapter(_ item: ManualItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.hairline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.sectionTitle)
                        .font(Font(AppTypography.plusJakarta(size: 12, weight: 700)))
                        .tracking(1.6)
                        .foregroundStyle(AppColors.inkFaint)
                    Spacer()
                    maturityLabel(item.maturity)
                }

                Text(item.statement)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Text(evidenceLine(item))
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 26)
        }
    }

    // MARK: - Personal Rules chapter

    private var rulesChapter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.hairline)

            VStack(alignment: .leading, spacing: 14) {
                Text("MY PERSONAL RULES")
                    .font(Font(AppTypography.plusJakarta(size: 12, weight: 700)))
                    .tracking(1.6)
                    .foregroundStyle(AppColors.inkFaint)

                if manual.myPersonalRules.isEmpty {
                    Text("No rules kept yet. Experiments in Personal Lab become rules once the evidence holds.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(manual.myPersonalRules.enumerated()), id: \.element.id) { index, rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.statement)
                                .font(.system(size: 19, weight: .regular, design: .serif))
                                .foregroundStyle(AppColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(rule.evidenceSource)
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkFaint)
                        }
                        .padding(.top, index == 0 ? 2 : 10)
                    }
                }
            }
            .padding(.vertical, 26)
        }
    }

    // MARK: - Unknowns chapter

    private var unknownsChapter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.hairline)

            VStack(alignment: .leading, spacing: 16) {
                Text("WHAT I STILL DON'T KNOW")
                    .font(Font(AppTypography.plusJakarta(size: 12, weight: 700)))
                    .tracking(1.6)
                    .foregroundStyle(AppColors.inkFaint)

                ForEach(manual.whatRebootStillDoesNotKnow) { unknown in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(unknown.statement)
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(unknown.evidenceSource)
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
            }
            .padding(.vertical, 26)
        }
    }

    // MARK: - Helpers

    /// Evidence line as quiet metadata; n-count only when real.
    private func evidenceLine(_ item: ManualItem) -> String {
        guard let n = item.observationCount, n > 0 else {
            return item.evidenceSource
        }
        return "\(item.evidenceSource) · \(n) observations"
    }

    /// Maturity as a two-word whisper, never a badge.
    private func maturityLabel(_ maturity: ManualMaturity) -> some View {
        Text(maturity.displayLabel.uppercased())
            .font(Font(AppTypography.plusJakarta(size: 10, weight: 600)))
            .tracking(0.8)
            .foregroundStyle(maturity == .repeatedSignal ? AppColors.coral : AppColors.inkFaint)
    }
}
