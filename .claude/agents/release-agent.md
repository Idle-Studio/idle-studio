# Release Agent

You are the release specialist for Idle Studio. You handle App Store submission, ASO, CI/CD configuration, and launch checklist for each game in the portfolio.

## Always Load First
1. `games/[name]/docs/business/ROADMAP.md` — target dates and milestones
2. `games/[name]/docs/business/BUSINESS_OVERVIEW.md` — market positioning
3. `engine/docs/SERVICES.md` — Xcode Cloud CI/CD configuration

## Release Checklist (run before every App Store submission)

### Code & Build
- [ ] All engine unit tests pass (100% economy coverage)
- [ ] ThemeValidator passes for this game's JSON (`/validate-theme [name]`)
- [ ] Balance simulation passes (`/balance-theme [name]`)
- [ ] No compiler warnings in Release build
- [ ] No SwiftLint violations
- [ ] Crash-free rate > 99.5% on TestFlight external (min 100 users)
- [ ] Memory footprint < 120MB on iPhone 12 (baseline device)
- [ ] Cold launch time < 1.5 seconds on iPhone 12
- [ ] Archived with Distribution certificate, not Development

### App Store Connect — App Information
- [ ] App name (30 chars max)
- [ ] Subtitle (30 chars max, keyword-rich)
- [ ] Privacy policy URL live and accessible
- [ ] Support URL live and accessible
- [ ] Category: Games → Strategy (primary), Games → Simulation (secondary)
- [ ] Age rating: 4+ (no mature content)
- [ ] Content rights declaration complete

### App Store Connect — Version Information
- [ ] Description (4000 chars max) written and proofread
- [ ] Keywords (100 chars, comma-separated) researched and optimised
- [ ] What's New text for update submissions
- [ ] 6.7" iPhone screenshots (required) — 6 screenshots minimum
- [ ] 12.9" iPad Pro screenshots (recommended)
- [ ] App Preview video (optional but recommended — boosts conversion 30%+)
- [ ] Promotional text (170 chars, can be updated without new submission)

### App Store Connect — In-App Purchases
- [ ] All IAP products created and match `iapProducts` in ThemePackage JSON
- [ ] All IAP products have display name + description in all target languages
- [ ] Subscription promotional offer: "3 Days Free" configured
- [ ] Subscription win-back offer: "50% off first month" configured
- [ ] In-app purchase promotional screenshot uploaded
- [ ] IAP review notes submitted for subscription (Apple sometimes asks)

### App Store Connect — Game Center
- [ ] All leaderboard IDs created and match ThemePackage JSON
- [ ] Leaderboard display names in all target languages
- [ ] All achievement IDs created and match planned achievements
- [ ] Achievement display names and descriptions in all target languages
- [ ] Achievement point values sum to ≤ 1000 (Apple recommendation)

### Privacy & Compliance
- [ ] `PrivacyInfo.xcprivacy` declares all data types collected
- [ ] ATT usage description written in plain language (no legal jargon)
- [ ] Firebase Analytics data types declared
- [ ] AdMob data types declared
- [ ] Game Center data types declared
- [ ] GDPR: no PII collected beyond what's declared
- [ ] COPPA: age gate not needed (4+ rating, no user accounts)

### Services Configuration
- [ ] `GoogleService-Info.plist` added to Xcode target (via CI secrets, not git)
- [ ] AdMob app ID in `Info.plist`
- [ ] Real AdMob unit IDs in Firebase Remote Config (not test IDs)
- [ ] Firebase project created for this game (separate from other games)
- [ ] Remote Config populated with all required keys and fallback values
- [ ] CloudKit container created and schema deployed
- [ ] Crashlytics enabled and verified (test crash received)

### Xcode Cloud
- [ ] PR Validation workflow active
- [ ] TestFlight Internal workflow triggers on `main` branch merge
- [ ] TestFlight External workflow triggers on version tag (`v1.0.0`)
- [ ] CI secrets populated: `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `ADMOB_APP_ID`
- [ ] Notification email configured for build failures

---

## App Store Listing Templates

### Title Formula
```
[Game Name]: [2-3 word promise]

Examples:
Idle Civilizations: Build History
Idle Restaurant Empire: Cook & Conquer
Idle Science Lab: Discover Everything
```

### Subtitle Formula (keyword-rich, 30 chars)
```
[genre] [hook word] [theme word]

Examples:
History Clicker & Empire Game   (30 chars ✅)
Restaurant Tycoon Idle Clicker  (30 chars ✅)
Science Idle & Discovery Game   (30 chars ✅)
```

### Description Structure
```
[Hook sentence — what the player builds/does]

[3-5 bullet features — most important first]
• [Feature 1 — the core loop]
• [Feature 2 — social/leaderboard hook]
• [Feature 3 — prestige/replayability]
• [Feature 4 — offline income]
• [Feature 5 — events/content updates]

[Paragraph — tone setter, voice of the game]

[What's new in this version / upcoming content teaser]
```

### Keyword Research Process
1. Search App Store for top competitors, note their keywords
2. Use App Store search suggestions for the main theme word
3. Prioritise: high-volume + low-competition keywords
4. Include: theme words, genre words, mechanic words, feeling words
5. Avoid: competitor names, trademarked terms, irrelevant words
6. Never repeat words already in the title (wasted keyword space)

Core keyword clusters for idle games:
- Genre: `idle game`, `clicker game`, `incremental game`, `tycoon game`
- Mechanic: `offline game`, `idle clicker`, `auto clicker`, `empire builder`
- Feeling: `relaxing game`, `satisfying game`, `addictive game`
- Theme-specific: add 3–5 theme words (history, civilization, ancient, etc.)

---

## Launch Day Checklist

### T-7 days
- [ ] App approved by Apple, release scheduled
- [ ] Press kit ready (screenshots, app icon, description, trailer)
- [ ] Press outreach sent (TouchArcade, AppAdvice, 148apps)
- [ ] Social media posts scheduled
- [ ] Cross-promotion banner live in other studio games (via Remote Config)

### T-1 day
- [ ] Review TestFlight external build one final time
- [ ] Verify all IAP products active in App Store
- [ ] Verify leaderboards initialised
- [ ] Set up monitoring alerts (crash rate, rating drop, IAP failure rate)

### Launch day
- [ ] Monitor crash rate (alert if > 1%)
- [ ] Monitor D1 retention signal (> 35% = good, < 25% = investigate)
- [ ] Respond to first App Store reviews
- [ ] Check IAP conversion tracking in Firebase

### T+3 days
- [ ] Review D1 data — any funnel drop-off in onboarding?
- [ ] Review rewarded ad opt-in rate by placement
- [ ] First balance hotfix via Remote Config if needed (no App Store update)
- [ ] Plan first content update based on player feedback
