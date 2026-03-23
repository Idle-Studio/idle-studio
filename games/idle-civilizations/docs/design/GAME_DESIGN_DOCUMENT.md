# Game Design Document — Idle Civilizations

## Game Concept
Idle Civilizations is an incremental idle game where players build humanity's history from the Stone Age to a Future Civilization. Players purchase and upgrade historically-inspired buildings, earn resources automatically, and advance through eras to unlock new content.

---

## Core Loop

```
Tap → Earn Gold
Buy buildings → Earn Gold automatically
Upgrade buildings → Earn faster
Hire managers → Buildings run without tapping
Save up → Advance Era (Prestige)
Prestige → Legacy Tokens → Permanent multiplier
Return daily → Collect offline income
```

### Session Design
- **30-second session**: Collect offline income, watch rewarded ad to double it, do one daily quest
- **5-minute session**: Buy several buildings, advance toward next Wonder
- **20-minute session**: Full era optimisation, prestige sequence, event participation
- **Background**: Game earns automatically, notifications bring you back

---

## Resource System

### Global Resources (exist in all eras)
| Resource | Icon | Purpose |
|----------|------|---------|
| Gold | 🪙 | Primary currency, all purchases |
| Legacy Tokens | ⚗️ | Earned on prestige, permanent multiplier |
| Premium Coins | 💎 | IAP currency, cosmetics, skip waits |

### Era Resources (unlocked per era)
| Era | Era Resources |
|-----|--------------|
| Stone Age | Population |
| Bronze Age | Bronze, Food |
| Classical | Culture, Trade |
| Medieval | Faith, Iron |
| Renaissance | Art, Knowledge |
| Industrial | Coal, Steam |
| Space Age | Science, Energy |
| Future | Data, Nanobots |

### Resource Interactions
- Era resources boost Gold production of certain buildings
- Culture unlocks cosmetic Wonders
- Science speeds up building upgrades
- Faith gives bonus production during events

---

## Building System

### Cost Formula
```
cost(n) = baseCost × costMultiplier^n
```
Where `n` = number already owned. costMultiplier is typically 1.15 (exponential growth).

### Production Formula
```
production(n) = baseProduction × n × (1 + upgradeBonus)
             × eraMultiplier × prestigeMultiplier × activeBoost
```

### Manager System
- First 10 of each building run automatically when bought at 10, 25, 50, 100...
- Manager = building runs idle with no tapping required
- Milestone counts trigger animations and bonuses

### Building Upgrade Tiers
Each building has 4 upgrade tiers (unlocked at 10, 25, 50, 100 owned):
- Tier 1 (10): +50% production
- Tier 2 (25): +100% production  
- Tier 3 (50): +200% production
- Tier 4 (100): +500% production

---

## Era Design

### Stone Age
- **Flavor**: "The dawn of humanity. Every spark of fire is a miracle."
- **Primary Color**: #8B7355 (warm brown)
- **Resources**: Gold, Population
- **Buildings**:
  1. Campfire (base: 0.1 Gold/s)
  2. Hunting Ground (base: 0.5 Gold/s)
  3. Berry Bush (base: 2 Gold/s)
  4. Cave Painting (bonus: Culture)
  5. Flint Workshop (base: 10 Gold/s)
- **Wonder**: Lascaux Cave (requires 1,000 Culture, +50% all production for era)
- **Advance Requirement**: 1,000 Gold

### Bronze Age
- **Flavor**: "From stone to metal — humanity begins to build empires."
- **Primary Color**: #CD7F32 (bronze)
- **Resources**: Gold, Bronze, Food
- **Buildings**:
  1. Grain Farm (base: 5 Gold/s)
  2. Bronze Mine (produces Bronze)
  3. Pottery Workshop (base: 20 Gold/s)
  4. Trading Post (bonus from Trade)
  5. Bronze Forge (base: 80 Gold/s)
  6. River Port (base: 300 Gold/s)
