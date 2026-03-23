# Testing Strategy

## Philosophy

Tests are how we ship confidently. The economy engine is pure math — it must be 100% covered by unit tests because a wrong formula silently destroys the player experience. UI tests cover critical revenue paths because a broken purchase flow means lost revenue.

---

## Test Pyramid

```
         /\
        /  \
       / UI \        ← XCUITest — critical paths only (slow, brittle)
      /──────\
     / Integ  \      ← Integration — engine + persistence + services
    /──────────\
   / Unit Tests \    ← Swift Testing — economy, models, content (fast, comprehensive)
  /______________\
```

---

## Unit Tests (Swift Testing)

**Framework:** Swift Testing exclusively (`@Test`, `#expect`, `#require`)  
**Target coverage:** 100% of Core/Economy, 90%+ of Core/Engine and Data/Models  
**Speed target:** Full unit test suite runs in < 10 seconds

### Priority 1: EconomyCalculator (must be 100%)

Every formula in `idle-civilizations-skill/references/economy-formulas.md` has parameterised tests with known values from the balance tables.

Tests needed:
```
EconomyCalculatorTests/
├── buildingCostAtZero                 — cost(n=0) = baseCost
├── buildingCostWithOwned              — cost(n=10) follows formula
├── bulkBuyCostEqualsLoopSum           — geometric series formula matches loop
├── maxAffordableWithNoGold            — returns 0
├── maxAffordableWithExactCost         — returns exactly 1
├── productionRateWithNoBuildings      — returns zero bundle
├── productionRateWithManagerRequired  — non-managed buildings contribute 0
├── productionRateUpgradeTiers         — each tier compounds correctly
├── prestigeMultiplierAt0Tokens        — 1.0×
├── prestigeMultiplierAt10Tokens       — ~1.219×
├── prestigeMultiplierAt100Tokens      — ~7.245×
├── legacyTokensAt0Gold                — 0 tokens
├── legacyTokensAt1TGold               — 1 token
├── legacyTokensAt100TGold             — 10 tokens
├── offlineIncomeAtCap                 — caps at 8h
├── offlineIncomeAboveCap              — same as at cap (no overflow)
└── offlineIncomeBelowCap              — proportional to time
```

### Priority 2: GameState Mutations (90%+)

```
GameStateMutationTests/
├── applyingProductionIncreasesGold
├── applyingProductionAccumulatesTotalEarned
├── deductingCostReducesGold
├── deductingNeverGoesNegative
├── incrementingBuildingIncreasesCount
├── incrementingNewBuildingCreatesEntry
├── prestigeResetsResourcesAndBuildings
├── prestigePreservesLegacyTokens
├── prestigePreservesCompletedWonders
├── settingOfflineIncomePopulatesFields
├── clearingOfflineIncomeClearsFields
```

### Priority 3: ContentRegistry (80%+)

```
ContentRegistryTests/
├── loadsValidJSONSuccessfully
├── failsGracefullyOnMalformedJSON
├── returnsNilForUnknownEraID
├── returnsNilForUnknownBuildingID
├── allBuildingIDsAreUnique             — parameterised across all eras
├── eraOrderHasNoGaps                   — sequential 1, 2, 3...
├── allWonderIDsAreUnique
├── remoteVersionOverridesBundledWhenNewer
├── bundledVersionUsedWhenRemoteFails
```

---

## Integration Tests

**Framework:** Swift Testing with real dependencies (not mocks)  
**Focus:** Engine + SwiftData persistence, engine lifecycle

```
GameEngineIntegrationTests/
├── engineStartsAndProducesResourcesAfter3Ticks
├── backgroundAndForegroundCalculatesOfflineIncome
├── buildingPurchaseUpdatesStateAndPersists
├── prestigeResetsStateProperly
├── saveAndLoadPreservesExactState           — floating point edge cases
└── concurrentTicksDoNotCauseDataRace        — @MainActor isolation verified
```

---

## Service Tests (via mocks + StoreKit Testing)

