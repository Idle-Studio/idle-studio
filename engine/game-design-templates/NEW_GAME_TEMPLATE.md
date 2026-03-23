# New Game Template

Copy this file and fill it in to create a new game. Run `/validate-theme [name]` when done.

## Before You Start — Answer These Questions

1. **Theme:** What is the core fantasy? ("Build history", "Build a restaurant empire", "Discover science")
2. **Levels (4–8):** What are the progression stages? (eras, cuisine styles, research periods)
3. **Units (3–8 per level):** What does the player buy? (buildings, kitchen equipment, lab gear)
4. **Milestones (1–2 per level):** What are the big achievements? (Wonders, Michelin Stars, Nobel Prizes)
5. **Secondary resource:** What is the era-specific resource that creates interesting decisions?
6. **Characters:** What collectables make sense? (historical leaders, famous chefs, legendary scientists)
7. **Events:** What weekly/seasonal events fit the theme naturally?
8. **Tone:** Serious or humorous? (Idle Civilizations is lightly humorous; adjust flavor text accordingly)

---

## ThemePackage JSON Template

```json
{
  "schemaVersion": "1.0",
  "gameID": "REPLACE_kebab-case-unique-id",
  "displayName": "REPLACE Game Display Name",
  "bundleID": "com.yourstudio.REPLACE",
  "primaryCurrency": "Gold",
  "primaryCurrencyIcon": "coin",

  "theme": {
    "colors": {
      "background":      "#0D0D0F",
      "surface":         "#1A1A20",
      "surfaceElevated": "#252530",
      "textPrimary":     "#F5F5F5",
      "textSecondary":   "#A0A0B0",
      "goldAccent":      "#FFD700"
    },
    "levelColors": [
      { "levelID": "REPLACE_level_1_id", "primary": "#REPLACE", "secondary": "#REPLACE" },
      { "levelID": "REPLACE_level_2_id", "primary": "#REPLACE", "secondary": "#REPLACE" }
    ]
  },

  "levels": [
    {
      "id": "REPLACE_level_1_id",
      "displayName": "REPLACE Level 1 Name",
      "order": 1,
      "flavorText": "REPLACE one sentence of flavor text",
      "artworkAsset": "level_REPLACE_1",
      "advanceRequirement": { "gold": 1000 },
      "levelResources": ["REPLACE_resource_name"],

      "units": [
        {
          "id": "REPLACE_unit_1_id",
          "displayName": "REPLACE Unit 1 Name",
          "description": "REPLACE one sentence description, slightly witty.",
          "iconAsset": "unit_REPLACE_1",
          "baseCost": { "gold": 10 },
          "costMultiplier": 1.15,
          "baseProductionPerSecond": { "gold": 0.1 },
          "managerThreshold": 10,
          "upgradeTiers": [
            { "atCount": 10,  "multiplier": 1.5 },
            { "atCount": 25,  "multiplier": 2.0 },
            { "atCount": 50,  "multiplier": 3.0 },
            { "atCount": 100, "multiplier": 6.0 }
          ]
        }
      ],

      "milestones": [
        {
          "id": "REPLACE_milestone_1_id",
          "displayName": "REPLACE Milestone Name",
          "description": "REPLACE one sentence description.",
          "artworkAsset": "milestone_REPLACE_1",
          "requirements": { "gold": 500, "REPLACE_resource": 50 },
          "constructionSeconds": 1800,
          "skipCostCoins": 50,
          "canSkipWithAd": true,
          "bonuses": [
            { "type": "multiply", "scope": "level", "resource": "all", "value": 1.75 }
          ],
          "isPermanentBonus": false
        }
      ]
    }
  ],

  "events": [
    {
      "id": "REPLACE_event_1_id",
      "displayName": "REPLACE Event Name",
      "type": "weekly",
      "durationSeconds": 604800,
      "eligibleFromLevelOrder": 2,
      "bonuses": [
        { "resource": "REPLACE_resource", "multiplier": 3.0 }
      ],
      "leaderboardMetric": "REPLACE_resource_earned",
      "rewards": {
        "top25pct": { "type": "character_skin", "id": "REPLACE_skin_id" },
        "top10pct": { "type": "milestone_skin", "id": "REPLACE_skin_id" },
        "top1pct":  { "type": "profile_badge",  "id": "REPLACE_badge_id" }
      }
    }
  ],

  "characters": [
    {
      "id": "REPLACE_char_1_id",
      "displayName": "REPLACE Character Name",
      "portraitAsset": "char_REPLACE_1",
      "unlockCondition": { "type": "completeLevel", "levelID": "REPLACE_level_1_id" },
      "bonuses": [
        { "unitID": "REPLACE_unit_1_id", "multiplier": 1.10 }
      ],
      "quote": "REPLACE a short memorable quote."
    }
  ],

  "iapProducts": {
    "starterPack":       "com.yourstudio.REPLACE.starter_pack",
    "removeAds":         "com.yourstudio.REPLACE.remove_ads",
    "premiumPass":       "com.yourstudio.REPLACE.pass.monthly",
    "premiumPassAnnual": "com.yourstudio.REPLACE.pass.annual",
    "coins1000":         "com.yourstudio.REPLACE.coins.1000",
    "coins5000":         "com.yourstudio.REPLACE.coins.5000",
    "coins15000":        "com.yourstudio.REPLACE.coins.15000",
    "lifetimePack":      "com.yourstudio.REPLACE.patron_lifetime",
    "levelBundles": {}
  },

  "leaderboards": {
    "globalTokens":  "com.yourstudio.REPLACE.lb.global_tokens",
    "weeklyGold":    "com.yourstudio.REPLACE.lb.weekly_gold",
    "countryTokens": "com.yourstudio.REPLACE.lb.country_tokens"
  },

  "copy": {
    "unitNoun":            "REPLACE (Building / Dish / Experiment / Player)",
    "unitNounPlural":      "REPLACE",
    "levelNoun":           "REPLACE (Era / Cuisine / Period / Division)",
    "milestoneNoun":       "REPLACE (Wonder / Star / Prize / Trophy)",
    "characterNoun":       "REPLACE (Leader / Chef / Scientist / Legend)",
    "premiumPassName":     "REPLACE Pass",
    "advanceVerb":         "REPLACE (Advance Era / Master Cuisine / Publish Discovery)",
    "prestigeTitle":       "REPLACE! (A New Era Begins! / New Cuisine Unlocked!)",

    "offlineSheet": {
      "title":         "REPLACE! (Your civilization flourished!)",
      "body":          "REPLACE (Your builders have been busy.)",
      "collectButton": "Collect",
      "doubleButton":  "Watch Ad: Double it!"
    },

    "notifications": {
      "offlineCapTitle": "REPLACE!",
      "offlineCapBody":  "REPLACE (Come collect before the coffers overflow!)",
      "dailyQuestTitle": "REPLACE (New daily quests are ready!)",
      "dailyQuestBody":  "REPLACE (Complete today's challenges for bonus coins.)",
      "weeklyEventTitle":"REPLACE (A new event begins!)",
      "levelReadyTitle": "REPLACE!",
      "levelReadyBody":  "REPLACE (You have enough Gold to advance.)"
    },

    "notificationPermission": {
      "title":        "REPLACE (Stay ahead of history)",
      "body":         "REPLACE (Get notified when your offline income caps...)",
      "enableButton": "Enable Notifications",
      "laterButton":  "Maybe later"
    },

    "onboarding": [
      {
        "step": 1,
        "title": "REPLACE (Build Your Civilization)",
        "body":  "REPLACE (Tap to earn Gold...)",
        "highlightTarget": "tapArea"
      },
      {
        "step": 2,
        "title": "REPLACE (Buy Buildings)",
        "body":  "REPLACE (Buildings earn Gold automatically...)",
        "highlightTarget": "firstUnit"
      }
    ]
  }
}
```

