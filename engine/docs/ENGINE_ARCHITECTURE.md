# Engine Architecture

The engine is the shared foundation. It knows nothing about civilizations, restaurants, or science. It only knows about levels, units, milestones, resources, and prestige.

**Core rule: if the word "civilization", "era", "building", or "wonder" appears in engine code → that's a bug.**

---

## Engine Layer Map

```
engine/
├── docs/
│   ├── ENGINE_ARCHITECTURE.md         ← This file
│   ├── THEME_PACKAGE.md               ← The contract every game must satisfy
│   └── ENGINE_API.md                  ← Public API surface for theme authors
│
└── game-design-templates/
    ├── NEW_GAME_TEMPLATE.md            ← Blank ThemePackage to fill in
    └── BALANCE_CHECKLIST.md            ← Validation checklist for new themes
```

---

## Module Structure (Xcode)

```
Packages/
├── IdleEngine (Swift Package — shared)
│   ├── Sources/IdleEngine/
│   │   ├── Core/
│   │   │   ├── GameEngine.swift        ← Actor, tick loop, lifecycle
│   │   │   ├── EconomyCalculator.swift ← Pure functions, all production math
│   │   │   ├── PrestigeSystem.swift    ← Token formula, multiplier, reset logic
│   │   │   └── OfflineCalculator.swift ← Offline income with cap
│   │   ├── Theme/
│   │   │   ├── ThemePackage.swift      ← Protocol + Codable models
│   │   │   ├── ThemeLoader.swift       ← Loads JSON from bundle or remote
│   │   │   └── ThemeValidator.swift    ← Validates contract at startup
│   │   ├── Data/
│   │   │   ├── GameState.swift         ← Immutable value type
│   │   │   ├── ResourceBundle.swift    ← Decimal arithmetic bundle
│   │   │   └── PersistenceService.swift ← SwiftData + CloudKit
│   │   ├── Services/
│   │   │   ├── StoreKitService.swift   ← StoreKit 2, reads product IDs from theme
│   │   │   ├── AdService.swift         ← AdMob, placement types defined by engine
│   │   │   ├── GameCenterService.swift ← Reads leaderboard IDs from theme
│   │   │   ├── NotificationService.swift ← Reads copy from theme
│   │   │   ├── AnalyticsService.swift  ← Fixed event types, theme-agnostic
│   │   │   └── RemoteConfigService.swift ← Firebase remote config
│   │   └── UI/
│   │       ├── Theme/
│   │       │   ├── AppTheme.swift      ← ThemeEnvironment, dynamic colors
│   │       │   └── Typography.swift    ← Fixed type scale
│   │       ├── Components/
│   │       │   ├── ResourceBar.swift
│   │       │   ├── UnitCard.swift      ← "BuildingCard" in the theme is "UnitCard" in engine
│   │       │   ├── NumberRoller.swift
│   │       │   ├── ProgressBar.swift
│   │       │   ├── MilestoneCard.swift
│   │       │   └── FloatingParticle.swift
│   │       └── Screens/
│   │           ├── GameplayScreen.swift
│   │           ├── LevelAdvanceScreen.swift  ← "Prestige" screen
│   │           ├── OfflineIncomeSheet.swift
│   │           ├── ShopScreen.swift
│   │           ├── LeaderboardScreen.swift
│   │           ├── SocialScreen.swift
│   │           └── SettingsScreen.swift
│   └── Tests/IdleEngineTests/
│       ├── EconomyCalculatorTests.swift
│       ├── PrestigeSystemTests.swift
│       ├── OfflineCalculatorTests.swift
│       ├── ThemeValidatorTests.swift
│       └── GameStateMutationTests.swift

└── [GameName] (Xcode Target — thin wrapper per game)
    ├── [GameName]App.swift      ← Entry point, loads theme JSON, starts engine
    ├── [theme].json             ← The entire game definition
    └── Assets.xcassets/         ← Theme-specific artwork
```

---

## ThemePackage Protocol (Swift)

```swift
// Engine defines this protocol — themes conform via the JSON model
public protocol ThemePackage {
    var gameID: String { get }
    var displayName: String { get }
    var levels: [ThemeLevel] { get }
    var events: [ThemeEvent] { get }
    var characters: [ThemeCharacter] { get }
    var iapProducts: ThemeIAPProducts { get }
    var leaderboards: ThemeLeaderboards { get }
    var copy: ThemeCopy { get }
    var themeColors: ThemeColors { get }
}

// Concrete JSON-decoded implementation
public struct JSONThemePackage: ThemePackage, Codable { ... }
```

---

## App Entry Point Pattern (per game — minimal)

Each game target is a ~20 line file. All logic is in the engine:

```swift
// IdleCivilizationsApp.swift
import SwiftUI
import IdleEngine

@main
struct IdleCivilizationsApp: App {
    var body: some Scene {
        WindowGroup {
            // Engine handles everything — game is the theme JSON
            IdleGameRoot(themeName: "civilizations")
        }
    }
}

// IdleRestaurantEmpireApp.swift
@main
struct IdleRestaurantEmpireApp: App {
    var body: some Scene {
        WindowGroup {
            IdleGameRoot(themeName: "restaurant")
        }
    }
}
```

