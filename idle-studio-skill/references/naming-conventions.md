# Naming Conventions Reference

## Content IDs (JSON / game-design files)
- All lowercase, underscores: `stone_age`, `campfire`, `pyramid_of_giza`
- Era IDs: `[name]_[period]` → `stone_age`, `bronze_age`, `space_age`
- Building IDs: descriptive noun → `campfire`, `grain_farm`, `steam_engine`
- Wonder IDs: full name → `pyramid_of_giza`, `notre_dame`, `eiffel_tower`
- Event IDs: `[theme]_[type]` → `greek_olympics`, `black_friday_trade`
- Leader IDs: `[name]_[epithet]` → `caesar_julius`, `cleopatra_vii`

## Swift Types
- ViewModels: `[Feature]ViewModel` → `HomeViewModel`, `ShopViewModel`
- Views: `[Feature]View` or `[Feature]Screen` → `HomeView`, `ShopScreen`
- Services: `[Name]Service` → `StoreKitService`, `AdService`
- Protocols: `[Name]Protocol` → `AnalyticsServiceProtocol`
- Actors: `[Name]` (no suffix) → `GameEngine`, `ContentRegistry`
- Models: plain noun → `GameState`, `Building`, `Era`
- Errors: `[Domain]Error` → `GameError`, `StoreError`

## Swift Properties & Methods
- Boolean properties: `is`, `has`, `can`, `should` prefix → `isActive`, `hasManager`, `canPrestige`
- Computed production: `productionRate`, `prestigeMultiplier`, `offlineIncome`
- Action methods: verb first → `purchaseBuilding()`, `advanceEra()`, `collectIncome()`
- Async methods: no special suffix (Swift async is the marker) → `func loadContent() async throws`

## Files
- One type per file (except small related types grouped together)
- File name = primary type name → `GameEngine.swift`, `HomeView.swift`
- Extensions in separate files: `GameState+Persistence.swift`, `Decimal+Formatting.swift`

## Asset Names
- Building icons: `building_[id]` → `building_campfire`, `building_steam_engine`
- Wonder images: `wonder_[id]` → `wonder_pyramid_of_giza`, `wonder_eiffel_tower`
- Era artwork: `era_[id]_artwork` → `era_stone_age_artwork`
- Leader portraits: `leader_[id]` → `leader_caesar_julius`
- UI icons: plain descriptive → `icon_prestige`, `icon_alliance`, `icon_settings`

## IAP Product IDs
Pattern: `com.idleciv.[category].[name]`
- Consumables: `com.idleciv.coins.1000`, `com.idleciv.boost.24h`
- Non-consumables: `com.idleciv.remove_ads`, `com.idleciv.era.stone_age`
- Subscriptions: `com.idleciv.pass.monthly`, `com.idleciv.pass.annual`

## Analytics Event Names
Pattern: `[noun]_[verb]` (snake_case)
- `era_advanced`, `building_purchased`, `wonder_started`, `wonder_completed`
- `ad_rewarded_watched`, `ad_interstitial_shown`
- `iap_purchase_complete`, `sub_trial_started`
- `prestige_performed`, `offline_income_collected`

## Notification Identifiers
Pattern: `notif.[type].[context]`
- `notif.offline.cap_warning`
- `notif.quest.daily_reset`
- `notif.event.weekly_start`
- `notif.wonder.complete.[wonderID]`
- `notif.alliance.gift_received`

## Git Branch Names
Pattern: `[type]/[ticket]-[short-description]`
- `feat/IC-42-stone-age-buildings`
- `fix/IC-87-offline-income-calculation`
- `content/IC-55-add-renaissance-era`
- `balance/IC-99-tune-bronze-age-costs`
- `chore/IC-12-setup-firebase`
