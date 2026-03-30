# Idle Restaurant Empire — Balance Guide

## Design Philosophy

Food is immediate. Unlike history (Civilizations), restaurant experiences are fast, visceral, and emotionally immediate. The balance reflects this: progression is faster, the first session should reach Level 2 comfortably, and Michelin Stars are achievable in single multi-session streaks.

---

## Level Advance Requirements

| Level | Name | Advance Req (Gold) | Approx sessions (no IAP) |
|-------|------|--------------------|--------------------------|
| 1 | Street Food Cart | 3,000 | 1 |
| 2 | French Bistro | 150,000 | 1–2 |
| 3 | Italian Trattoria | 8,000,000 | 2–3 |
| 4 | Dim Sum Palace | 500,000,000 | 3–4 |
| 5 | Sushi Bar | 30,000,000,000 | 4–5 |
| 6 | Fusion Kitchen | 2,000,000,000,000 | 5–7 |
| 7 | Michelin Fine Dining | 100,000,000,000,000 | 6–8 |
| 8 | Global Empire | 5,000,000,000,000,000 | 8–10 |

Each level is ~50× the previous advance requirement — faster than Civilizations (100×) to match the faster-paced food theme.

---

## Unit Cost Ratios (within level)

Each consecutive unit costs ~6× more than the previous (range: 5–8×). This creates a natural "unlock" feeling as players accumulate gold.

**Example — Level 1:**
- Street Cart: 10 Gold
- Taco Stand: 60 Gold (6×)
- Noodle Stall: 360 Gold (6×)
- Dumpling Cart: 2,160 Gold (6×)
- Waffle Truck: 12,960 Gold (6×)

---

## Production Rate Formula

`baseProductionPerSecond = baseCost × 0.01`

Break-even at 100 seconds per unit (buy 1 unit, it pays for itself in ~100s). This is consistent across all levels and creates a predictable upgrade loop.

---

## costMultiplier Progression

costMultiplier decreases slightly at higher levels to keep late-game purchases feeling achievable despite the enormous numbers:

| Levels | costMultiplier |
|--------|---------------|
| 1–2 | 1.15 / 1.13 |
| 3–4 | 1.12 |
| 5–6 | 1.12 / 1.11 |
| 7–8 | 1.11 / 1.10 |

---

## Manager Thresholds

- **Early units per level (units 1–3):** threshold 10 — fast automation, rewarding quick play
- **Anchor units per level (units 4–6):** threshold 25 — requires commitment, sustains engagement

---

## Upgrade Tiers (all units)

| Count | Multiplier | Cumulative |
|-------|-----------|-----------|
| 10 | 1.5× | 1.5× |
| 25 | 2.0× | 3.0× |
| 50 | 3.0× | 9.0× |
| 100 | 6.0× | 54× |

At 100 units, production is 54× the base rate. This is the key scaling lever.

---

## Secondary Resource Timing

Secondary resources start producing from unit 3 or 4 in each level:

| Level | Secondary | First unit producing it | Rate |
|-------|-----------|------------------------|------|
| Street Food Cart | foot_traffic | Noodle Stall (#3) | 0.01/s |
| French Bistro | wine | Wine Cellar (#3) | 0.05/s |
| Italian Trattoria | olive_oil | Olive Press (#3) | 0.1/s |
| Dim Sum Palace | tea | Tea House (#3) | 0.1/s |
| Sushi Bar | fresh_fish | Tsukiji Contract (#3) | 0.1/s |
| Fusion Kitchen | creativity | Molecular Station (#3) | 0.1/s |
| Michelin Fine Dining | prestige | Cheese Cave (#3) | 0.1/s |
| Global Empire | fame | Culinary Academy (#3) | 0.1/s |

This keeps Level entry simple (gold-only for first 2 purchases) before secondary resource management begins.

---

## Michelin Star Construction Times

| Level | Star | Construction | Skip Cost |
|-------|------|-------------|-----------|
| 1 | Yelp Favorite | 30 min | 30 coins |
| 1 | Local Legend | 1 hr | 60 coins |
| 2 | Bib Gourmand | 1 hr | 60 coins |
| 2 | First Michelin Star | 2 hr | 120 coins |
| 3 | DOP Certification | 1.5 hr | 90 coins |
| 3 | Slow Food Designation | 3 hr | 180 coins |
| 4 | Sunday Yum Cha | 2 hr | 120 coins |
| 4 | Imperial Court Approval | 4 hr | 240 coins |
| 5 | Freshness Certificate | 3 hr | 180 coins |
| 5 | Omakase Institution | 5 hr | 300 coins |
| 6 | Culinary Innovation Award | 4 hr | 240 coins |
| 6 | World's 50 Best Entry | 6 hr | 360 coins |
| 7 | Second Michelin Star | 5 hr | 300 coins |
| 7 | Third Michelin Star | 8 hr | 480 coins |
| 8 | Global Brand Recognition | 6 hr | 360 coins |
| 8 | Culinary World Heritage | 8 hr | 480 coins (**permanent bonus**) |

Skip cost formula: `1 coin per minute of construction`

---

## Prestige Calibration

First complete run (all 8 levels): ~15–30 Legacy Tokens → 1.34×–1.81× multiplier
After 10 runs: ~100–200 tokens → 7.24×–52.5× multiplier

The global_empire final milestone (`culinary_world_heritage`) gives a permanent 3× global gold multiplier — this incentivises completing the final level before prestige and makes each prestige run more satisfying.

---

## Event Balance

All event bonuses capped at 4× (engine limit). No event modifies gold directly unless eligibleFromLevelOrder ≥ 4.

| Event | Bonus | Cap |
|-------|-------|-----|
| Street Food Festival | 3× foot_traffic | ✓ |
| Harvest Week | 3× olive_oil, 2× wine | ✓ |
| Critics' Table | 4× fresh_fish | ✓ (at limit) |
| Lunar New Year Banquet | 4× tea, 2× gold | ✓ |
| World Restaurant Awards | 4× prestige, 3× gold | ✓ (gold at limit) |

---

## Known Tuning Points

If playtesting reveals issues, adjust here first:

1. **Level 1 too fast** → Raise advance req from 3,000 → 5,000
2. **Level 3 feels slow** → Lower advance req by 20% (6.4M instead of 8M)
3. **Secondary resources accumulate too fast** → Halve production rates on secondary-producing units
4. **Stars feel unachievable** → Reduce requirements by 30% before raising construction times
5. **Late game (7–8) drags** → Reduce advance req ratio from 50× to 30× for levels 7 and 8
