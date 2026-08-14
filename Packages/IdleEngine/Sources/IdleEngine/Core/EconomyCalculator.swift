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
    /// - Parameter milestoneBonuses: Bonuses from completed milestones, built by
    ///   `milestoneBonuses(completedIDs:milestones:)`. Defaults to none.
    ///
    /// Performance note: this used to allocate ~560 dictionaries per call by chaining
    /// `ResourceBundle *` (each of which allocated twice — once in `mapValues`, once in
    /// `init`'s zero-pruning filter) and `.filter` on the tier array. At 10 Hz over 40
    /// units that was ~5,600 heap allocations per second for a value that only changes
    /// on a purchase, prestige, or level advance. It now accumulates in place into a
    /// single dictionary. `GameEngine` additionally caches the result.
    public static func productionRate(
        state: GameState,
        units: [ThemeUnit],
        eraUpgrades: [ThemeEraUpgrade] = [],
        milestoneBonuses: MilestoneBonuses = .none
    ) -> ResourceBundle {
        let globalMultiplier = prestigeMultiplier(tokens: state.prestigeTokens)
            * eraProductionMultiplier(purchasedIDs: state.purchasedUpgradeIDs, upgrades: eraUpgrades)

        var totals: [String: Decimal] = [:]
        totals.reserveCapacity(8)

        for unit in units {
            let count = state.unitCount(id: unit.id)
            guard count > 0 else { continue }

            var tierMultiplier = Decimal(1)
            for tier in unit.upgradeTiers where count >= tier.atCount {
                tierMultiplier *= tier.multiplier
            }

            let scale = Decimal(count) * tierMultiplier * globalMultiplier
            let unitBonuses = milestoneBonuses.perUnitMultipliers[unit.id]

            for (resource, perUnit) in unit.baseProductionPerSecond.amounts {
                var amount = perUnit * scale
                if let resourceMultiplier = milestoneBonuses.globalMultipliers[resource] {
                    amount *= resourceMultiplier
                }
                if let unitMultiplier = unitBonuses?[resource] {
                    amount *= unitMultiplier
                }
                totals[resource, default: 0] += amount
            }
        }

        // Flat `add`-type milestone bonuses contribute regardless of units owned.
        for (resource, flat) in milestoneBonuses.flatAdditions {
            totals[resource, default: 0] += flat
        }

        return ResourceBundle(totals)
    }

    // MARK: - Milestone Bonuses

    /// Production bonuses granted by completed milestones, resolved per resource.
    ///
    /// The theme schema has always declared these (`ThemeMilestone.bonuses`) and every
    /// shipped theme authors them, but nothing ever read them — so wonders granted no
    /// production at all. For Idle Civilizations that is ×787.5 of promised output.
    public struct MilestoneBonuses: Sendable, Equatable {
        /// resource ID → multiplier applied to every unit's output of that resource.
        public var globalMultipliers: [String: Decimal]
        /// unit ID → (resource ID → multiplier), for `scope == .unit` bonuses.
        public var perUnitMultipliers: [String: [String: Decimal]]
        /// resource ID → flat per-second amount, for `type == .add` bonuses.
        public var flatAdditions: [String: Decimal]

        public static let none = MilestoneBonuses(
            globalMultipliers: [:], perUnitMultipliers: [:], flatAdditions: [:]
        )

        public init(
            globalMultipliers: [String: Decimal],
            perUnitMultipliers: [String: [String: Decimal]],
            flatAdditions: [String: Decimal]
        ) {
            self.globalMultipliers = globalMultipliers
            self.perUnitMultipliers = perUnitMultipliers
            self.flatAdditions = flatAdditions
        }
    }

    /// Resolves every bonus attached to a completed milestone into a `MilestoneBonuses`.
    ///
    /// Both `.level` and `.global` scopes apply for as long as the milestone stays
    /// completed. `.level` is *not* restricted to the level the milestone belongs to:
    /// milestone bonuses are the reward for building the wonder, and whether they survive
    /// a prestige reset is controlled separately by `isPermanentBonus`.
    ///
    /// - Parameters:
    ///   - completedIDs: `state.completedMilestoneIDs`.
    ///   - milestones: Every milestone in the theme (`theme.allMilestones`).
    public static func milestoneBonuses(
        completedIDs: Set<String>,
        milestones: [ThemeMilestone]
    ) -> MilestoneBonuses {
        guard !completedIDs.isEmpty else { return .none }

        var global: [String: Decimal] = [:]
        var perUnit: [String: [String: Decimal]] = [:]
        var flat: [String: Decimal] = [:]

        for milestone in milestones where completedIDs.contains(milestone.id) {
            for bonus in milestone.bonuses {
                switch (bonus.type, bonus.scope) {
                case (.multiply, .global), (.multiply, .level):
                    global[bonus.resource, default: 1] *= bonus.value
                case (.multiply, .unit):
                    guard let unitID = bonus.unitID else { continue }
                    perUnit[unitID, default: [:]][bonus.resource, default: 1] *= bonus.value
                case (.add, _):
                    flat[bonus.resource, default: 0] += bonus.value
                }
            }
        }

        return MilestoneBonuses(
            globalMultipliers: global, perUnitMultipliers: perUnit, flatAdditions: flat
        )
    }

    // MARK: - Prestige Math

    /// Legacy tokens that would be earned if the player prestiged now.
    /// Formula: `floor(sqrt(totalLifetimeGold / 3_000_000_000_000))`
    /// Tokens are always a non-negative integer.
    /// Lifetime primary-currency earnings required for the first prestige token.
    ///
    /// Exposed so tests assert against the same constant the implementation uses. When this
    /// was an inline literal, a rebalance moved it from 1e12 to 3e12 and six tests silently
    /// rotted — nobody noticed, because the suite had not compiled in months.
    public static let legacyTokenThreshold: Decimal = 3_000_000_000_000

    public static func legacyTokens(totalGold: Decimal) -> Decimal {
        let threshold = legacyTokenThreshold
        guard totalGold >= threshold, !totalGold.isNaN else { return 0 }
        let ratio = NSDecimalNumber(decimal: totalGold / threshold).doubleValue
        guard ratio.isFinite, ratio >= 0 else { return 0 }

        let root = Foundation.sqrt(ratio)
        // `Int(_: Double)` traps — it does not saturate — once the value passes Int.max.
        // Guarding `ratio.isFinite` above is the wrong quantity: the trap fires at
        // totalGold ≈ 2.552e50, where sqrt(ratio) crosses 9.22e18. Reachable via a
        // corrupted or synced save, and this runs inside SwiftUI body evaluation, so the
        // result was a crash on every launch with no way out.
        guard root.isFinite else { return maxLegacyTokens }
        guard root < Double(Int.max) else { return maxLegacyTokens }
        return Decimal(Int(root))
    }

    /// Ceiling returned by `legacyTokens` instead of trapping. Far beyond reachable play;
    /// exists so an impossible save degrades to a huge number rather than a crash.
    static let maxLegacyTokens = Decimal(Int.max)

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
    ///
    /// A negative exponent yields NaN rather than 0. This function's only callers compute
    /// *costs*, and a negative exponent is only reachable from a corrupt unit count — so
    /// returning 0 made everything free (`canAfford` on a zero cost is trivially true),
    /// whereas NaN is explicitly treated as unaffordable by `ResourceBundle.canAfford`.
    /// Fail closed, not open.
    static func decimalPow(_ base: Decimal, _ exponent: Int) -> Decimal {
        guard exponent >= 0 else { return .nan }
        guard exponent > 0 else { return 1 }
        if exponent == 1 { return base }
        let half = decimalPow(base, exponent / 2)
        return exponent.isMultiple(of: 2) ? half * half : half * half * base
    }
}
