# /validate-theme Command

## Purpose
Validate a ThemePackage JSON against the engine contract. Must pass before any game ships.

## Usage
```
/validate-theme [game-id]
```

## What This Command Does

1. **Load:**
   - `games/[game-id]/[game-id].json`
   - `engine/docs/THEME_PACKAGE.md` → validation rules
   - `engine/game-design-templates/BALANCE_CHECKLIST.md`

2. **Run all validation checks** (grouped by severity):

### 🔴 Critical (blocks shipping)
- `schemaVersion` matches engine version
- `gameID` is present and kebab-case
- `bundleID` follows reverse-domain format
- Level `order` is sequential 1, 2, 3... no gaps
- Each level has ≥ 3 units and ≤ 10 units
- Each level has ≥ 1 milestone
- Each unit has all 4 upgrade tiers (at 10, 25, 50, 100)
- All `costMultiplier` values between 1.07 and 1.20
- All required `copy` keys present and non-empty
- All required IAP product IDs present
- All leaderboard IDs present
- All `levelColors` entries present (one per level)
- No notification string > 100 characters

### 🟡 Warning (should fix before shipping)
- Any unit without a description
- Any character without a quote
- Any event multiplier > 5× (< 6× is technically valid, > 5× is risky)
- Any milestone construction time < 1800s (30 min) — may feel trivial
- Level count < 5 — short game, may have retention issues
- `levelResources` missing for any level after Level 1

### 🟢 Info (nice to fix, not blocking)
- Any unit `iconAsset` name not following `unit_[id]` convention
- Any milestone `artworkAsset` name not following `milestone_[id]` convention
- Copy strings that contain `REPLACE` (unfilled template placeholder)
- `gameID` matches folder name? (consistency check)

3. **Run balance simulation:**
   - Estimate sessions to advance each level (using economy formulas)
   - Flag any level taking > 35 sessions or < 3 sessions
   - Check prestige token earnings after a full run
   - Report milestone achievability timing

## Output Format

```
## Validation Report: [Game Display Name]

### 🔴 Critical Issues (must fix)
[none] ✅  OR  list of issues with exact JSON paths

### 🟡 Warnings (should fix)
[none] ✅  OR  list of warnings

### 🟢 Info
[list of minor suggestions]

### Balance Simulation
| Level | Est. Sessions | Status |
|-------|--------------|--------|
| Level 1 | ~5 sessions | ✅ |
| Level 2 | ~10 sessions | ✅ |
| Level 3 | ~45 sessions | ❌ Too slow |

### Prestige Token Estimate
After completing all levels (first run): ~[N] tokens → [X.XX]× multiplier
Status: ✅ In target range (5–20 tokens)

### Overall Status
✅ READY TO SHIP  /  ⚠️ WARNINGS ONLY (review before shipping)  /  ❌ CRITICAL ISSUES (must fix)
```
