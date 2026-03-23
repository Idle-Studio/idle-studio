# UX Flows

Critical user journeys through Idle Civilizations. Each flow specifies the exact screen sequence, decision points, and expected outcomes.

---

## 1. First Launch & Onboarding

```
App Install → Cold Launch
    ↓
Splash screen (1.5s, animated logo)
    ↓
Onboarding Step 1: "Build Your Civilization"
  - Era artwork (Stone Age) animates in
  - "Tap to earn your first Gold" call to action
  - [Tap campfire area] → "+10 Gold" floats up
    ↓
Onboarding Step 2: "Buy Buildings"
  - Campfire card highlighted, bounces
  - "Buy your first Campfire to earn automatically"
  - [Buy Campfire] → Purchase animation, building appears
    ↓
Onboarding Step 3: "Earn While Away"
  - Campfire produces visibly
  - "Your civilization earns Gold even when you're not playing!"
  - [Got it!] → tutorial complete
    ↓
Main Gameplay Screen (full UI unlocked)
```

**Goals:** Player buys their first building within 2 minutes. First earning animation plays within 30 seconds.  
**Skip:** No forced onboarding — tap anywhere else skips to main screen.

---

## 2. Main Gameplay Loop

```
Open App
    ↓
[If away > 30s] → Offline Income Sheet (see Flow 4)
[If event active] → Event banner pulses on Events tab
    ↓
Main Screen:
  - Resource bar (top): Gold count + rate, Culture, era resources
  - Era artwork (center): tapable area for manual Gold
  - Era progress bar: "500K / 1M Gold to advance"
  - Buildings list (scrollable): BuyCard for each building
    ↓
Player actions available:
  A) Tap era artwork → +Gold (manual, no manager needed)
  B) Buy a building → deduct cost, add building, production increases
  C) Buy ×10 or ×Max → bulk purchase
  D) Tap building's manager button (when unlocked) → building runs idle
  E) Era progress bar fills → "Advance Era" button pulses gold
  F) Open Shop tab → IAP and coin store
  G) Open Social tab → leaderboard, alliance, friends
  H) Open Events tab → active event, leaderboard
```

---

## 3. Era Advance (Prestige) Flow

```
Player accumulates required Gold
    ↓
"Advance Era" button appears pulsing (gold glow, subtle bounce)
    ↓
Player taps → Prestige Preview Screen:
  ┌─────────────────────────────────────┐
  │  ⚠️  Ready to advance?              │
  │                                      │
  │  You're entering the [Bronze Age]!   │
  │                                      │
  │  You'll earn: +[N] Legacy Tokens     │
  │  New multiplier: [X.XX]×             │
  │                                      │
  │  ✅ KEEPS: Tokens, skins, Wonders    │
  │  🔄 RESETS: Buildings, resources     │
  │                                      │
  │  [  Cancel  ]  [  Advance Era!  →]  │
  └─────────────────────────────────────┘
    ↓
[Player taps Advance Era]
    ↓
Transition animation (2–3 seconds):
  1. Current era artwork zooms out slowly
  2. White/gold flash fills screen
  3. New era artwork zooms in
  4. "Bronze Age Begins!" text rises from centre
  5. Legacy Token counter ticks up (+N)
  6. Multiplier badge shows "Now [X.XX]×"
    ↓
[ONLY on first-ever prestige]:
Notification Permission Sheet:
  "Stay ahead of history!"
  [Enable] → system permission dialog
  [Maybe later] → dismiss
    ↓
Main screen: new era colors, empty buildings list, fresh resources
```

---

## 4. Offline Income Sheet

**Triggers:** Player returns after > 30 seconds away.

```
App foregrounded
    ↓
Calculate offline income (EconomyCalculator.offlineIncome)
    ↓
[If income > 0 and not seen this session]:
Offline Income Sheet (modal, slides up):
  ┌────────────────────────────────────┐
  │  ⏰ You were away 4 hours 23 min   │
  │                                    │
  │  Your civilization earned:         │
  │  💰 1.24M Gold                     │
  │  🎭 432 Culture                    │
  │                                    │
  │  [  Collect  ]                     │
  │  [📺 Watch Ad: Double it! → 2.48M] │
  └────────────────────────────────────┘
    ↓
[Collect] → income added, sheet dismissed
[Watch Ad] → rewarded ad plays → income ×2 added → success animation
    ↓
[Ad not available]:
  "Watch Ad" button grayed out, show why: "Ad not ready yet"
```

**Rules:**
- Sheet shown maximum once per app foreground
- If income < 100 Gold (< 1 second away), skip the sheet silently
- Rewarded ad offer shown only if `isRewardedAdReady(for: .offlineIncome)` is true
- `analyticsService.track(.offlineIncomeCollected(...))` fires on collection

