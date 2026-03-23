# Wonders of the World

All available Wonders in Idle Civilizations. Each Wonder is a significant achievement that provides a permanent era-scoped production bonus and remains visually on the world map after prestige.

## Design Rules

- Each era has **1–2 Wonders** available
- Wonder costs are achievable but require focused effort (not just passive waiting)
- Construction times between **30 minutes and 20 hours** (no instant completion)
- Short Wonders (< 2h): skippable with Rewarded Ad OR Premium Coins
- Long Wonders (≥ 2h): skippable with Premium Coins only (too valuable for free skip)
- Skip coin cost: **100 Coins per hour** of remaining time
- Bonuses apply to the current era only and reset on prestige (visual persists)
- The bonus is a **multiplicative** modifier on top of all other multipliers

---

## Wonder Catalogue

### Stone Age

#### Lascaux Cave
**ID:** `lascaux_cave`  
**Era:** Stone Age  
**Icon:** `wonder_lascaux`

| Stat | Value |
|------|-------|
| Gold cost | 500 |
| Culture cost | 50 |
| Construction time | 30 minutes |
| Can skip with | Rewarded Ad or 50 Coins |
| Production bonus | +75% all Stone Age buildings |
| Bonus scope | Stone Age only |

> *"Art is the first language of civilization."*

---

### Bronze Age

#### Pyramid of Giza
**ID:** `pyramid_of_giza`  
**Era:** Bronze Age  
**Icon:** `wonder_pyramid_giza`

| Stat | Value |
|------|-------|
| Gold cost | 10,000 |
| Bronze cost | 500 |
| Construction time | 2 hours |
| Can skip with | 200 Coins |
| Production bonus | +100% Gold production |
| Secondary bonus | +30% all resources |
| Bonus scope | Bronze Age only |

> *"A monument to ambition. And a lot of sand."*

---

### Classical Empire

#### Roman Colosseum
**ID:** `roman_colosseum`  
**Era:** Classical Empire  
**Icon:** `wonder_colosseum`

| Stat | Value |
|------|-------|
| Gold cost | 500,000 |
| Culture cost | 1,000 |
| Construction time | 3 hours |
| Can skip with | 300 Coins |
| Production bonus | +150% Culture-producing buildings |
| Secondary bonus | +50% all Classical buildings |
| Bonus scope | Classical Empire only |

> *"Nothing unites a civilization like watching people fight lions."*

---

### Medieval Kingdom

#### Notre-Dame Cathedral
**ID:** `notre_dame`  
**Era:** Medieval Kingdom  
**Icon:** `wonder_notre_dame`

| Stat | Value |
|------|-------|
| Gold cost | 5,000,000 |
| Faith cost | 5,000 |
| Construction time | 6 hours |
| Can skip with | 600 Coins |
| Production bonus | +200% Faith-producing buildings |
| Secondary bonus | +75% all Medieval buildings |
| Bonus scope | Medieval Kingdom only |

> *"It took 200 years to build. You get to watch it happen in 6 hours. Progress."*

#### Great Wall of China
**ID:** `great_wall`  
**Era:** Medieval Kingdom  
**Icon:** `wonder_great_wall`

| Stat | Value |
|------|-------|
| Gold cost | 10,000,000 |
| Iron cost | 2,000 |
| Construction time | 5 hours |
| Can skip with | 500 Coins |
| Production bonus | +100% all Medieval Gold production |
| Secondary bonus | +2% per Legacy Token (bonus stacks permanently) |
| Bonus scope | Medieval Kingdom (token bonus is permanent) |

> *"Keeps out barbarians. Very effective against imaginary threats too."*

**Special:** The Great Wall has a unique mechanic — its token bonus is **permanent** (not reset on prestige). This makes it a priority wonder for prestige-focused players.

---

### Renaissance

#### Sistine Chapel
**ID:** `sistine_chapel`  
**Era:** Renaissance  
**Icon:** `wonder_sistine_chapel`

| Stat | Value |
|------|-------|
| Gold cost | 500,000,000 |
| Art cost | 50,000 |
| Construction time | 10 hours |
| Can skip with | 1,000 Coins |
| Production bonus | +250% Art production |
| Secondary bonus | +100% all Renaissance buildings |
| Bonus scope | Renaissance only |

> *"Michelangelo spent 4 years on his back painting this. You spent 10 hours idle. Different approaches."*

---

### Industrial Revolution

#### Eiffel Tower
**ID:** `eiffel_tower`  
**Era:** Industrial Revolution  
**Icon:** `wonder_eiffel_tower`

| Stat | Value |
|------|-------|
| Gold cost | 10,000,000,000 |
| Steam cost | 10,000 |
| Construction time | 14 hours |
| Can skip with | 1,400 Coins |
| Production bonus | +200% all Industrial buildings |
| Secondary bonus | +50% offline income (permanent) |
| Bonus scope | Industrial buildings + permanent offline bonus |

> *"Originally considered an eyesore. Now everyone loves it. Marketing is powerful."*

**Special:** The +50% offline income bonus is **permanent** — it stays even after prestige. This makes the Eiffel Tower the highest-priority Wonder in the entire game for returning players.

---

### Space Age

#### International Space Station
**ID:** `intl_space_station`  
**Era:** Space Age  
**Icon:** `wonder_iss`

| Stat | Value |
|------|-------|
| Gold cost | 1,000,000,000,000,000 (1Qa) |
| Science cost | 1,000,000 |
| Energy cost | 500,000 |
| Construction time | 20 hours |
| Can skip with | 2,000 Coins |
| Production bonus | +300% all Space Age buildings |
| Secondary bonus | +100% Science and Energy production |
| Special bonus | Reduces next prestige advance requirement by 25% |
| Bonus scope | Space Age + prestige modifier |

> *"Built by 15 countries. Powered by science. Funded by the question 'what if we tried really hard?'"*

---

## Wonder Priority Guide (for players)

| Wonder | Priority | Why |
|--------|---------|-----|
| Eiffel Tower | 🔴 Highest | Permanent +50% offline income — affects all future play (14h build = highest skip value) |
| Great Wall | 🔴 Highest | Permanent token bonus — compounds forever |
| Lascaux Cave | 🟡 High | Fast Stone Age bonus — first prestige rush |
| Pyramid of Giza | 🟡 High | Bronze Age is the first real multiplier test |
| All others | 🟢 Standard | Strong era bonuses, worth building each run |

---

## Wonder Construction UX

When player taps "Build Wonder":
1. Show confirmation with cost breakdown + construction time
2. Deduct resources immediately
3. Wonder appears as "Under Construction" on world map (animated building scene)
4. Local notification scheduled for completion
5. On completion: Wonder reveal animation (short cinematic, 3–5 seconds)
6. Production bonus applied immediately
7. Wonder art persists on world map for all future runs (cosmetic)
