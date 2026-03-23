# Balance Guide

The definitive reference for tuning the Idle Civilizations economy. All new content must be validated against these targets. If a content PR fails balance checks, it must be revised before merging.

---

## Core Balance Philosophy

1. **Early game is fast and forgiving** — Stone Age to Classical should feel like rapid wins
2. **Mid-game adds depth** — Medieval to Industrial introduces resource dependencies and meaningful choices
3. **Late game rewards patience** — Space Age to Future rewards dedicated players with compounding multipliers
4. **Prestige should always feel worth it** — every reset must leave the player clearly stronger
5. **No era should feel like a wall** — if progress stalls for more than 2 sessions, it's a bug

---

## Era Progression Targets

### Time to Advance (sessions, no IAP)

| Era | Min Sessions | Target Sessions | Max Sessions |
|-----|-------------|----------------|-------------|
| Stone Age | 3 | 5 | 7 |
| Bronze Age | 7 | 10 | 14 |
| Classical Empire | 12 | 16 | 20 |
| Medieval Kingdom | 16 | 22 | 28 |
| Renaissance | 20 | 28 | 36 |
| Industrial Revolution | 26 | 36 | 45 |
| Space Age | 35 | 48 | 60 |

A "session" = 5–15 minutes of active play. If advance takes more than the maximum, the era needs tuning (reduce advance requirement or increase production).

### Subscription Impact
Civ Pass (+30% idle income) should reduce session count by approximately 20%, not more. It should feel like a quality-of-life improvement, not a skip button.

---

## Building Balance Rules

### Cost Curve Within Era

Building N should cost approximately **5–10× more** than Building N-1 (at count=0):

```
building[0] baseCost: X
building[1] baseCost: 5X–10X
building[2] baseCost: 50X–100X
...
building[N] baseCost: 5^N × X (approximately)
```

### Production Curve Within Era

At count=1, Building N should produce approximately **5–8× more** than Building N-1 at count=1:

```
building[0] rate: R
building[1] rate: 5R–8R
building[2] rate: 25R–64R
...
```

This ensures there's always a clear "best use of current gold" decision.

### Time to First Manager (Building N=0)

```
timeToManager = cost(0) + cost(1) + ... + cost(9)   ÷   currentProductionRate

Target: 3–8 minutes at typical advancement stage
```

If time to first manager > 10 minutes → reduce base cost of that building.  
If time to first manager < 90 seconds → increase base cost (too trivial to matter).

### Cross-Era Production Jump

When advancing to the next era, the **first building in the new era at count=1** should produce approximately **10× more** than the **last building in the previous era at count=100**:

```
newEra.building[0].rate(1) ≈ 10 × prevEra.building[N].rate(100)
```

This guarantees era advancement always feels rewarding ("wow, this is so much faster now").

---

## Cost Multiplier Guidelines

| Multiplier | When to use |
|-----------|-------------|
| 1.15 | Standard buildings — good baseline, provides clear cost growth |
| 1.13–1.14 | Mid-tier buildings needing a slightly slower cost ramp |
| 1.10–1.12 | Resource-dependent buildings (need to buy other buildings first) |
| 1.08–1.10 | Final/mega buildings in an era (expensive but not oppressive) |

**Never go above 1.18** — cost growth becomes too steep, players feel locked out.  
**Never go below 1.07** — cost growth is too flat, building spam trivialises the economy.

---

## Prestige Balance Targets

### Legacy Token Earnings Per Run

| Prestige # | Expected Tokens | Cumulative | Expected Multiplier |
|-----------|----------------|-----------|---------------------|
| 1st (Stone → Bronze) | 0–1 | 0–1 | 1.00–1.02× |
| 2nd (reach Classical) | 1–3 | 1–4 | 1.02–1.08× |
| 3rd (reach Medieval) | 3–8 | 4–12 | 1.08–1.27× |
| 5th run | 8–20 | 20–40 | 1.49–2.21× |
| 10th run | 25–50 | 100–200 | 7.2–52.5× |
| 20th run | 80–150 | 500+ | massive |

