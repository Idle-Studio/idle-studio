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
    /// Quantity mode selected for the whole list. Was `@State private` and never mutated —
    /// no picker, no long-press, no cycle — so `×10` and `MAX` were unreachable dead code
    /// and players could only buy one unit at a time. Bulk buy is table stakes in this
    /// genre and the engine supported it all along.
    public let buyQuantity: BuyQuantity
    /// Resolved quantity for `.max`, supplied by the owner via `GameEngine.maxAffordable`.
    /// The `.max` sentinel must never reach `purchaseUnit`.
    public let maxAffordable: Int
    public let onPurchase: (Int) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        unit: ThemeUnit,
        ownedCount: Int,
        canAfford: Bool,
        discountMultiplier: Decimal = 1,
        buyQuantity: BuyQuantity = .one,
        maxAffordable: Int = 0,
        onPurchase: @escaping (Int) -> Void
    ) {
        self.unit = unit
        self.ownedCount = ownedCount
        self.canAfford = canAfford
        self.discountMultiplier = discountMultiplier
        self.buyQuantity = buyQuantity
        self.maxAffordable = maxAffordable
        self.onPurchase = onPurchase
    }

    /// Concrete quantity to purchase for the current mode.
    private var resolvedQuantity: Int {
        switch buyQuantity {
        case .one: return 1
        case .ten: return 10
        case .max: return max(1, maxAffordable)
        }
    }

    private var isPurchasable: Bool {
        buyQuantity == .max ? maxAffordable > 0 : canAfford
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
                // Fires only on a purchase the engine will accept. The haptic used to run
                // before `onPurchase`, so a rejected purchase still felt successful.
                guard isPurchasable else { return }
                HapticsService.impact(.medium)
                onPurchase(resolvedQuantity)
            } label: {
                HStack(spacing: 4) {
                    if !isPurchasable {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    Text(buyButtonLabel)
                        .font(Typography.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14)
                // The primary action in a game built on repeated purchases was a ~26pt
                // target. Apple's minimum is 44pt.
                .frame(minWidth: 64, minHeight: 44)
                .background(buyButtonBackground)
                .foregroundStyle(isPurchasable ? .black : theme.textSecondaryColor)
                .clipShape(.capsule)
            }
            .disabled(!isPurchasable)
            .accessibilityLabel(buyAccessibilityLabel)
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
        case .one: return totalCost.idleFormatted()
        case .ten: return "×10  \(totalCost.idleFormatted())"
        case .max: return maxAffordable > 0 ? "MAX ×\(maxAffordable)" : "MAX"
        }
    }

    private var buyAccessibilityLabel: String {
        let quantity = resolvedQuantity
        let noun = quantity == 1 ? unit.displayName : "\(unit.displayName), \(quantity)"
        return "Buy \(noun) for \(totalCost.idleFormatted())"
    }

    /// Cost of the whole batch for the current mode — the button used to show only the cost
    /// of a single unit regardless of quantity.
    private var totalCost: Decimal {
        EconomyCalculator.bulkBuyCost(
            unit: unit,
            currentCount: ownedCount,
            quantity: resolvedQuantity,
            discountMultiplier: discountMultiplier
        )[theme.primaryCurrency]
    }
}

// MARK: - Equatable

extension UnitCard: Equatable {
    /// Compares only the data inputs. The `onPurchase` closure is intentionally excluded —
    /// closures aren't Equatable and the behaviour is always equivalent across renders.
    public nonisolated static func == (lhs: UnitCard, rhs: UnitCard) -> Bool {
        lhs.unit.id == rhs.unit.id &&
        lhs.ownedCount == rhs.ownedCount &&
        lhs.canAfford == rhs.canAfford &&
        lhs.discountMultiplier == rhs.discountMultiplier &&
        lhs.buyQuantity == rhs.buyQuantity &&
        lhs.maxAffordable == rhs.maxAffordable
    }
}

// MARK: - Buy Quantity

/// Bulk-purchase mode. Deliberately NOT backed by an `Int` raw value any more.
///
/// `.max` used to be `rawValue = -1` and that sentinel was passed straight through to
/// `GameEngine.purchaseUnit`, where `bulkBuyCost` returned `.zero` for it, an empty bundle
/// was trivially affordable, and the unit count went negative — after which `decimalPow` on
/// a negative exponent returned 0 and every later purchase of that unit was free.
public enum BuyQuantity: String, CaseIterable, Sendable, Identifiable {
    case one
    case ten
    case max

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .one: return "×1"
        case .ten: return "×10"
        case .max: return "MAX"
        }
    }
}