### StoreKit Testing
Use `.storekit` configuration file in Xcode for StoreKit unit tests:

```
StoreKitServiceTests/
├── purchaseConsumableGrantsCoins
├── purchaseNonConsumableGrantsEntitlement
├── subscriptionActiveReturnsTrue
├── expiredSubscriptionReturnsFalse
├── removeAdsEntitlementPersistsAcrossLaunches
└── restorePurchasesRestoresEntitlements
```

### Analytics Mock Tests
```
AnalyticsTests/
├── eraAdvanceTracksCorrectEraAndTokens
├── buildingPurchaseTracksCorrectID
├── offlineCollectTracksDoubledFlag
└── allEventsHaveRequiredProperties
```

---

## UI Tests (XCUITest — critical paths only)

**Framework:** XCUITest  
**Environment:** StoreKit Sandbox, AdMob test mode  
**Speed target:** Full UI test suite < 5 minutes  
**Run on:** Simulator (CI) + real device (pre-release)

### Critical Path 1: Onboarding
```
test_onboarding_completes_and_reaches_gameplay
  1. Fresh install
  2. Verify campfire tutorial appears
  3. Tap campfire area → verify Gold appears
  4. Buy campfire via tutorial prompt
  5. Verify main gameplay screen visible
  6. Verify resource bar shows Gold
```

### Critical Path 2: First Purchase
```
test_first_iap_purchase_completes
  1. Reach an offer moment (era advance)
  2. Offer sheet appears
  3. Tap "Buy" → StoreKit sandbox payment UI appears
  4. Confirm payment in sandbox
  5. Verify entitlement granted (coins added / skin applied)
  6. Verify thank-you state
```

### Critical Path 3: Era Advance
```
test_era_advance_prestige_flow
  1. Set game state to have enough gold (via launch argument)
  2. Verify "Advance Era" button visible and pulsing
  3. Tap → prestige preview screen appears
  4. Verify token count shown
  5. Verify "resets" and "persists" lists visible
  6. Tap "Advance Era!" → transition animation plays
  7. Verify new era name visible
  8. Verify buildings list is empty
  9. Verify legacy token count increased
```

### Critical Path 4: Offline Income
```
test_offline_income_sheet_appears_on_return
  1. Launch app, start game
  2. Background app (simulate)
  3. Wait 5 seconds
  4. Foreground app
  5. Verify offline income sheet appears
  6. Verify Gold amount displayed
  7. Tap "Collect" → sheet dismisses
  8. Verify Gold added to balance
```

---

## Test Naming Convention

```swift
@Test("[what it tests] — [scenario or condition]")
func buildingCostAtZero_equalsBaseCost() { ... }

@Test("prestige multiplier produces correct results", arguments: [
    (0,   Decimal(1.0)),
    (10,  Decimal(string: "1.21899")!),
    (100, Decimal(string: "7.24465")!),
])
func prestigeMultiplier_correctForKnownTokenCounts(tokens: Int, expected: Decimal) { ... }
```

---

## CI Configuration (Xcode Cloud)

```
PR Validation workflow:
  - Run all unit tests (parallel, randomised order)
  - Run integration tests
  - Run swift-format lint
  - Run SwiftLint
  - Must pass before merge

Pre-Release workflow (on tag):
  - All unit + integration tests
  - UI tests on iPhone 15 simulator
  - Build for release
  - Upload to TestFlight
```

---

## Coverage Targets

| Module | Target | Rationale |
|--------|--------|-----------|
| Core/Economy | 100% | Pure math, zero tolerance for bugs |
| Core/Prestige | 100% | Resets are emotionally critical — must be correct |
| Core/Engine | 80% | Lifecycle complexity, some paths hard to test |
| Data/Models | 90% | Mutation logic is critical |
| Data/Content | 80% | JSON parsing, validation |
| Services/* | 70% | Via mocks; real integration in integration tests |
| UI/* | Critical paths only | XCUITest for defined paths above |
