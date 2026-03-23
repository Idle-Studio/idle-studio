# Content Format Reference

All game content is defined in markdown spec files under `game-design/` and compiled into `content.json`.  
When adding new content, always produce BOTH the markdown spec AND the JSON block.

---

## Era Format

### Markdown spec (in `game-design/eras/[era-id].md`)

```markdown
# [Era Name]

**ID:** `stone_age`  
**Order:** 1  
**Flavor text:** "The dawn of humanity. Every spark of fire is a miracle."  
**Primary color:** `#8B7355`  
**Secondary color:** `#6B5335`  
**Advance requirement:** 1,000 Gold  
**Era resources:** Population  

## Buildings
(list building IDs defined in buildings section)

## Wonders
(list wonder IDs available in this era)

## Historical context
1–2 sentences for in-game flavor and leader quotes.
```

### JSON block (in `content.json`)

```json
{
  "id": "stone_age",
  "name": "Stone Age",
  "order": 1,
  "flavorText": "The dawn of humanity. Every spark of fire is a miracle.",
  "primaryColor": "#8B7355",
  "secondaryColor": "#6B5335",
  "advanceRequirement": { "gold": 1000 },
  "eraResources": ["population"],
  "buildingIDs": ["campfire", "hunting_ground", "berry_bush", "cave_painting", "flint_workshop"],
  "wonderIDs": ["lascaux_cave"],
  "leaderIDs": ["og_the_wise"]
}
```

---

## Building Format

### Markdown spec (in `game-design/buildings/BUILDINGS.md`, one entry per building)

```markdown
### Campfire

**ID:** `campfire`  
**Era:** Stone Age  
**Icon:** `building_campfire` (SF Symbol or custom asset)  
**Description:** "Warmth and light — the first step toward civilization."

| Stat | Value |
|------|-------|
| Base cost | 10 Gold |
| Cost multiplier | 1.15 |
| Base production | 0.1 Gold/s |
| Manager threshold | 10 owned |
| Max count | unlimited |

**Upgrade tiers:**
- 10 owned → +50% production
- 25 owned → +100% production
- 50 owned → +200% production
- 100 owned → +500% production
```

### JSON block

```json
{
  "id": "campfire",
  "eraID": "stone_age",
  "name": "Campfire",
  "description": "Warmth and light — the first step toward civilization.",
  "iconName": "building_campfire",
  "baseCost": { "gold": 10 },
  "costMultiplier": 1.15,
  "baseProductionPerSecond": { "gold": 0.1 },
  "managerUnlockCount": 10,
  "maxCount": null,
  "upgradeTiers": [
    { "requiredCount": 10, "productionMultiplier": 1.5 },
    { "requiredCount": 25, "productionMultiplier": 2.0 },
    { "requiredCount": 50, "productionMultiplier": 3.0 },
    { "requiredCount": 100, "productionMultiplier": 6.0 }
  ]
}
```

---

## Wonder Format

### Markdown spec (in `game-design/wonders/WONDERS.md`)

```markdown
### Pyramid of Giza

**ID:** `pyramid_of_giza`  
**Era:** Bronze Age  
**Icon:** `wonder_pyramid`  
**Flavor:** "A monument to ambition. And a lot of sand."

| Stat | Value |
|------|-------|
| Gold cost | 10,000 |
| Era resource cost | 500 Bronze |
| Construction time | 2 hours |
| Can skip with | Premium coins (200) or rewarded ad |
| Bonus | +100% Gold production, +30% all resources |
| Bonus scope | Bronze Age only |
| Persists through prestige? | Visual only (bonus resets) |
```

### JSON block

```json
{
  "id": "pyramid_of_giza",
  "eraID": "bronze_age",
  "name": "Pyramid of Giza",
  "description": "A monument to ambition. And a lot of sand.",
  "iconName": "wonder_pyramid",
  "requirements": { "gold": 10000, "bronze": 500 },
  "constructionSeconds": 7200,
  "skipCostCoins": 200,
  "canSkipWithAd": false,
  "bonuses": [
    { "type": "multiply", "resource": "gold", "value": 2.0 },
    { "type": "multiply", "resource": "all", "value": 1.3 }
  ],
  "bonusScope": "era"
}
```

---

## Event Format

### Markdown spec (in `game-design/events/EVENTS.md`)

```markdown
### Greek Olympics

**ID:** `greek_olympics`  
**Type:** `seasonal`  
**Duration:** 48 hours  
**Cadence:** Annual (summer)  
**Eligible eras:** Classical Empire and above

**Mechanic:**  
- Culture production ×3 during event  
- Exclusive leaderboard: most Culture earned in 48h  
- Top 10%: exclusive "Olympian" leader card  
- Top 1%: exclusive "Zeus's Blessing" cosmetic Wonder  

**Push notification:** "The Greek Olympics begin! Earn 3× Culture for 48 hours."
```

### JSON block

```json
{
  "id": "greek_olympics",
  "name": "Greek Olympics",
  "type": "seasonal",
  "durationSeconds": 172800,
  "eligibleEraOrder": 3,
  "bonuses": [
    { "type": "multiply", "resource": "culture", "value": 3.0 }
  ],
  "leaderboard": {
    "metric": "culture_earned",
    "rewards": {
      "top10pct": { "type": "leader_card", "id": "olympian" },
      "top1pct": { "type": "cosmetic_wonder", "id": "zeus_blessing" }
    }
  },
  "notificationBody": "The Greek Olympics begin! Earn 3× Culture for 48 hours."
}
```

---

## Validation Rules

When adding any content, verify:

1. **Costs follow the balance curve** — see `game-design/balance/BALANCE_GUIDE.md`
2. **Building IDs are unique** across all eras
3. **Wonder IDs are unique** globally
4. **Era order** numbers are sequential with no gaps
5. **costMultiplier** is between 1.08 and 1.20
6. **productionMultiplier** in upgrade tiers is always ≥ previous tier
7. **Construction times** for Wonders: minimum 30min, maximum 12h
8. **Colors** are valid hex codes and pass 4.5:1 contrast ratio on dark background
