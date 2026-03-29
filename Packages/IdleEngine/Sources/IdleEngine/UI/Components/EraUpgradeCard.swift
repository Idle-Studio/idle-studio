import SwiftUI

/// Card displaying a one-time purchasable era upgrade.
/// Shows the effect type icon, name, description, cost, and a buy/purchased state.
public struct EraUpgradeCard: View {
    public let upgrade: ThemeEraUpgrade
    public let isPurchased: Bool
    public let canAfford: Bool
    public let onPurchase: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        upgrade: ThemeEraUpgrade,
        isPurchased: Bool,
        canAfford: Bool,
        onPurchase: @escaping () -> Void
    ) {
        self.upgrade = upgrade
        self.isPurchased = isPurchased
        self.canAfford = canAfford
        self.onPurchase = onPurchase
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Effect type icon
            Image(systemName: effectIcon)
                .font(.title3)
                .foregroundStyle(isPurchased ? theme.textSecondaryColor : theme.goldAccentColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            // Name + description
            VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.displayName)
                    .font(Typography.headline)
                    .foregroundStyle(theme.textPrimaryColor)
                    .lineLimit(1)

                Text(upgrade.description)
                    .font(Typography.caption)
                    .foregroundStyle(theme.textSecondaryColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Cost / purchased state
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Purchased")
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    costLabel
                    Button(action: onPurchase) {
                        Text("BUY")
                            .font(Typography.subheadline.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(canAfford ? theme.goldAccentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(canAfford ? .black : theme.textSecondaryColor)
                            .clipShape(.capsule)
                    }
                    .disabled(!canAfford)
                    .accessibilityLabel("Buy \(upgrade.displayName)")
                    .accessibilityHint("Double-tap to purchase this upgrade")
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .opacity(isPurchased ? 0.55 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isPurchased)
    }

    // MARK: - Private

    private var effectIcon: String {
        if upgrade.productionMultiplier > 1 { return "bolt.fill" }
        if upgrade.costDiscountFraction > 0 { return "tag.fill" }
        if upgrade.offlineMultiplier > 1    { return "moon.fill" }
        return "sparkles"
    }

    private var costLabel: some View {
        let parts = upgrade.cost.amounts
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { "\($0.value.idleFormatted()) \($0.key)" }
        return Text(parts.joined(separator: " · "))
            .font(Typography.caption)
            .foregroundStyle(canAfford ? theme.goldAccentColor : theme.textSecondaryColor)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26, macOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            theme.surfaceColor
        }
    }
}

// MARK: - Equatable

extension EraUpgradeCard: Equatable {
    public nonisolated static func == (lhs: EraUpgradeCard, rhs: EraUpgradeCard) -> Bool {
        lhs.upgrade.id == rhs.upgrade.id &&
        lhs.isPurchased == rhs.isPurchased &&
        lhs.canAfford == rhs.canAfford
    }
}
