import Foundation
import Testing
@testable import IdleEngine

@Suite("OfflineCalculator")
struct OfflineCalculatorTests {

    // MARK: - Cap constant

    @Test("Offline cap is exactly 8 hours")
    func capIsEightHours() {
        #expect(OfflineCalculator.maxCapSeconds == 8 * 3_600)
        #expect(OfflineCalculator.maxCapSeconds == 28_800)
    }

    // MARK: - Zero production

    @Test("Offline result is zero when no units are owned")
    func offlineZeroWithNoUnits() {
        let state = GameState.initial(firstLevelID: "test")
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.campfire],
            awayDuration: 3_600
        )
        #expect(result.earnedResources == .zero)
        #expect(!result.wasCapped)
    }

    @Test("Offline result is zero when no units are defined")
    func offlineZeroWithNoUnitDefinitions() {
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 5, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [],    // No unit definitions → no production rate
            awayDuration: 3_600
        )
        #expect(result.earnedResources == .zero)
    }

    // MARK: - Correct calculation

    @Test("Offline income for 1 unit over 100 seconds = 100 gold")
    func offlineOneUnitHundredSeconds() {
        // simpleUnit: 1 g/s, 1 unit owned → 1 g/s × 100s = 100 gold
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "simple", quantity: 1, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.simpleUnit],
            awayDuration: 100
        )
        #expect(result.earnedResources["gold"] == 100)
        #expect(!result.wasCapped)
        #expect(result.effectiveDuration == 100)
    }

    @Test("Offline income for 5 units over 1 hour")
    func offlineFiveUnitsOneHour() {
        // simpleUnit: 1 g/s, 5 units → 5 g/s × 3600s = 18_000 gold
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "simple", quantity: 5, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.simpleUnit],
            awayDuration: 3_600
        )
        #expect(result.earnedResources["gold"] == 18_000)
        #expect(!result.wasCapped)
    }

    // MARK: - Cap behaviour

    @Test("Income is capped at exactly 8 hours of production")
    func offlineCapAt8Hours() {
        // simpleUnit: 1 g/s, 1 unit → max = 1 × 28800 = 28800 gold
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "simple", quantity: 1, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.simpleUnit],
            awayDuration: 10 * 3_600  // 10 hours away
        )
        #expect(result.wasCapped)
        #expect(result.effectiveDuration == OfflineCalculator.maxCapSeconds)
        #expect(result.earnedResources["gold"] == 28_800)
    }

    @Test("Income is NOT capped when away less than 8 hours")
    func offlineNotCappedUnder8Hours() {
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "simple", quantity: 1, cost: .zero)
        let awayTime: TimeInterval = 4 * 3_600 // 4 hours
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.simpleUnit],
            awayDuration: awayTime
        )
        #expect(!result.wasCapped)
        #expect(result.effectiveDuration == awayTime)
    }

    @Test("Income is NOT capped at exactly 8 hours away")
    func offlineNotCappedAtExactlyEightHours() {
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "simple", quantity: 1, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.simpleUnit],
            awayDuration: OfflineCalculator.maxCapSeconds
        )
        #expect(!result.wasCapped)
        #expect(result.effectiveDuration == OfflineCalculator.maxCapSeconds)
    }

    // MARK: - Upgrade tiers applied

    @Test("Offline income applies upgrade tier multipliers")
    func offlineAppliesUpgradeTiers() {
        // campfire: 10 units → tier-10 multiplier 1.5x → 10 × 0.1 × 1.5 = 1.5 g/s
        let state = GameState.initial(firstLevelID: "test")
            .purchasing(unitID: "campfire", quantity: 10, cost: .zero)
        let result = OfflineCalculator.calculate(
            state: state,
            units: [.campfire],
            awayDuration: 100
        )
        // 1.5 g/s × 100s = 150 gold
        #expect(result.earnedResources["gold"] == 150)
    }

    // MARK: - OfflineResult properties

    @Test("OfflineResult.effectiveDuration is min(awayDuration, cap)")
    func offlineEffectiveDurationIsBounded() {
        let state = GameState.initial(firstLevelID: "test")
        let shortTrip = OfflineCalculator.calculate(state: state, units: [.simpleUnit], awayDuration: 60)
        let longTrip = OfflineCalculator.calculate(state: state, units: [.simpleUnit], awayDuration: 100_000)
        #expect(shortTrip.effectiveDuration == 60)
        #expect(longTrip.effectiveDuration == OfflineCalculator.maxCapSeconds)
    }
}