---

## Balance Guidelines for New Themes

Follow the balance curve from `engine/game-design-templates/BALANCE_CHECKLIST.md`.

Quick reference for level advance requirements (first 6 levels):

```
Level 1: 1,000 Gold
Level 2: 50,000 Gold
Level 3: 5,000,000 Gold
Level 4: 100,000,000 Gold
Level 5: 10,000,000,000 Gold
Level 6: 1,000,000,000,000 Gold
```

These are the defaults. You can adjust by ±50% if the theme strongly suggests it (e.g., a faster-paced theme might use 50% of these values). Go outside that range and you need a strong design justification.

---

## Art Brief Template

Once the ThemePackage JSON is complete, fill in the art brief at:
`games/[name]/docs/design/ART_BRIEF.md`

Required assets per game:
- Level artwork: 1 scene per level (1920×1080px, illustrated)
- Unit icons: 1 per unit (64×64pt @3x SVG, theme color palette)
- Milestone artwork: 1 per milestone (512×512px, illustrated)
- Character portraits: 1 per character (256×256px, illustrated)
- App icon: 1024×1024px + all required sizes
- App Store screenshots: 6.7" iPhone (required), iPad Pro (recommended)

---

## Checklist Before Submitting a New Theme

- [ ] All `REPLACE` placeholders filled in
- [ ] `/validate-theme [name]` passes all checks
- [ ] `/balance-theme [name]` shows no critical issues
- [ ] All asset names match the JSON `iconAsset` / `artworkAsset` fields
- [ ] App Store Connect: IAP products created with matching product IDs
- [ ] App Store Connect: Game Center leaderboards created with matching IDs
- [ ] App Store Connect: Achievements created with matching IDs
- [ ] `GoogleService-Info.plist` added to Xcode target (not committed to git)
- [ ] AdMob app registered, real ad unit IDs in Remote Config
- [ ] `CLAUDE.md` created in `games/[name]/` folder
