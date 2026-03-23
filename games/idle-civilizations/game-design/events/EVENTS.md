# Events — Master Design Document

Events are time-limited gameplay experiences that add variety, drive session frequency, and provide exclusive rewards. They are a key retention and social tool.

## Event Types

### Weekly Events
- Run Monday 00:00 → Sunday 23:59 UTC
- Active every week (different theme each week, rotating)
- Eligible from Bronze Age and above
- Drive leaderboard competition
- Reward: cosmetic items and coins

### Seasonal Events
- Run 48–72 hours
- 4 per year (tied to seasons/historical moments)
- Higher multipliers and more exclusive rewards
- Cross-promote across game portfolio in later stages

---

## Weekly Event Catalogue

### The Silk Road
**ID:** `weekly_silk_road`  
**Theme:** Ancient trade routes  
**Eligible eras:** Bronze Age and above  
**Duration:** 7 days  
**Cadence:** Appears every 4–6 weeks (rotating pool)

**Mechanic:** Trade Gold production ×2.5  
**Leaderboard metric:** Total Gold earned during event  
**Rewards:**
- Top 10%: "Merchant Prince" leader cosmetic variant
- Top 1%: Exclusive "Silk Road Oasis" Wonder skin

**Notification:** "The Silk Road opens! Trade Gold earns 2.5× this week."

---

### The Agricultural Revolution
**ID:** `weekly_agri_rev`  
**Theme:** Farming breakthroughs  
**Eligible eras:** Stone Age and above  
**Duration:** 7 days

**Mechanic:** All Food-related buildings produce ×3  
**Leaderboard metric:** Food resource produced  
**Rewards:**
- Top 10%: "Harvest Festival" building skin pack
- Top 1%: "Golden Grain" global multiplier cosmetic

**Notification:** "The harvest season is here! Food production triples this week."

---

### The Grand Tournament
**ID:** `weekly_tournament`  
**Theme:** Medieval competition  
**Eligible eras:** Medieval Kingdom and above  
**Duration:** 7 days

**Mechanic:** Knight Order and Castle production ×4  
**Leaderboard metric:** Legacy Tokens earned  
**Rewards:**
- Top 10%: "Tournament Champion" leader title
- Top 1%: Exclusive "Arena" Wonder cosmetic

**Notification:** "The Grand Tournament begins! Knights and Castles produce 4× this week."

---

### The Industrial Boom
**ID:** `weekly_industrial_boom`  
**Theme:** Factory revolution  
**Eligible eras:** Industrial Revolution and above  
**Duration:** 7 days

**Mechanic:** All Industrial buildings ×3, offline income cap extended to 12h  
**Leaderboard metric:** Coal and Steam produced  
**Rewards:**
- Top 10%: Industrial era exclusive building skins
- Top 1%: "Tycoon" profile badge (permanent)

**Notification:** "Industrial Boom! Your factories run 3× faster and offline cap extends to 12h."

---

## Seasonal Event Catalogue

### Greek Olympics ⛅ (Summer)
**ID:** `seasonal_greek_olympics`  
**Type:** Seasonal  
**Duration:** 72 hours  
**Eligible eras:** Classical Empire and above  
**Cadence:** Annual, July

**Mechanic:** Culture production ×5 for 72 hours  
**Leaderboard metric:** Culture earned during event  
**Special mechanic:** "Torch Relay" — each day, tapping a special torch gives a stacking Culture multiplier (×1 → ×2 → ×3 over 3 days)  
**Rewards:**
- Top 25%: "Olympian" leader skin
- Top 10%: "Zeus's Blessing" Wonder skin (exclusive)
- Top 1%: "Champion of Olympia" permanent profile badge

**Notification:** "🏅 The Greek Olympics begin! Earn 5× Culture for 72 hours. Light the torch!"

---

### The Renaissance Fair 🍂 (Autumn)
**ID:** `seasonal_renaissance_fair`  
**Type:** Seasonal  
**Duration:** 48 hours  
**Eligible eras:** Renaissance and above  
**Cadence:** Annual, October

**Mechanic:** Art and Knowledge ×5. Premium Coins earned from quests ×2.  
**Leaderboard metric:** Art + Knowledge combined  
**Special mechanic:** Mystery Boxes — every 2h, player gets a box with random bonus (coins, boost, or cosmetic)  
**Rewards:**
- Top 25%: "Renaissance Artist" building skin
- Top 1%: "Da Vinci's Workshop" exclusive Wonder skin

**Notification:** "🎨 The Renaissance Fair is here! Art and Knowledge earn 5× for 48 hours."

---

### Industrial World Expo ❄️ (Winter)
**ID:** `seasonal_world_expo`  
**Type:** Seasonal  
**Duration:** 48 hours  
**Eligible eras:** Industrial Revolution and above  
**Cadence:** Annual, December

**Mechanic:** All production ×4. Wonder construction time halved.  
**Leaderboard metric:** Total Gold produced  
**Special mechanic:** "Expo Showcase" — build a Wonder during the event for bonus coins and event leaderboard points  
**Rewards:**
- Top 25%: Crystal Palace exclusive building skin set
- Top 1%: "World Fair Champion" permanent profile badge + exclusive app icon

**Notification:** "🏭 The World Expo opens! All production ×4 and Wonders build twice as fast."

---

### The Space Race 🌸 (Spring)
**ID:** `seasonal_space_race`  
**Type:** Seasonal  
**Duration:** 72 hours  
**Eligible eras:** Space Age and above  
**Cadence:** Annual, April

**Mechanic:** Science and Energy ×6. Offline income cap: 24 hours (from 8h).  
**Leaderboard metric:** Science produced  
**Special mechanic:** "Mission Control" — complete daily milestones to launch rockets (each rocket gives a temporary ×2 Science boost)  
**Rewards:**
- Top 25%: "Cosmonaut" leader skin
- Top 1%: "Apollo" exclusive app icon + permanent "First to the Stars" badge

**Notification:** "🚀 The Space Race begins! Science earns 6× and offline cap extends to 24h for 72 hours."

---

## Event Design Rules

1. **Events must be additive**, never punishing — a player who ignores an event loses nothing from their normal progression
2. **Leaderboard resets** every event — even veteran players start fresh, giving new players a real shot
3. **Rewards are cosmetic or coins** — never permanent production advantages that create pay-to-win perception
4. **Notification is sent at event start** (Monday 09:00 local for weeklies)
5. **Event UI banner** appears on main screen and in the dedicated Events tab
6. **Multiplier cap** for events: 6× maximum (higher breaks progression math)
7. **Eligible era gates** ensure events feel relevant — no Stone Age player sees a Space Race event

## Events Tab UI

The Events tab shows:
- Currently active event(s) with a countdown timer
- Leaderboard for the active event (player's rank highlighted)
- Upcoming events preview (next 2 weeks)
- Past event reward showcase (inspires participation)
- Event-specific daily quests (visible only during that event)
