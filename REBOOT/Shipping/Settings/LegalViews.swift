import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        EditorialHeadline(text: "Privacy Policy")
                            .padding(.top, 10)

                        Text("Last updated: August 2026")
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)

                        legalSection(
                            title: "1. Local-First Architecture",
                            content: "REBOOT is built with an uncompromising local-first privacy architecture. All attention diagnoses, focus session recordings, interruption triggers, personal rules, fuel context logs, and operating manual synthesis occur entirely on your device."
                        )

                        legalSection(
                            title: "2. Apple Screen Time & FamilyControls",
                            content: "When you grant Screen Time access, REBOOT uses Apple's native framework solely to place local shields on selected distracting apps during active focus sessions. REBOOT never receives, records, or transmits the names, bundle IDs, or contents of the apps you use."
                        )

                        legalSection(
                            title: "3. No Analytics or Third-Party Tracking",
                            content: "REBOOT does not integrate advertising SDKs, tracking pixels, or third-party behavioral analytics. We do not sell, rent, or monetize your personal focus data."
                        )

                        legalSection(
                            title: "4. StoreKit & Subscriptions",
                            content: "In-app purchases and subscription transactions are processed directly by Apple via StoreKit 2. We never have access to your credit card or billing details."
                        )

                        legalSection(
                            title: "5. Data Deletion",
                            content: "You can permanently erase all data collected by REBOOT at any time via Settings → Erase All Data. Uninstalling the app also removes all local sandboxed data."
                        )

                        Link(destination: AppConfig.privacyPolicyURL) {
                            HStack {
                                Text("View Web Version")
                                    .type(.heroReason)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(AppColors.coral)
                            .padding(.top, 10)
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
        }
    }

    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .type(.heroReason)
                .foregroundStyle(AppColors.ink)
            Text(content)
                .type(.footnote)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(4)
        }
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        EditorialHeadline(text: "Terms of Service")
                            .padding(.top, 10)

                        Text("Last updated: August 2026")
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkFaint)

                        legalSection(
                            title: "1. Acceptance of Terms",
                            content: "By downloading, accessing, or using REBOOT, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the application."
                        )

                        legalSection(
                            title: "2. Non-Medical Disclaimer",
                            content: "REBOOT is an attention training protocol and personal operating manual designed for educational and cognitive practice purposes. REBOOT is not a medical device, mental health service, or medical treatment. It is not intended to diagnose, treat, prevent, or cure ADHD or any other clinical condition."
                        )

                        legalSection(
                            title: "3. Subscriptions & Billing",
                            content: "Payment is charged to your Apple ID Account at confirmation of purchase. Subscriptions automatically renew unless cancelled at least 24 hours prior to the end of the current period in your Apple ID Account Settings."
                        )

                        legalSection(
                            title: "4. User Ownership & Intellectual Property",
                            content: "You own all session reflections, notes, and personal rules generated on your device. REBOOT's algorithms, curriculum, interface, and branding are the intellectual property of REBOOT."
                        )

                        Link(destination: AppConfig.termsOfServiceURL) {
                            HStack {
                                Text("View Web Version")
                                    .type(.heroReason)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(AppColors.coral)
                            .padding(.top, 10)
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
        }
    }

    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .type(.heroReason)
                .foregroundStyle(AppColors.ink)
            Text(content)
                .type(.footnote)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(4)
        }
    }
}
