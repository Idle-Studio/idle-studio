import Foundation
import Testing
@testable import IdleEngine

@Suite("PrestigeSystem")
struct PrestigeSystemTests {

    // MARK: - canPrestige

    /// A theme with no gate milestone, so these tests exercise the token threshold alone.
    private var ungatedTheme: MockThemePackage { MockThemePackage.fixture() }

    /// Assertions are expressed against `legacyTokenThreshold` rather than a literal.
    /// A rebalance previously moved it from 1e12 to 3e12 and every hardcoded expectation
    /// here silently became wrong.
    private var threshold: Decimal { EconomyCalculator.legacyTokenThreshold }

    @Test("Cannot prestige with zero lifetime gold")
    func cannotPrestigeWithNoGold() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(!PrestigeSystem.canPrestige(state: state, theme: ungatedTheme))
    }

    @Test("Cannot prestige just below the token threshold")
    func cannotPrestigeJustBelowThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(threshold - 1)
        #expect(!PrestigeSystem.canPrestige(state: state, theme: ungatedTheme))
    }

    @Test("Can prestige at exactly the threshold (1 token earned)")
    func canPrestigeAtThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(threshold)
        #expect(PrestigeSystem.canPrestige(state: state, theme: ungatedTheme))
        #expect(PrestigeSystem.tokensEarned(from: state) == 1)
    }

    @Test("Can prestige well above threshold")
    func canPrestigeWellAboveThreshold() {
        let state = GameState.initial(firstLevelID: "level_1").withGold(threshold * 100)
        #expect(PrestigeSystem.canPrestige(state: state, theme: ungatedTheme))
    }

    @Test("Gate milestone blocks prestige until completed")
    func gateMilestoneBlocksPrestige() {
        let theme = MockThemePackage.fixture(permanentMilestoneID: "milestone_regular")
        let rich = GameState.initial(firstLevelID: "level_1").withGold(threshold * 100)
        // The mock's gate is only enforced when the theme declares one.
        if theme.prestigeRequirementMilestoneID != nil {
            #expect(!PrestigeSystem.canPrestige(state: rich, theme: theme))
            let gated = rich.completing(milestoneID: theme.prestigeRequirementMilestoneID!)
            #expect(PrestigeSystem.canPrestige(state: gated, theme: theme))
        }
    }

    // MARK: - tokensEarned

    @Test("Tokens earned are 0 below threshold")
    func tokensEarnedBelowThreshold() {
        let state = GameState.initial(firstLevelID: "test").withGold(threshold / 2)
        #expect(PrestigeSystem.tokensEarned(from: state) == 0)
    }

    @Test("Tokens earned scale with the square root of lifetime earnings")
    func tokensEarnedScaling() {
        let state4x = GameState.initial(firstLevelID: "test").withGold(threshold * 4)
        let state9x = GameState.initial(firstLevelID: "test").withGold(threshold * 9)
        #expect(PrestigeSystem.tokensEarned(from: state4x) == 2)
        #expect(PrestigeSystem.tokensEarned(from: state9x) == 3)
    }

    // MARK: - Regression: the unbounded prestige farm

    /// `tokensEarned` is a delta against tokens already granted, not the raw lifetime total.
    ///
    /// `totalLifetimeGold` never resets and the gate milestone is flagged permanent, so the
    /// raw-total version left `canPrestige` true forever after the first reset and every
    /// additional tap re-awarded the full amount — 1,000 taps compounded to roughly 5,881×
    /// production and maxed every leaderboard.
    @Test("A second prestige with no intervening earnings awards zero tokens")
    func prestigeIsNotFarmable() {
        let theme = ungatedTheme
        let first = GameState.initial(firstLevelID: "level_1").withGold(threshold * 9)
        #expect(PrestigeSystem.tokensEarned(from: first) == 3)

        let afterFirst = first.applying(
            prestige: PrestigeSystem.tokensEarned(from: first),
            firstLevelID: "level_1",
            keepingMilestoneIDs: []
        )
        #expect(afterFirst.prestigeTokens == 3)
        #expect(PrestigeSystem.tokensEarned(from: afterFirst) == 0)
        #expect(!PrestigeSystem.canPrestige(state: afterFirst, theme: theme))

        // Repeated attempts must stay at zero.
        var state = afterFirst
        for _ in 0..<10 {
            let earned = PrestigeSystem.tokensEarned(from: state)
            #expect(earned == 0)
            state = state.applying(
                prestige: earned, firstLevelID: "level_1", keepingMilestoneIDs: []
            )
        }
        #expect(state.prestigeTokens == 3)
    }

    @Test("Earning past the next threshold re-enables prestige for the delta only")
    func prestigeResumesAfterMoreEarnings() {
        let afterFirst = GameState.initial(firstLevelID: "level_1")
            .withGold(threshold * 9)
            .applying(prestige: 3, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(PrestigeSystem.tokensEarned(from: afterFirst) == 0)

        // Lifetime earnings now entitle the player to 5 tokens total; 3 are already held.
        let grown = afterFirst.withGold(threshold * 25 - threshold * 9)
        #expect(EconomyCalculator.legacyTokens(totalGold: grown.totalLifetimeGold) == 5)
        #expect(PrestigeSystem.tokensEarned(from: grown) == 2)
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
