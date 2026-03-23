# Monetization Strategy — Idle Civilizations

## Philosophy
Monetization should feel like the game helping you, not the game extracting from you. Every revenue touchpoint is designed around player value — the moment a player feels manipulated, we've failed.

---

## StoreKit 2 IAP Implementation

### Product Catalogue

```swift
// Sources/IdleCivilizations/Services/StoreKit/Products.swift

enum IAPProduct: String, CaseIterable {
    // Consumables
    case starterPack       = "com.idleciv.starter_pack"
    case smallCoinBundle   = "com.idleciv.coins_1000"
    case mediumCoinBundle  = "com.idleciv.coins_5000"
    case largeCoinBundle   = "com.idleciv.coins_15000"
    
    // Non-consumables
    case removeAds         = "com.idleciv.remove_ads"
    case legendaryPack     = "com.idleciv.legendary_pack"
    case patronOfHistory   = "com.idleciv.patron_lifetime"
    
    // Era bundles (non-consumable)
    case eraBundle_stone   = "com.idleciv.era.stone_age"
    case eraBundle_bronze  = "com.idleciv.era.bronze_age"
    case eraBundle_classical = "com.idleciv.era.classical"
    case eraBundle_medieval = "com.idleciv.era.medieval"
    case eraBundle_renaissance = "com.idleciv.era.renaissance"
    case eraBundle_industrial = "com.idleciv.era.industrial"
    case eraBundle_space   = "com.idleciv.era.space_age"
    
    // Auto-renewable subscription
    case civPassMonthly    = "com.idleciv.civ_pass.monthly"
    case civPassAnnual     = "com.idleciv.civ_pass.annual"
}
```

### Pricing Tiers

| Product | Price | Type | Value Proposition |
|---------|-------|------|-------------------|
| Starter Pack | €1.99 | Consumable (one-time) | 2× production 24h + exclusive flag skin |
| Small Coins | €0.99 | Consumable | 1,000 premium coins |
| Medium Coins | €3.99 | Consumable | 5,000 coins (25% bonus) |
| Large Coins | €9.99 | Consumable | 15,000 coins (50% bonus) |
| XL Coins | €19.99 | Consumable | 30,000 coins (best value — covers 15 ISS wonder skips) |
| Mega Coins | €39.99 | Consumable | 75,000 coins (extreme value — 37 ISS wonder skips) |
| Remove Ads | €4.99 | Non-consumable | Removes interstitials permanently |
| Era Bundle (Eras 1–2) | €2.99 | Non-consumable | Skins + 500/750 Coins for Stone/Bronze Age |
| Era Bundle (Eras 3–4) | €2.99 | Non-consumable | Skins + 1,000/1,500 Coins for Ancients/Classical |
| Era Bundle (Eras 5–6) | €2.99 | Non-consumable | Skins + 2,000/2,500 Coins for Medieval/Renaissance |
| Era Bundle (Eras 7–8) | €2.99 | Non-consumable | Skins + 3,000/4,000 Coins for Industrial/Space Age |
| Legendary Pack | €29.99 | Non-consumable | Permanent 1.5× multiplier + exclusive Wonder |
| Patron of History | €99.99 | Non-consumable | All content forever + VIP badge |
| Civ Pass Monthly | €9.99/mo | Subscription | No banners, daily coins, exclusive leader, +30% idle |
| Civ Pass Annual | €79.99/yr | Subscription | All monthly benefits (33% saving) |

---

## Ad Strategy

### Ad SDK Stack
- **Mediation**: Google AdMob with mediation waterfall
- **Networks**: AdMob, Meta Audience Network, IronSource, AppLovin MAX
- **Format priority**: Rewarded Video > Offer Wall > Interstitial > Banner (last resort)

### Rewarded Ad Placement Map

| Moment | Reward | Expected Opt-in |
|--------|--------|----------------|
| Return from background | 2× offline income (one-time) | 55% |
| Production bottleneck reached | 10-min 3× boost | 48% |
| Daily quest complete | +500 coins | 42% |
| Pre-era advance | 30-min income boost | 38% |
| Wonder construction | Skip 2-hour wait | 35% |
| Leaderboard rank boost | +1 rank token | 28% |

### Interstitial Rules
- **Never** in first 20 minutes of new user session
- **Never** during active gameplay (building, tapping)
- **Max** 2 per session, minimum 5 minutes apart
- **Only** at natural break points: era transition, app reopen, prestige screen
- Removing ads via IAP removes all interstitials permanently

### Banner Ads
- Only shown to free users who haven't seen the remove-ads offer
- Position: bottom of screen, below fold
- Hidden during: tutorial, prestige sequence, Wonder build celebration
- Removed when subscription active

---

## Subscription — Civ Pass

### Monthly Benefits
- No interstitial or banner ads
- Daily login bonus: 200 premium coins
- Exclusive leader unlock (one per month, rotating)
- +30% offline income multiplier
- Exclusive "Patron" badge on leaderboard
- Early access to seasonal events (24h before public)

### Subscription Best Practices
- Free 3-day trial (StoreKit 2 introductory offer)
- Offer at: first prestige, first leader card unlock, first leaderboard view
- Grace period: 16 days for billing failures (retain subscriber)
- Win-back offer: 50% off first month after cancellation (after 30 days)
- Never gate core gameplay behind subscription

---

## IAP Presentation Moments

### The "Emotional Peak" Rule
Present purchase offers ONLY at moments of genuine excitement:

```
Era advance celebration → "Complete your era with the Era Bundle! Get unique skins 
                           for every building you just unlocked."

First Wonder built → "Commemorate your achievement — the Legendary Pack gives you 
                      a permanent 1.5× bonus to honor your achievement."

Leaderboard breakthrough (enter top 100) → "You're climbing! Civ Pass subscribers 
                                             get a +20% offline bonus..."

Daily quest streak (7 days) → Starter Pack offer (first-time offer)

Late-era Wonder unlock (Crystal Palace or ISS) →
  "Skip the wait — an XL Coins pack covers this Wonder and 14 more just like it."
```

### Pricing Psychology
- Starter Pack shown once, within first 48 hours, at a genuine engagement moment
- Bundle discounts are shown as savings ("Save 50%" not "Was €20")
- No fake countdown timers — seasonal bundles have real end dates
- Offer comparison screen shows clear value hierarchy

---

## Anti-Patterns to Avoid
- ❌ Paywalling content that was previously free
- ❌ Fake "limited time" offers with no real end
- ❌ Showing ads immediately on launch
- ❌ Purchase nags more than once per session
- ❌ Manipulative "Are you sure?" dialogs on IAP cancel
- ❌ Gating leaderboard participation behind payment
- ❌ Energy systems that hard-block gameplay

---

## Revenue Tracking & Analytics

### Key Events to Track
```
iap_purchase_initiated     { product_id, screen, session_minutes }
iap_purchase_complete      { product_id, revenue, currency }
iap_purchase_failed        { product_id, error }
ad_rewarded_offered        { placement, context }
ad_rewarded_watched        { placement, context }
ad_rewarded_skipped        { placement, time_watched }
ad_interstitial_shown      { placement }
subscription_started       { product_id, offer_type }
subscription_cancelled     { product_id, tenure_days }
subscription_renewed       { product_id }
```

### Funnel Targets
```
Install → First session engagement (>5 min): 70%
First session → Return D1: 45%
D1 → First IAP or 10 ad views: 25%
D7 → Subscription trial start: 5%
Trial → Paid subscription: 40%
```
