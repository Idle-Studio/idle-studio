import Foundation
import Testing
@testable import IdleEngine

@Suite("GameState Mutations")
struct GameStateMutationTests {

    // MARK: - Initial state

    @Test("Initial state has zero resources")
    func initialStateHasZeroResources() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(state.resources == .zero)
    }

    @Test("Initial state has empty unit counts")
    func initialStateHasEmptyUnits() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(state.unitCounts.isEmpty)
    }

    @Test("Initial state has empty milestone set")
    func initialStateHasEmptyMilestones() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(state.completedMilestoneIDs.isEmpty)
    }

    @Test("Initial state has zero prestige tokens")
    func initialStateHasZeroTokens() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(state.prestigeTokens == 0)
        #expect(state.totalPrestigeCount == 0)
    }

    @Test("Initial state sets the correct first level ID")
    func initialStateCorrectLevelID() {
        let state = GameState.initial(firstLevelID: "stone_age")
        #expect(state.currentLevelID == "stone_age")
    }

    @Test("Initial state has zero studio points")
    func initialStateHasZeroPoints() {
        let state = GameState.initial(firstLevelID: "level_1")
        #expect(state.studioPoints == 0)
    }

    // MARK: - applying(production:)

    @Test("Applying production adds gold to resources")
    func applyingProductionAddsGold() {
        let state = GameState.initial(firstLevelID: "test")
        let newState = state.applying(production: ResourceBundle(["gold": 500]), primaryCurrency: "gold")
        #expect(newState.resources["gold"] == 500)
    }

    @Test("Applying production increments totalLifetimeGold")
    func applyingProductionIncrementsLifetimeGold() {
        let state = GameState.initial(firstLevelID: "test")
        let newState = state.applying(production: ResourceBundle(["gold": 100]), primaryCurrency: "gold")
        #expect(newState.totalLifetimeGold == 100)
    }

    @Test("Lifetime gold accumulates across multiple production ticks")
    func lifetimeGoldAccumulates() {
        let state = GameState.initial(firstLevelID: "test")
            .applying(production: ResourceBundle(["gold": 100]), primaryCurrency: "gold")
            .applying(production: ResourceBundle(["gold": 200]), primaryCurrency: "gold")
        #expect(state.totalLifetimeGold == 300)
    }

    @Test("Non-gold resources do not affect totalLifetimeGold")
    func nonGoldDoesNotAffectLifetimeGold() {
        let state = GameState.initial(firstLevelID: "test")
            .applying(production: ResourceBundle(["population": 50]), primaryCurrency: "gold")
        #expect(state.totalLifetimeGold == 0)
        #expect(state.resources["population"] == 50)
    }

    @Test("Applying production is immutable — original state unchanged")
    func applyingProductionIsImmutable() {
        let original = GameState.initial(firstLevelID: "test")
        _ = original.applying(production: ResourceBundle(["gold": 999]), primaryCurrency: "gold")
        #expect(original.resources == .zero)
        #expect(original.totalLifetimeGold == 0)
    }

    // MARK: - purchasing(unitID:quantity:cost:)

    @Test("Purchasing increments unit count")
    func purchasingIncrementsCount() {
        let state = GameState.initial(firstLevelID: "test")
            .withGold(100)
            .purchasing(unitID: "campfire", quantity: 3, cost: ResourceBundle(["gold": 30]))
        #expect(state.unitCount(id: "campfire") == 3)
    }

    @Test("Purchasing deducts cost from resources")
    func purchasingDeductsCost() {
        let state = GameState.initial(firstLevelID: "test")
            .withGold(100)
            .purchasing(unitID: "campfire", quantity: 1, cost: ResourceBundle(["gold": 10]))
        #expect(state.resources["gold"] == 90)
    }

    @Test("Purchasing stacks with existing count")
    func purchasingStacksCount() {
        let state = GameState.initial(firstLevelID: "test")
            .withGold(500)
            .purchasing(unitID: "campfire", quantity: 5, cost: ResourceBundle(["gold": 50]))
            .purchasing(unitID: "campfire", quantity: 3, cost: ResourceBundle(["gold": 30]))
        #expect(state.unitCount(id: "campfire") == 8)
    }

    @Test("unitCount returns 0 for unknown unit ID")
    func unitCountUnknownIDReturnsZero() {
        let state = GameState.initial(firstLevelID: "test")
        #expect(state.unitCount(id: "nonexistent") == 0)
    }

    @Test("Purchasing is immutable — original state unchanged")
    func purchasingIsImmutable() {
        let original = GameState.initial(firstLevelID: "test").withGold(100)
        _ = original.purchasing(unitID: "campfire", quantity: 1, cost: ResourceBundle(["gold": 10]))
        #expect(original.unitCount(id: "campfire") == 0)
        #expect(original.resources["gold"] == 100)
    }

    // MARK: - completing(milestoneID:)

    @Test("Completing a milestone adds it to the completed set")
    func completingMilestoneAddsToSet() {
        let state = GameState.initial(firstLevelID: "test")
            .completing(milestoneID: "great_wall")
        #expect(state.completedMilestoneIDs.contains("great_wall"))
    }

    @Test("Completing a milestone awards 25 Studio Points")
    func completingMilestoneAwardsPoints() {
        let state = GameState.initial(firstLevelID: "test")
            .completing(milestoneID: "great_wall")
        #expect(state.studioPoints == 25)
    }

    @Test("Completing multiple milestones adds each to the set")
    func completingMultipleMilestones() {
        let state = GameState.initial(firstLevelID: "test")
            .completing(milestoneID: "ms_1")
            .completing(milestoneID: "ms_2")
            .completing(milestoneID: "ms_3")
        #expect(state.completedMilestoneIDs.count == 3)
        #expect(state.studioPoints == 75)
    }

    @Test("Completing milestone is immutable — original state unchanged")
    func completingMilestoneIsImmutable() {
        let original = GameState.initial(firstLevelID: "test")
        _ = original.completing(milestoneID: "great_wall")
        #expect(original.completedMilestoneIDs.isEmpty)
    }

    // MARK: - advancingLevel(to:)

    @Test("Advancing level changes currentLevelID")
    func advancingLevelChangesID() {
        let state = GameState.initial(firstLevelID: "level_1")
            .advancingLevel(to: "level_2")
        #expect(state.currentLevelID == "level_2")
    }

    @Test("Advancing level awards 50 Studio Points")
    func advancingLevelAwardsPoints() {
        let state = GameState.initial(firstLevelID: "level_1")
            .advancingLevel(to: "level_2")
        #expect(state.studioPoints == 50)
    }

    @Test("Advancing level preserves resources and unit counts")
    func advancingLevelPreservesProgress() {
        let state = GameState.initial(firstLevelID: "level_1")
            .withGold(500)
            .purchasing(unitID: "campfire", quantity: 5, cost: ResourceBundle(["gold": 50]))
            .advancingLevel(to: "level_2")
        #expect(state.resources["gold"] == 450)
        #expect(state.unitCount(id: "campfire") == 5)
    }

    // MARK: - applying(prestige:firstLevelID:keepingMilestoneIDs:)

    @Test("Prestige resets resources to zero")
    func prestigeResetsResources() {
        let state = GameState.initial(firstLevelID: "level_1")
            .withGold(10_000)
            .applying(prestige: 3, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.resources == .zero)
    }

    @Test("Prestige resets unit counts to empty")
    func prestigeResetsUnits() {
        let state = GameState.initial(firstLevelID: "level_1")
            .withGold(500)
            .purchasing(unitID: "campfire", quantity: 5, cost: ResourceBundle(["gold": 50]))
            .applying(prestige: 1, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.unitCounts.isEmpty)
    }

    @Test("Prestige returns to first level")
    func prestigeReturnsToFirstLevel() {
        let state = GameState.initial(firstLevelID: "level_1")
            .advancingLevel(to: "level_3")
            .applying(prestige: 2, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.currentLevelID == "level_1")
    }

    @Test("Prestige accumulates tokens on top of existing tokens")
    func prestigeAccumulatesTokens() {
        let base = GameState(
            currentLevelID: "level_1", resources: .zero, unitCounts: [:],
            completedMilestoneIDs: [], prestigeTokens: 5, totalPrestigeCount: 1,
            totalLifetimeGold: 0, sessionStartDate: .now, lastSaveDate: .now, studioPoints: 0
        )
        let newState = base.applying(prestige: 3, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(newState.prestigeTokens == 8)
    }

    @Test("Prestige increments totalPrestigeCount")
    func prestigeIncrementsCount() {
        let state = GameState.initial(firstLevelID: "level_1")
            .applying(prestige: 1, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.totalPrestigeCount == 1)
    }

    @Test("Prestige preserves totalLifetimeGold")
    func prestigePreservesLifetimeGold() {
        let state = GameState.initial(firstLevelID: "level_1")
            .withGold(5_000_000_000_000)
            .applying(prestige: 2, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.totalLifetimeGold == 5_000_000_000_000)
    }

    @Test("Prestige keeps only the specified milestone IDs")
    func prestigeKeepsSpecifiedMilestones() {
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "permanent_ms")
            .completing(milestoneID: "transient_ms")
            .applying(prestige: 1, firstLevelID: "level_1", keepingMilestoneIDs: ["permanent_ms"])
        #expect(state.completedMilestoneIDs.contains("permanent_ms"))
        #expect(!state.completedMilestoneIDs.contains("transient_ms"))
    }

    @Test("Prestige with no kept milestones clears completed set")
    func prestigeClearsMilestonesWhenNoneKept() {
        let state = GameState.initial(firstLevelID: "level_1")
            .completing(milestoneID: "ms_1")
            .completing(milestoneID: "ms_2")
            .applying(prestige: 1, firstLevelID: "level_1", keepingMilestoneIDs: [])
        #expect(state.completedMilestoneIDs.isEmpty)
    }
}
