# Eras — Master Index

All historical eras in Idle Civilizations, in progression order.

| # | Era ID | Name | Advance Req. | File |
|---|--------|------|-------------|------|
| 1 | `stone_age` | Stone Age | 1,000 Gold | [stone-age.md](stone-age.md) |
| 2 | `bronze_age` | Bronze Age | 50,000 Gold | [bronze-age.md](bronze-age.md) |
| 3 | `classical_empire` | Classical Empire | 5,000,000 Gold | [classical-empire.md](classical-empire.md) |
| 4 | `medieval_kingdom` | Medieval Kingdom | 100,000,000 Gold | [medieval-kingdom.md](medieval-kingdom.md) |
| 5 | `renaissance` | Renaissance | 10,000,000,000 Gold | [renaissance.md](renaissance.md) |
| 6 | `industrial_revolution` | Industrial Revolution | 1,000,000,000,000 Gold | [industrial-revolution.md](industrial-revolution.md) |
| 7 | `space_age` | Space Age | 1,000,000,000,000,000 Gold | [space-age.md](space-age.md) |
| 8 | `future_civilization` | Future Civilization | Grand Prestige endpoint | [future-civilization.md](future-civilization.md) |

## Advance Requirement Rationale

Each era requires ~50–100× more Gold than the previous:

```
Stone Age:        1,000      (1K)
Bronze Age:       50,000     (50K)     ×50
Classical:        5,000,000  (5M)      ×100
Medieval:         100,000,000 (100M)   ×20
Renaissance:      10,000,000,000 (10B) ×100
Industrial:       1,000,000,000,000 (1T) ×100
Space Age:        1,000,000,000,000,000 (1Qa) ×1000
Future:           Grand Prestige (infinite loop begins)
```

The Medieval era has a smaller jump (×20) to provide a "breather" mid-game and reward players coming off the prestige high of leaving Classical.

## Era Color System

Each era has a primary color that tints the entire UI while active. All colors pass 4.5:1 contrast on `#0D0D0F` background.

| Era | Primary Color | Mood |
|-----|-------------|------|
| Stone Age | `#8B7355` | Warm earth, primitive |
| Bronze Age | `#CD7F32` | Metallic bronze, emerging power |
| Classical | `#C9A84C` | Gold and marble, empire |
| Medieval | `#4A7358` | Forest green, fortified |
| Renaissance | `#8B2635` | Rich red, artistic passion |
| Industrial | `#607D8B` | Steel blue-grey, machinery |
| Space Age | `#1565C0` | Deep space blue, exploration |
| Future | `#6200EA` | Electric purple, transcendence |

## Era Unlock Flow

```
Player reaches Gold threshold
    → "Advance Era" button pulses and glows in era's primary color
    → Player taps → Prestige Preview Screen shown
    → Player confirms → Era transition animation plays
    → New era UI color palette fades in
    → Buildings list resets, new buildings available
    → Notification permission asked (first advance only)
```

## Era-Specific Resources

| Era | Extra Resource 1 | Extra Resource 2 | Purpose |
|-----|-----------------|-----------------|---------|
| Stone Age | Population | — | Unlocks certain buildings at population milestones |
| Bronze Age | Bronze | Food | Bronze required for Wonder; Food boosts some buildings |
| Classical | Culture | Trade | Culture unlocks cosmetics; Trade boosts economy |
| Medieval | Faith | Iron | Faith boosts religious buildings; Iron for military/Wonder |
| Renaissance | Art | Knowledge | Art for cosmetics; Knowledge speeds upgrades |
| Industrial | Coal | Steam | Coal fuels Steam Engine; Steam is core multiplier |
| Space Age | Science | Energy | Science unlocks upgrades; Energy required for late buildings |
| Future | Data | Nanobots | Both are late-game multipliers with no cap |
