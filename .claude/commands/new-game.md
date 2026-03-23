# /new-game Command

## Purpose
Scaffold a complete new game folder from the engine template, ready for content authoring.

## Usage
```
/new-game [game-id] [theme-description]
```

Examples:
```
/new-game idle-restaurant-empire "Restaurant empire from street food to Michelin stars"
/new-game idle-science-lab "Scientific discoveries from fire to artificial intelligence"
/new-game idle-football-club "Football club from Sunday league to Champions League"
```

## What This Command Does

1. **Load references:**
   - `engine/docs/THEME_PACKAGE.md`
   - `engine/game-design-templates/NEW_GAME_TEMPLATE.md`
   - `idle-studio-skill/SKILL.md`

2. **Create the folder structure:**
   ```
   games/[game-id]/
   ├── CLAUDE.md                    ← Game-specific Claude context
   ├── [game-id].json               ← ThemePackage (filled from template)
   ├── .claude/
   │   └── settings.json            ← Inherits studio settings
   ├── docs/
   │   ├── architecture/            ← Points to engine docs (game-specific additions only)
   │   ├── business/
   │   │   ├── BUSINESS_OVERVIEW.md ← Game-specific market + positioning
   │   │   └── ROADMAP.md           ← Game-specific launch plan
   │   └── design/
   │       ├── ART_BRIEF.md         ← Asset list for artist
   │       └── STORE_LISTING.md     ← App Store copy
   └── game-design/
       ├── levels/                  ← One .md per level
       ├── units/                   ← Unit specs
       ├── milestones/              ← Milestone specs
       └── events/                  ← Event specs
   ```

3. **Pre-fill the ThemePackage JSON** with:
   - A suggested vocabulary table (level/unit/milestone/character names)
   - 4–6 level stubs with placeholder names from the theme
   - Advance requirements following the balance curve
   - Correct bundle ID pattern: `com.yourstudio.[game-id-without-dashes]`
   - All copy stubs adapted to the theme vocabulary

4. **Create `CLAUDE.md`** for the game with:
   - Theme overview and vocabulary table
   - Link to engine docs (don't duplicate engine content)
   - Game-specific agents and commands that override studio defaults

5. **Create `ART_BRIEF.md`** listing all required assets based on the level/unit/milestone count

6. **Output a checklist** of next steps:
   ```
   ✅ Folder structure created
   ✅ ThemePackage stub at games/[id]/[id].json
   
   Next steps:
   [ ] Fill in all REPLACE placeholders in [id].json
   [ ] Run /balance-theme [id] after filling costs + production rates
   [ ] Run /validate-theme [id] when complete
   [ ] Commission artwork (see docs/design/ART_BRIEF.md)
   [ ] Configure App Store Connect (see docs/business/ROADMAP.md)
   [ ] Add GoogleService-Info.plist to Xcode target (not git)
   ```
