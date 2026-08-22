import SwiftUI

struct DataPrivacyView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showEraseConfirmation = false
    @State private var showFinalEraseConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            MetaLabel(text: "DATA & PRIVACY", color: AppColors.coral)
                            EditorialHeadline(text: "Your Attention, Fully Local")
                            Text(
                                "REBOOT operates on an uncompromising local-first model. Your cognitive data never leaves this device.",
                                style: .todaySentence
                            )
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 4)
                        }

                        // Architecture Card
                        PaperCard(radius: 20, padding: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "internaldrive")
                                        .foregroundStyle(AppColors.coral)
                                    Text("On-Device Storage Only")
                                        .type(.heroReason)
                                        .foregroundStyle(AppColors.ink)
                                }
                                Text("Session recordings, task switch logs, rule discoveries, and fuel context snapshots are encoded into local app sandbox storage. There are no remote sync databases or cloud profiles.")
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkSoft)
                                    .lineSpacing(4)
                            }
                        }

                        // Export Attention Operating Manual
                        PaperCard(radius: 20, padding: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Export Operating Manual")
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                                Text("Download a plain-text markdown export of your complete 11-dimension Attention Operating Manual.")
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkSoft)

                                ShareLink(
                                    item: product.operatingManual.exportAsText(),
                                    subject: Text("REBOOT — Attention Operating Manual"),
                                    message: Text("Exported Attention Operating Manual from REBOOT.")
                                ) {
                                    GlassPill(text: "Export as Text", symbol: "square.and.arrow.up", tint: AppColors.ink)
                                }
                            }
                        }

                        // Erase Data Section
                        PaperCard(radius: 20, padding: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.red)
                                    Text("Erase All Data")
                                        .type(.heroReason)
                                        .foregroundStyle(Color.red)
                                }
                                Text("Permanently deletes all historical sessions, diagnosed profile models, discovered rules, and settings from this iPhone.")
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkSoft)

                                Button(role: .destructive) {
                                    showEraseConfirmation = true
                                } label: {
                                    Text("Erase All REBOOT Data")
                                        .type(.heroReason)
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.red.opacity(0.88))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
            .confirmationDialog(
                "Are you sure you want to erase all data?",
                isPresented: $showEraseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Erase All Data", role: .destructive) {
                    showFinalEraseConfirmation = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your session history, rules, and operating manual will be permanently lost.")
            }
            .alert(
                "Confirm Permanent Deletion",
                isPresented: $showFinalEraseConfirmation
            ) {
                Button("Permanently Delete", role: .destructive) {
                    eraseAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All local records will be completely deleted and the app will reset to the introduction.")
            }
        }
    }

    private func eraseAllData() {
        product.reset()
        state.reset()
        dismiss()
    }
}
