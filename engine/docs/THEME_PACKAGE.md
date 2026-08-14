# ThemePackage — Engine Contract

The `ThemePackage` is the complete specification a game must provide to run on the Idle Studio engine. The engine is entirely driven by this contract — it contains zero hardcoded game content.

**If you're adding a new game: fill in this contract. No Swift changes needed.**

---

## Contract Overview

```
ThemePackage
├── identity            ← App name, colors, fonts, bundle ID
├── levels[]            ← Ordered progression stages (eras, cuisines, etc.)
│   ├── units[]         ← Things to buy within a level (buildings, dishes, etc.)
│   └── milestones[]    ← Special achievements (Wonders, Stars, Trophies, etc.)
├── resources[]         ← What gets earned (Gold + up to 2 level-specific types)
├── events[]            ← Weekly and seasonal events
├── characters[]        ← Collectable leader/mascot cards
├── iapMapping          ← Product IDs → in-game rewards
├── leaderboardIDs      ← Game Center identifiers
├── achievementIDs      ← Game Center achievement identifiers
└── copy                ← All display strings
```

---

## Full JSON Schema

```jsonc
{
  // ─── Identity ───────────────────────────────────────────────────────────────
  "schemaVersion": "1.0",            // engine validates this matches its version
  "gameID": "idle-civilizations",    // unique, kebab-case, permanent
  "displayName": "Idle Civilizations",
  "bundleID": "com.idlestudio.idleciv",
  "primaryCurrency": "Gold",         // always shown in resource bar
  "primaryCurrencyIcon": "coin",     // SF Symbol or asset name

  "theme": {
    "colors": {
      "background":      "#0D0D0F",  // must pass 4.5:1 contrast ratio
      "surface":         "#1A1A20",
      "surfaceElevated": "#252530",
      "textPrimary":     "#F5F5F5",
      "textSecondary":   "#A0A0B0",
      "goldAccent":      "#FFD700"
    },
    "levelColors": [
      // One entry per level, in order. Applied to entire UI when that level is active.
      { "levelID": "stone_age",   "primary": "#8B7355", "secondary": "#6B5335" },
      { "levelID": "bronze_age",  "primary": "#CD7F32", "secondary": "#8B4513" }
      // ... one per level
    ]
  },

  // ─── Levels ─────────────────────────────────────────────────────────────────
  // "levels" is what the engine calls eras internally.
  // In Civilizations they're eras. In Restaurant they're cuisine eras. Etc.
  // The engine term is always "level". Your display name is in "displayName".
  "levels": [
    {
      "id": "stone_age",
      "displayName": "Stone Age",           // shown in UI
      "order": 1,                            // sequential, 1-based, no gaps
      "flavorText": "The dawn of humanity.", // shown on level advance screen
      "artworkAsset": "era_stone_age",       // asset catalogue name
      "advanceRequirement": {
        "gold": 1000
      },
      "levelResources": ["population"],      // secondary resources for this level
                                             // max 2, engine reserves "gold" globally

      // ─── Units ──────────────────────────────────────────────────────────────
      // "units" = buildings / dishes / experiments / players etc.
      "units": [
        {
          "id": "campfire",
          "displayName": "Campfire",
          "description": "Warmth and light — the first step toward civilization.",
          "iconAsset": "unit_campfire",       // asset catalogue name
          "baseCost": { "gold": 10 },
          "costMultiplier": 1.15,             // per unit owned, 1.08–1.20
          "baseProductionPerSecond": { "gold": 0.1 },
          "managerThreshold": 10,             // auto-runs when owned ≥ this
          "upgradeTiers": [
            { "atCount": 10,  "multiplier": 1.5 },
            { "atCount": 25,  "multiplier": 2.0 },
            { "atCount": 50,  "multiplier": 3.0 },
            { "atCount": 100, "multiplier": 6.0 }
          ]
        }
        // ... more units
      ],

      // ─── Milestones ─────────────────────────────────────────────────────────
      // "milestones" = Wonders / Michelin Stars / Nobel Prizes / Trophies
      "milestones": [
        {
          "id": "lascaux_cave",
          "displayName": "Lascaux Cave",
          "description": "Art is the first language of civilization.",
          "artworkAsset": "milestone_lascaux",
          "requirements": { "gold": 500, "population": 50 },
          "constructionSeconds": 1800,        // 30 minutes
          "skipCostCoins": 50,
          "canSkipWithAd": true,              // only true for < 3600s milestones
          "bonuses": [
            { "type": "multiply", "scope": "level", "resource": "all", "value": 1.75 }
          ],
          "isPermanentBonus": false           // true = survives prestige (rare)
        }
      ]
    }
    // ... more levels
  ],

  // ─── Events ─────────────────────────────────────────────────────────────────
  "events": [
    {
      "id": "greek_olympics",
      "displayName": "Greek Olympics",
      "type": "seasonal",                     // "weekly" | "seasonal"
      "durationSeconds": 259200,              // 72 hours
      "eligibleFromLevelOrder": 3,            // Classical Empire and above
      "bonuses": [
        { "resource": "culture", "multiplier": 5.0 }
      ],
      "leaderboardMetric": "culture_earned",  // must match an analytics event field
      "rewards": {
        "top25pct": { "type": "character_skin", "id": "olympian_variant" },
        "top10pct": { "type": "milestone_skin", "id": "zeus_blessing" },
        "top1pct":  { "type": "profile_badge",  "id": "champion_of_olympia" }
      }
    }
  ],

  // ─── Characters ─────────────────────────────────────────────────────────────
  // Leaders in Civilizations, Chefs in Restaurant, Scientists in Lab, etc.
  "characters": [
    {
      "id": "leader_og",
      "displayName": "Og the Wise",
      "portraitAsset": "char_og",
      "unlockCondition": { "type": "completeLevel", "levelID": "stone_age" },
      "bonuses": [
        { "unitID": "campfire", "multiplier": 1.10 }
      ],
      "quote": "Fire makes all things possible."
    }
  ],

  // ─── IAP Mapping ────────────────────────────────────────────────────────────
  // Engine handles all StoreKit 2 logic. Theme provides the product IDs.
  "iapProducts": {
    "starterPack":      "com.idlestudio.idleciv.starter_pack",
    "removeAds":        "com.idlestudio.idleciv.remove_ads",
    "premiumPass":      "com.idlestudio.idleciv.civ_pass.monthly",
    "premiumPassAnnual":"com.idlestudio.idleciv.civ_pass.annual",
    "coins1000":        "com.idlestudio.idleciv.coins.1000",
    "coins5000":        "com.idlestudio.idleciv.coins.5000",
    "coins15000":       "com.idlestudio.idleciv.coins.15000",
    "lifetimePack":     "com.idlestudio.idleciv.patron_lifetime",
    "levelBundles": {
      "stone_age":   "com.idlestudio.idleciv.bundle.stone_age",
      "bronze_age":  "com.idlestudio.idleciv.bundle.bronze_age"
      // ... one per level
    }
  },

  // ─── Game Center ────────────────────────────────────────────────────────────
  "leaderboards": {
    "globalTokens":  "com.idlestudio.idleciv.lb.global_tokens",
    "weeklyGold":    "com.idlestudio.idleciv.lb.weekly_gold",
    "countryTokens": "com.idlestudio.idleciv.lb.country_tokens"
  },

  // ─── Copy ───────────────────────────────────────────────────────────────────
  // All user-facing strings. Engine uses these keys — never hardcodes strings.
  "copy": {
    "unitNoun":            "Building",          // "Building", "Dish", "Experiment"
    "unitNounPlural":      "Buildings",
    "levelNoun":           "Era",               // "Era", "Cuisine", "Period"
    "milestoneNoun":       "Wonder",            // "Wonder", "Star", "Trophy"
    "characterNoun":       "Leader",            // "Leader", "Chef", "Scientist"
    "premiumPassName":     "Civ Pass",          // "Civ Pass", "Chef's Table", "Lab Pass"
    "advanceVerb":         "Advance Era",       // "Advance Era", "Unlock Cuisine"
    "prestigeTitle":       "A New Era Begins!", // shown on level advance screen

    "offlineSheet": {
      "title":          "Your civilization flourished!",
      "body":           "Your builders have been busy.",
      "collectButton":  "Collect",
      "doubleButton":   "Watch Ad: Double it!"
    },

    "notifications": {
      "offlineCapTitle":  "Your civilization is flourishing!",
      "offlineCapBody":   "Come collect before the coffers overflow!",
      "dailyQuestTitle":  "New daily quests are ready!",
      "dailyQuestBody":   "Complete today's challenges for bonus coins.",
      "weeklyEventTitle": "A new historical event begins!",
      "levelReadyTitle":  "History awaits!",
      "levelReadyBody":   "You have enough Gold to advance your civilization."
    },

    "notificationPermission": {
      "title":       "Stay ahead of history",
      "body":        "Get notified when your offline income caps, Wonders complete, and daily quests reset.",
      "enableButton":"Enable Notifications",
      "laterButton": "Maybe later"
    },

    "onboarding": [
      {
        "step": 1,
        "title": "Build Your Civilization",
        "body":  "Tap to earn Gold and start your journey through history.",
        "highlightTarget": "tapArea"
      },
      {
        "step": 2,
        "title": "Buy Buildings",
        "body":  "Buildings earn Gold automatically — even when you're away.",
        "highlightTarget": "firstUnit"
      }
    ]
  }
}
```

