import SwiftUI
import FamilyControls

struct SettingsView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var state: AppState
    @ObservedObject var environmentStore: EnvironmentStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss

    @State private var showRestartProgramConfirmation = false
    @State private var showPaywall = false
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    @State private var showDataPrivacySheet = false
    @State private var showScreenTimePermissionSheet = false
    @State private var showNotificationPermissionSheet = false
    @State private var showEnvironmentLab = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Membership Card
                        membershipHeaderCard

                        // 1. Program Section
                        programSection

                        // 2. Attention & Environment Section
                        attentionEnvironmentSection

                        // 3. Notifications Section
                        notificationsSection

                        // 4. Data & Privacy Section
                        dataPrivacySection

                        // 5. About & Legal Section
                        aboutLegalSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(subscriptionStore: subscriptionStore)
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsSheet) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showDataPrivacySheet) {
                DataPrivacyView(product: product, state: state)
            }
            .sheet(isPresented: $showScreenTimePermissionSheet) {
                ScreenTimePermissionSheet {
                    Task {
                        await environmentStore.requestAuthorization()
                    }
                }
            }
            .sheet(isPresented: $showNotificationPermissionSheet) {
                NotificationPermissionSheet {
                    Task {
                        _ = await notificationService.requestAuthorization()
                    }
                }
            }
            .sheet(isPresented: $showEnvironmentLab) {
                EnvironmentLabView(product: product, environmentStore: environmentStore)
            }
            .confirmationDialog(
                "Restart 90-Day Program?",
                isPresented: $showRestartProgramConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restart Program from Day 1", role: .destructive) {
                    restartProgram()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current day will reset to Day 1. Your previous session recordings and discoveries will remain preserved in your archive.")
            }
        }
    }

    // MARK: - Membership Header Card

    private var membershipHeaderCard: some View {
        PaperCard(radius: 22, padding: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(subscriptionStore.status.displayLabel)
                            .type(.heroReason)
                            .foregroundStyle(AppColors.ink)
                        if subscriptionStore.status.isPremium {
                            GlassPill(text: "Active", tint: AppColors.coral)
                        }
                    }
                    if let expiry = subscriptionStore.status.formattedExpiry {
                        Text(expiry)
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkSoft)
                    } else if !subscriptionStore.status.isPremium {
                        Text("Unlock 90-day program, daily guidance & operating manual.")
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
                Spacer()
                Button {
                    showPaywall = true
                } label: {
                    GlassPill(
                        text: subscriptionStore.status.isPremium ? "Manage" : "Upgrade",
                        symbol: subscriptionStore.status.isPremium ? "creditcard" : "sparkles",
                        tint: AppColors.ink
                    )
                }
            }
        }
    }

    // MARK: - 1. Program Section

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "PROGRAM", color: AppColors.coral)

            PaperCard(radius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Trajectory")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text(programStatusDescription)
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                    }

                    Divider()
                        .background(AppColors.hairline)

                    Button(role: .destructive) {
                        showRestartProgramConfirmation = true
                    } label: {
                        HStack {
                            Text("Restart 90-Day Program")
                                .type(.footnote)
                                .foregroundStyle(AppColors.coral)
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }
            }
        }
    }

    private var programStatusDescription: String {
        if product.ownModeState.active || product.programStatus == .completed {
            return "Own Mode (Program Graduated)"
        }
        return "Day \(product.day) of 90 · \(product.currentProgramPhase.title)"
    }

    private func restartProgram() {
        product.restartProgram()
    }

    // MARK: - 2. Attention & Environment Section

    private var attentionEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "ATTENTION & ENVIRONMENT", color: AppColors.coral)

            PaperCard(radius: 20, padding: 16) {
                VStack(spacing: 14) {
                    // Fuel Context Prompts Toggle
                    Toggle(isOn: Binding(
                        get: { product.fuelState.promptsEnabled },
                        set: { product.fuelState.promptsEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pre-Session Fuel Sampling")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text("Optional 1-tap sleep & energy context prompt.")
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                    }
                    .tint(AppColors.coral)

                    Divider().background(AppColors.hairline)

                    // Screen Time Connection
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Time Protection")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text(environmentStore.isConnected ? "Authorized & Connected" : "Not Connected")
                                .type(.footnote)
                                .foregroundStyle(environmentStore.isConnected ? Color.green : AppColors.inkSoft)
                        }
                        Spacer()
                        if !environmentStore.isConnected {
                            Button {
                                showScreenTimePermissionSheet = true
                            } label: {
                                GlassPill(text: "Connect", symbol: "hourglass", tint: AppColors.ink)
                            }
                        }
                    }

                    Divider().background(AppColors.hairline)

                    // Digital Environment Lab Link
                    Button {
                        showEnvironmentLab = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Digital Environment Lab")
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                                Text("Manage friction ladder, shields & focus windows.")
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "NOTIFICATIONS", color: AppColors.coral)

            PaperCard(radius: 20, padding: 16) {
                VStack(spacing: 14) {
                    // Daily Practice Reminder Toggle
                    Toggle(isOn: Binding(
                        get: { notificationService.preferences.dailyPracticeEnabled },
                        set: { enabled in
                            var updated = notificationService.preferences
                            updated.dailyPracticeEnabled = enabled
                            notificationService.updatePreferences(updated)
                            if enabled && notificationService.authorizationStatus != .authorized {
                                showNotificationPermissionSheet = true
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Practice Reminder")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text("Gentle notification when your session is ready.")
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                    }
                    .tint(AppColors.coral)

                    if notificationService.preferences.dailyPracticeEnabled {
                        HStack {
                            Text("Reminder Time")
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { notificationService.preferences.dailyPracticeTime },
                                    set: { newTime in
                                        var updated = notificationService.preferences
                                        updated.dailyPracticeTime = newTime
                                        notificationService.updatePreferences(updated)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }

                    Divider().background(AppColors.hairline)

                    // Weekly Review Alerts
                    Toggle(isOn: Binding(
                        get: { notificationService.preferences.weeklyReviewAlertsEnabled },
                        set: { enabled in
                            var updated = notificationService.preferences
                            updated.weeklyReviewAlertsEnabled = enabled
                            notificationService.updatePreferences(updated)
                            if enabled && notificationService.authorizationStatus != .authorized {
                                showNotificationPermissionSheet = true
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Review Alerts")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Text("Alert when a weekly checkpoint unlocks.")
                                .type(.footnote)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                    }
                    .tint(AppColors.coral)
                }
            }
        }
    }

    // MARK: - 4. Data & Privacy Section

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "DATA & PRIVACY", color: AppColors.coral)

            PaperCard(radius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Button {
                        showDataPrivacySheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local-First Architecture & Export")
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                                Text("Export Operating Manual or erase on-device records.")
                                    .type(.footnote)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. About & Legal Section

    private var aboutLegalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "ABOUT & LEGAL", color: AppColors.coral)

            PaperCard(radius: 20, padding: 16) {
                VStack(spacing: 14) {
                    HStack {
                        Text("Version")
                            .type(.heroReason)
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                        Text(AppConfig.fullVersionString)
                            .type(.footnote)
                            .foregroundStyle(AppColors.inkSoft)
                    }

                    Divider().background(AppColors.hairline)

                    Button { showPrivacySheet = true } label: {
                        HStack {
                            Text("Privacy Policy")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }

                    Divider().background(AppColors.hairline)

                    Button { showTermsSheet = true } label: {
                        HStack {
                            Text("Terms of Service")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }

                    Divider().background(AppColors.hairline)

                    Link(destination: URL(string: "mailto:\(AppConfig.supportEmail)")!) {
                        HStack {
                            Text("Contact Support")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Image(systemName: "envelope")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }
            }

            Text(AppConfig.medicalDisclaimer)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}