---

## 5. IAP Purchase Flow (StoreKit 2)

```
Player triggers an offer moment (e.g. era advance)
    ↓
Offer Sheet appears:
  ┌──────────────────────────────────┐
  │  🎉 Commemorate this moment!     │
  │                                  │
  │  Bronze Age Bundle               │
  │  • All Bronze Age building skins │
  │  • 2,000 Premium Coins          │
  │  • +10% Bronze Age production   │
  │                                  │
  │  €4.99                           │
  │                                  │
  │  [  Buy Bronze Bundle  ]         │
  │  [  Not now  ]                   │
  └──────────────────────────────────┘
    ↓
[Buy]:
  StoreKit 2 system sheet appears (Apple handles payment UI)
    ↓
  [Payment success]:
    → Transaction verified
    → Entitlement granted immediately
    → "Thank you!" confirmation animation
    → Skins applied, coins added
    → analytics: iapPurchaseComplete
    ↓
  [Payment failed / cancelled]:
    → Dismiss silently (no guilt UI)
    → analytics: iapPurchaseCancelled
```

---

## 6. Rewarded Ad Flow

```
Player taps a rewarded ad offer (e.g. "Double offline income")
    ↓
[Check: isRewardedAdReady(for placement)]:
  [Not ready]: 
    → Show: "Ad loading... try again in a moment"
    → Begin preloading in background
    ↓
  [Ready]:
    → AdMob rewarded ad plays (30 seconds, player can X after 5s)
    ↓
[Ad completed (watched to end or reward threshold)]:
  → Reward granted immediately
  → Confirmation animation
  → analytics: adRewardedWatched
  → Preload next rewarded ad
    ↓
[Ad skipped early]:
  → No reward granted
  → analytics: adRewardedSkipped
  → No penalty, no guilt UI
```

---

## 7. Subscription Purchase Flow

```
Trigger: Player enters top 100 on weekly leaderboard
    ↓
Tooltip appears: "🥇 You're in the top 100! Civ Pass subscribers get +20% idle income..."
  [Learn more] → Subscription Screen
    ↓
Subscription Screen:
  - Monthly vs Annual toggle (annual highlighted as "Best Value")
  - Clear benefit list (no ads, daily coins, leader, +20% idle)
  - "Try free for 3 days" badge on monthly
  - Fine print: "Cancel anytime in App Store settings"
  - [Start Free Trial] or [Subscribe Annual]
    ↓
StoreKit 2 handles payment
    ↓
[Success]: Welcome animation, benefits applied immediately
[Cancel]: Dismiss, no re-prompt for remainder of session
```

---

## 8. Notification Permission Flow

**Trigger:** Immediately after first-ever era advance.

```
Era advance animation completes
    ↓
Custom pre-permission screen (before iOS prompt):
  ┌──────────────────────────────────────┐
  │  🏺  Stay ahead of history            │
  │                                       │
  │  Get notified when:                   │
  │  • Your offline income is about to cap│
  │  • A Wonder is complete               │
  │  • Your daily quests reset            │
  │  • Alliance gifts arrive              │
  │                                       │
  │  We send max 1–2 notifications/day.   │
  │                                       │
  │  [ Enable Notifications ]             │
  │  [ Maybe later ]                      │
  └──────────────────────────────────────┘
    ↓
[Enable]:
  → iOS system permission dialog
  → [Allow]: schedule all notifications, analytics: notifications_enabled
  → [Don't Allow]: record in UserDefaults, never ask again on this run
    ↓
[Maybe later]:
  → Dismiss, try again at next prestige (max once per prestige)
```

---

## 9. Wonder Construction Flow

```
Player has enough resources for a Wonder
    ↓
Wonder card shows "Ready to Build!" glow
    ↓
Player taps card → Wonder Detail Sheet:
  - Wonder artwork (large)
  - Flavor text
  - Cost breakdown (Gold + era resources)
  - Construction time: "2 hours"
  - Bonus: "+100% Gold production"
  - [Start Construction] [Cancel]
    ↓
[Start Construction]:
  → Resources deducted
  → Wonder card shows progress bar + countdown
  → Local notification scheduled for completion
  → Wonder artwork shows "Under Construction" overlay on world map
    ↓
[Timer expires (foreground)]:
  → Completion animation plays automatically
    ↓
[Timer expires (background)]:
  → Local notification fires: "Your Pyramid is complete!"
  → On next app open: completion animation plays
    ↓
Completion Celebration (3 seconds):
  → Wonder art full-screen reveal
  → Particle burst
  → "[Wonder Name] Complete! +100% Gold production active"
  → Haptic: heavy impact × 2
```