The multiplier should feel meaningful by the 3rd prestige and transformative by the 10th.

### "Should I Prestige Now?" Heuristic
A player should feel the pull to prestige when:
1. They're within 20% of the advance requirement (almost there)
2. Their production rate is growing slowly (bottleneck hit)
3. They've completed the current era's Wonder(s)

The game should surface this nudge via a pulsing "Advance Era" button when within 20% of the requirement.

---

## Wonder Balance Rules

### Cost vs. Era Stage

Wonder cost should be reachable after the player has the **mid-era buildings unlocked** — not at the very beginning or the very end:

```
Wonder reachable when player owns: ≈ 25 of each building in the era
Target: builds the Wonder about 40% through the era progression
```

### Construction Time vs. Bonus

| Construction Time | Minimum Bonus | Maximum Bonus |
|-----------------|--------------|--------------|
| 30 min | +50% | +100% |
| 1–2 hours | +75% | +150% |
| 3–5 hours | +100% | +250% |
| 6–8 hours | +150% | +350% |
| 10–12 hours | +200% | +500% |

Longer build = bigger bonus. Players must feel the wait was worth it.

### Skip Cost Calibration
- Rewarded Ad skip: only for Wonders ≤ 1 hour
- Coin skip: 100 Coins per hour of remaining time
- At max (20h Wonder): 2,000 Coins — achievable with the coins30000 pack (€19.99 covers 15 ISS skips)

### Offline Multiplier Progression

Era capstone upgrades provide stacking offline income bonuses. The progression is:

| Era Capstone Upgrade | offlineMultiplier |
|---------------------|------------------|
| Bronze Age — Warlord's Army | ×1.25 |
| Ancient Empires — Golden Age | ×1.25 |
| Classical World — Divine Mandate | ×1.50 |
| Medieval Era — Sacred Relic | ×1.50 |
| Renaissance — Scientific Revolution | ×1.75 |
| Industrial Revolution — Industrial Empire | ×2.0 |
| Space Age — Space Economy | ×2.5 |

These multipliers stack multiplicatively with the Civ Pass subscription (+30% idle income).
A fully upgraded Space Age player with Civ Pass: **2.5 × 1.30 = ×3.25 offline rate** — clears the Space Age advance requirement in a single 8h offline session as a reward for dedication.

---

## Resource Balance Rules

### Era Resource Accumulation Targets

Era resources should accumulate passively and be plentiful enough to not feel scarce:

| Era Resource | Buildings that produce it | Target stock at era mid-point |
|-------------|--------------------------|------------------------------|
| Population | Berry Bush | 500 |
| Bronze | Bronze Mine | 2,000 |
| Food | Grain Farm | 5,000 |
| Culture | Temple, Cave Painting | 10,000 |
| Faith | Church | 5,000 |
| Science | University, Observatory | 20,000 |

If these targets aren't met with normal building progression → increase production rate of the generating buildings.

### Resource Sink Balance (Wonders)

Wonder resource costs should consume approximately **50–75%** of the player's stockpile at the target moment. If it consumes < 30%, the resource has no strategic weight. If it requires more than the player has accumulated naturally, it's a wall.

---

## Event Balance Rules

- Event multiplier maximum: **6×** (higher breaks offline income calculations)
- Event duration minimum: **24 hours** (must be reachable for players with 1 session/day)
- Leaderboard reward distribution: top 25% get something, top 1% get exclusive
- Event bonuses must **not** carry over after the event ends
- Permanent event rewards (badges, skins) must **not** provide production advantages

---

## A/B Test Candidates

These values should be validated with real player data and A/B tested:

| Parameter | Default | Test Range |
|-----------|---------|-----------|
| Offline cap | 8 hours | 6h, 12h |
| Stone Age advance req | 1,000 | 750, 1,500 |
| First interstitial delay | 20 min | 15 min, 30 min |
| Rewarded ad offer: offline doubler | Shown every return | Only shown if > 2h away |
| Legacy token formula divisor | 1,000,000,000,000 | 500B, 2T |

All A/B tests run via Firebase Remote Config. No App Store update required to adjust these values.
