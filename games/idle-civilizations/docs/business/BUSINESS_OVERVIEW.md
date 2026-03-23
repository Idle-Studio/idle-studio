# Business Overview — Idle Civilizations Studio

## Mission
Build a portfolio of addictive idle incremental games on iOS, starting with *Idle Civilizations*, using a single scalable engine that powers multiple themed releases. Each game monetizes through a proven hybrid model: rewarded ads for free users, IAP for engaged players, and a monthly subscription for superfans.

---

## Product Portfolio Strategy

### The Engine-First Bet
Every game in the portfolio shares the same Swift codebase. Content (eras, buildings, resources, events) is 100% data-driven via JSON config files. A new game = new theme + new JSON + new art. Target: one new game every 3–4 months after Game #1 launches.

```
Game Engine (shared Swift codebase)
    ├── Idle Civilizations     ← Game #1  (history/civilizations theme)
    ├── Idle Restaurant Empire ← Game #2  (world cuisines through time)
    ├── Idle Science Lab       ← Game #3  (inventions & discoveries)
    ├── Idle Football Club     ← Game #4  (Sunday League → Champions League)
    └── Idle Mythology         ← Game #5  (gods & pantheons)
```

---

## Market Opportunity

| Metric | Value | Source |
|--------|-------|--------|
| Top idle game peak weekly revenue (iOS US) | $311K | Sensor Tower Q1 2025 |
| Average rewarded ad opens per session (idle) | 9.7× | ASO World |
| ARPDAU vs hyper-casual games | 9× higher | Industry data |
| Hybrid monetization adoption | 72% of devs | AppSamurai |
| Paying user LTV premium | 2.6× vs non-payers | Gamigion |

### Why History/Civilization?
- No dominant idle game owns this niche cleanly
- Universal appeal — recognized globally across all ages
- Built-in content roadmap: each real historical era = DLC
- Educational angle helps with press coverage and App Store featuring
- Aspirational: "I built the Roman Empire" is shareable

---

## Revenue Model

### Free Users (Ads)
| Format | Trigger | Expected Engagement |
|--------|---------|-------------------|
| Rewarded video | Offline income doubler, resource boost, bottleneck bailout | 42% opt-in |
| Interstitial | Era transition, app reopen after 4h (max 2/session) | Background revenue |
| Offer wall | Optional tasks for premium currency | High eCPM ($530 US avg) |

### Paid Users (IAP)

| Product ID | Price | Contents | Target User |
|-----------|-------|----------|-------------|
| `starter_pack` | €1.99 | 2× production 24h + flag skin | New engaged players |
| `era_bundle_[name]` | €4.99 | Era-themed building skins + 10K coins | Era completionists |
| `civ_pass_monthly` | €9.99/mo | No banners, daily bonus, exclusive leader, +20% idle | Superfans |
| `legendary_pack` | €29.99 | Permanent 1.5× multiplier + exclusive Wonder | Whales |
| `patron_of_history` | €99.99 | All content forever + VIP badge | Ultra whales |

### Revenue Split Target
- Year 1: 60% ads / 40% IAP
- Year 2+: 45% ads / 40% IAP / 15% subscriptions

### Key Monetization Rules
1. **Never show ads in first 20 minutes** — build the habit first
2. **Frame rewarded ads as rescues** — "Double your offline earnings!" not "Watch an ad"
3. **Offer IAP at emotional peaks** — first Wonder built, first prestige, new era
4. **Subscription value must be obvious** — daily bonus alone should feel worth €9.99/mo

---

## Go-to-Market Plan

### Phase 1: Soft Launch (Month 1–3)
- Romania + 3–5 EU markets (lower CPI, real monetization data)
- KPIs to hit before global: D1 >40%, D7 >20%, D30 >8%, ARPU >€0.12/DAU

### Phase 2: Global Launch (Month 4)
- App Store featuring pitch: history + education angle
- TikTok creatives: "satisfying number go up", era transition moments, Wonder builds
- Meta campaigns: lookalike audiences from soft launch cohorts
- Press: TouchArcade, AppAdvice, Apple-focused blogs
- Target CPI: €0.40–1.20 (casual idle benchmark)

### Phase 3: Portfolio Expansion (Month 5+)
- Cross-promote within the portfolio (exclusive building unlock if you try Game #2)
- Shared loyalty system: "Civilization Points" earned across all games
- Seasonal cross-game events

---

## Key Metrics & Targets

### Retention (North Star)
| Metric | Target | Industry Average |
|--------|--------|-----------------|
| Day 1 | 45% | 30–40% |
| Day 7 | 22% | 12–18% |
| Day 30 | 10% | 5–8% |
| Sessions/day | 4+ | 2–3 |

### Revenue
| Metric | Month 6 Target | Month 12 Target |
|--------|---------------|----------------|
| DAU | 10,000 | 50,000 |
| ARPDAU | €0.12 | €0.18 |
| Monthly Revenue | €36K | €270K |
| LTV (D90) | €3.50 | €5.00 |

---

## Competitive Landscape

| Game | Theme | Weakness | Our Edge |
|------|-------|----------|----------|
| Gold & Goblins | Fantasy mining | Generic theme | Real history hook |
| Carnival Tycoon | Carnival | Niche appeal | Universal civilization |
| Idle Miner Tycoon | Mining | Repetitive | Dynamic era system |
| AdVenture Capitalist | Business | No story | Historical narrative |
| Egg, Inc. | Chickens | No social | Full alliance system |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Low D1 retention | Medium | High | A/B test first 5 minutes heavily |
| Ad revenue drops | Low | Medium | Diversify to IAP early |
| Competition copies theme | Medium | Medium | Move fast, build brand loyalty |
| App Store rejection | Low | High | Follow guidelines strictly; no dark patterns |
| Engine bugs in new games | Medium | Medium | Shared test suite, content validation CI |
