# Stone Age

**ID:** `stone_age`  
**Order:** 1  
**Primary color:** `#8B7355`  
**Secondary color:** `#6B5335`  
**Advance requirement:** 1,000 Gold  
**Era resources:** Population  
**Available from:** Game start (no unlock required)

> *"The dawn of humanity. Every spark of fire is a miracle."*

## Historical Context
70,000–3,000 BCE. Early humans master fire, develop basic tools, create cave art, and begin to form the first communities. The era ends with the discovery of metalworking.

## Buildings

| # | ID | Name | Base Cost | Cost Mult | Base Rate | Manager @ |
|---|-----|------|-----------|-----------|-----------|-----------|
| 1 | `campfire` | Campfire | 10 Gold | 1.15 | 0.1 Gold/s | 10 owned |
| 2 | `hunting_ground` | Hunting Ground | 100 Gold | 1.15 | 0.5 Gold/s | 10 owned |
| 3 | `berry_bush` | Berry Bush | 800 Gold | 1.14 | 4 Gold/s | 10 owned |
| 4 | `cave_painting` | Cave Painting | 1,200 Gold | 1.13 | 10 Gold/s | 25 owned |
| 5 | `flint_workshop` | Flint Workshop | 3,000 Gold | 1.12 | 40 Gold/s | 10 owned |

### Building Notes
- **Campfire:** Entry building. Player's first purchase. Tutorial guides them here.
- **Hunting Ground:** Second building, introduces the "buy when you can" loop.
- **Berry Bush:** Population bonus — produces +1 Population per 5 owned (Population unlocks Cave Painting faster).
- **Cave Painting:** Requires 10 Population to unlock. Produces Culture as secondary resource.
- **Flint Workshop:** End-era building. Produces the most gold, gated behind progress in earlier buildings.

### Upgrade Tiers (all buildings share this tier structure in Stone Age)
| Owned | Production Bonus |
|-------|-----------------|
| 10 | +50% production |
| 25 | +100% production |
| 50 | +200% production |
| 100 | +500% production |

## Wonders

### Lascaux Cave
**ID:** `lascaux_cave`  
**Requirement:** 500 Gold + 50 Culture  
**Construction time:** 30 minutes  
**Skip cost:** 50 Premium Coins  
**Bonus:** +75% production for all Stone Age buildings (for current era)  
**Flavor:** *"Art is the first language of civilization."*

## Leaders Available

### Og the Wise
**ID:** `leader_og`  
**Bonus:** +10% Campfire production  
**Unlock:** Complete the Stone Age  
**Quote:** *"Fire makes all things possible."*

## Progression Notes

### Expected Session Pattern
- **Session 1 (min 1–10):** Tutorial → buy Campfire → earn → buy Hunting Ground → earn ~50 Gold passively
- **Session 2 (min 5–8):** Return → collect offline income → buy more Campfires and Hunting Grounds → unlock manager
- **Session 3–4:** Push toward Berry Bush, unlock Cave Painting, start Flint Workshop
- **Session 5–6:** Enough Flint Workshops to hit 1,000 Gold advance requirement

### Balance Targets
- Time to first manager (Campfire): ~3–5 minutes
- Time to advance era: ~4–6 sessions
- Offline income at era advance: ~50 Gold/s (8h cap = 1.44M Gold — but advance only needs 1K, so early prestige is fast by design)

### First-Time Experience
Stone Age is the tutorial era. The game deliberately makes it fast and satisfying so players experience their first prestige quickly — this is the hook that creates the "just one more" loop.

## JSON Block

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
  "leaderIDs": ["leader_og"]
}
```
