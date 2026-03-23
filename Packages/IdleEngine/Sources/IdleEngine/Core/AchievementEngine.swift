import Foundation

/// Pure achievement evaluation. No side effects — just checks conditions against state.
///
/// Called by `GameEngine` before every state broadcast. Returns only newly-earned IDs
/// (i.e. those not already in `state.earnedAchievementIDs`).
public enum AchievementEngine {

    /// Returns the IDs of achievements that are newly satisfied but not yet earned.
    public static func check(state: GameState, theme: any ThemePackage) -> Set<String> {
        var newlyEarned = Set<String>()
        for achievement in theme.achievements {
            guard !state.earnedAchievementIDs.contains(achievement.id) else { continue }
            if isMet(condition: achievement.condition, state: state, theme: theme) {
                newlyEarned.insert(achievement.id)
            }
        }
        return newlyEarned
    }

    // MARK: - Condition Evaluation

    private static func isMet(
        condition: AchievementCondition,
        state: GameState,
        theme: any ThemePackage
    ) -> Bool {
        switch condition.type {

        case "reachLevel":
            guard let targetOrder = condition.levelOrder else { return false }
            let currentOrder = theme.level(id: state.currentLevelID)?.order ?? 0
            return currentOrder >= targetOrder

        case "earnLifetimeGold":
            guard let amount = condition.goldAmount else { return false }
            return state.totalLifetimeGold >= amount

        case "prestigeCount":
            guard let count = condition.count else { return false }
            return state.totalPrestigeCount >= count

        case "completeMilestone":
            guard let milestoneID = condition.milestoneID else { return false }
            return state.completedMilestoneIDs.contains(milestoneID)

        case "completeMilestoneCount":
            guard let count = condition.count else { return false }
            return state.completedMilestoneIDs.count >= count

        case "ownUnitsTotal":
            guard let count = condition.count else { return false }
            let total = state.unitCounts.values.reduce(0, +)
            return total >= count

        case "purchaseUpgradesCount":
            guard let count = condition.count else { return false }
            return state.purchasedUpgradeIDs.count >= count

        case "totalPlayHours":
            guard let hours = condition.playHours else { return false }
            return state.totalPlaySeconds >= hours * 3600

        default:
            return false
        }
    }
}
