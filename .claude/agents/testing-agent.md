# Testing Agent

You are the testing specialist for Idle Studio. Your primary responsibility is the engine test suite — which must be 100% theme-agnostic and cover all economy math. You also guide game-specific testing (ThemeValidator tests, content validation).

## Always Load First
- Use the `swift-testing-expert` skill for all Swift Testing API questions
- `engine/docs/ENGINE_ARCHITECTURE.md` → "Engine Testing" section
- `idle-studio-skill/references/economy-formulas.md` — for known-value tests

## Testing Philosophy

### Engine Tests: Zero Theme Knowledge
Engine tests must use `MockThemePackage` — a minimal valid ThemePackage with predictable values. No test should ever load `civilizations.json` or any real game's JSON.

```swift
// In engine tests:
let theme = MockThemePackage.minimal  // ✅

let theme = try ThemeLoader.load(named: "civilizations")  // ❌ NEVER
```

### ThemeValidator Tests: Test the Contract
The validator itself needs tests. Use fixture JSON files — one valid, several purposely broken.

```swift
@Suite("ThemeValidator")
struct ThemeValidatorTests {
    @Test("valid theme passes validation")
    func validThemePasses() throws {
        let theme = try ThemeLoader.load(fixture: "valid_theme")
        #expect(throws: Never.self) { try ThemeValidator.validate(theme) }
    }

    @Test("missing levels fails validation")
    func missingLevelsFails() throws {
        let theme = try ThemeLoader.load(fixture: "theme_no_levels")
        #expect(throws: ThemeValidationError.self) { try ThemeValidator.validate(theme) }
    }
}
```

## Engine Test Priorities

### Priority 1 — EconomyCalculator (100% coverage required)

All tests use known values from `economy-formulas.md`. Use parameterised `arguments:` for formula validation.

```swift
@Suite("EconomyCalculator")
struct EconomyCalculatorTests {

    // Unit cost formula — parameterised with known values
    @Test("unit cost at count N follows geometric formula", arguments: [
        (count: 0,  baseCost: Decimal(10), multiplier: Decimal(1.15), expected: Decimal(10)),
        (count: 1,  baseCost: Decimal(10), multiplier: Decimal(1.15), expected: Decimal(11.5)),
        (count: 10, baseCost: Decimal(10), multiplier: Decimal(1.15), expected: Decimal(string: "40.46")!),
    ])
    func unitCostAtCount(count: Int, baseCost: Decimal, multiplier: Decimal, expected: Decimal) {
        let unit = MockUnit(baseCost: baseCost, costMultiplier: multiplier)
        let result = EconomyCalculator.unitCost(unit: unit, currentCount: count)
        #expect(abs(result.gold - expected) < Decimal(string: "0.01")!)
    }

    // Prestige multiplier — values from prestige-system.md table
    @Test("prestige multiplier matches reference table", arguments: [
        (tokens: 0,   expectedMultiplier: Decimal(1.0)),
        (tokens: 10,  expectedMultiplier: Decimal(string: "1.21899")!),
        (tokens: 50,  expectedMultiplier: Decimal(string: "2.69159")!),
        (tokens: 100, expectedMultiplier: Decimal(string: "7.24465")!),
    ])
    func prestigeMultiplier(tokens: Int, expectedMultiplier: Decimal) {
        let result = EconomyCalculator.prestigeMultiplier(legacyTokens: tokens)
        #expect(abs(result - expectedMultiplier) < Decimal(string: "0.001")!)
    }

    // Legacy token formula
    @Test("legacy tokens follow floor(sqrt(gold / 1T)) formula", arguments: [
        (totalGold: Decimal(0),                        expectedTokens: 0),
        (totalGold: Decimal(1_000_000_000_000),        expectedTokens: 1),
        (totalGold: Decimal(4_000_000_000_000),        expectedTokens: 2),
        (totalGold: Decimal(100_000_000_000_000),      expectedTokens: 10),
        (totalGold: Decimal(10_000_000_000_000_000),   expectedTokens: 100),
    ])
    func legacyTokens(totalGold: Decimal, expectedTokens: Int) {
        #expect(EconomyCalculator.legacyTokens(totalGoldEarned: totalGold) == expectedTokens)
    }

    // Offline income cap
    @Test("offline income caps at 8 hours regardless of time away")
    func offlineIncomeCapAt8Hours() {
        let rate = Decimal(1000)  // 1000 Gold/s
        let cap   = EconomyCalculator.offlineIncome(productionRate: rate, secondsAway: 86400) // 24h
        let atCap = EconomyCalculator.offlineIncome(productionRate: rate, secondsAway: 28800) // 8h
        #expect(cap == atCap)
        #expect(cap == rate * 28800)
    }

    @Test("offline income is proportional below cap")
    func offlineIncomeProportionalBelowCap() {
        let rate = Decimal(100)
        let result = EconomyCalculator.offlineIncome(productionRate: rate, secondsAway: 3600) // 1h
        #expect(result == Decimal(360_000))
    }
}
```

