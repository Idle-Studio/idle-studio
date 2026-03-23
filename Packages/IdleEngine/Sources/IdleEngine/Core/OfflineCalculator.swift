import Foundation

/// Calculates income earned while the player was away.
/// Caps at 8 hours to maintain game balance.
public enum OfflineCalculator {

    /// Maximum time credited for offline income: 8 hours.
    public static let maxCapSeconds: TimeInterval = 8 * 3_600

    /// Calculates resources earned during `awayDuration`.
    /// - Parameters:
    ///   - state: Game state at the moment the player left.
    ///   - units: All units from the active theme.
    ///   - awayDuration: Actual seconds away. Capped at `maxCapSeconds`.
    ///   - eraUpgrades: Upgrades for the current era (applied for production and offline bonuses).
    /// - Returns: An `OfflineResult` with the earned resources and cap info.
    public static func calculate(
        state: GameState,
        units: [ThemeUnit],
        awayDuration: TimeInterval,
        eraUpgrades: [ThemeEraUpgrade] = []
    ) -> OfflineResult {
        let effectiveDuration = min(awayDuration, maxCapSeconds)
        let ratePerSecond = EconomyCalculator.productionRate(state: state, units: units, eraUpgrades: eraUpgrades)
        let offlineBonus = EconomyCalculator.eraOfflineMultiplier(purchasedIDs: state.purchasedUpgradeIDs, upgrades: eraUpgrades)
        let earned = ratePerSecond * Decimal(effectiveDuration) * offlineBonus
        return OfflineResult(
            earnedResources: earned,
            effectiveDuration: effectiveDuration,
            wasCapped: awayDuration > maxCapSeconds
        )
    }
}

// MARK: - OfflineResult

public struct OfflineResult: Sendable, Equatable {
    /// Resources earned during the offline period.
    public let earnedResources: ResourceBundle
    /// Seconds actually credited (≤ `OfflineCalculator.maxCapSeconds`).
    public let effectiveDuration: TimeInterval
    /// True if `awayDuration` exceeded the cap.
    public let wasCapped: Bool

    public init(earnedResources: ResourceBundle, effectiveDuration: TimeInterval, wasCapped: Bool) {
        self.earnedResources = earnedResources
        self.effectiveDuration = effectiveDuration
        self.wasCapped = wasCapped
    }
}
