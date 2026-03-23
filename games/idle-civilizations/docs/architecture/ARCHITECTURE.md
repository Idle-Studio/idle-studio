# Technical Architecture — Idle Civilizations

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 (strict concurrency) |
| UI Framework | SwiftUI (iOS 17+) |
| State Management | `@Observable` macro + `@MainActor` |
| Persistence | SwiftData (primary) + CloudKit (sync) |
| Networking | URLSession async/await |
| Remote Config | Firebase Remote Config |
| Analytics | Firebase Analytics + custom events |
| Crash Reporting | Firebase Crashlytics |
| Ads | Google AdMob (mediation) |
| IAP | StoreKit 2 |
| Social | GameKit (Game Center) |
| Push Notifications | UNUserNotificationCenter (local) |
| Numbers | Swift `Decimal` (big number arithmetic) |
| Testing | Swift Testing + XCUITest |
| CI/CD | Xcode Cloud |
| Dependencies | Swift Package Manager only |

---

## Architectural Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│   SwiftUI Views ←→ ViewModels (@Observable, @MainActor)     │
├─────────────────────────────────────────────────────────────┤
│                      Feature Layer                           │
│   Feature coordinators, use cases, domain logic             │
├─────────────────────────────────────────────────────────────┤
│                       Core Layer                             │
│   GameEngine · EconomyCalculator · PrestigeSystem           │
│   OfflineIncomeCalculator · NotificationScheduler           │
│   (Pure Swift — zero UI imports)                            │
├─────────────────────────────────────────────────────────────┤
│                       Data Layer                             │
│   Models · SwiftData persistence · CloudKit sync            │
│   Remote JSON config · Content validator                    │
├─────────────────────────────────────────────────────────────┤
│                      Services Layer                          │
│   StoreKitService · AdService · GameCenterService           │
│   AnalyticsService · RemoteConfigService                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Engine Design

### GameEngine (Actor)

```swift
// The heart of the game — single actor serialises all mutations
@globalActor
actor GameEngine {
    static let shared = GameEngine()
    
    private var gameState: GameState
    private var tickTimer: Task<Void, Never>?
    
    // Called every second while app is in foreground
    func tick() async {
        let elapsed: TimeInterval = 1.0
        let produced = EconomyCalculator.calculate(
            state: gameState,
            elapsed: elapsed
        )
        gameState = gameState.applying(production: produced)
        await MainActor.run {
            NotificationCenter.default.post(name: .gameStateTicked, object: gameState)
        }
    }
    
    func startTicking() {
        tickTimer = Task {
            while !Task.isCancelled {
                await tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
```

### EconomyCalculator (Pure Functions)

```swift
// Stateless — takes state IN, returns production OUT
// Easily unit-testable
enum EconomyCalculator {
    static func calculate(state: GameState, elapsed: TimeInterval) -> ResourceBundle {
        let baseProduction = state.buildings
            .filter { $0.count > 0 }
            .reduce(ResourceBundle.zero) { acc, building in
                acc + building.productionPerSecond(state: state) * Decimal(elapsed)
            }
        
        let multiplied = baseProduction
            * state.globalMultiplier
            * state.prestigeMultiplier
            * state.activeBoostMultiplier
        
        return multiplied
    }
    
    static func prestigeMultiplier(legacyTokens: Int) -> Decimal {
        // Each token = +2% multiplicative bonus
        return pow(Decimal(1.02), legacyTokens)
    }
    
    static func offlineIncome(
        productionRate: Decimal,
        secondsAway: TimeInterval,
        cap: TimeInterval = 8 * 3600
    ) -> Decimal {
        return productionRate * Decimal(min(secondsAway, cap))
    }
}
```

### BigNumber Formatting

```swift
// Resources reach 10^100+ — need readable display
extension Decimal {
    func formatted(style: NumberStyle = .abbreviation) -> String {
        switch style {
        case .abbreviation:
            return abbreviatedString()
        case .scientific:
            return scientificString()
        }
    }
    
    private func abbreviatedString() -> String {
        let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
        // ... implementation
    }
}
```

