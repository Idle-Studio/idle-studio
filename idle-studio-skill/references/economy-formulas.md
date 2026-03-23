# Economy Formulas Reference

## Production Rate

```
productionRate = Σ(buildings) × globalMultiplier × prestigeMultiplier × activeBoost

Per building:
  buildingRate(n) = baseProductionPerSecond × n × upgradeMultiplier(n)

upgradeMultiplier(n):
  if n >= 100: ×5.0 (cumulative with lower tiers)
  if n >= 50:  ×2.0
  if n >= 25:  ×1.0 (i.e., +100% = 2× at this tier)
  if n >= 10:  ×0.5 (i.e., +50%)
  base:        ×1.0
  
  Combined: all applicable tiers multiply together
  Example at n=100: 1.5 × 2.0 × 2.0 × 5.0 = 30× base
```

## Building Cost

```
cost(n) = baseCost × costMultiplier^n
  where n = number currently owned

Bulk buy cost (buying qty from current n):
  totalCost = baseCost × (costMultiplier^(n+qty) - costMultiplier^n) / (costMultiplier - 1)
```

## Offline Income

```
offlineIncome = productionRate × min(secondsAway, 28800)
  where 28800 = 8 hours × 3600 seconds

Note: productionRate used is the rate AT TIME OF BACKGROUNDING
      (not retroactively updated if player would have bought buildings)

Doubled by rewarded ad: offlineIncome × 2 (one-time per return)
```

## Prestige / Legacy Tokens

```
legacyTokensEarned = floor( sqrt( totalGoldEarned / 1_000_000_000_000 ) )
prestigeMultiplier = 1.02 ^ totalLegacyTokens

Examples:
  1T total gold  → floor(sqrt(1))    = 1 token  → 1.02× multiplier
  4T total gold  → floor(sqrt(4))    = 2 tokens → 1.04× multiplier  
  100T total gold→ floor(sqrt(100))  = 10 tokens → 1.219× multiplier
  10,000T gold   → floor(sqrt(10000))= 100 tokens → 7.245× multiplier
```

## Resource Production per Era

Each era introduces additional resource types. Gold is universal.  
Era resources act as production multipliers for specific buildings.

```
effectiveGoldRate = goldRate × (1 + eraResourceBonus)

eraResourceBonus:
  culture: applies to cultural buildings (e.g. +1% per 10 culture stored)
  science: applies to research buildings
  faith:   applies to religious buildings
  era1/2:  defined per era in content.json
```

## Global Multiplier Sources

```
globalMultiplier = product of all active multipliers:
  - Wonder bonuses (each Wonder adds a multiplier, persists until prestige resets)
  - Active timed boosts (from rewarded ads, IAP)
  - Subscription bonus (+20% if Civ Pass active)
  - Alliance bonus (+5% per active alliance member, max +50%)
  - Daily quest completion bonus (24h, +25%)
```

## Number Formatting

```swift
// Abbreviation thresholds (display strings)
< 1_000               → "123"
< 1_000_000           → "1.23K"
< 1_000_000_000       → "1.23M"
< 1_000_000_000_000   → "1.23B"
< 1e15                → "1.23T"
< 1e18                → "1.23Qa"
< 1e21                → "1.23Qi"
< 1e24                → "1.23Sx"
< 1e27                → "1.23Sp"
< 1e30                → "1.23Oc"
>= 1e30               → scientific: "1.23e30"

Always: store full Decimal precision internally, only abbreviate for display
```

## Tick Rate

```
Foreground: 1 tick per second
Background: no ticking — offline income calculated on return

Tick budget: entire tick must complete in < 5ms
  - Economy calculation: O(buildings_count) ≈ 50 buildings max → fast
  - No I/O in tick — persistence batched every 30 seconds separately
```