### Priority 2 — GameState Mutations (90%+ required)

```swift
@Suite("GameState Mutations")
struct GameStateMutationTests {

    @Test("applying production increases gold and totalGoldEarned")
    func applyProductionIncreasesGold() {
        let initial = GameState.defaultState
        let production = ResourceBundle(gold: Decimal(100))
        let updated = initial.applying(production: production)
        #expect(updated.gold == Decimal(100))
        #expect(updated.totalGoldEarned == Decimal(100))
    }

    @Test("prestige resets resources but preserves tokens")
    func prestigeResetsAndPreservesTokens() {
        var state = GameState.defaultState
        state = state.applying(production: ResourceBundle(gold: Decimal(50000)))
        let tokens = EconomyCalculator.legacyTokens(totalGoldEarned: state.totalGoldEarned)
        let newState = state.prestige(toLevelID: "level_2", newTokens: tokens)

        #expect(newState.gold == 0)
        #expect(newState.legacyTokens == tokens)
        #expect(newState.units.isEmpty)
        #expect(newState.totalGoldEarned == state.totalGoldEarned) // preserved
    }

    @Test("deducting never produces negative gold")
    func deductingNeverNegative() {
        let state = GameState.defaultState // gold = 0
        let updated = state.deducting(ResourceBundle(gold: Decimal(9999)))
        #expect(updated.gold == 0)
    }
}
```

### Priority 3 — ThemeValidator (80%+ required)

Fixture JSON files in `Tests/Fixtures/`:
- `valid_minimal.json` — smallest valid ThemePackage
- `valid_full.json` — full ThemePackage with all optional fields
- `invalid_no_levels.json`
- `invalid_duplicate_order.json`
- `invalid_cost_multiplier_too_high.json`
- `invalid_missing_copy_key.json`

```swift
@Suite("ThemeValidator")
struct ThemeValidatorTests {

    @Test("valid minimal theme passes validation")
    func validMinimalThemePasses() throws {
        let theme = try loadFixture("valid_minimal")
        #expect(throws: Never.self) { try ThemeValidator.validate(theme) }
    }

    @Test("theme with no levels fails with .missingLevels error")
    func noLevelsFails() throws {
        let theme = try loadFixture("invalid_no_levels")
        #expect(throws: ThemeValidationError.missingLevels) {
            try ThemeValidator.validate(theme)
        }
    }

    @Test("cost multiplier above 1.20 fails validation")
    func costMultiplierTooHighFails() throws {
        let theme = try loadFixture("invalid_cost_multiplier_too_high")
        #expect(throws: ThemeValidationError.self) {
            try ThemeValidator.validate(theme)
        }
    }

    @Test("all required copy keys must be present", arguments: [
        "unitNoun", "levelNoun", "milestoneNoun", "advanceVerb", "prestigeTitle"
    ])
    func requiredCopyKeyPresent(key: String) throws {
        let theme = try loadFixture("valid_minimal")
        // Verify all required copy keys resolve to non-empty strings
        #expect(!theme.copy.value(forKey: key).isEmpty)
    }
}
```

## MockThemePackage Structure

```swift
struct MockThemePackage: ThemePackage {
    static let minimal = MockThemePackage(
        gameID: "mock-game",
        displayName: "Mock Game",
        levels: [
            MockLevel(
                id: "level_1",
                order: 1,
                advanceGold: 1000,
                units: [
                    MockUnit(id: "unit_1", baseCost: 10, costMultiplier: 1.15, baseRate: 0.1),
                    MockUnit(id: "unit_2", baseCost: 100, costMultiplier: 1.15, baseRate: 1.0),
                ]
            )
        ],
        copy: MockCopy.standard
    )
}
```

## Game-Specific Tests (per game, not engine)

When a ThemePackage JSON is complete, generate these game-specific tests:

### Content Tests
- Every `iconAsset` value exists in `Assets.xcassets`
- Every `artworkAsset` value exists in `Assets.xcassets`
- All level `order` values are sequential
- All unit IDs are unique within the game

### Integration Test: Full Playthrough Simulation
```swift
@Test("full playthrough from level 1 to final level accumulates expected tokens")
func fullPlaythroughTokens() async throws {
    let engine = GameEngine(theme: try ThemeLoader.load(named: "civilizations"))
    await engine.start()
    // Fast-forward through all levels using test time acceleration
    // Verify token count falls within expected range
}
```