---

## Data Models

### GameState

```swift
@Model
final class GameState {
    var currentEraID: String
    var gold: Decimal
    var culture: Decimal
    var science: Decimal
    var legacyTokens: Int
    var globalMultiplier: Decimal
    var buildings: [BuildingState]
    var completedWonders: [String]
    var lastActiveAt: Date
    var totalPlaytime: TimeInterval
    
    // Computed — not stored
    var currentEra: Era { ContentRegistry.shared.era(id: currentEraID) }
    var prestigeMultiplier: Decimal { EconomyCalculator.prestigeMultiplier(legacyTokens: legacyTokens) }
}
```

### Content Models (decoded from JSON)

```swift
struct Era: Codable, Identifiable {
    let id: String
    let name: String
    let flavorText: String
    let primaryColor: String          // hex
    let unlockRequirement: EraUnlock
    let buildings: [Building]
    let availableWonders: [String]    // wonder IDs
    let resources: [ResourceType]
    let historicalPeriod: String
}

struct Building: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let baseCost: ResourceBundle
    let costMultiplier: Decimal       // e.g. 1.15 (15% more per purchase)
    let baseProductionPerSecond: ResourceBundle
    let productionMultiplierPerLevel: Decimal
    let managerUnlockCount: Int       // how many to buy before it auto-runs
    let maxCount: Int?               // nil = unlimited
}
```

---

## Data-Driven Content System

All game content lives in `game-design/content.json`. The app ships with a bundled copy and fetches updates via Remote Config without requiring an App Store update.

```json
{
  "version": "1.0.0",
  "eras": [
    {
      "id": "stone_age",
      "name": "Stone Age",
      "order": 1,
      "flavorText": "Humanity's first steps...",
      "primaryColor": "#8B7355",
      "unlockRequirement": { "type": "start" },
      "resources": ["gold", "population"],
      "buildings": [
        {
          "id": "campfire",
          "name": "Campfire",
          "baseCost": { "gold": 10 },
          "costMultiplier": 1.15,
          "baseProductionPerSecond": { "gold": 0.1 },
          "managerUnlockCount": 10
        }
      ]
    }
  ]
}
```

### ContentRegistry (Actor)

```swift
actor ContentRegistry {
    static let shared = ContentRegistry()
    
    private var content: GameContent?
    
    func load() async throws {
        // 1. Load bundled JSON (always available)
        let bundled = try loadBundled()
        // 2. Fetch remote update (async, non-blocking)
        let remote = try? await fetchRemote()
        // 3. Use newest version
        content = remote?.version > bundled.version ? remote! : bundled
    }
    
    func era(id: String) -> Era {
        content?.eras.first { $0.id == id } ?? .placeholder
    }
}
```

---

## Offline Income Flow

```
App enters background
    → Record timestamp in UserDefaults
    → Cancel tick timer
    → Schedule local notifications (6h cap warning)

App enters foreground
    → Calculate secondsAway = now - lastActiveAt
    → offlineIncome = productionRate × min(secondsAway, 28800)
    → Show OfflineIncomeSheet:
        "You were away 4 hours!"
        "Your civilization earned: 1.2M Gold"
        [Collect]  [Watch Ad: Double it!]
    → Apply income to game state
    → Resume tick timer
```

---

## Persistence & Sync

### Primary Storage: SwiftData
- `GameState` — persisted locally
- `PlayerProfile` — name, preferences, achievements
- `PurchaseHistory` — StoreKit 2 transactions
- `LeaderboardCache` — recent scores

### Cloud Sync: CloudKit
- Auto-syncs `GameState` and `PlayerProfile` across devices
- Conflict resolution: highest `legacyTokens` wins (most progress)
- Graceful degradation: cloud sync failure doesn't break local gameplay

### Remote Config: Firebase
- `content_version` — triggers content refresh
- `ad_interstitial_min_interval` — A/B test ad frequency
- `prestige_formula_v` — roll out balance changes safely
- `offer_wall_enabled` — kill switch for offer wall
- `new_era_teaser` — show upcoming era before release

