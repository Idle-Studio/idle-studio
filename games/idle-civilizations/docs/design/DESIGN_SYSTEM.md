# Design System — Idle Civilizations

## Philosophy
The UI must feel premium, satisfy the "number go up" dopamine loop, and adapt its visual identity per historical era. Each era gets its own color palette while the structural UI stays consistent.

---

## Color System

### Base Palette (era-independent)

```swift
extension Color {
    // Backgrounds
    static let background = Color("Background")          // Deep dark: #0D0D0F
    static let surface = Color("Surface")                // Card surface: #1A1A20
    static let surfaceElevated = Color("SurfaceElevated") // #252530

    // Text
    static let textPrimary = Color("TextPrimary")        // #F5F5F5
    static let textSecondary = Color("TextSecondary")    // #A0A0B0
    static let textMuted = Color("TextMuted")            // #606070

    // Semantic
    static let goldAccent = Color("GoldAccent")          // #FFD700
    static let goldGlow = Color("GoldGlow")              // #FFD700 @ 30% opacity
    static let success = Color("Success")                // #4CAF50
    static let premium = Color("Premium")                // #9C27B0
    static let danger = Color("Danger")                  // #F44336
}
```

### Era Color Palettes

| Era | Primary | Secondary | Accent | Glow |
|-----|---------|-----------|--------|------|
| Stone Age | #8B7355 | #6B5335 | #DEB887 | #8B7355@40% |
| Bronze Age | #CD7F32 | #8B4513 | #FFB347 | #CD7F32@40% |
| Classical | #C9A84C | #8B7536 | #FFD700 | #C9A84C@40% |
| Medieval | #4A3728 | #2C1A0E | #8B6914 | #4A3728@60% |
| Renaissance | #8B4513 | #6B3410 | #CC7722 | #8B4513@40% |
| Industrial | #4A4A4A | #2A2A2A | #708090 | #4A4A4A@50% |
| Space Age | #1A237E | #0D1B5E | #3F51B5 | #1A237E@50% |
| Future | #7C4DFF | #4A2FCC | #B39DFF | #7C4DFF@40% |

---

## Typography

```swift
extension Font {
    // Display — era names, major milestones
    static let display = Font.custom("Georgia", size: 32).bold()
    static let displayMedium = Font.custom("Georgia", size: 24).bold()

    // Headlines — section headers
    static let headlineLarge = Font.system(size: 20, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 17, weight: .semibold)

    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 12, weight: .regular)

    // Numbers — production rates, resource counts
    static let numberLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let numberMedium = Font.system(size: 20, weight: .bold, design: .rounded)
    static let numberSmall = Font.system(size: 15, weight: .semibold, design: .rounded)

    // Labels — button text, chips
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)
}
```

---

## Component Library

### ResourceDisplay
Shows a resource with icon, count, and production rate:
```
[💰] 1.24M Gold    +45.2K/s
```

### BuildingCard
Tall card showing building name, current count, cost, and buy button:
```
┌──────────────────────┐
│ 🏕️  Campfire   × 12  │
│ +0.1 Gold/s          │
│ Cost: 156 Gold       │
│ [  Buy ×1  ][×10][×M]│
└──────────────────────┘
```

### ProgressBar
Era advance progress:
```
Era Progress ████████░░ 80%
            500K / 625K Gold needed
```

### NumberRoller
Animated number that "rolls up" when resources increase — satisfying visual feedback.

### WonderCard
Special elevated card for Wonders with unique artwork background.

### LeaderboardRow
Rank, player name, score, era reached, flag.

---

## Screen Specifications

### Main Gameplay Screen
```
┌─────────────────────────────┐
│ [Era Name]    [Menu] [Shop] │ ← Navigation
├─────────────────────────────┤
│  💰 1.24M Gold   +45K/s    │ ← Resource bar
│  🎭 Culture: 892 +12/s     │
├─────────────────────────────┤
│        [ERA ARTWORK]        │ ← Animated era scene
│   Tap to earn!              │ ← Tap target
├─────────────────────────────┤
│ Era Progress ███░░░ 62%     │ ← Progress to next era
├─────────────────────────────┤
│ BUILDINGS                   │ ← Scrollable list
│ [BuildingCard]              │
│ [BuildingCard]              │
│ [BuildingCard]              │
└─────────────────────────────┘
```

### Era Advance Celebration
Full-screen dramatic sequence:
1. Camera zooms out from current era art
2. Transition flash (era color)
3. New era art animates in
4. "Bronze Age Begins!" text rises
5. Legacy Tokens earned displayed
6. [Continue] button → Optional prestige info

### Prestige Screen
Shows: Legacy Tokens to earn, multiplier preview, what resets vs persists, dramatic confirm button.

---

## Animation Guidelines

### Principles
- Production numbers update smoothly (interpolated, not instant jumps)
- Gold earned from tapping shows floating "+X Gold" particles
- Building purchase: short scale pop + sparkle
- Era advance: full-screen cinematic transition
- Wonder completion: particle burst + camera shake

### Performance Budget
- All animations: 60fps
- No physics engines (too CPU intensive for idle)
- Use SwiftUI animations (`.spring()`, `.easeOut`) — no custom CAAnimation
- Particle effects: SwiftUI Canvas, max 50 particles on screen

### Haptics
- Building purchase: `.impact(.light)`
- Era advance: `.notification(.success)`
- Prestige: `.notification(.success)` + custom pattern
- Wonder complete: `.impact(.heavy)` × 3

---

## Icon System

### App Icon Variants
- Default: Gold coin with laurel wreath on dark background
- Era-specific dynamic icons (iOS 18+): Stone, Bronze, Classical, Medieval, Renaissance, Industrial, Space, Future
- iOS 18 tinted icon: Monochrome coin/wreath

### Building Icons (64×64pt @3x SVG)
All building icons follow these rules:
- Flat design, 2 colors max (era primary + white/gold)
- Recognizable at 32pt
- Dark background compatible
- No fine details that disappear small

### Asset Catalogue Structure
```
Assets.xcassets/
├── AppIcon.appiconset/
├── LaunchScreen.imageset/
├── Eras/
│   ├── stone-age-artwork.imageset/ (1920×1080 scene)
│   ├── bronze-age-artwork.imageset/
│   └── ...
├── Buildings/
│   ├── campfire.imageset/
│   ├── hunting-ground.imageset/
│   └── ...
├── Wonders/
│   ├── pyramid-of-giza.imageset/
│   └── ...
├── Leaders/
│   └── ...
├── Colors/ (all era color sets)
└── UI/
    └── (shared UI icons)
```
