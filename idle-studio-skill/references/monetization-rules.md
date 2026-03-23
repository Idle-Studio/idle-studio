# Monetization Rules Reference

## Core Philosophy

Every revenue touchpoint must pass the **player value test**: would a reasonable player, in this moment, feel helped or feel manipulated? If manipulated → don't ship it.

---

## IAP Product Catalogue

### Consumables
| Product ID | Price | Contents | When to Offer |
|-----------|-------|----------|--------------|
| `starter_pack` | €1.99 | 2× production 24h + exclusive flag skin | Day 1–2, first era advance |
| `coins_1000` | €0.99 | 1,000 Premium Coins | Anytime in shop |
| `coins_5000` | €3.99 | 5,000 Coins (25% bonus) | Anytime in shop |
| `coins_15000` | €9.99 | 15,000 Coins (50% bonus) | Anytime in shop |

### Non-Consumables
| Product ID | Price | Contents | When to Offer |
|-----------|-------|----------|--------------|
| `remove_ads` | €4.99 | Removes interstitials permanently | After 3rd interstitial shown |
| `era_bundle_[id]` | €4.99 each | Era building skins + prestige multiplier | Era advance celebration |
| `legendary_pack` | €29.99 | Permanent 1.5× multiplier + exclusive Wonder | First prestige or first Wonder |
| `patron_lifetime` | €99.99 | All content forever + VIP badge | After 3 months play or top 100 |

### Subscriptions
| Product ID | Price | Benefits | Trial |
|-----------|-------|---------|-------|
| `civ_pass_monthly` | €9.99/mo | No banners, daily 200 coins, exclusive leader, +20% idle | 3-day free trial |
| `civ_pass_annual` | €79.99/yr | All monthly benefits (33% saving) | 3-day free trial |

---

## Offer Timing Rules

### The Emotional Peak Rule
**Only** present purchase offers at genuine moments of player excitement. These are the only approved offer moments:

1. **Era advance celebration** → era bundle for the era just entered
2. **First Wonder completion** → legendary pack ("commemorate this achievement")
3. **First prestige** → starter pack if not already bought
4. **Leaderboard breakthrough (enter top 100 nationally)** → Civ Pass subscription
5. **Day 2 login** → starter pack (if not shown day 1)
6. **7-day login streak completion** → coins bundle

**Maximum one offer per session.** Never stack multiple offers.

### IAP Anti-Patterns (Never Do These)
- ❌ Popup offers on cold app launch
- ❌ Offers during active gameplay (mid-tap session)
- ❌ More than one offer per session
- ❌ Fake "limited time" labels without a real end date
- ❌ "Are you sure?" guilt trip on IAP cancel
- ❌ Paywalling previously free content
- ❌ Gating leaderboard entry or alliance joining behind payment
- ❌ Manipulative "X players just bought this!" FOMO text

---

## Ad Strategy

### Ad Format Priority
1. **Rewarded video** (player-initiated, highest value) — always preferred
2. **Offer wall** (optional tasks for coins) — shown in shop
3. **Interstitial** (system-initiated, at natural breaks) — use sparingly
4. **Banner** (passive, bottom of screen) — lowest priority, remove-ads eligible

### Rewarded Ad Placements (with expected opt-in rate)

| Placement | Offer | Expected Opt-In |
|-----------|-------|----------------|
| Return from background | 2× offline income | ~55% |
| Production bottleneck hit | 10-min 3× boost | ~48% |
| Daily quest complete | +500 coins | ~42% |
| Pre-era-advance | 30-min income boost | ~38% |
| Wonder construction | Skip 2h wait (short wonders only) | ~35% |

### Interstitial Rules
- **Never** in first 20 minutes of any session (new user or returning)
- **Never** during active building-buying
- **Maximum** 2 interstitials per session
- **Minimum** 5-minute gap between interstitials
- **Only** at natural breaks: era transition, app reopen after 4h, prestige screen back
- **Disabled permanently** if player purchased `remove_ads`
- **Disabled** during active Civ Pass subscription

### Banner Ad Rules
- Only free users who haven't seen the remove-ads offer 3+ times
- Position: bottom, below fold — never overlapping gameplay
- Hidden during: tutorial, prestige sequence, Wonder celebration, onboarding
- Removed: subscription active, or `remove_ads` purchased

---

## Subscription Management

### Free Trial
- 3-day free trial via StoreKit 2 introductory offers
- Only offered once per Apple ID
- Shows clearly as "Try free for 3 days, then €9.99/month"

### Renewal & Retention
- Grace period: 16 days for billing failures (Apple default — preserve subscriber)
- Win-back offer: 50% off first month, shown 30 days after cancellation
- Never hide the cancel button or make it hard to find
- "Manage Subscription" link always visible in Settings screen

### Subscription Value Checklist
Every benefit must be:
- Desirable (player would want it even if ad-free separately)
- Clear in value (not vague like "exclusive content")
- Never retroactively removed if subscription expires (cosmetics earned stay)

---

## Analytics Events for Monetization

Track all of these — non-negotiable for optimisation:

```
iap_offer_shown         { product_id, trigger_moment, session_minutes }
iap_purchase_initiated  { product_id }
iap_purchase_complete   { product_id, price, currency }
iap_purchase_cancelled  { product_id }
iap_purchase_failed     { product_id, error_code }

ad_rewarded_offered     { placement, player_era, session_count }
ad_rewarded_accepted    { placement }
ad_rewarded_completed   { placement }
ad_rewarded_skipped     { placement, seconds_watched }
ad_interstitial_shown   { trigger, player_era }
ad_interstitial_clicked { trigger }

sub_trial_started       { product_id }
sub_converted           { product_id }
sub_renewed             { product_id, tenure_months }
sub_cancelled           { product_id, tenure_months }
sub_reactivated         { product_id }
```