---

## Services Architecture

All external services implement a protocol for testability:

```swift
// Protocol
protocol AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent) async
    func setUserProperty(_ property: UserProperty) async
}

// Production implementation
final class FirebaseAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent) async { /* Firebase */ }
}

// Test mock
final class MockAnalyticsService: AnalyticsServiceProtocol {
    var trackedEvents: [AnalyticsEvent] = []
    func track(_ event: AnalyticsEvent) async { trackedEvents.append(event) }
}

// Injected via Environment
struct ContentView: View {
    @Environment(\.analyticsService) var analytics
}
```

---

## Navigation Architecture

Using SwiftUI's typed navigation (NavigationStack + NavigationPath):

```swift
enum AppRoute: Hashable {
    case gameplay
    case eraDetail(eraID: String)
    case prestige
    case shop(context: ShopContext)
    case leaderboard(scope: LeaderboardScope)
    case social
    case settings
    case achievements
}

@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath()
    
    func navigate(to route: AppRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
}
```

---

## Push Notification Architecture

All notifications are **local** (no server required for v1):

```swift
enum GameNotification: String {
    case offlineCapWarning     // Fires at 6h after backgrounding
    case dailyQuestReset       // Fires daily at 8am local time
    case weeklyEventStart      // Fires on Monday 9am
    case friendGiftReceived    // Fires when Game Center gift queued
    case eraAdvanceReminder    // Fires 24h after era unlock if not advanced
    
    var content: UNMutableNotificationContent { /* ... */ }
}
```

### Permission Request Strategy
```swift
// In EraAdvanceCelebrationView — after first era advance
func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    let status = await center.notificationSettings().authorizationStatus
    guard status == .notDetermined else { return }
    
    // Contextual prompt first (iOS 16+ style)
    showNotificationExplainer = true
    // Then: if user taps "Enable", call requestAuthorization
}
```

---

## Security & Privacy

- No server-side game state validation in v1 (single player, no real money from gameplay)
- StoreKit 2 receipt validation is handled by StoreKit itself
- No personally identifiable information collected beyond Game Center ID
- CloudKit data is end-to-end encrypted by Apple
- ATT prompt shown before any IDFA-requiring ad network initialisation
- Privacy manifest (PrivacyInfo.xcprivacy) declares all data usage
- App Tracking Transparency framework integrated before AdMob init

---

## Testing Strategy

### Unit Tests (Swift Testing)
- `EconomyCalculator` — all production formulas
- `OfflineIncomeCalculator` — boundary conditions
- `PrestigeSystem` — token calculation, multiplier math
- `ContentRegistry` — JSON parsing, version comparison
- `NumberFormatter` — all abbreviation thresholds

### Integration Tests
- `GameEngine` — full tick cycle with real state
- `SwiftData` — persistence round-trips
- `StoreKitService` — StoreKit Testing configuration

### UI Tests (XCUITest)
- Onboarding flow complete
- First purchase flow (StoreKit sandbox)
- Era advance and prestige sequence
- Offline income sheet
- Notification permission request moment

---

## CI/CD — Xcode Cloud

```yaml
# xcode-cloud workflow
workflows:
  - name: PR Validation
    triggers:
      - pullRequest
    actions:
      - test: { scheme: IdleCivilizationsTests, destination: simulator }
      - analyze: { scheme: IdleCivilizations }
  
  - name: TestFlight
    triggers:
      - tag: { pattern: "v*" }
    actions:
      - build: { scheme: IdleCivilizations, configuration: Release }
      - testflight: { groups: [Internal, External] }
```

---

## Performance Targets

| Metric | Target |
|--------|--------|
| App cold launch | < 1.5 seconds |
| Frame rate during gameplay | 60fps consistent |
| Tick cycle duration | < 5ms |
| Offline income calc | < 50ms |
| Memory footprint | < 120MB |
| Battery impact | Negligible (1s tick, no GPU in background) |
| App binary size | < 80MB |
