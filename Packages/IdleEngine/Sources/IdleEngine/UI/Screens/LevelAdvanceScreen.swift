import SwiftUI

/// Full-screen celebration shown when the player completes a level advance (prestige-lite).
/// All copy comes from `theme.copy` — no hardcoded strings.
public struct LevelAdvanceScreen: View {
    public let completedLevelName: String
    public let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(completedLevelName: String, onDismiss: @escaping () -> Void) {
        self.completedLevelName = completedLevelName
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Celebration icon
                Image(systemName: "star.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(theme.goldAccentColor)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55), value: appeared)

                // Theme-supplied title and flavor
                VStack(spacing: 12) {
                    Text(theme.copy.prestigeTitle)
                        .font(Typography.display)
                        .foregroundStyle(theme.textPrimaryColor)
                        .multilineTextAlignment(.center)

                    Text(completedLevelName)
                        .font(Typography.title)
                        .foregroundStyle(theme.goldAccentColor)

                    Text(theme.copy.levelCompleteSubtitle)
                        .font(Typography.body)
                        .foregroundStyle(theme.textSecondaryColor)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.2), value: appeared)

                Spacer()

                // Continue button
                Button(action: onDismiss) {
                    Text(theme.copy.continueButton)
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.goldAccentColor)
                        .foregroundStyle(.black)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.5), value: appeared)
            }
        }
        .onAppear { appeared = true }
        .accessibilityAction(named: Text(theme.copy.continueButton)) { onDismiss() }
    }
}
