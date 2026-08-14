import SwiftUI
import UserNotifications

/// Custom pre-permission modal shown before the iOS system notification prompt.
/// Displays a value-prop layout with bullet-point benefits from theme copy.
/// "Enable" triggers the iOS system prompt; "Maybe Later" records the ask and dismisses without prompting.
public struct NotificationPermissionSheet: View {
    let prestigeCount: Int
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    @State private var isRequesting = false

    public init(prestigeCount: Int, onDismiss: @escaping () -> Void) {
        self.prestigeCount = prestigeCount
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Bell icon with era-accent gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.goldAccentColor, theme.goldAccentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            // Title
            Text(theme.copy.notificationPermission.title)
                .font(Typography.display)
                .foregroundStyle(theme.textPrimaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Body
            Text(theme.copy.notificationPermission.body)
                .font(Typography.body)
                .foregroundStyle(theme.textSecondaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)

            // Bullet points
            if !theme.copy.notificationPermission.bulletPoints.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(theme.copy.notificationPermission.bulletPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.goldAccentColor)
                                .font(.body)
                            Text(point)
                                .font(Typography.body)
                                .foregroundStyle(theme.textPrimaryColor)
                        }
                    }
                }
                .padding(16)
                .background(theme.surfaceColor)
                .clipShape(.rect(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            Spacer(minLength: 24)

            // Enable button
            Button {
                enable()
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(theme.copy.notificationPermission.enableButton)
                            .font(Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.goldAccentColor)
                .foregroundStyle(.black)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(isRequesting)
            .padding(.horizontal, 24)

            // Maybe Later button
            Button {
                recordAsked()
                onDismiss()
            } label: {
                Text(theme.copy.notificationPermission.laterButton)
                    .font(Typography.subheadline)
                    .foregroundStyle(theme.textSecondaryColor)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        .presentationBackground(.ultraThinMaterial)
        .presentationDragIndicator(.visible)
    }

    private func enable() {
        isRequesting = true
        recordAsked()
        Task {
            let granted = await LiveNotificationService().requestPermission()
            await MainActor.run {
                isRequesting = false
                _ = granted // analytics hook point
                onDismiss()
            }
        }
    }

    private func recordAsked() {
        UserDefaults.standard.set(true, forKey: "notif_asked_prestige_\(prestigeCount)")
    }
}