---

## Engine Terminology → Theme Terminology

The engine uses neutral internal terms. Each theme maps them to its own vocabulary:

| Engine Term | Civilizations | Restaurant Empire | Science Lab | Football Club |
|-------------|--------------|-------------------|-------------|---------------|
| `level` | Era | Cuisine Era | Research Period | Division |
| `unit` | Building | Dish/Kitchen | Experiment | Player/Facility |
| `milestone` | Wonder | Michelin Star | Nobel Prize | Trophy |
| `character` | Leader | Head Chef | Scientist | Club Legend |
| `levelResource1` | Bronze/Faith/etc | Ingredient | Element | Formation |
| `premiumPass` | Civ Pass | Chef's Table | Lab Pass | Club Pass |
| `advanceVerb` | Advance Era | Master Cuisine | Publish Discovery | Earn Promotion |

The `copy` block in the ThemePackage provides these translations. The engine never uses its internal terms in the UI.

---

## Validation Rules (enforced by ThemeValidator)

Before any ThemePackage ships, `ThemeValidator` checks:

```
Identity
  ✓ gameID is unique (not used by any other theme)
  ✓ schemaVersion matches engine version
  ✓ bundleID follows reverse-domain format

Levels
  ✓ At least 4 levels, maximum 12
  ✓ order is sequential 1, 2, 3... no gaps
  ✓ Every level has at least 3 units, maximum 10
  ✓ Every level has at least 1 milestone
  ✓ levelResources max 2, no overlap with "gold"
  ✓ advanceRequirement exists and is > 0

Units
  ✓ IDs unique within the theme (not globally — themes are isolated)
  ✓ costMultiplier between 1.07 and 1.20
  ✓ baseProductionPerSecond > 0
  ✓ managerThreshold between 5 and 50
  ✓ upgradeTiers at 10, 25, 50, 100 (all 4 required)
  ✓ iconAsset key exists in asset catalogue

Balance (from BALANCE_GUIDE.md logic)
  ✓ Each level's first unit base cost < previous level's last unit base cost × 0.01
  ✓ Advance requirements follow geometric growth (ratio 10–1000× per level)
  ✓ No level takes more than 35 estimated sessions to complete

Copy
  ✓ All required copy keys present
  ✓ Notification strings < 100 characters
  ✓ No copy key is empty

IAP
  ✓ All required product IDs present
  ✓ Product IDs follow bundle ID prefix convention
  ✓ levelBundles has one entry per level

Colors
  ✓ All colors are valid hex
  ✓ background + surface + surfaceElevated pass WCAG AA (4.5:1 contrast ratio)
  ✓ One levelColor entry per level
```

