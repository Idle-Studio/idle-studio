import Foundation

/// Prestige (reset) logic. Pure functions — no side effects.
///
/// "Prestige" is the engine's internal term. Each theme provides its own verb
/// via `ThemeCopy.advanceVerb` — the player may see "Advance Era" or "Master Cuisine",
/// never the word "prestige".
public enum PrestigeSystem {

    /// Minimum tokens that must be earned before a prestige is allowed.
    public static let minimumTokensRequired: Decimal = 1

    // MARK: - Token Calculation

    /// Tokens that will be earned if the player prestiges right now.
    public static func tokensEarned(from state: GameState) -> Decimal {
        EconomyCalculator.legacyTokens(totalGold: state.totalLifetimeGold)
    }

    // MARK: - Availability

    /// Returns true if the player meets all prestige requirements:
    /// - Has earned at least the minimum token threshold
    /// - Has completed the theme's gate milestone (if one is defined)
    public static func canPrestige(state: GameState, theme: any ThemePackage) -> Bool {
        let hasTokens = tokensEarned(from: state) >= minimumTokensRequired
        guard let gateID = theme.prestigeRequirementMilestoneID else { return hasTokens }
        return hasTokens && state.completedMilestoneIDs.contains(gateID)
    }

    // MARK: - What Survives a Reset

    /// Returns the subset of completed milestone IDs that are marked `isPermanentBonus`
    /// in the theme. These milestone bonuses survive the prestige reset.
    public static func persistentMilestoneIDs(
        state: GameState,
        theme: any ThemePackage
    ) -> Set<String> {
        let permanentIDs = Set(
            theme.allMilestones
                .filter { $0.isPermanentBonus }
                .map { $0.id }
        )
        return state.completedMilestoneIDs.intersection(permanentIDs)
    }
}
