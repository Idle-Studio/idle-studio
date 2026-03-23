# Idle Civilizations — Game Context

**Game #1 in the Idle Studio portfolio.**
Theme: Human history from Stone Age to Space Age across 8 eras.
Status: ThemePackage authored — ready for art and App Store configuration.

## Important: Read Studio Context First

Before working on this game, read:
1. `../../CLAUDE.md` — studio-level context (engine/theme split, development phases)
2. `../../Packages/IdleEngine/Sources/IdleEngine/Theme/ThemeValidator.swift` — validation rules

---

## Vocabulary

| Engine Term | Civilizations Term |
|-------------|-------------------|
| level | Era |
| unit | Building |
| milestone | Wonder |
| character | Leader |
| advance verb | "Advance Era" |
| prestige title | "Found New Empire" |
| premium pass | "Civ Pass" |

---

## Era Progression

| Order | Era | Advance Req (Gold) | Secondary Resource |
|-------|-----|-------------------|--------------------|
| 1 | Stone Age | 3,000,000 | — |
| 2 | Bronze Age | 500,000,000 | bronze |
| 3 | Ancient Empires | 50,000,000,000 | culture |
| 4 | Classical World | 8,000,000,000,000 | faith |
| 5 | Medieval Era | 250,000,000,000,000 | faith |
| 6 | Renaissance | 7,000,000,000,000,000 | science |
| 7 | Industrial Revolution | 260,000,000,000,000,000 | coal |
| 8 | Space Age | 8,000,000,000,000,000,000 | energy |

---

## Leaders

| ID | Era | Key Bonus |
|----|-----|-----------|
| og_the_elder | stone_age | campfire ×1.10 |
| hammurabi | bronze_age | marketplace ×1.20, mine ×1.15 |
| julius_caesar | classical_world | roman_legions ×1.25, forum ×1.15 |
| da_vinci | renaissance | da_vinci_workshop ×1.30, art_studio ×1.15 |
| nikola_tesla | industrial_revolution | power_station ×1.25, steam_engine ×1.15 |

---

## Wonders

| ID | Era | Build Time | Permanent? |
|----|-----|-----------|-----------|
| lascaux_cave | stone_age | 30 min | No |
| stonehenge | bronze_age | 1 hr | No |
| great_library | ancient_empires | 2 hr | No |
| parthenon | classical_world | 4 hr | No |
| notre_dame | medieval_era | 6 hr | No |
| sistine_chapel | renaissance | 10 hr | No |
| crystal_palace | industrial_revolution | 14 hr | No |
| international_space_station | space_age | 20 hr | **Yes** — ×2 global gold |

---

## ThemePackage File

`idle-civilizations.json` — fully authored and ready for validation.

Run `/validate-theme idle-civilizations` to check all engine constraints.
Run `/balance-theme idle-civilizations` to simulate economy.

## Art

All required assets listed in `docs/design/ART_BRIEF.md`.
Total: 66 images (8 era scenes, 8 wonder art, 40 unit icons, 5 leader portraits, 1 app icon).

## Historical Accuracy Rules

- Building names and descriptions should be historically grounded
- Flavor text may be playfully anachronistic but never factually wrong about major events
- Leaders are real historical figures
- Wonder names use their real-world names
- Content tone: lightly humorous — Rome is grand AND a punchline
