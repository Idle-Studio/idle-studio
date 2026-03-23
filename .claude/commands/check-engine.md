# /check-engine Command

## Purpose
Scan the engine package for any theme-specific code that violates the engine/theme separation. Run before every engine PR merge.

## Usage
```
/check-engine
```

## What This Command Does

1. **Load:**
   - `engine/docs/ENGINE_ARCHITECTURE.md`
   - All engine Swift files

2. **Scan for violations:**

### Hardcoded Display Strings
Flag any string literal in engine Swift files that is user-facing.
```swift
// ❌ VIOLATION — engine should never contain display strings
Text("Your civilization is flourishing!")

// ✅ CORRECT
Text(theme.copy.offlineSheet.title)
```

### Game-Specific Vocabulary
Flag these words appearing in engine Swift files (outside of comments):
- era, civilization, building, wonder
- restaurant, cuisine, dish, kitchen
- science, experiment, laboratory
- football, match, stadium, league
- Any other game-specific noun

```swift
// ❌ VIOLATION
func advanceEra() { ... }

// ✅ CORRECT
func advanceLevel() { ... }
```

### Hardcoded Colors
```swift
// ❌ VIOLATION
.foregroundStyle(Color(hex: "#8B7355"))

// ✅ CORRECT
.foregroundStyle(theme.themeColors.levelPrimary)
```

### Hardcoded Product IDs
```swift
// ❌ VIOLATION
let productID = "com.yourstudio.idleciv.civ_pass.monthly"

// ✅ CORRECT
let productID = theme.iapProducts.premiumPass
```

### Hardcoded Leaderboard IDs
```swift
// ❌ VIOLATION
GKLeaderboard.loadEntries(for: ["com.yourstudio.idleciv.lb.weekly_gold"])

// ✅ CORRECT
GKLeaderboard.loadEntries(for: [theme.leaderboards.weeklyGold])
```

### ThemeValidator Not Called at Startup
```swift
// ❌ VIOLATION — theme loaded without validation
let theme = try ThemeLoader.load(named: themeName)
engine.start(with: theme)

// ✅ CORRECT
let theme = try ThemeLoader.load(named: themeName)
try ThemeValidator.validate(theme)  // throws on invalid
engine.start(with: theme)
```

### Real Game JSON Loaded in Tests
```swift
// ❌ VIOLATION — engine tests must use mock theme
let theme = try ThemeLoader.load(named: "civilizations")

// ✅ CORRECT
let theme = MockThemePackage.minimal
```

## Output Format

```
## Engine Purity Check

### 🔴 Violations Found
- `Core/GameEngine.swift:47` — hardcoded string "Your civilization..."
- `Services/NotificationService.swift:23` — game vocabulary "era" in function name
- `UI/Screens/GameplayScreen.swift:89` — hardcoded color #8B7355

### ✅ No Violations Found
Engine code is clean. No theme-specific content detected.

### Summary
Violations: [N]  
Files scanned: [N]  
Status: ✅ CLEAN / ❌ VIOLATIONS MUST FIX BEFORE MERGE
```
