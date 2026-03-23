import SwiftUI

/// A card displaying one purchasable unit. Shows name, description, count owned,
/// production rate, and a buy button. Reads vocabulary from `@Environment(\.theme)`.
///
/// "Unit" is the engine term — the displayed noun comes from `theme.copy.unitNoun`.
public struct UnitCard: View {
    public let unit: ThemeUnit
    public let ownedCount: Int
    public let canAfford: Bool
    public let discountMultiplier: Decimal
    public let onPurchase: (Int) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var buyQuantity: BuyQuantity = .one

    public init(
        unit: ThemeUnit,
        ownedCount: Int,
        canAfford: Bool,
        discountMultiplier: Decimal = 1,
        onPurchase: @escaping (Int) -> Void
    ) {
        self.unit = unit
        self.ownedCount = ownedCount
        self.canAfford = canAfford
        self.discountMultiplier = discountMultiplier
        self.onPurchase = onPurchase
    }

    public var body: some View {
        HStack(spacing: 12) {
            unitIcon
            unitInfo
            Spacer(minLength: 0)
            purchaseSection
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .opacity(canAfford ? 1 : 0.55)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: canAfford)
    }

    // MARK: - Subviews

    private var unitIcon: some View {
        Image(unit.iconAsset)
            .resizable()
            .scaledToFill()
            .frame(width: 52, height: 52)
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    private var unitInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(unit.displayName)
                .font(Typography.headline)
                .foregroundStyle(theme.textPrimaryColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(productionLabel)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
                .lineLimit(2)
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // Count badge
            Text("\(ownedCount)")
                .font(Typography.number)
                .foregroundStyle(theme.textPrimaryColor)
                .monospacedDigit()
                .animation(reduceMotion ? nil : .spring(response: 0.25), value: ownedCount)

            // Buy button
            Button {
                HapticsService.impact(.medium)
                onPurchase(buyQuantity.rawValue)
            } label: {
                HStack(spacing: 4) {
                    if !canAfford {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    Text(buyButtonLabel)
                        .font(Typography.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(buyButtonBackground)
                .foregroundStyle(canAfford ? .black : theme.textSecondaryColor)
                .clipShape(.capsule)
            }
            .disabled(!canAfford)
            .accessibilityLabel(buyAccessibilityLabel)
            .accessibilityHint("Double-tap to purchase")
        }
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

    @ViewBuilder
    private var buyButtonBackground: some View {
        if canAfford {
            theme.goldAccentColor
        } else {
            Color.secondary.opacity(0.2)
        }
    }

    // MARK: - Computed Labels

    private var productionLabel: String {
        let multiplier = Decimal(max(1, ownedCount))
        let parts = unit.baseProductionPerSecond.amounts
            .sorted { $0.key < $1.key }
            .map { "\(($0.value * multiplier).idleFormatted()) \($0.key)/s" }
        return parts.joined(separator: " · ")
    }

    private var buyButtonLabel: String {
        switch buyQuantity {
        case .one:  return nextCost.idleFormatted()
        case .ten:  return "×10"
        case .max:  return "MAX"
        }
    }

    private var buyAccessibilityLabel: String {
        "Buy \(buyQuantity.rawValue) \(unit.displayName) for \(nextCost.idleFormatted()) \(theme.primaryCurrency)"
    }

    private var nextCost: Decimal {
        EconomyCalculator.unitCost(unit: unit, currentCount: ownedCount, discountMultiplier: discountMultiplier)["gold"]
    }
}

// MARK: - Buy Quantity

enum BuyQuantity: Int, CaseIterable {
    case one = 1
    case ten = 10
    case max = -1 // sentinel — caller resolves via maxAffordable
}
