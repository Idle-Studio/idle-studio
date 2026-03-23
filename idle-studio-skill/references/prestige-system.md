# Prestige System Reference

## Overview

Prestige in Idle Civilizations means **advancing to the next historical era**. It resets buildings and resources but grants permanent Legacy Tokens that compound into a production multiplier — the core long-term progression hook.

---

## Triggering Prestige

**Condition:** Player has accumulated the required Gold for the target era.  
**Player action:** Taps "Advance Era" on the prestige screen.  
**Requirement:** Player must have seen the prestige preview screen (can't accidentally trigger).

### Advance Requirements

| From → To | Gold Required | Expected Session Count to Reach |
|-----------|--------------|-------------------------------|
| Stone Age → Bronze Age | 1,000 | 1–2 sessions |
| Bronze Age → Classical | 50,000 | 3–5 sessions |
| Classical → Medieval | 5,000,000 | 5–8 sessions |
| Medieval → Renaissance | 100,000,000 | 8–12 sessions |
| Renaissance → Industrial | 10,000,000,000 | 10–15 sessions |
| Industrial → Space Age | 1,000,000,000,000 | 15–20 sessions |
| Space Age → Future | 1,000,000,000,000,000 | 20–30 sessions |

Times assume **no IAP**. With subscription (+20% idle) these are ~15% faster.

---

## Legacy Token Formula

```
legacyTokensThisPrestige = floor( sqrt( totalGoldEarned / 1_000_000_000_000 ) )
```

`totalGoldEarned` is the **all-time cumulative gold**, NOT current gold.  
It never resets, so each prestige earns more tokens than the previous one.

### Token Earnings Table

| Total Gold Ever Earned | Legacy Tokens (this prestige) |
|------------------------|-------------------------------|
| 1T (1e12)              | 1                             |
| 4T                     | 2                             |
| 9T                     | 3                             |
| 100T                   | 10                            |
| 1,000T (1Qa)           | 31                            |
| 10,000T                | 100                           |
| 1e18 (1Qi)             | 1,000                         |

---

## Prestige Multiplier Formula

```
prestigeMultiplier = 1.02 ^ totalLegacyTokensEver
```

Each token adds exactly **2% compounding** production bonus — permanent, forever.

### Multiplier Table

| Total Tokens | Multiplier | Effective Bonus |
|-------------|-----------|-----------------|
| 0           | 1.000×    | +0%             |
| 10          | 1.219×    | +22%            |
| 25          | 1.641×    | +64%            |
| 50          | 2.692×    | +169%           |
| 100         | 7.245×    | +625%           |
| 200         | 52.49×    | +5,149%         |
| 500         | 19,905×   | massive         |

---

## What Resets vs. Persists

### Resets on Prestige
- All building counts → 0
- All current resources (Gold, Culture, Science, Faith, era resources) → 0
- Active timed boosts → cancelled
- Wonder construction in progress → cancelled (materials refunded in coins)
- Daily quest progress → cleared
- Current offline income accumulation → cleared

### Persists Through Prestige
- **Legacy Tokens** (accumulate forever, ever-increasing total)
- **Cosmetic era skins** (unlocked visuals stay unlocked)
- **Wonders** (visual presence stays; production bonus resets)
- **Achievements** (never reset)
- **Game Center leaderboard scores** (historical bests preserved)
- **Premium Coins** (never reset)
- **Subscription status** (never reset)
- **Alliance membership** (never reset)
- **Total Gold Ever Earned** counter (never reset — drives future token earnings)

---

## Prestige UX Flow

```
Player reaches Gold milestone
    ↓
"Advance Era" button pulses gold (attention signal)
    ↓
Player taps → Prestige Preview Screen:
    "You're about to enter the Bronze Age!"
    "Legacy Tokens you'll earn: +3"
    "New multiplier: 1.06× (was 1.04×)"
    "What resets: Buildings, Resources"
    "What keeps: Your tokens, skins, achievements"
    [  Cancel  ]  [  Advance Era! → ]
    ↓
Dramatic transition animation:
    1. Current era art zooms out
    2. Flash of era color
    3. New era art animates in with particle burst
    4. "Bronze Age Begins!" rises from center
    5. Token count ticks up (+3)
    6. Multiplier shows new value
    ↓
Notification permission request (ONLY on first-ever prestige):
    "Get notified when your next era is ready!"
    [Enable Notifications]  [Not now]
    ↓
Back to gameplay — new era, empty buildings, fresh start
```

---

## Infinite Prestige (Post-Future Era)

After reaching Future Civilization, players can "Grand Prestige" — resetting to Stone Age with all tokens preserved. This creates infinite replayability with ever-compounding multipliers. Each Grand Prestige cycle should take ~20% less time than the previous one (due to multiplier growth).

**Grand Prestige token bonus:** `+10 bonus Legacy Tokens` per Grand Prestige completed, rewarding long-term players.
