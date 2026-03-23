# Data Models Reference

All Swift data types used in Idle Civilizations, documented for Claude to understand the domain model when writing code.

---

## Core Game State

### GameState (value type — immutable struct)
The complete snapshot of the player's current game. All mutations return a new copy.

```
GameState
├── currentEraID: String              — e.g. "bronze_age"
├── gold: Decimal                     — current gold balance
├── culture: Decimal
├── science: Decimal
├── faith: Decimal
├── eraResource1: Decimal             — era-specific (e.g. Bronze)
├── eraResource2: Decimal             — era-specific (e.g. Food)
├── legacyTokens: Int                 — accumulated all-time (never resets)
├── totalGoldEarned: Decimal          — cumulative all-time (drives prestige tokens)
├── globalMultiplier: Decimal         — product of all active multipliers
├── buildings: [BuildingState]        — current counts and manager status
├── completedWonderIDs: [String]      — visual persistence only
├── activeBoost: ActiveBoost?         — timed production boost if active
├── pendingOfflineIncome: Decimal     — set on return from background
├── pendingOfflineSeconds: TimeInterval
├── lastActiveAt: Date
└── totalPlaytime: TimeInterval
```

**Key rule:** Never store derived values in GameState (e.g., don't store `productionRate` — compute it from `EconomyCalculator` when needed).

### BuildingState
```
BuildingState
├── id: String                        — matches Building.id from content
├── count: Int                        — how many the player owns
├── hasManager: Bool                  — auto-runs without tapping
└── managerUnlockThreshold: Int       — count at which manager activates
```

### ActiveBoost
```
ActiveBoost
├── multiplier: Decimal               — e.g. 2.0 for 2×
├── expiresAt: Date
└── source: BoostSource               — .rewardedAd | .iap | .dailyBonus | .event
```

---

## Content Models (decoded from content.json, never mutated)

### Era
```
Era
├── id: String
├── name: String
├── order: Int                        — sequential, 1-based
├── flavorText: String
├── primaryColor: String              — hex, e.g. "#8B7355"
├── secondaryColor: String
├── advanceRequirement: EraUnlock
├── eraResources: [ResourceType]
├── buildingIDs: [String]
├── wonderIDs: [String]
└── leaderIDs: [String]
```

### Building
```
Building
├── id: String
├── eraID: String
├── name: String
├── description: String
├── iconName: String
├── baseCost: ResourceBundle
├── costMultiplier: Decimal           — typically 1.08–1.15
├── baseProductionPerSecond: ResourceBundle
├── managerUnlockCount: Int           — typically 10
├── maxCount: Int?                    — nil = unlimited
└── upgradeTiers: [UpgradeTier]
```

### UpgradeTier
```
UpgradeTier
├── requiredCount: Int                — e.g. 10, 25, 50, 100
└── productionMultiplier: Decimal     — e.g. 1.5 (50% more)
```

### Wonder
```
Wonder
├── id: String
├── eraID: String
├── name: String
├── description: String
├── iconName: String
├── requirements: ResourceBundle
├── constructionSeconds: TimeInterval
├── skipCostCoins: Int
├── canSkipWithAd: Bool               — only for short Wonders (< 1h)
├── bonuses: [WonderBonus]
└── bonusScope: BonusScope           — .era | .permanent
```

### ResourceBundle
```
ResourceBundle
├── gold: Decimal
├── culture: Decimal
├── science: Decimal
├── faith: Decimal
├── era1: Decimal                     — maps to eraResources[0]
└── era2: Decimal                     — maps to eraResources[1]
```

Supports `+`, `-`, `*`, `/` operators. All arithmetic uses `Decimal` internally.

---

## Player Profile (persisted, CloudKit synced)

```
PlayerProfile
├── id: UUID                          — local identifier
├── displayName: String               — from Game Center or custom
├── gameCenterID: String?
├── countryCode: String               — ISO 3166-1 alpha-2, for leaderboards
├── equippedLeaderID: String?
├── unlockedLeaderIDs: [String]
├── unlockedSkinIDs: [String]
├── premiumCoinBalance: Int
├── hasRemovedAds: Bool               — from StoreKit entitlement
├── hasActiveCivPass: Bool            — from StoreKit subscription
├── allianceID: String?
├── achievements: [AchievementState]
└── statistics: PlayerStatistics
```

### PlayerStatistics
```
PlayerStatistics
├── totalSessions: Int
├── totalPlaytimeSeconds: TimeInterval
├── totalPrestigesPerformed: Int
├── totalGoldEarnedAllTime: Decimal   — matches GameState.totalGoldEarned
├── totalAdsWatched: Int
├── totalIAPSpend: Decimal            — populated from StoreKit history
└── highestEraReached: Int            — order number of highest era
```

---

## Services Protocols

All external services implement a protocol for testability:

### AnalyticsServiceProtocol
```
func track(_ event: AnalyticsEvent) async
func setUserProperty(_ property: UserProperty) async
func setScreen(_ name: String) async
```

### StoreKitServiceProtocol
```
func setup() async
func products() async throws -> [Product]
func purchase(_ productID: String) async throws -> Transaction
func currentEntitlements() -> AsyncStream<Transaction>
func isSubscriptionActive() async -> Bool
func hasRemovedAds() async -> Bool
```

### AdServiceProtocol
```
func loadRewardedAd(for placement: AdPlacement) async
func isRewardedAdReady(for placement: AdPlacement) -> Bool
func showRewardedAd(for placement: AdPlacement, from viewController: UIViewController) async throws -> AdReward
func shouldShowInterstitial() -> Bool
func showInterstitial(from viewController: UIViewController) async
```

### GameCenterServiceProtocol
```
func authenticate() async
func isAuthenticated() -> Bool
func submitScore(_ score: Int, to leaderboardID: String) async throws
func fetchLeaderboard(_ leaderboardID: String) async throws -> [LeaderboardEntry]
func reportAchievement(_ id: String, progress: Double) async throws
```

---

## Analytics Events

```swift
enum AnalyticsEvent {
    // Gameplay
    case eraAdvanced(era: String, tokens: Int)
    case buildingPurchased(buildingID: String, count: Int, eraID: String)
    case wonderStarted(wonderID: String)
    case wonderCompleted(wonderID: String)
    case prestigePerformed(fromEra: String, toEra: String, tokens: Int)
    case offlineIncomeCollected(gold: Decimal, secondsAway: TimeInterval, doubled: Bool)

    // Monetization
    case iapOfferShown(productID: String, trigger: String)
    case iapPurchaseComplete(productID: String, price: Decimal)
    case iapPurchaseCancelled(productID: String)
    case adRewardedWatched(placement: AdPlacement)
    case adRewardedSkipped(placement: AdPlacement, secondsWatched: Int)
    case adInterstitialShown(trigger: String)
    case subscriptionStarted(productID: String)
    case subscriptionCancelled(productID: String, tenureMonths: Int)

    // Social
    case leaderboardViewed(scope: String)
    case allianceJoined
    case giftSent
    case giftReceived

    // Retention
    case notificationReceived(type: String)
    case appOpenedFromNotification(type: String)
}
```
