import Foundation
import Testing
@testable import IdleEngine

@Suite("EconomyCalculator")
struct EconomyCalculatorTests {

    // MARK: - Unit Cost

    @Test("Unit cost at count 0 equals base cost")
    func unitCostAtZeroEqualsBase() {
        let cost = EconomyCalculator.unitCost(unit: .campfire, currentCount: 0)
        #expect(cost["gold"] == 10)
    }

    @Test("Unit cost at count 1 equals baseCost × multiplier")
    func unitCostAtOneScalesCorrectly() {
        let cost = EconomyCalculator.unitCost(unit: .campfire, currentCount: 1)
        #expect(cost["gold"] == Decimal(string: "11.5")!)
    }

    @Test("Unit cost at count 2 equals baseCost × multiplier²")
    func unitCostAtTwoScalesCorrectly() {
        // 10 × 1.15² = 10 × 1.3225 = 13.225
        let cost = EconomyCalculator.unitCost(unit: .campfire, currentCount: 2)
        #expect(cost["gold"] == Decimal(string: "13.225")!)
    }

    @Test("Unit cost grows monotonically with count")
    func unitCostMonotonicallyIncreasing() {
        for i in 0..<20 {
            let c1 = EconomyCalculator.unitCost(unit: .campfire, currentCount: i)["gold"]
            let c2 = EconomyCalculator.unitCost(unit: .campfire, currentCount: i + 1)["gold"]
            #expect(c1 < c2, "Cost at \(i) should be less than cost at \(i + 1)")
        }
    }

    // MARK: - Bulk Buy Cost