---

## What the Engine Provides (Theme Gets For Free)

When a ThemePackage passes validation, the engine provides:

- ✅ Full idle game loop (tick, production, offline income)
- ✅ Prestige / level advance system with Legacy Tokens
- ✅ BigNumber formatting (1K → 1Qa → scientific)
- ✅ All SwiftUI screens (main gameplay, prestige, shop, leaderboard, social, settings)
- ✅ Era transition animations (parameterised by theme colors)
- ✅ Offline income sheet (copy from ThemePackage)
- ✅ Push notification scheduling (copy from ThemePackage)
- ✅ Notification permission moment (after first level advance)
- ✅ StoreKit 2 IAP (product IDs from ThemePackage)
- ✅ AdMob rewarded + interstitial ads (all placement logic)
- ✅ Game Center leaderboards + achievements
- ✅ CloudKit save sync
- ✅ Firebase Analytics (all events fire automatically)
- ✅ Remote Config content updates
- ✅ Alliance / social system
- ✅ Daily quests system
- ✅ Weekly events system
- ✅ ThemeValidator CLI tool

Theme author provides:
- 📝 `[theme].json` — the ThemePackage content
- 🎨 Artwork (level scenes, unit icons, milestone art, character portraits)
- 🎵 Sound identity (optional — engine has default sounds)
- 📱 App Store assets (screenshots, preview video, metadata)
- ⚙️ App Store Connect configuration (products, leaderboards, achievements)
