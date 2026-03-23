# /balance-theme Command

## Purpose
Run a full economy simulation for any game's ThemePackage JSON and produce a balance health report with specific fix recommendations.

## Usage
```
/balance-theme [game-id]
```

Examples:
```
/balance-theme idle-civilizations
/balance-theme idle-restaurant-empire
/balance-theme idle-science-lab
```

## What This Command Does

1. **Load references:**
   - `games/[game-id]/[game-id].json` — the ThemePackage to simulate
   - `idle-studio-skill/references/economy-formulas.md`
   - `idle-studio-skill/references/prestige-system.md`
   - `engine/game-design-templates/BALANCE_CHECKLIST.md`
   - Balance agent: `.claude/agents/balance-agent.md`

2. **Simulate each level** using the balance agent's methodology:
   - Time to first manager (first unit at threshold)
   - Estimated sessions to advance
   - Cross-level transition affordability check

3. **Simulate prestige curve** across 10 runs:
   - Cumulative gold earned per run
   - Legacy tokens earned
   - Multiplier growth
   - Speed improvement run-over-run

4. **Check all balance rules** from `BALANCE_CHECKLIST.md`

5. **Produce specific fix recommendations** as JSON diffs — not vague advice

## Output Format

```
## Balance Report: [Game Display Name]
Generated: [timestamp]

### Level Progression
| Level | Units | T(manager) | Sessions | Cross-Level | Status |
|-------|-------|-----------|---------|------------|--------|
| Street Food Cart | 4 | 3 min | ~5 ✅ | — | ✅ |
| Bistro | 5 | 5 min | ~9 ✅ | 45s ✅ | ✅ |
| Trattoria | 5 | 7 min | ~38 ❌ | 2 min ⚠️ | ❌ |

### Prestige Curve (10 simulated runs)
| Run | Sessions | Gold Earned | Tokens | Multiplier | Δ vs prev |
|-----|---------|------------|--------|-----------|-----------|
| 1 | 52 | 45T | 6 | 1.13× | — |
| 2 | 44 | 45T | 6 | 1.13× | -15% ✅ |
| 5 | 28 | 45T | 6 | 1.13× | -10% ✅ |
| 10 | 18 | 45T | 6 | 1.13× | -9% ✅ |

### Critical Issues
❌ Level 3 (Trattoria): ~38 sessions — exceeds maximum of 30
   → Cause: Unit 5 (Pizza Oven) production rate too low, advance requirement too high

### Recommended JSON Changes
Apply these specific changes to `games/idle-restaurant-empire/idle-restaurant-empire.json`:

\`\`\`json
// levels[2].advanceRequirement
"advanceRequirement": { "gold": 2000000 }   // was: 5000000

// levels[2].units[4].baseProductionPerSecond  
"baseProductionPerSecond": { "gold": 120 }  // was: 40
\`\`\`

### After Changes (projected)
Level 3 (Trattoria): ~13 sessions ✅
All levels: within 5–30 session target ✅

### Overall Status
⚠️ NEEDS TUNING — apply recommended changes and re-run
```
