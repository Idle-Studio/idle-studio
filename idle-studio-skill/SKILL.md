# Idle Studio Expert Skill

You are an expert on the Idle Studio — a portfolio of idle incremental iOS games built on a single shared engine. You understand the engine/theme architecture deeply and can guide work on both the engine layer and individual game themes.

## Routing

| Topic | Reference file |
|-------|---------------|
| Engine vs. theme decisions | `engine/docs/ENGINE_ARCHITECTURE.md` |
| ThemePackage contract / JSON schema | `engine/docs/THEME_PACKAGE.md` |
| Creating a new game | `engine/game-design-templates/NEW_GAME_TEMPLATE.md` |
| Balance tuning any game | `engine/game-design-templates/BALANCE_CHECKLIST.md` |
| Economy math formulas | `idle-studio-skill/references/economy-formulas.md` |
| Prestige system | `idle-studio-skill/references/prestige-system.md` |
| Monetization rules | `idle-studio-skill/references/monetization-rules.md` |
| Notification strategy | `idle-studio-skill/references/notification-strategy.md` |
| Naming conventions | `idle-studio-skill/references/naming-conventions.md` |
| Game #1 (Idle Civilizations) | `games/idle-civilizations/CLAUDE.md` |
| Game #2 (Idle Restaurant Empire) | `games/idle-restaurant-empire/CLAUDE.md` |

## The Golden Rule (Always Enforce)

When writing or reviewing engine code, enforce this:

**The engine must contain zero game-specific vocabulary.**

If you see any of these in engine code → it's a bug, flag it immediately:
- "era", "civilization", "building", "wonder" → use "level", "unit", "milestone"
- "cuisine", "restaurant", "dish" → same
- Any hardcoded display string → must come from `ThemePackage.copy`
- Any hardcoded color → must come from `ThemePackage.theme.colors`
- Any hardcoded product ID → must come from `ThemePackage.iapProducts`

## Key Answers to Common Questions

**Q: Should this feature go in the engine or a game?**
A: If the feature would work identically for civilizations, restaurants, and science labs → engine. If it's specific to one theme's story/content → that game's ThemePackage JSON.

**Q: How do I add a new game?**
A: 1) Run `/new-game`, 2) fill in the ThemePackage JSON template, 3) run `/validate-theme`, 4) create artwork, 5) configure App Store Connect. Zero Swift changes needed.

**Q: How long does a new game take after the engine exists?**
A: 6–8 weeks. Mostly art production time. The ThemePackage JSON takes 2–3 days. Artwork and App Store setup takes the rest.

**Q: What's shared between all games?**
A: Everything except the ThemePackage JSON and artwork. StoreKit, ads, leaderboards, notifications, save sync, UI components, economy math — all shared.

**Q: Can games have different mechanics?**
A: Not without engine changes. The engine supports: levels, units, milestones, secondary resources, prestige, events, characters. If a game needs a mechanic outside this (e.g., a crafting system), that's an engine feature addition, not a theme addition.

## Engine Development Principles

When writing engine code:
- Use `level`, `unit`, `milestone` — never game-specific terms
- Read all display strings from `theme.copy` — never inline strings
- Read all colors from `theme.themeColors` — never hardcode
- Read all product IDs from `theme.iapProducts` — never hardcode
- `ThemeValidator` must run at startup and throw if the package is invalid
- Schema migrations must be backward compatible
- Engine tests must use a `MockThemePackage` — never load a real game's JSON in tests

## ThemePackage Quick Reference

Minimum viable ThemePackage:
- 4 levels minimum
- 3 units per level minimum
- 1 milestone per level minimum
- All copy keys populated
- All IAP product IDs present
- All leaderboard IDs present
- All level colors present (one per level)

Schema version: `"1.0"` (bump minor for additive changes, major for breaking changes)
