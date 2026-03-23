# Player Psychology & Retention Design

Understanding *why* idle games are addictive is critical to designing features that drive genuine long-term engagement — not dark patterns.

---

## Core Psychological Hooks

### 1. Variable Reward Schedule (BF Skinner)
The most powerful retention mechanism. Players don't know *exactly* when the next satisfying moment will arrive — this uncertainty drives compulsive checking.

**In Idle Civilizations:**
- Offline income amount varies (production rate changes, boosts may have expired)
- Building upgrade unlocks are spaced irregularly as numbers grow
- Wonder completion timing varies per session
- Daily quest variety (players don't know what quests will appear)

**Design rule:** Always have *something* coming soon — a Wonder finishing, an upgrade threshold close, an era 80% complete. The player should always have a "just one more session" hook visible.

---

### 2. Progress & Completion (Endowment Effect)
Players feel ownership over their civilization. They've invested time; that investment feels *real*.

**In Idle Civilizations:**
- Named historical eras create identity ("I'm in the Renaissance now")
- Wonders persist visually forever — the Pyramid they built on day 1 is still there
- Legacy Token accumulation is visible and never resets — a permanent record of progress
- Achievement badges are permanent status symbols

**Design rule:** Never take away something the player earned. Prestige resets buildings — but explicitly preserves everything emotionally meaningful.

---

### 3. Autonomy & Agency (Self-Determination Theory)
Players need to feel their choices matter. Idle games that feel completely automatic lose players fast.

**In Idle Civilizations:**
- Resource allocation: Bronze Mine vs Gold buildings — a real tradeoff
- Wonder timing: build now (short-term sacrifice) or wait (save for advance?)
- Prestige timing: early (more runs, slower start) vs late (fewer runs, better tokens)
- Alliance vs solo play — genuine choice, no penalty either way

**Design rule:** Every session, the player should face at least one meaningful decision. If there's nothing to decide, the game is too automated.

---

### 4. Social Comparison (Festinger)
Players benchmark their progress against others — both motivating and engaging.

**In Idle Civilizations:**
- Weekly leaderboard resets ensure everyone can compete, not just veterans
- Country leaderboard: "Romania's #1 Civilization" is more emotionally resonant than "Global #4,821"
- Alliance collective score: shared identity, collective achievement
- Shareable civilization cards: "Look what I built" content for social media

**Design rule:** Leaderboards must reset regularly. Permanent leaderboards kill motivation for new players. Weekly resets keep it competitive for everyone.

---

### 5. Loss Aversion (Kahneman & Tversky)
The fear of missing out is more motivating than the prospect of gain.

**In Idle Civilizations:**
- Offline income CAP at 8 hours — players feel the urgency to return before capping
- Daily quests RESET at midnight — incomplete quests feel like waste
- Weekly events END — "Leaderboard closes in 6 hours" drives final-day engagement
- Limited-time seasonal cosmetics — create genuine FOMO for rare items

**Design rule:** Scarcity is powerful but must be *real*. Fake countdowns destroy trust. Real end dates create genuine motivation.

---

### 6. Achievement & Mastery (Flow Theory)
Players need challenges that match their skill level — too easy = boredom, too hard = frustration.

**In Idle Civilizations:**
- Early eras (Stone, Bronze) are fast to provide quick wins and build confidence
- Later eras (Industrial, Space) require more planning and resource management
- Prestige system creates meta-game mastery: "I know exactly which buildings to prioritize now"
- Alliance battles reward strategic coordination

**Design rule:** New players should feel smart, not lost. The tutorial must create a "I get it!" moment within the first 5 minutes.

---

## Session Frequency Design

### Why Players Return (in order of importance)

1. **Offline income capped** — most powerful single return trigger
2. **Daily quest reset** — habit-forming, players feel "owed" their quests
3. **Wonder completion notification** — high excitement, visual reward waiting
4. **Leaderboard rank changed** — competitive anxiety
5. **Weekly event starts** — FOMO and fresh competition
6. **Alliance gift received** — social obligation (reciprocity principle)

### Ideal Session Pattern
```
08:00 → Morning: collect overnight income, claim daily quests (+3 min)
12:30 → Lunch: buy buildings, push toward Wonder (+8 min)
18:00 → Evening: Wonder complete, buy more buildings, check leaderboard (+12 min)
22:00 → Night: final daily quest, check event leaderboard (+5 min)

Total: ~30 min/day, 4 sessions — matches top idle game benchmarks
```

### The 6-Hour Notification Strategy
The offline income cap is 8 hours. We notify at **6 hours**, not 8.

Why 6 hours?
- Player has time to open the app before capping (at 8h, they've already missed income)
- Creates urgency without panic
- Trains players to return on a ~6h cycle (4 sessions per day)
- Players who return at 6h get 2 more hours of production before the next cap warning

---

## Anti-Retention Dark Patterns (Never Ship These)

### Energy Systems
Systems that *hard block* gameplay until a timer expires. Players feel punished for playing.  
**Our approach:** Offline income cap is a *soft* limit on away income only — it never blocks active play.

### Pay Walls on Core Content
Gating essential buildings or eras behind payment.  
**Our approach:** All eras are free. IAP accelerates or enhances, never blocks.

### Manipulative Social Pressure
"Your friend [Name] is 3 eras ahead of you!" guilt notifications.  
**Our approach:** Social features are opt-in and frame others' achievements positively.

### Escalating Interstitials
Showing more ads the longer someone plays (rewards engagement with punishment).  
**Our approach:** Hard cap of 2 interstitials per session, regardless of session length.

### Fake Limited Time Offers
"50% off! Ends in 00:12:34" where the timer always resets.  
**Our approach:** Seasonal bundles only — real end dates tied to real calendar events.

---

## Onboarding Psychology

### The "Aha Moment" Rule
Players decide whether to keep a game within **90 seconds**. Our aha moment must be:

**"My civilization earns Gold while I do nothing."**

This moment happens when they buy their first building and *watch it produce*. Everything in the tutorial is designed to reach this moment as quickly as possible.

### Tutorial Principles
1. **Show, don't tell** — let players experience, not read instructions
2. **Immediate first success** — Gold appears within 15 seconds
3. **Progressive disclosure** — don't show all features at once (confusing)
4. **Never block** — tutorial is additive guidance, not a forced funnel
5. **First prestige is the hook** — design Stone Age to be completable in session 1 on first run

### New Player First Session Target
```
0:00 — App opens
0:30 — First Gold earned (tap or campfire produces)
2:00 — First building bought (Campfire)
3:00 — Campfire produces automatically (aha moment!)
5:00 — Enough Gold to buy second building type
8:00 — First manager consideration (10 campfires = manager)
12:00 — Era progress visible at 30%+
15:00 — Session naturally ends (player puts phone down)
```

Player returns. Stone Age likely complete in session 2–3. First prestige is the moment they become a retained user.