    @Test("Bulk buy for quantity 0 returns zero cost")
    func bulkBuyZeroQuantityReturnsZero() {
        let cost = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 0, quantity: 0)
        #expect(cost == .zero)
    }

    @Test("Bulk buy for quantity 1 equals single unit cost")
    func bulkBuyOneEqualsSingleCost() {
        let single = EconomyCalculator.unitCost(unit: .campfire, currentCount: 0)
        let bulk = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 0, quantity: 1)
        #expect(single == bulk)
    }

    @Test("Bulk buy cost matches sum of individual costs")
    func bulkBuyMatchesSumOfIndividuals() {
        let quantity = 5
        let bulk = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 0, quantity: quantity)
        let summed = (0..<quantity).reduce(ResourceBundle.zero) { acc, i in
            acc + EconomyCalculator.unitCost(unit: .campfire, currentCount: i)
        }
        // Geometric series formula vs sum — allow tiny Decimal rounding delta
        let diff = abs(NSDecimalNumber(decimal: bulk["gold"] - summed["gold"]).doubleValue)
        #expect(diff < 0.0001, "Bulk cost \(bulk["gold"]) vs sum \(summed["gold"]) differ by \(diff)")
    }

    @Test("Bulk buy from non-zero starting count works correctly")
    func bulkBuyFromNonZeroStart() {
        // Buying 3 units starting from owning 5 should cost the same as
        // buying units 6, 7, 8 individually.
        let bulk = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 5, quantity: 3)
        let sum = (5..<8).reduce(ResourceBundle.zero) { acc, i in
            acc + EconomyCalculator.unitCost(unit: .campfire, currentCount: i)
        }
        let diff = abs(NSDecimalNumber(decimal: bulk["gold"] - sum["gold"]).doubleValue)
        #expect(diff < 0.0001)
    }

    @Test("Bulk buy with simple ×2 multiplier matches manual calculation")
    func bulkBuySimpleMultiplier() {
        // simpleUnit: baseCost=10, multiplier=2
        // Buying 3 from 0: 10 + 20 + 40 = 70
        let cost = EconomyCalculator.bulkBuyCost(unit: .simpleUnit, currentCount: 0, quantity: 3)
        #expect(cost["gold"] == 70)
    }

    // MARK: - Max Affordable

    @Test("Max affordable is 0 when cannot afford first unit")
    func maxAffordableZeroWhenBroke() {
        let resources = ResourceBundle(["gold": 5])
        let max = EconomyCalculator.maxAffordable(unit: .campfire, currentCount: 0, resources: resources)
        #expect(max == 0)
    }

    @Test("Max affordable returns at least 1 when exact change")
    func maxAffordableExactChange() {
        let resources = ResourceBundle(["gold": 10])
        let max = EconomyCalculator.maxAffordable(unit: .campfire, currentCount: 0, resources: resources)
        #expect(max == 1)
    }

    @Test("Buying maxAffordable units is affordable but maxAffordable+1 is not")
    func maxAffordableBoundary() {
        let resources = ResourceBundle(["gold": 100])
        let max = EconomyCalculator.maxAffordable(unit: .campfire, currentCount: 0, resources: resources)
        #expect(max > 0)

        let costMax = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 0, quantity: max)
        let costOver = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 0, quantity: max + 1)

        #expect(resources.canAfford(costMax))
        #expect(!resources.canAfford(costOver))
    }

    @Test("Max affordable from non-zero starting count respects current cost")
    func maxAffordableFromNonZeroStart() {
        // After owning 10, next unit costs ~10 × 1.15^10 ≈ 40.46
        let resources = ResourceBundle(["gold": 500])
        let max = EconomyCalculator.maxAffordable(unit: .campfire, currentCount: 10, resources: resources)
        let cost = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 10, quantity: max)
        #expect(resources.canAfford(cost))

        if max > 0 {
            let costOver = EconomyCalculator.bulkBuyCost(unit: .campfire, currentCount: 10, quantity: max + 1)
            #expect(!resources.canAfford(costOver))
        }
    }

    // MARK: - Production Rate

    @Test("Production rate is zero with no units owned")
    func productionRateZeroWithNoUnits() {
        let state = GameState.initial(firstLevelID: "test")
        let rate = EconomyCalculator.productionRate(state: state, units: [.campfire])
        #expect(rate == .zero)
    }

    @Test("Production rate scales linearly with unit count (no upgrades, no prestige)")
    func productionRateLinearScale() {
        // 5 campfires × 0.1 g/s = 0.5 g/s (below tier 10, prestige tokens = 0)
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 5, cost: .zero)
        let rate = EconomyCalculator.productionRate(state: state, units: [.campfire])
        #expect(rate["gold"] == Decimal(string: "0.5")!)
    }

    @Test("Production rate applies tier-10 upgrade multiplier at exactly 10 units")
    func productionRateTierTenApplies() {
        // 10 × 0.1 × 1.5 (tier 10) = 1.5
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 10, cost: .zero)
        let rate = EconomyCalculator.productionRate(state: state, units: [.campfire])
        #expect(rate["gold"] == Decimal(string: "1.5")!)
    }

    @Test("Upgrade tiers are not applied below threshold")
    func productionRateTierNotAppliedBeforeThreshold() {
        // 9 units — tier 10 should NOT be active
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 9, cost: .zero)
        let rate = EconomyCalculator.productionRate(state: state, units: [.campfire])
        #expect(rate["gold"] == Decimal(string: "0.9")!)
    }

    @Test("Multiple upgrade tiers stack cumulatively")
    func productionRateTiersStack() {
        // 25 units × 0.1 × 1.5 (tier10) × 2.0 (tier25) = 7.5
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 25, cost: .zero)
        let rate = EconomyCalculator.productionRate(state: state, units: [.campfire])
        #expect(rate["gold"] == Decimal(string: "7.5")!)
    }

    @Test("Production rate applies prestige multiplier")
    func productionRateAppliesPrestigeMultiplier() {
        // State with 10 prestige tokens: multiplier = 1 + 10×0.02 = 1.2
        // 5 campfires × 0.1 × 1.2 = 0.6
        let baseState = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 5, cost: .zero)
        let stateWithPrestige = GameState(
            currentLevelID: baseState.currentLevelID,
            resources: baseState.resources,
            unitCounts: baseState.unitCounts,
            completedMilestoneIDs: baseState.completedMilestoneIDs,
            prestigeTokens: 10,
            totalPrestigeCount: 1,
            totalLifetimeGold: baseState.totalLifetimeGold,
            sessionStartDate: baseState.sessionStartDate,
            lastSaveDate: baseState.lastSaveDate,
            studioPoints: baseState.studioPoints
        )
        let rate = EconomyCalculator.productionRate(state: stateWithPrestige, units: [.campfire])
        #expect(rate["gold"] == Decimal(string: "0.6")!)
    }

    // MARK: - Legacy Tokens

    @Test("Legacy tokens return 0 below threshold")
    func legacyTokensBelowThreshold() {
        let tokens = EconomyCalculator.legacyTokens(totalGold: 999_999_999_999)
        #expect(tokens == 0)
    }

    @Test("Legacy tokens return 0 for zero gold")
    func legacyTokensZeroGold() {
        let tokens = EconomyCalculator.legacyTokens(totalGold: 0)
        #expect(tokens == 0)
    }

    @Test("Legacy tokens return 1 at exactly 1 trillion gold")
    func legacyTokensAtThreshold() {
        let tokens = EconomyCalculator.legacyTokens(totalGold: 1_000_000_000_000)
        #expect(tokens == 1)
    }

    @Test("Legacy tokens return 2 at 4 trillion gold (sqrt(4) = 2)")
    func legacyTokensFourTrillion() {
        let tokens = EconomyCalculator.legacyTokens(totalGold: 4_000_000_000_000)
        #expect(tokens == 2)
    }

    @Test("Legacy tokens return 3 at 9 trillion gold (sqrt(9) = 3)")
    func legacyTokensNineTrillion() {
        let tokens = EconomyCalculator.legacyTokens(totalGold: 9_000_000_000_000)
        #expect(tokens == 3)
    }

    @Test("Legacy tokens are always whole numbers (floor applied)")
    func legacyTokensAreWholeNumbers() {
        // 2 trillion → sqrt(2) ≈ 1.41 → floor = 1
        let tokens = EconomyCalculator.legacyTokens(totalGold: 2_000_000_000_000)
        #expect(tokens == 1)
    }

    // MARK: - Prestige Multiplier

    @Test("Prestige multiplier is exactly 1 with no tokens")
    func prestigeMultiplierNoTokens() {
        #expect(EconomyCalculator.prestigeMultiplier(tokens: 0) == 1)
    }

    @Test("Prestige multiplier is 1.02 with 1 token")
    func prestigeMultiplierOneToken() {
        #expect(EconomyCalculator.prestigeMultiplier(tokens: 1) == Decimal(string: "1.02")!)
    }

    @Test("Prestige multiplier is 3.0 with 100 tokens")
    func prestigeMultiplierHundredTokens() {
        // 1 + 100 × 0.02 = 3.0
        #expect(EconomyCalculator.prestigeMultiplier(tokens: 100) == 3)
    }

    @Test("Prestige multiplier grows linearly with token count")
    func prestigeMultiplierLinear() {
        let m50 = EconomyCalculator.prestigeMultiplier(tokens: 50)
        let m100 = EconomyCalculator.prestigeMultiplier(tokens: 100)
        // m100 - m50 should equal m50 - m0
        let m0 = EconomyCalculator.prestigeMultiplier(tokens: 0)
        #expect(m100 - m50 == m50 - m0)
    }

    // MARK: - DecimalPow

    @Test("decimalPow: base^0 == 1")
    func decimalPowZero() {
        #expect(EconomyCalculator.decimalPow(Decimal(5), 0) == 1)
        #expect(EconomyCalculator.decimalPow(Decimal(string: "1.15")!, 0) == 1)
    }

    @Test("decimalPow: base^1 == base")
    func decimalPowOne() {
        #expect(EconomyCalculator.decimalPow(Decimal(7), 1) == 7)
        #expect(EconomyCalculator.decimalPow(Decimal(string: "1.15")!, 1) == Decimal(string: "1.15")!)
    }

    @Test("decimalPow: 2^8 == 256")
    func decimalPowTwoToEight() {
        #expect(EconomyCalculator.decimalPow(2, 8) == 256)
    }

    @Test("decimalPow: 2^10 == 1024")
    func decimalPowTwoToTen() {
        #expect(EconomyCalculator.decimalPow(2, 10) == 1024)
    }

    @Test("decimalPow: 3^3 == 27")
    func decimalPowCube() {
        #expect(EconomyCalculator.decimalPow(3, 3) == 27)
    }
}
