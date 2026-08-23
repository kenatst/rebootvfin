import SwiftUI

/// DATA & PRIVACY hub: local-first explanation, whole-app data export,
/// and a real erase-all that returns the app to a true first-launch state.
struct DataPrivacyView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var state: AppState
    var environmentStore: EnvironmentStore? = nil
    var notificationService: NotificationService? = nil
    var subscriptionStore: SubscriptionStore? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var showEraseConfirmation = false
    @State private var showFinalEraseConfirmation = false
    @State private var eraseAcknowledgeChecked = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        architectureCard
                        exportCard
                        legalLinksCard
                        eraseCard
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
            .confirmationDialog(
                L("Erase all REBOOT data?"),
                isPresented: $showEraseConfirmation,
                titleVisibility: .visible
            ) {
                Button(L("Continue"), role: .destructive) {
                    showFinalEraseConfirmation = true
                }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("This permanently deletes your sessions, profile, rules, experiments, environment setup, and Operating Manual from this iPhone. It cannot be undone."))
            }
            .alert(
                L("Confirm permanent deletion"),
                isPresented: $showFinalEraseConfirmation
            ) {
                Button(L("Permanently Delete"), role: .destructive) {
                    eraseAllData()
                }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("Everything will be deleted and REBOOT will return to its first launch. Your Apple subscription is managed separately in your Apple ID settings and is not deleted by this."))
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: L("DATA & PRIVACY"), color: AppColors.coral)
            EditorialHeadline(text: L("Your attention, fully local"))
            Text(
                L("REBOOT keeps everything on this device. There is no account, no cloud profile, and no analytics."),
                style: .todaySentence
            )
            .foregroundStyle(AppColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
    }

    private var architectureCard: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(AppColors.coral)
                    Text(L("On-device storage only"))
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                }
                Text(L("Diagnosis answers, session records, switch and return evidence, personal rules, experiment results, Fuel context, Flow projects, environment settings, and your Operating Manual are stored in the app's local sandbox on this iPhone. Nothing is transmitted to REBOOT or to anyone else."))
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(4)
            }
        }
    }

    /// GDPR-style portability: one JSON document containing every meaningful
    /// piece of personal state REBOOT holds, shared through the native sheet.
    private var exportCard: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .foregroundStyle(AppColors.coral)
                    Text(L("Export my REBOOT data"))
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                }
                Text(L("A single JSON file containing everything REBOOT knows: diagnosis answers, profile, sessions, rules, experiments, Flow projects and evidence, Fuel history, environment observations, reviews, and your Operating Manual. Nothing leaves your device except through the share sheet you control."))
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(4)

                ShareLink(
                    item: exportItem,
                    subject: Text("REBOOT data export"),
                ) {
                    GlassPill(text: L("Export as JSON"), symbol: "square.and.arrow.up", tint: AppColors.ink)
                }
            }
        }
    }

    /// A real .json file when the export can be written, otherwise the raw
    /// JSON payload — the share sheet always carries the full document.
    private var exportItem: String {
        RebootDataExport.writeFile(product: product, answers: state.answers)?.absoluteString
            ?? RebootDataExport.jsonString(product: product, answers: state.answers)
    }

    private var legalLinksCard: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(AppColors.coral)
                    Text(L("Legal"))
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                }
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    LegalRowLabel(title: L("Privacy Policy"))
                }
                Divider().overlay(AppColors.hairline)
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    LegalRowLabel(title: L("Terms of Service"))
                }
            }
        }
    }

    private var eraseCard: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                    Text(L("Erase all data"))
                        .type(.heroReason)
                        .foregroundStyle(Color.red)
                }
                Text(L("Permanently deletes everything REBOOT has learned — sessions, profile, rules, experiments, Flow projects, environment setup, notifications, and your Operating Manual — and returns the app to its first launch. Screen Time authorization and notification permission are Apple settings and remain; scheduled protections are removed."))
                    .type(.footnote)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(4)

                Toggle(isOn: $eraseAcknowledgeChecked) {
                    Text(L("I understand this cannot be undone"))
                        .type(.footnote)
                        .foregroundStyle(AppColors.ink)
                        .tint(AppColors.coral)
                }
                .padding(.top, 2)

                Button(role: .destructive) {
                    showEraseConfirmation = true
                } label: {
                    Text(L("Erase All REBOOT Data"))
                        .type(.heroReason)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(eraseAcknowledgeChecked ? 0.88 : 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!eraseAcknowledgeChecked)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Erase chain

    private func eraseAllData() {
        notificationService?.eraseAllData()
        environmentStore?.eraseAllData()
        subscriptionStore?.clearCachedEntitlement()
        product.erasePersistedData()
        state.reset()
        dismiss()
        // ContentView observes state.phase; resetting to .cinematic routes the
        // user back to the true first-launch experience.
    }
}

private struct LegalRowLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .type(.heroReason)
                .foregroundStyle(AppColors.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.inkFaint)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
