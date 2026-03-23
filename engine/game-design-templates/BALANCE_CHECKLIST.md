# Balance Checklist — New Theme Validation

Run this checklist for every new ThemePackage before shipping. The `/balance-theme [name]` command automates most of this, but you should understand the reasoning.

---

## 1. Level Count & Advance Requirements

**Target:** 4–8 levels. Each takes 5–30 sessions to advance (no IAP).

| Check | Rule | Your Value | Pass? |
|-------|------|-----------|-------|
| Level count | 4 minimum, 8 maximum | | |
| Level 1 advance | 500 – 5,000 Gold | | |
| Level 2 advance | 10× – 100× Level 1 | | |
| Level 3 advance | 10× – 100× Level 2 | | |
| Consistent growth | Each advance 10×–1000× previous | | |
| Final level advance | Reachable in 30 sessions from start | | |

**Adjustment levers:**
- Too fast → increase advance requirements OR reduce production
- Too slow → decrease advance requirements OR increase production

---

## 2. Unit Costs Within a Level

**Target:** Each unit should cost 5–10× more than the previous unit (at count=0).

For each level, list units in cost order and verify the ratio:

```
Level 1:
Unit 1 base cost: ________  
Unit 2 base cost: ________  ratio to prev: ____× (target: 5–10×)
Unit 3 base cost: ________  ratio to prev: ____× (target: 5–10×)
...

Level 2:
Unit 1 base cost: ________  
vs Level 1 last unit at count=100: ________  ratio: ____× (target: 0.001–0.01×)
```

The first unit of Level 2 should cost approximately **100× less** than the last unit of Level 1 at count=100. This is the "new era feels refreshing" check.

---

## 3. Unit Production Rates

**Target:** Each unit produces 5–8× more than the previous unit (at count=1).

| Unit | Rate at count=1 | Ratio to previous |
|------|-----------------|-------------------|
| | | |

**Upgrade tier check:**
At count=100 (all tiers active), production multiplier = 1.5 × 2.0 × 3.0 × 6.0 = 54×
- Does this feel significant? ✅
- Does it trivialise earlier units? (if yes → reduce later tier multipliers)

---

## 4. Time to First Manager

Manager threshold is typically 10 owned. Check how long it takes to buy 10 of the first unit:

```
Cost to buy 10 of Unit 1:
= baseCost × (1 + 1.15 + 1.15² + ... + 1.15⁹)
= baseCost × (1.15¹⁰ - 1) / (1.15 - 1)
≈ baseCost × 20.3

Starting production (0 units): 0 Gold/s (player must tap)
Tap rate estimate: ~2 taps/s × 10 Gold/tap = 20 Gold/s (tutorial)

Time estimate: (baseCost × 20.3) / 20 Gold/s = ___ seconds
```

**Target:** 2–8 minutes. If > 10 minutes → reduce Unit 1 base cost.

---

## 5. Level-Specific Resource Balance

**Target:** The secondary resource should accumulate naturally without feeling like a grind.

| Check | Rule | Your Value |
|-------|------|-----------|
| Buildings producing the resource | At least 1 per level | |
| Resource required for milestone | 50–75% of natural stockpile at that point | |
| Resource production rate | Enough to reach milestone while advancing | |

---

## 6. Milestone Balance

**Target:** Milestone achievable after owning ~25 of each unit in the level (mid-era).

| Milestone | Gold cost | Era resource cost | Construction time | Skip cost (coins) |
|-----------|-----------|-------------------|-------------------|-------------------|
| | | | | |

**Checks:**
- Gold cost: achievable when player has ~25 of most units? ✅/❌
- Construction time: 30 min – 12 hours? ✅/❌
- Skip cost: 100 coins per hour? ✅/❌
- `canSkipWithAd`: only true if construction < 3600 seconds? ✅/❌
- Bonus value: significant enough to feel earned? ✅/❌
- Bonus scope: `level` (resets on prestige) or `permanent` (rare, justified)? ✅/❌

---

## 7. Prestige Token Calibration

These numbers come from the engine formula. Verify they feel right for your theme:

```
After completing all N levels (reaching the end), cumulative Gold earned:
Expected totalGoldEarned ≈ ________

Legacy Tokens earned: floor(sqrt(totalGoldEarned / 1,000,000,000,000)) = ____
Prestige multiplier: 1.02^tokens = ____×
```

**Target after first full run:** 5–20 tokens (1.10× – 1.49× multiplier)
**Target after 10 full runs:** 50–200 tokens (2.7× – 52.5× multiplier)

If first-run tokens < 3: advance requirements may be too low (earning too little gold).  
If first-run tokens > 50: advance requirements may be too high (grinding too much).

---

## 8. Event Balance

| Event | Multiplier | Duration | Eligible from level | Pass? |
|-------|-----------|---------|---------------------|-------|
| | | | | |

**Checks:**
- No event multiplier > 6×? ✅/❌
- All events duration ≥ 24 hours? ✅/❌
- Weekly events achievable in 1 session per day? ✅/❌
- Seasonal events don't overlap? ✅/❌

---

## 9. Tone Consistency Check

Read all flavor text and copy out loud. Answer:

- Does the tone match the theme (playful/serious/educational)?
- Are all descriptions 1 sentence?
- Are notification strings < 100 characters?
- Does the `prestigeTitle` create genuine excitement?
- Is the `offlineSheet.title` warm and rewarding (not neutral)?
- Does the `notificationPermission.body` give clear, specific reasons to enable?

---

## 10. Final Validation

Run the automated check:
```
/validate-theme [game-name]
```

All checks must pass before the ThemePackage is considered shippable.

If any check fails, do not ship. Fix the issue and re-run validation.
