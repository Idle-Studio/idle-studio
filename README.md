# Idle Studio

A game studio portfolio. One shared engine, multiple themed idle games.

## Games

| Game | Theme | Status | Target |
|------|-------|--------|--------|
| [Idle Civilizations](games/idle-civilizations/) | Human history | In development | Month 4 |
| [Idle Restaurant Empire](games/idle-restaurant-empire/) | World cuisines | Pre-production | Month 8 |
| [Idle Science Lab](games/idle-science-lab/) | Scientific discoveries | Concept | Month 12 |
| Idle Football Club | Football divisions | Concept | Month 16 |
| Idle Mythology | Gods & pantheons | Concept | Month 20 |

## Development Order

```
Month 1–2:  Build the engine (IdleEngine Swift Package)
Month 3–4:  Build Game #1 (Idle Civilizations) using the engine
Month 4:    Launch Game #1 globally
Month 5–8:  Build Game #2 (Idle Restaurant Empire) — new theme, zero engine changes
Month 8:    Launch Game #2
...repeat every 3–4 months
```

## Repository Structure

```
IdleStudio/
├── CLAUDE.md                    ← Master context (READ THIS FIRST)
├── .claude/                     ← Studio-wide agents + commands
├── idle-studio-skill/           ← Local Claude skill for this studio
│
├── engine/                      ← Shared engine (built ONCE)
│   ├── docs/
│   │   ├── ENGINE_ARCHITECTURE.md   ← How the engine works
│   │   └── THEME_PACKAGE.md         ← The contract every game must satisfy
│   └── game-design-templates/
│       ├── NEW_GAME_TEMPLATE.md     ← Blank ThemePackage to fill in
│       └── BALANCE_CHECKLIST.md     ← Validation for new games
│
└── games/
    ├── idle-civilizations/      ← Full docs + content design
    ├── idle-restaurant-empire/  ← Concept + stub
    └── idle-science-lab/        ← Concept + stub
```

## Claude Code Skills

```bash
/plugin marketplace add AvdLee/SwiftUI-Agent-Skill
/plugin install swiftui-expert@swiftui-expert-skill

/plugin marketplace add AvdLee/Swift-Concurrency-Agent-Skill
/plugin install swift-concurrency-expert@swift-concurrency-agent-skill

/plugin marketplace add AvdLee/Swift-Testing-Agent-Skill
/plugin install swift-testing-expert@swift-testing-agent-skill

/plugin marketplace add AvdLee/Core-Data-Agent-Skill
/plugin install core-data-expert@core-data-agent-skill
```

## Key Commands

| Command | Use |
|---------|-----|
| `/new-game [id] [theme]` | Scaffold a new game |
| `/validate-theme [id]` | Validate a ThemePackage JSON |
| `/balance-theme [id]` | Run economy simulation |
| `/check-engine` | Verify engine has no theme-specific code |
| `/add-level [game] [name]` | Add a level to any game |
| `/add-unit [game] [level] [name]` | Add a unit to any game |
