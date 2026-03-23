# /add-unit Command

## Purpose
Add a new unit (building, dish, experiment, player) to a specific level within a game.

## Usage
```
/add-unit [game-id] [level-id] [unit-name]
```

Examples:
```
/add-unit idle-civilizations stone_age "Flint Spear Workshop"
/add-unit idle-restaurant-empire bistro "Copper Saucepan"
/add-unit idle-science-lab ancient_discoveries "Sundial"
```

## What This Command Does

1. **Load references:**
   - `games/[game-id]/[game-id].json` — find the target level and existing units
   - `games/[game-id]/CLAUDE.md` — vocabulary (unit noun, tone)
   - `engine/docs/THEME_PACKAGE.md` — unit format spec
   - `idle-studio-skill/references/economy-formulas.md`
   - `engine/game-design-templates/BALANCE_CHECKLIST.md`

2. **Position the unit** within the level's existing units:
   - Compare costs to find where this unit fits in the progression
   - Ensure it fills a genuine gap (not redundant)
   - Suggest placement: "This unit sits between [Unit A] and [Unit B]"

3. **Calculate balanced values:**
   - Base cost: fits between adjacent units (5–10× above previous)
   - Cost multiplier: 1.08–1.15 based on position (later units slightly more forgiving)
   - Base production rate: 5–8× more than previous unit at count=1
   - Manager threshold: 10 (standard) or 25 (if complex/late unit)
   - All 4 upgrade tiers at 10/25/50/100

4. **Write the unit spec** following the game's tone:
   - Description: 1 sentence, on-theme, slightly witty
   - Icon asset name following `unit_[id]` convention

5. **Check it doesn't dominate** existing units:
   - At count=1, new unit should not produce more than unit N+2 at count=10
   - If it would dominate, reduce production rate

6. **Produce the JSON block** ready to paste into the level's `units` array

## Output Format

```
## New Unit: [Unit Name] → [Game Name] / [Level Name]

**ID:** `[unit_id]`  
**Placement:** Between [Unit A] and [Unit B]  
**Description:** "[one-sentence description]"

### JSON Block (paste into levels[[N]].units[] array):
\`\`\`json
{
  "id": "[unit_id]",
  "displayName": "[Unit Name]",
  "description": "[description]",
  "iconAsset": "unit_[unit_id]",
  "baseCost": { "gold": [value] },
  "costMultiplier": [value],
  "baseProductionPerSecond": { "gold": [value] },
  "managerThreshold": [value],
  "upgradeTiers": [
    { "atCount": 10,  "multiplier": 1.5 },
    { "atCount": 25,  "multiplier": 2.0 },
    { "atCount": 50,  "multiplier": 3.0 },
    { "atCount": 100, "multiplier": 6.0 }
  ]
}
\`\`\`

### Balance Check
✅ Base cost: [value] (fits between [Unit A] at [cost] and [Unit B] at [cost])
✅ Rate at count=1: [value] Gold/s (5–8× [Unit A] rate ✅)
✅ Manager in: ~[N] purchases at typical play pace
✅ Does not dominate adjacent units
⚠️ [any warnings]

### Art Asset Needed
- Icon: `unit_[unit_id]` (64×64pt @3x SVG, [level] color palette)
  Brief: [2-sentence visual description for artist]

### Next Steps
[ ] Paste JSON into [game-id].json
[ ] Run /validate-theme [game-id]
[ ] Run /balance-theme [game-id] to verify level balance unchanged
[ ] Commission icon art
```
