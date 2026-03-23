# /add-level Command

## Purpose
Add a new level (era, cuisine, period, division) to an existing game's ThemePackage.

## Usage
```
/add-level [game-id] [level-name]
```

Examples:
```
/add-level idle-civilizations "Space Age"
/add-level idle-restaurant-empire "Japanese Omakase"
/add-level idle-science-lab "Digital Revolution"
```

## What This Command Does

1. **Load references:**
   - `games/[game-id]/[game-id].json` — existing ThemePackage
   - `games/[game-id]/CLAUDE.md` — vocabulary for this game
   - `engine/docs/THEME_PACKAGE.md` — level format spec
   - `idle-studio-skill/references/economy-formulas.md`
   - `engine/game-design-templates/BALANCE_CHECKLIST.md`

2. **Determine next order number** from existing levels

3. **Calculate advance requirement** following the balance curve:
   - Find the previous level's advance requirement
   - Apply 10×–100× multiplier based on position in the curve
   - Flag if this would make the level disproportionate

4. **Design the level content:**
   - 3–6 units fitting the theme vocabulary and this level's sub-theme
   - Unit costs that follow from the previous level's scale
   - 1–2 milestones appropriate to the theme
   - Secondary resource that creates interesting gameplay decisions
   - Level color that fits the visual identity

5. **Produce the JSON block** for the new level — ready to paste into the ThemePackage `levels` array

6. **Run balance validation** on the new level in context of the full game

7. **Update game-design docs** — append to the relevant index file

## Output Format

```
## New Level: [Level Name] → [Game Name]

**Order:** [N]  
**Vocabulary:** [Era/Cuisine/Period] ([game-specific term])  
**Secondary resource:** [Resource name]

### JSON Block (paste into levels[] array in [game-id].json):
\`\`\`json
{
  "id": "[level_id]",
  "displayName": "[Level Name]",
  "order": [N],
  ...
}
\`\`\`

### Balance Validation
✅ Advance requirement: [value] (curve target: [range])
✅ First unit affordable in < 3 minutes after advance
✅ Estimated sessions to advance: ~[N] (target: 5–30)
⚠️ [any warnings]

### Art Assets Needed
- Level artwork: `level_[id]` (1920×1080px illustrated scene)
- Unit icons: [N] icons at `unit_[id]` (64×64pt @3x SVG)
- Milestone artwork: [N] images at `milestone_[id]`

### Next Steps
[ ] Paste JSON block into [game-id].json levels[] array
[ ] Run /validate-theme [game-id]
[ ] Run /balance-theme [game-id]
[ ] Commission artwork
[ ] Create level bundle IAP product in App Store Connect
[ ] Add to game-design docs
```
