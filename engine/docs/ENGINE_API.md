# Engine Public API

This documents the public surface of `IdleEngine` that theme authors and game targets interact with. Everything inside the engine is internal — only what's listed here is available to game code.

The game target (`IdleCivilizationsApp.swift` etc.) is ~20 lines and uses only this API.

---

## Entry Point

### `IdleGameRoot`
The top-level SwiftUI view. Pass the theme name; the engine handles everything else.

```swift
IdleGameRoot(themeName: "civilizations")
// OR with overrides for testing:
IdleGameRoot(themeName: "civilizations", overrideTheme: MockThemePackage.minimal)
```

The engine:
1. Loads `[themeName].json` from the bundle
2. Validates it via `ThemeValidator` (crashes on failure with a descriptive error)
3. Injects theme into `@Environment(\.theme)`
4. Starts `GameEngine`
5. Presents the full game UI

---

## ThemePackage Protocol

What a ThemePackage must expose (read-only, decoded from JSON):

```swift
public protocol ThemePackage: Sendable {
    var schemaVersion: String { get }
    var gameID: String { get }
    var displayName: String { get }
    var primaryCurrency: String { get }
    var primaryCurrencyIcon: String { get }
    var themeColors: ThemeColors { get }
    var levels: [ThemeLevel] { get }
    var events: [ThemeEvent] { get }
    var characters: [ThemeCharacter] { get }
    var iapProducts: ThemeIAPProducts { get }
    var leaderboards: ThemeLeaderboards { get }
    var copy: ThemeCopy { get }

    // Convenience helpers (provided by default implementations)
    func level(id: String) -> ThemeLevel?
    func nextLevel(after levelID: String) -> ThemeLevel?
    func unit(id: String, levelID: String) -> ThemeUnit?
    func milestone(id: String) -> ThemeMilestone?
    func levelColor(for levelID: String) -> LevelColors
}
```

---

## ThemeLevel

```swift
public struct ThemeLevel: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let order: Int
    public let flavorText: String
    public let artworkAsset: String
    public let advanceRequirement: ResourceCost
    public let levelResources: [String]
    public let units: [ThemeUnit]
    public let milestones: [ThemeMilestone]
}
```

---

## ThemeUnit

```swift
public struct ThemeUnit: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let iconAsset: String
    public let baseCost: ResourceCost
    public let costMultiplier: Decimal
    public let baseProductionPerSecond: ResourceBundle
    public let managerThreshold: Int
    public let upgradeTiers: [UpgradeTier]

    // Computed
    public func cost(atCount count: Int) -> ResourceCost
    public func productionRate(atCount count: Int) -> ResourceBundle
    public func upgradeMultiplier(atCount count: Int) -> Decimal
}
```

---

## ThemeMilestone

```swift
public struct ThemeMilestone: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let artworkAsset: String
    public let requirements: ResourceCost
    public let constructionSeconds: TimeInterval
    public let skipCostCoins: Int
    public let canSkipWithAd: Bool
    public let bonuses: [MilestoneBonus]
    public let isPermanentBonus: Bool
}
```

---

## ThemeCopy

```swift
public struct ThemeCopy: Sendable {
    // Nouns
    public let unitNoun: String           // "Building", "Dish", "Experiment"
    public let unitNounPlural: String
    public let levelNoun: String          // "Era", "Cuisine", "Period"
    public let milestoneNoun: String      // "Wonder", "Star", "Prize"
    public let characterNoun: String      // "Leader", "Chef", "Scientist"

    // Verbs & phrases
    public let premiumPassName: String
    public let advanceVerb: String
    public let prestigeTitle: String

    // Sheets
    public let offlineSheet: OfflineSheetCopy
    public let notifications: NotificationCopy
    public let notificationPermission: NotificationPermissionCopy
    public let onboarding: [OnboardingStep]
}
```

---

## Environment Keys (for SwiftUI)

```swift
// Access the loaded theme anywhere in the view hierarchy
@Environment(\.theme) var theme: any ThemePackage

// Access the game engine
@Environment(\.gameEngine) var engine: GameEngine

// Access the app router
@Environment(\.router) var router: AppRouter
```

---

## GameEngine (observable state for UI)

The engine is an actor, but it exposes an `AsyncStream<GameState>` for UI observation:

```swift
// Observe state changes in a ViewModel:
Task {
    for await state in engine.stateStream {
        await MainActor.run { self.currentState = state }
    }
}
```

Player actions (called from UI via ViewModel → engine):

```swift
// All throwing — handle errors in ViewModel
try await engine.purchaseUnit(id: "campfire", quantity: 1)
try await engine.purchaseUnit(id: "campfire", quantity: 10)
try await engine.purchaseMaxUnits(id: "campfire")   // buys max affordable
try await engine.advanceLevel()                      // prestige
try await engine.startMilestone(id: "lascaux_cave")
try await engine.collectOfflineIncome(doubled: false)
try await engine.collectOfflineIncome(doubled: true) // after rewarded ad

// Non-throwing
await engine.applyBoost(multiplier: 3.0, duration: 600)  // timed boost
await engine.saveState()
```

---

## EconomyCalculator (public pure functions for UI display)

These are available to ViewModels for displaying computed values without going through the engine actor:

```swift
// How much would buying N of this unit cost right now?
EconomyCalculator.unitCost(unit: themeUnit, currentCount: 12, quantity: 1)
EconomyCalculator.unitCost(unit: themeUnit, currentCount: 12, quantity: 10)

// How many can the player currently afford?
EconomyCalculator.maxAffordable(unit: themeUnit, currentCount: 12, availableGold: playerGold)

// What's the current production rate?
EconomyCalculator.productionRate(for: gameState, theme: theme)

// What would the prestige multiplier be with N more tokens?
EconomyCalculator.prestigeMultiplier(legacyTokens: 15)

// What's the pending offline income?
EconomyCalculator.offlineIncome(productionRate: rate, secondsAway: 14400)
```

---

## ThemeValidator

Run this at startup — the engine calls it automatically, but you can also call it explicitly:

```swift
// Throws ThemeValidationError with descriptive message on failure
try ThemeValidator.validate(theme)

// Returns all errors without throwing (for debug tools)
let errors = ThemeValidator.allErrors(in: theme)
let warnings = ThemeValidator.allWarnings(in: theme)
```

---

## Schema Versioning

```swift
// Check if a theme JSON is compatible with the current engine
ThemeValidator.isCompatible(schemaVersion: "1.0")  // Bool

// Attempt migration from older schema
let migrated = try ThemeMigrator.migrate(from: "0.9", theme: oldThemeData)
```

---

## What's NOT Public

The following are internal to the engine and cannot be accessed from game targets:

- `GameState` mutation methods (only the engine calls these)
- `PersistenceService` (engine manages persistence)
- `StoreKitService` internals (engine manages IAP)
- `AdService` internals (engine manages ads)
- `NotificationService` internals (engine manages scheduling)
- Any hardcoded content (there is none)
