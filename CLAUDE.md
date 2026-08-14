# Idle Studio — Master Claude Context

## What This Repository Is

A game studio monorepo. One shared engine, multiple themed idle games releasing every 3–4 months.

```
IdleStudio/
├── engine/          ← Shared, theme-agnostic game engine (built ONCE)
├── games/
│   ├── idle-civilizations/     ← Game #1 (history theme)
│   ├── idle-restaurant-empire/ ← Game #2 (cuisine theme)
│   ├── idle-science-lab/       ← Game #3 (inventions theme)
│   └── idle-football-club/     ← Game #4 (football theme)
└── idle-studio-skill/          ← Local Claude skill for this studio
```

---

## The Golden Rule: Engine vs. Theme

**ALWAYS ask: "Does this belong in the engine or in a theme?"**

| Belongs in `engine/` | Belongs in `games/[name]/` |
|---------------------|---------------------------|
| Economy math (production, costs, prestige) | Era/level names and progression story |
| Offline income calculation | Building names, descriptions, icons |
| Prestige / reset system | Resource names (Gold is universal, but "Bronze" is a theme) |
| Big number formatting | Color palette |
| SwiftData persistence layer | Music and sound identity |
| StoreKit 2 integration | App icon and screenshots |
| AdMob integration | IAP product names and descriptions |
| GameKit / leaderboards | Notification copy |
| Push notification scheduling | Event names and flavor text |
| Analytics event types | App Store listing copy |
| UI component library | Wonder / milestone names |
| Navigation architecture | Leader characters |
| Theme protocol + ThemePackage | The content.json itself |

If you're ever unsure: **put it in the engine, expose it via the ThemePackage protocol.**

---

## Development Phases

### Phase 1: Build the Engine (Months 1–2)
**Do not build any game yet.** Build only the engine layer.

Deliverables:
- `GameEngine` actor with tick, offline calc, prestige
- `EconomyCalculator` pure functions
- `ThemePackage` protocol — the contract every game must satisfy
- `ContentLoader` — loads a `ThemePackage` from JSON at runtime
- `ThemeValidator` — validates a new theme's JSON before shipping
- Full UI component library (resource bar, building card, progress bar, number roller)
- StoreKit 2 service with the IAP shell (product IDs injected by theme)
- AdMob service with placement types defined
- GameKit service (leaderboard IDs injected by theme)
- Push notification service (copy injected by theme)
- SwiftData persistence (theme-agnostic models)
- CloudKit sync
- Firebase Analytics + Remote Config wired up
- Full unit test suite for engine (100% economy coverage)

Done when: a `ThemePackage` JSON can be loaded and the game is fully playable.

### Phase 2: Build Game #1 — Idle Civilizations (Month 3–4)
Use the engine. Build only:
- `idle-civilizations.json` — the complete ThemePackage content
- Era artwork (8 scenes)
- Building icons (~45 icons)
- Wonder artwork (9 images)
- App icon set
- App Store assets
- Notification copy (in ThemePackage JSON)
- IAP product names/descriptions (in ThemePackage JSON)

Done when: Game #1 ships globally.

### Phase 3: Game #2 — Idle Restaurant Empire (Month 5–8)
Engine unchanged. Build only:
- `restaurant.json` — new ThemePackage
- New artwork
- New App Store listing
- Cross-promotion hook in Game #1

**Target: 6–8 weeks per game after Phase 1.**

---

## ThemePackage — The Core Abstraction

Every game is a `ThemePackage`. This is the contract defined in `engine/docs/THEME_PACKAGE.md`.

A ThemePackage contains:
1. **Identity** — app name, bundle ID, colors, fonts
2. **Levels** — the progression stages (eras in Civ, cuisines in Restaurant, etc.)
3. **Units** — the things players buy (buildings, dishes, experiments, players)
4. **Milestones** — the special achievements (Wonders, Michelin Stars, Nobel Prizes, Trophies)
5. **Resources** — what gets earned (Gold is universal; secondary resources are theme-specific)
6. **Events** — weekly and seasonal events with multipliers
7. **Characters** — collectable leader/mascot cards
8. **Copy** — all display strings (notification text, onboarding, etc.)
9. **IAP mapping** — product IDs to in-game rewards
10. **Leaderboard IDs** — Game Center leaderboard identifiers

The engine never reads hardcoded strings. It always asks the ThemePackage.

---

## How to Start a New Game

1. Run `/new-game [name] [theme]` — scaffolds the folder and CLAUDE.md
2. Read `engine/docs/THEME_PACKAGE.md` — understand the contract
3. Read `engine/game-design-templates/NEW_GAME_TEMPLATE.md` — content spec template
4. Fill in the ThemePackage JSON following the template
5. Run `/validate-theme [name]` — engine validates the JSON
6. Build artwork (brief in `games/[name]/docs/design/ART_BRIEF.md`)
7. Configure App Store Connect (products, leaderboards, metadata)
8. Ship

**No Swift code changes required for a new game theme.**

---

## Agents Available

| Agent | Scope |
|-------|-------|
| `engine-architect-agent.md` | Engine internals, ThemePackage protocol, shared services |
| `theme-author-agent.md` | Creating new game themes, filling ThemePackage JSON |
| `balance-agent.md` | Economy tuning across any theme |
| `monetization-agent.md` | IAP, ads, subscriptions — applies to all games |
| `testing-agent.md` | Engine test suite, theme validation tests |
| `release-agent.md` | App Store submission, ASO, CI/CD per game |

---

## Commands Available

| Command | What it does |
|---------|-------------|
| `/new-game [name] [theme]` | Scaffold a new game from the engine template |
| `/validate-theme [name]` | Check ThemePackage JSON against engine contract |
| `/balance-theme [name]` | Run economy simulation for any theme |
| `/check-engine` | Verify engine has no theme-specific code |
| `/add-level [game] [name]` | Add a new level (era/cuisine/etc.) to a theme |
| `/add-unit [game] [level] [name]` | Add a new unit (building/dish/etc.) to a theme |
| `/release-notes [game]` | Generate App Store release notes |

---

## Active Skills

- `swiftui-expert` (AvdLee) — SwiftUI patterns
- `swift-concurrency-expert` (AvdLee) — actors, async/await
- `swift-testing-expert` (AvdLee) — Swift Testing
- `core-data-expert` (AvdLee) — SwiftData
- `idle-studio-expert` (local) — this studio's domain knowledge