- **Wonder**: Pyramid of Giza (requires 10K Gold + 500 Bronze)
- **Advance Requirement**: 50,000 Gold

### Classical Empire
- **Flavor**: "Rome wasn't built in a day. Yours might be."
- **Primary Color**: #C9A84C (gold/marble)
- **Resources**: Gold, Culture, Trade
- **Buildings**:
  1. Forum (base: 500 Gold/s)
  2. Aqueduct (bonus to all production)
  3. Temple (produces Culture)
  4. Colosseum (massive Culture, attracts tourists)
  5. Senate (unlocks policies)
  6. Trade Route (produces Trade Gold)
  7. Legion (military bonus to production)
- **Wonder**: Colosseum (requires 500K Gold + 1K Culture)
- **Advance Requirement**: 5,000,000 Gold

### Medieval Kingdom
- **Flavor**: "Castles, cathedrals, and the Black Death. Mostly castles."
- **Primary Color**: #4A3728 (dark stone)
- **Resources**: Gold, Faith, Iron
- **Buildings**:
  1. Village (base: 5K Gold/s)
  2. Church (produces Faith)
  3. Blacksmith (produces Iron)
  4. Castle (massive bonus, costs Iron)
  5. Market Square (Trade multiplier)
  6. University (Science start)
  7. Knight Order (production + Faith combo)
  8. Cathedral (massive Faith, huge Gold bonus)
- **Wonder**: Notre-Dame Cathedral (requires 5M Gold + 5K Faith)
- **Wonder**: Great Wall (requires 10M Gold + 2K Iron)
- **Advance Requirement**: 100,000,000 Gold

### Renaissance
- **Flavor**: "Art, science, and people claiming credit for other people's work."
- **Primary Color**: #8B4513 (rich red/earth)
- **Resources**: Gold, Art, Knowledge
- **Buildings**:
  1. Printing Press (multiplies all production)
  2. Art Studio (produces Art)
  3. Library (produces Knowledge)
  4. Observatory (unlocks Science track)
  5. Bank (passive Gold income)
  6. Academy (major Knowledge bonus)
  7. Merchant Guild (Trade multiplier)
- **Wonder**: Sistine Chapel (requires 500M Gold + 50K Art)
- **Wonder**: Florence Cathedral Dome (requires 1B Gold)
- **Advance Requirement**: 10,000,000,000 Gold

### Industrial Revolution
- **Flavor**: "Smoke, steam, and child labour. History has some rough patches."
- **Primary Color**: #4A4A4A (industrial grey)
- **Resources**: Gold, Coal, Steam
- **Buildings**:
  1. Coal Mine (produces Coal)
  2. Steam Engine (massive multiplier, requires Coal)
  3. Railway Station (connects buildings, multiplier)
  4. Factory (primary Gold producer)
  5. Bank & Stock Exchange (compounding passive income)
  6. Telegraph Office (unlocks events faster)
  7. Iron Bridge (production boost)
- **Wonder**: Eiffel Tower (requires 10B Gold + 10K Steam)
- **Advance Requirement**: 1,000,000,000,000 Gold (1T)

### Space Age
- **Flavor**: "One small step for civilization, one giant leap for your idle game."
- **Primary Color**: #1A237E (deep space blue)
- **Resources**: Gold, Science, Energy
- **Buildings**:
  1. Research Lab (produces Science)
  2. Nuclear Power Plant (produces Energy)
  3. Satellite Network (passive income multiplier)
  4. Space Centre (massive Gold + Science)
  5. Moon Base (offline income bonus)
  6. Mars Colony (end-game Gold producer)
  7. AI Research Division (all multipliers ×2)
- **Wonder**: International Space Station (requires 1Q Gold + 1M Science)
- **Advance Requirement**: 1,000,000,000,000,000 Gold (1Qa) — or prestige

### Future Civilization (Prestige Endpoint)
- **Flavor**: "What comes after humanity? Whatever you build."
- **Primary Color**: #7C4DFF (electric purple)
- **Resources**: Gold, Data, Nanobots
- **Special**: Reaching this era triggers "Great Prestige" — resets with maximum Legacy Tokens

