import Foundation

/// Pure stateless economy math. All inputs and outputs are `Decimal`.
/// No side effects, no stored state — safe to call from any context.
public enum EconomyCalculator {

    // MARK: - Unit Costs

    /// Cost of purchasing one unit when the player already owns `currentCount`.
    /// Formula: `baseCost × multiplier^currentCount × discountMultiplier`
    /// Pass `discountMultiplier` < 1 to apply era upgrade cost discounts (e.g. 0.85 for −15%).
    public static func unitCost(unit: ThemeUnit, currentCount: Int, discountMultiplier: Decimal = 1) -> ResourceBundle {
        let factor = decimalPow(unit.costMultiplier, currentCount)
        return unit.baseCost * factor * discountMultiplier
    }

    /// Cost of purchasing `quantity` units starting from `currentCount` owned.
    /// Uses the closed-form geometric series:
    /// `baseCost × multiplier^n × (multiplier^k − 1) / (multiplier − 1) × discountMultiplier`
    public static func bulkBuyCost(unit: ThemeUnit, currentCount: Int, quantity: Int, discountMultiplier: Decimal = 1) -> ResourceBundle {
        guard quantity > 0 else { return .zero }
        guard quantity > 1 else { return unitCost(unit: unit, currentCount: currentCount, discountMultiplier: discountMultiplier) }
        let m = unit.costMultiplier
        let mPowN = decimalPow(m, currentCount)
        let mPowK = decimalPow(m, quantity)
        let factor = mPowN * (mPowK - 1) / (m - 1)
        return unit.baseCost * factor * discountMultiplier
    }

    /// Maximum number of units affordable given available `resources`.
    /// Binary searches the geometric series for the largest affordable quantity.
    public static func maxAffordable(unit: ThemeUnit, currentCount: Int, resources: ResourceBundle, discountMultiplier: Decimal = 1) -> Int {
        guard resources.canAfford(unitCost(unit: unit, currentCount: currentCount, discountMultiplier: discountMultiplier)) else { return 0 }
        var lo = 1
        var hi = 10_000
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if resources.canAfford(bulkBuyCost(unit: unit, currentCount: currentCount, quantity: mid, discountMultiplier: discountMultiplier)) {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    // MARK: - Production

    /// Total production per second for all units in `state`, applying upgrade tiers, prestige multiplier,
    /// and any purchased era upgrade production bonuses.
    /// Upgrade tiers stack cumulatively (tier 10 + tier 25 + tier 50 all apply at count 50).
    public static func productionRate(
        state: GameState,
        units: [ThemeUnit],
        eraUpgrades: [ThemeEraUpgrade] = []
    ) -> ResourceBundle {
        let prestigeBonus = prestigeMultiplier(tokens: state.prestigeTokens)
        let eraBonus = eraProductionMultiplier(purchasedIDs: state.purchasedUpgradeIDs, upgrades: eraUpgrades)
        return units.reduce(.zero) { total, unit in
            let count = state.unitCount(id: unit.id)
            guard count > 0 else { return total }
            let upgradeFactor = unit.upgradeTiers
                .filter { count >= $0.atCount }
                .reduce(Decimal(1)) { $0 * $1.multiplier }
            let perSecond = unit.baseProductionPerSecond * Decimal(count) * upgradeFactor * prestigeBonus * eraBonus
            return total + perSecond
        }
    }

    // MARK: - Prestige Math

    /// Legacy tokens that would be earned if the player prestiged now.
    /// Formula: `floor(sqrt(totalLifetimeGold / 3_000_000_000_000))`
    /// Tokens are always a non-negative integer.
    public static func legacyTokens(totalGold: Decimal) -> Decimal {
        let threshold: Decimal = 3_000_000_000_000
        guard totalGold >= threshold else { return 0 }
        let ratio = NSDecimalNumber(decimal: totalGold / threshold).doubleValue
        guard ratio.isFinite else { return 0 }
        return Decimal(Int(Foundation.sqrt(ratio)))
    }

    /// Production multiplier from accumulated prestige tokens.
    /// Formula: `1 + tokens × 0.02` (each token gives +2%)
    public static func prestigeMultiplier(tokens: Decimal) -> Decimal {
        guard tokens > 0 else { return 1 }
        return 1 + tokens * Decimal(string: "0.02")!
    }

    // MARK: - Era Upgrade Multipliers

    /// Product of all `productionMultiplier` values from purchased era upgrades.
    /// Returns 1.0 when no upgrades are purchased (no-op).
    public static func eraProductionMultiplier(purchasedIDs: Set<String>, upgrades: [ThemeEraUpgrade]) -> Decimal {
        upgrades
            .filter { purchasedIDs.contains($0.id) }
            .reduce(Decimal(1)) { $0 * $1.productionMultiplier }
    }

    /// Product of `(1 − costDiscountFraction)` for each purchased era upgrade with a cost discount.
    /// Returns 1.0 when no discount upgrades are purchased (no-op).
    /// Example: two upgrades with fractions 0.15 and 0.20 → 0.85 × 0.80 = 0.68.
    public static func eraCostMultiplier(purchasedIDs: Set<String>, upgrades: [ThemeEraUpgrade]) -> Decimal {
        upgrades
            .filter { purchasedIDs.contains($0.id) && $0.costDiscountFraction > 0 }
            .reduce(Decimal(1)) { $0 * (1 - $1.costDiscountFraction) }
    }

    /// Product of all `offlineMultiplier` values from purchased era upgrades.
    /// Returns 1.0 when no offline upgrades are purchased (no-op).
    public static func eraOfflineMultiplier(purchasedIDs: Set<String>, upgrades: [ThemeEraUpgrade]) -> Decimal {
        upgrades
            .filter { purchasedIDs.contains($0.id) }
            .reduce(Decimal(1)) { $0 * $1.offlineMultiplier }
    }

    // MARK: - Internal Helpers

    /// Fast integer exponentiation by repeated squaring. O(log n).
    /// Used throughout to avoid converting `Decimal` to `Double`.
    static func decimalPow(_ base: Decimal, _ exponent: Int) -> Decimal {
        guard exponent > 0 else { return exponent == 0 ? 1 : 0 }
        if exponent == 1 { return base }
        let half = decimalPow(base, exponent / 2)
        return exponent.isMultiple(of: 2) ? half * half : half * half * base
    }
}
