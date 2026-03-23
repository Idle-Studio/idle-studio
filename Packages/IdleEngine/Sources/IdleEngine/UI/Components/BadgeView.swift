import SwiftUI

// MARK: - BadgeView

/// Activity-app-style circular badge.
/// Earned: vivid gradient ring + glow + full color.
/// Locked: grayscale fill + lock overlay + dimmed title.
public struct BadgeView: View {
    public let achievement: ThemeAchievement
    public let isEarned: Bool

    @State private var showDetail = false

    public init(achievement: ThemeAchievement, isEarned: Bool) {
        self.achievement = achievement
        self.isEarned = isEarned
    }

    private var gradientColors: [Color] {
        achievement.badgeColors.prefix(2).map { Color(hex: $0) }
    }

    private var primaryColor: Color {
        gradientColors.first ?? .gray
    }

    public var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 8) {
                badgeCircle
                    .frame(width: 72, height: 72)

                Text(achievement.displayName)
                    .font(Typography.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(isEarned ? .white : .white.opacity(0.4))
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(achievement.displayName), \(isEarned ? "earned" : "locked")")
        .accessibilityHint("Double-tap to view details")
        .sheet(isPresented: $showDetail) {
            BadgeDetailSheet(achievement: achievement, isEarned: isEarned)
        }
    }

    // MARK: - Circle

    @ViewBuilder
    private var badgeCircle: some View {
        ZStack {
            if isEarned {
                // Glow behind
                Circle()
                    .fill(primaryColor.opacity(0.35))
                    .blur(radius: 10)
                    .scaleEffect(1.3)

                // Gradient fill
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors.count >= 2 ? gradientColors : [primaryColor, primaryColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: primaryColor.opacity(0.6), radius: 8, y: 2)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.08))
            }

            // Icon
            Image(systemName: achievement.iconSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(isEarned ? .white : .white.opacity(0.25))

            // Lock overlay for unearned badges — provides non-color state indicator
            if !isEarned {
                Circle()
                    .fill(Color.black.opacity(0.3))
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(x: 20, y: 20)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - BadgeDetailSheet

struct BadgeDetailSheet: View {
    let achievement: ThemeAchievement
    let isEarned: Bool
    @Environment(\.dismiss) private var dismiss

    private var gradientColors: [Color] {
        achievement.badgeColors.prefix(2).map { Color(hex: $0) }
    }
    private var primaryColor: Color { gradientColors.first ?? .gray }

    var body: some View {
        VStack(spacing: 24) {
                // Large badge
                ZStack {
                    if isEarned {
                        Circle()
                            .fill(primaryColor.opacity(0.25))
                            .blur(radius: 24)
                            .frame(width: 150, height: 150)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: gradientColors.count >= 2 ? gradientColors : [primaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: primaryColor.opacity(0.7), radius: 20)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 110, height: 110)
                    }

                    Image(systemName: achievement.iconSymbol)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(isEarned ? .white : .white.opacity(0.2))
                }
                .padding(.top, 12)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(achievement.displayName)
                        .font(Typography.title)
                        .foregroundStyle(.white)

                    Text(achievement.description)
                        .font(Typography.body)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Status pill
                HStack(spacing: 6) {
                    Image(systemName: isEarned ? "checkmark.circle.fill" : "lock.fill")
                    Text(isEarned ? "Earned" : "Locked")
                        .font(Typography.caption.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isEarned ? primaryColor.opacity(0.3) : Color.white.opacity(0.1))
                )
                .foregroundStyle(isEarned ? primaryColor : Color.white.opacity(0.4))

                // Category label
                Text(achievement.category.displayName.uppercased())
                    .font(Typography.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .tracking(1.2)

                Spacer()

                Button("Close") { dismiss() }
                    .font(Typography.body)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}