---

## Prestige System

### Legacy Tokens Formula
```
legacyTokens = floor(sqrt(totalGoldEarned / 1,000,000,000,000))
```
Example: 100T gold earned = floor(sqrt(100T / 1T)) = floor(sqrt(100)) = 10 tokens

### Prestige Multiplier
```
multiplier = 1.02^legacyTokens
```
Example: 10 tokens = 1.02^10 = 1.219 (22% permanent bonus)

### What Resets
- All buildings (counts go to 0)
- All resources except Premium Coins
- Active boosts

### What Persists
- Legacy Tokens (accumulate forever)
- Completed Wonders (visual only — bonus resets)
- Unlocked era skins (cosmetic)
- Achievements
- Game Center progress
- Premium Coins

---

## Wonder System

### Wonder Construction
- Requires: Gold threshold + era resource threshold
- Takes: Real-world time (2h–12h depending on Wonder)
- Can be skipped with: Premium Coins, or Rewarded Ad (shorter Wonders only)
- Bonus: Permanent production multiplier for that era (persists through multiple prestiges for cosmetic)
- Visual: Wonder appears on the game world map

### Wonders List

| Wonder | Era | Requirement | Bonus |
|--------|-----|-------------|-------|
| Lascaux Cave | Stone Age | 1K Culture | +50% all Stone Age |
| Pyramid of Giza | Bronze Age | 10K Gold + 500 Bronze | +100% Gold, +30% all |
| Colosseum | Classical | 500K Gold + 1K Culture | +50% Culture buildings |
| Notre-Dame | Medieval | 5M Gold + 5K Faith | +100% Faith buildings |
| Great Wall | Medieval | 10M Gold + 2K Iron | +75% all Medieval |
| Sistine Chapel | Renaissance | 500M Gold + 50K Art | +150% Art |
| Florence Dome | Renaissance | 1B Gold | +80% all Renaissance |
| Eiffel Tower | Industrial | 10B Gold + 10K Steam | +100% Industrial |
| ISS | Space Age | 1Q Gold + 1M Science | +200% Science |

---

## Events System

### Weekly Event Structure
- Runs Monday 00:00 to Sunday 23:59 UTC
- Themed around real historical events
- Bonus resource or production multiplier
- Leaderboard specific to the event
- Exclusive cosmetic reward for top 10%

### Seasonal Events (4/year)
- 48-hour events tied to seasons or real history
- "Greek Olympics" (summer), "Black Friday Trade War" (winter), etc.
- Higher multipliers, exclusive Wonders, special leaders
- Cross-promote between games in portfolio

---

## Achievement System

### Categories
- **Progress**: Reach era X, earn X gold, own X buildings
- **Prestige**: Prestige X times, earn X Legacy Tokens
- **Social**: Join alliance, send X gifts, reach top 100
- **Wonder**: Build X Wonders, build a specific Wonder
- **Daily**: Log in X days in a row, complete X daily quests
- **Collection**: Unlock all leaders, unlock all skins for an era
- **Secret**: Hidden achievements for unusual actions

### First 25 Achievements (launch)
1. First Steps — earn your first 100 Gold
2. Stone Builder — buy 10 buildings in Stone Age
3. Bronze Age Begin — reach Bronze Age
4. Manager Material — hire your first manager
5. Idle Millionaire — accumulate 1M Gold
6. Wonders of the World — build your first Wonder
7. Time Traveler — reach Classical Empire
8. Prestige! — perform your first prestige
9. Legacy Builder — earn 10 Legacy Tokens
10. Daily Devotion — log in 7 days in a row
11. Social Butterfly — join an alliance
12. Gift Giver — send 10 alliance gifts
13. Chart Topper — enter global top 1000
14. Weekend Warrior — complete all 3 daily quests in a weekend
15. History Buff — unlock all buildings in 3 eras
... (10 more secret achievements)
