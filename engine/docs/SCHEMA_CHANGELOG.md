# Schema Changelog

Version history for the ThemePackage JSON schema. The engine validates `schemaVersion` at startup and applies migrations if needed.

---

## Version 1.0 (Current)
**Released:** Initial release with Idle Civilizations (Game #1)

### Fields introduced
All fields in the initial schema. See `THEME_PACKAGE.md` for the full specification.

**Required fields:**
- `schemaVersion`, `gameID`, `displayName`, `bundleID`
- `primaryCurrency`, `primaryCurrencyIcon`
- `theme.colors` (6 color keys)
- `theme.levelColors` (one entry per level)
- `levels[]` (4 minimum) with all nested fields
- `events[]`
- `characters[]`
- `iapProducts` (all 8 required product types)
- `leaderboards` (3 required IDs)
- `copy` (all required string keys)

**Optional fields (with defaults):**
- `levels[].units[].maxCount` — defaults to `null` (unlimited)
- `levels[].milestones[].isPermanentBonus` — defaults to `false`
- `levels[].milestones[].canSkipWithAd` — defaults to `false`

### Engine features included at 1.0
- Economy: production, costs, bulk buy, upgrade tiers
- Prestige: legacy tokens, multiplier, full/partial reset
- Offline income: calculation, 8-hour cap, rewarded-ad double
- Notifications: all 6 trigger types, permission moment after first advance
- StoreKit 2: all IAP types, subscription, restore purchases
- AdMob: rewarded (5 placements), interstitial (with timing guards), banner
- Game Center: leaderboards (3 types), achievements
- CloudKit: full save sync, conflict resolution
- Firebase: Analytics (all events), Remote Config, Crashlytics
- UI: all 7 screens, all components, era-adaptive theme colors
- Alliance system: create, join, gift, collective score
- Daily quests: 3 per day, reset at midnight
- Events: weekly and seasonal
- Cross-promotion: Remote Config-driven banner in Settings tab
- Studio Points: earned across all games, CloudKit-synced

---

## Upcoming — Version 1.1 (Planned, Month 6)

**Motivation:** Community feedback from Game #1 launch.  
**Breaking changes:** None — all additions are optional with defaults.

### Fields to add

```jsonc
// levels[].units[].specialMechanic (optional)
// Allows one unit per level to have a non-standard behavior
"specialMechanic": {
  "type": "resourceConverter",  // converts resource A to resource B
  "inputResource": "coal",
  "outputResource": "steam",
  "conversionRate": 5.0         // 1 coal → 5 steam per second
}

// levels[].milestones[].specialReward (optional)
// Allows milestones to grant permanent offline income bonus
"specialReward": {
  "type": "offlineIncomeMultiplier",
  "value": 1.5                  // +50% offline income permanently
}

// copy.shareCard (optional)
// Customise the shareable milestone/advance card
"shareCard": {
  "backgroundAsset": "share_card_bg",
  "tagline": "I just built the Eiffel Tower in Idle Civilizations!"
}
```

### Migration
Version 1.0 themes automatically valid in 1.1 engine — new optional fields use defaults.

---

## Upcoming — Version 2.0 (Planned, Month 12)

**Motivation:** New game mechanics for Game #4+ that don't fit the current model.  
**Breaking changes:** YES — requires migration path.

### Proposed additions (subject to design review)

- **Crafting system**: units can be combined to produce new resources
- **Map layer**: levels have a geographic/spatial representation
- **Team mechanics**: real-time alliance battles (not just collective scores)
- **Dynamic events**: events that respond to aggregate player behavior

### Migration strategy
- Engine 2.0 ships with a `ThemeMigrator.migrate(from: "1.x")` function
- Game targets set minimum engine version in Package.swift
- Old games continue running on Engine 1.x until they opt into 2.0 features
- New games target Engine 2.0 from day one

---

## Schema Design Principles

When adding fields to the schema:

1. **Always optional with sensible defaults** — don't break existing themes
2. **Document the purpose, not the implementation** — the JSON describes intent, not code
3. **Test with at least 2 different theme concepts** — if it only makes sense for Civilizations, it's not engine-level
4. **Validate at startup** — new required fields must have corresponding `ThemeValidator` checks
5. **Update `NEW_GAME_TEMPLATE.md`** — new fields must appear in the template with `REPLACE` placeholders
6. **Bump minor version** for additive changes, **major version** for breaking changes
7. **Never remove fields** — deprecate first (mark in schema), remove in next major version
