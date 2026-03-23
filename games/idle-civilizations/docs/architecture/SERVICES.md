# Services Integration Guide

External services used in Idle Civilizations, with integration instructions, key APIs, and gotchas.

---

## Firebase (Analytics + Crashlytics + Remote Config)

### Setup
- Add `GoogleService-Info.plist` to project (never commit to git — use CI secrets)
- Import via SPM: `https://github.com/firebase/firebase-ios-sdk`
- Products: `FirebaseAnalytics`, `FirebaseCrashlytics`, `FirebaseRemoteConfig`

### Analytics
- All events defined in `docs/architecture/DATA_MODELS.md` → `AnalyticsEvent` enum
- Fire events from `FirebaseAnalyticsService` — never call Firebase directly from features
- User properties set on first launch: `player_era`, `has_civ_pass`, `has_removed_ads`
- Debug mode: `FirebaseApp.configure()` with `DebugView` in Xcode scheme args

### Remote Config
Keys managed in Firebase console. Values:
```
content_version         String    "1.0.0"
offline_cap_hours       Number    8
first_interstitial_delay_minutes  Number    20
max_interstitials_per_session     Number    2
prestige_formula_divisor          Number    1000000000000
offer_wall_enabled      Boolean   true
event_active_id         String    ""   (empty = no event)
event_multiplier        Number    1.0
```

Fetch on launch, apply after fetch completes (not before). Bundle fallbacks for all keys.

### Crashlytics
- Enabled automatically after `FirebaseApp.configure()`
- Add custom keys on crashes: `currentEra`, `buildingCount`, `legacyTokens`
- Log non-fatal errors for StoreKit failures, ad failures, content parse failures

---

## AdMob (Google Mobile Ads SDK)

### Setup
- Add `GADApplicationIdentifier` to `Info.plist`
- Import via SPM: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
- Initialize ONLY after ATT prompt result (never before)

### App Tracking Transparency
```swift
// AppState.bootstrap():
let status = await ATTrackingManager.requestTrackingAuthorization()
// Then initialize AdMob regardless of result
// (will serve limited ads if denied — still revenue, just lower eCPM)
await GADMobileAds.sharedInstance().start()
```

### Ad Unit IDs
Never hardcode real ad unit IDs in source. Store in Remote Config:
```
admob_rewarded_offline          String    "ca-app-pub-xxx/yyy"
admob_rewarded_bottleneck       String    "ca-app-pub-xxx/yyy"
admob_interstitial_era_advance  String    "ca-app-pub-xxx/yyy"
admob_banner                    String    "ca-app-pub-xxx/yyy"
```

Test IDs (use in DEBUG builds):
```
Rewarded:       ca-app-pub-3940256099942544/1712485313
Interstitial:   ca-app-pub-3940256099942544/4411468910
Banner:         ca-app-pub-3940256099942544/2934735716
```

### Rewarded Ad Lifecycle
```
1. loadRewardedAd() → stores loaded ad in AdService
2. isRewardedAdReady() → checks loaded ad is non-nil
3. showRewardedAd() → presents ad, awaits completion
4. In adDidEarnReward: → grant reward
5. In adDidDismissFullScreenContent: → preload next ad
6. In didFailToReceiveAd: → log error, don't offer again this session
```

### Interstitial Guard Conditions (ALL must be true to show)
- Session duration > 20 minutes
- Interstitials shown this session < 2
- Time since last interstitial > 5 minutes
- Time since last rewarded ad > 2 minutes
- `removeAds` entitlement NOT active
- `civPass` subscription NOT active

---

## StoreKit 2

### Products in App Store Connect
Configure all products before implementing. See `docs/business/MONETIZATION.md` for full list.

### Transaction Listener
Start listening for transactions as early as possible — before any UI loads:
```swift
// In AppState.init():
Task {
    for await verificationResult in Transaction.updates {
        await storeKitService.handle(verificationResult)
    }
}
```

### Entitlement Check Pattern
```swift
// On every app foreground:
let entitlements = Transaction.currentEntitlements
for await result in entitlements {
    if case .verified(let transaction) = result {
        await grantEntitlement(for: transaction.productID)
    }
}
```

### StoreKit Testing Configuration
Create `Configuration.storekit` in Xcode for unit/integration tests. Include all products. Use `SKTestSession` for UI tests.

---

## GameKit (Game Center)

### Authentication
```swift
GKLocalPlayer.local.authenticateHandler = { viewController, error in
    // If viewController != nil → show it (player needs to log in)
    // If error != nil → Game Center unavailable (degrade gracefully)
    // If both nil → authenticated
}
```

**Never block core gameplay on Game Center auth.** Degrade gracefully if unavailable.

### Leaderboard IDs (configure in App Store Connect)
```
com.idleciv.leaderboard.global_tokens          — all-time legacy tokens
com.idleciv.leaderboard.weekly_gold            — gold this week (resets Monday)
com.idleciv.leaderboard.country_tokens         — by GKLocalPlayer.local.local.regionCode
```

### Score Submission Rate Limiting
- Submit scores maximum once per minute
- Batch submissions — don't fire on every tick
- Queue submissions if Game Center temporarily unavailable, retry on next session

### Achievement IDs (configure in App Store Connect)
```
com.idleciv.achievement.first_steps
com.idleciv.achievement.stone_builder
com.idleciv.achievement.first_wonder
... (full list in docs/design/GAME_DESIGN_DOCUMENT.md)
```

---

## CloudKit (Save Sync)

### Container
`iCloud.com.yourstudio.idlecivilizations`

### Record Types
```
GameState       — primary game progress (one per player)
PlayerProfile   — display name, cosmetics, preferences
AllianceRecord  — public database (shared between players)
GiftRecord      — public database (alliance gift queue)
```

### Conflict Resolution
`GameState` conflicts: higher `legacyTokens` wins.  
Use `CKFetchRecordsOperation` with `desiredKeys` to fetch only changed fields on foreground.

### Offline Behavior
- CloudKit sync failures never block local gameplay
- Local SwiftData is the source of truth
- Cloud sync is best-effort, not guaranteed
- Show sync status indicator in Settings (not in gameplay)

---

## Push Notifications (Local Only in v1)

No server required. All notifications are scheduled locally.

```swift
// Request permission (after first era advance):
let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

// Schedule notification:
let content = UNMutableNotificationContent()
content.title = "Your civilization is flourishing!"
content.body = "Come collect before the coffers overflow!"
content.sound = .default

let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 21600, repeats: false)
let request = UNNotificationRequest(identifier: "notif.offline.cap_warning", content: content, trigger: trigger)
try await center.add(request)
```

**Important:** Always cancel and reschedule on every app background. State may have changed (production rate, events active, etc.).

---

## Xcode Cloud CI/CD

### Workflows

**PR Validation** (on every PR):
```yaml
trigger: pullRequest
actions:
  - test: { scheme: IdleCivilizationsTests, destination: simulator }
  - analyze: {}
post-action: notify Slack on failure
```

**TestFlight Internal** (on merge to main):
```yaml
trigger: branch (main)
actions:
  - build: { scheme: IdleCivilizations, configuration: Release }
  - testflight: { groups: [Internal] }
```

**TestFlight External** (on version tag):
```yaml
trigger: tag: v*
actions:
  - test: { all test targets }
  - build: { Release }
  - testflight: { groups: [Internal, External] }
```

### Environment Variables (Xcode Cloud secrets)
```
GOOGLE_SERVICE_INFO_PLIST_BASE64    — Firebase config (not committed to git)
ADMOB_APP_ID                        — for Info.plist injection
CLOUDKIT_CONTAINER_ID
```
