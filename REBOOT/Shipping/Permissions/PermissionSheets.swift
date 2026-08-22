import SwiftUI
import FamilyControls

// MARK: - Screen Time Permission Sheet

struct ScreenTimePermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAuthorize: () -> Void

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MetaLabel(text: "DIGITAL ENVIRONMENT", color: AppColors.coral)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 36, height: 36)
                            .background(AppColors.paperRaised)
                            .clipShape(Circle())
                    }
                }

                EditorialHeadline(text: "On-Device Screen Time Protection")
                    .padding(.top, 20)

                Text(
                    "REBOOT uses Apple's Screen Time framework to shield distracting apps during active sessions and scheduled focus windows.",
                    style: .todaySentence
                )
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 10)

                VStack(spacing: 12) {
                    permissionPoint(
                        icon: "lock.shield",
                        title: "100% Private & Local",
                        detail: "App tokens remain on your device. REBOOT never receives app names or browsing history."
                    )
                    permissionPoint(
                        icon: "hand.raised",
                        title: "Friction, Not Punishment",
                        detail: "Shields active only during focus blocks. You can unlock apps at any time."
                    )
                    permissionPoint(
                        icon: "bolt.horizontal",
                        title: "Adaptive Escalation",
                        detail: "REBOOT starts with physical placement first, only shielding when lower friction is insufficient."
                    )
                }
                .padding(.top, 24)

                Spacer()

                PrimaryPillButton(
                    title: "Connect Screen Time",
                    symbol: "hourglass",
                    action: {
                        onAuthorize()
                        dismiss()
                    }
                )
                .padding(.top, 20)

                Button("Maybe Later") {
                    dismiss()
                }
                .type(.footnote)
                .foregroundStyle(AppColors.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .padding(24)
        }
    }

    private func permissionPoint(icon: String, title: String, detail: String) -> some View {
        PaperCard(radius: 18, padding: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.coral)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                    Text(detail)
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
        }
    }
}

// MARK: - Notification Permission Sheet

struct NotificationPermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAllow: () -> Void

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MetaLabel(text: "LOCAL REMINDERS", color: AppColors.coral)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 36, height: 36)
                            .background(AppColors.paperRaised)
                            .clipShape(Circle())
                    }
                }

                EditorialHeadline(text: "Quiet Daily Reminders")
                    .padding(.top, 20)

                Text(
                    "Optional local notifications to let you know when today's practice is ready or when a Focus Window begins.",
                    style: .todaySentence
                )
                .foregroundStyle(AppColors.inkSoft)
                .padding(.top, 10)

                VStack(spacing: 12) {
                    permissionPoint(
                        icon: "bell.slash",
                        title: "Zero Spam or Streaks",
                        detail: "No guilt-inducing reminders, no fake urgency, and no engagement bait."
                    )
                    permissionPoint(
                        icon: "clock",
                        title: "You Choose the Timing",
                        detail: "Set your preferred session reminder time in Settings whenever you wish."
                    )
                }
                .padding(.top, 24)

                Spacer()

                PrimaryPillButton(
                    title: "Allow Notifications",
                    symbol: "bell",
                    action: {
                        onAllow()
                        dismiss()
                    }
                )
                .padding(.top, 20)

                Button("Not Now") {
                    dismiss()
                }
                .type(.footnote)
                .foregroundStyle(AppColors.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .padding(24)
        }
    }

    private func permissionPoint(icon: String, title: String, detail: String) -> some View {
        PaperCard(radius: 18, padding: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.coral)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .type(.heroReason)
                        .foregroundStyle(AppColors.ink)
                    Text(detail)
                        .type(.footnote)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
        }
    }
}
