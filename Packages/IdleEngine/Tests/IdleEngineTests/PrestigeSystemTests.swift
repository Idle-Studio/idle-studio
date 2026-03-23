import Foundation
import Testing
@testable import IdleEngine

@Suite("PrestigeSystem")
struct PrestigeSystemTests {

    // MARK: - canPrestige

    @Test("Cannot prestige with zero lifetime gold")
    func cannotPrestigeWithNoGold() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(!PrestigeSystem.canPrestige(state: state))
    }

    @Test("Cannot prestige just below the 1-trillion threshold")
    func cannotPrestigeJustBelowThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(999_999_999_999)
        #expect(!PrestigeSystem.canPrestige(state: state))
    }

    @Test("Can prestige at exactly 1 trillion gold (1 token earned)")
    func canPrestigeAtThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(1_000_000_000_000)
        #expect(PrestigeSystem.canPrestige(state: state))
    }

    @Test("Can prestige well above threshold")
    func canPrestigeWellAboveThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(100_000_000_000_000)
        #expect(PrestigeSystem.canPrestige(state: state))
    }

    // MARK: - tokensEarned

    @Test("Tokens earned matches EconomyCalculator.legacyTokens")
    func tokensEarnedMatchesCalculator() {
        let gold: Decimal = 9_000_000_000_000
        let state = GameState.initial(firstLevelID: "test").withGold(gold)
        let fromSystem = PrestigeSystem.tokensEarned(from: state)
        let fromCalc = EconomyCalculator.legacyTokens(totalGold: gold)
        #expect(fromSystem == fromCalc)
    }

    @Test("Tokens earned are 0 below threshold")
    func tokensEarnedBelowThreshold() {
        let state = GameState.initial(firstLevelID: "test").withGold(500_000_000_000)
        #expect(PrestigeSystem.tokensEarned(from: state) == 0)
    }

    @Test("Tokens earned scale with gold earned")
    func tokensEarnedScaling() {
        let state4t = GameState.initial(firstLevelID: "test").withGold(4_000_000_000_000)
        let state9t = GameState.initial(firstLevelID: "test").withGold(9_000_000_000_000)
        #expect(PrestigeSystem.tokensEarned(from: state4t) == 2)
        #expect(PrestigeSystem.tokensEarned(from: state9t) == 3)
    }

    // MARK: - persistentMilestoneIDs

    @Test("Empty completed milestones → empty persistent set")
    func emptyCompletedMilestonesYieldsEmpty() {
        let theme = MockThemePackage.fixture(permanentMilestoneID: "great_wall")
        let state = GameState.initial(firstLevelID: "level_1")
        let kept = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        #expect(kept.isEmpty)
    }

    @Test("Permanent milestone is preserved through prestige")
    func permanentMilestonePreserved() {
        let theme = MockThemePackage.fixture(permanentMilestoneID: "milestone_regular")
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "milestone_regular")
        let kept = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        #expect(kept.contains("milestone_regular"))
    }

    @Test("Non-permanent milestone is NOT preserved through prestige")
    func transientMilestoneNotPreserved() {
        let theme = MockThemePackage.fixture(permanentMilestoneID: "milestone_regular")
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "colosseum")
        let kept = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        #expect(!kept.contains("colosseum"))
    }

    @Test("Only permanent milestones survive when multiple are completed")
    func onlyPermanentSurvives() {
        let theme = MockThemePackage.fixture(permanentMilestoneID: "milestone_regular")
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "milestone_regular")
            .completing(milestoneID: "colosseum")
        let kept = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        #expect(kept.contains("milestone_regular"))
        #expect(!kept.contains("colosseum"))
        #expect(kept.count == 1)
    }

    @Test("No permanent milestones in theme → nothing preserved")
    func noPermanentMilestonesInTheme() {
        // fixture() with no permanentMilestoneID → isPermanentBonus = false
        let theme = MockThemePackage.fixture()
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "milestone_regular")
        let kept = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        #expect(kept.isEmpty)
    }
}