`IdleGameRoot` is provided by the engine. It:
1. Loads `[themeName].json` from the bundle
2. Validates it via `ThemeValidator`
3. Injects the theme into `AppEnvironment`
4. Presents the full game UI
5. Starts `GameEngine` with the theme's level/unit definitions

---

## GameEngine (Theme-Agnostic)

```swift
actor GameEngine {
    // Engine knows "levels" and "units" — not "eras" and "buildings"
    private var state: GameState       // theme-agnostic model
    private var theme: any ThemePackage

    func tick() {
        // EconomyCalculator uses theme's unit production values
        // but doesn't know what a "unit" represents
        let production = EconomyCalculator.production(for: state, theme: theme, elapsed: 1.0)
        state = state.applying(production: production)
    }

    func purchaseUnit(id: String, quantity: Int) throws {
        // "unit" = building, dish, experiment, player — theme doesn't matter
        guard let unit = theme.unit(id: id) else { throw EngineError.unknownUnit(id) }
        let cost = EconomyCalculator.unitCost(unit: unit, currentCount: state.unitCount(id: id))
        // ...
    }

    func advanceLevel() throws {
        // "level" = era, cuisine era, research period, division — theme doesn't matter
        guard let nextLevel = theme.nextLevel(after: state.currentLevelID) else {
            throw EngineError.noNextLevel
        }
        // ...
    }
}
```

---

## UI Components (Theme-Agnostic)

Components read display names from the theme via `@Environment(\.theme)`:

```swift
struct UnitCard: View {
    let unit: ThemeUnit
    @Environment(\.theme) var theme

    var body: some View {
        // Displays unit.displayName, unit.description
        // In Civilizations: "Campfire", "Warmth and light..."
        // In Restaurant: "Pizza Oven", "Authentic Neapolitan heat..."
        // Same component, different data
    }
}

struct LevelAdvanceScreen: View {
    @Environment(\.theme) var theme

    var body: some View {
        Text(theme.copy.prestigeTitle)        // "A New Era Begins!" or "New Cuisine Unlocked!"
        Text(theme.copy.advanceVerb)          // "Advance Era" or "Master Cuisine"
    }
}
```

---

## What Changes Per Game (Only These Things)

| Asset / Config | Location | Example (Civ vs Restaurant) |
|---------------|----------|-----------------------------|
| Theme JSON | `games/[name]/[name].json` | `civilizations.json` vs `restaurant.json` |
| Level artwork | `Assets.xcassets/levels/` | Era panoramas vs cuisine kitchen scenes |
| Unit icons | `Assets.xcassets/units/` | Campfire icon vs Pizza Oven icon |
| Milestone artwork | `Assets.xcassets/milestones/` | Pyramid vs Michelin Star badge |
| Character portraits | `Assets.xcassets/characters/` | Caesar portrait vs Gordon Ramsay-style chef |
| App icon | `Assets.xcassets/AppIcon` | Globe/coin vs fork/plate |
| App Store listing | App Store Connect | History-themed vs food-themed |
| IAP product names | App Store Connect + JSON | "Civ Pass" vs "Chef's Table" |
| Game Center config | App Store Connect + JSON | Civilization leaderboards vs Recipe leaderboards |
| Bundle ID | Xcode target | `com.studio.idleciv` vs `com.studio.idlerest` |

**Everything else is the engine.** Zero Swift code changes for a new game.

---

## Engine Version Contract

The ThemePackage JSON includes `schemaVersion`. The engine validates this at startup.

- If `schemaVersion` matches → proceed
- If `schemaVersion` is older → engine attempts migration (if migration exists)
- If `schemaVersion` is newer than engine → crash with clear error (update the engine)

This allows the engine to evolve (new features, schema additions) while old theme JSONs remain valid via migration paths. New fields are always optional with sensible defaults.

---

## Cross-Game Features

These engine features work identically across all games:

### Shared Loyalty (Studio Points)
Players earn "Studio Points" by playing any game in the portfolio. Studio Points unlock cross-game cosmetics and create stickiness across the portfolio.

Engine tracks `studioPoints` in `PlayerProfile` (CloudKit-synced). Each game awards points at:
- Every level advance: +50 points
- Every milestone completed: +25 points  
- Every 7-day streak: +100 points
- Every IAP: +200 points

Studio Points leaderboard is portfolio-wide (separate Game Center leaderboard per game but aggregated in a future "Studio Hub" app).

### Cross-Promotion
When a new game ships, the engine can show a cross-promo card in existing games:
- Configured via Remote Config (no update needed)
- `crossPromo` key in Remote Config → engine shows the card in Settings tab
- Tapping opens App Store product page

### Shared Save Profile
`PlayerProfile` (CloudKit) stores cosmetics and preferences shared across all games. A player who buys a profile badge in Game #1 keeps it in Game #2.
