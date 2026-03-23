import Foundation
import Testing
@testable import IdleEngine

// MARK: - Helpers

/// Build a minimal valid mock theme with N levels (default 4) that passes all rules.
private func validTheme(levelCount: Int = 4) -> MockThemePackage {
    let levels = (1...levelCount).map { i in
        ThemeLevel(
            id: "level_\(i)",
            displayName: "Level \(i)",
            order: i,
            flavorText: "Flavor for level \(i).",
            artworkAsset: "art_level_\(i)",
            advanceRequirement: ResourceBundle(["gold": EconomyCalculator.decimalPow(10, i + 3)]),
            levelResources: [],
            units: (1...3).map { u in
                ThemeUnit(
                    id: "unit_\(i)_\(u)",
                    displayName: "Unit \(u)",
                    description: "Desc",
                    iconAsset: "icon_u\(u)",
                    baseCost: ResourceBundle(["gold": Decimal(u * 10)]),
                    costMultiplier: Decimal(string: "1.15")!,
                    baseProductionPerSecond: ResourceBundle(["gold": Decimal(u)]),
                    managerThreshold: 10,
                    upgradeTiers: [
                        ThemeUpgradeTier(atCount: 10,  multiplier: Decimal(string: "1.5")!),
                        ThemeUpgradeTier(atCount: 25,  multiplier: 2),
                        ThemeUpgradeTier(atCount: 50,  multiplier: 3),
                        ThemeUpgradeTier(atCount: 100, multiplier: 6)
                    ]
                )
            },
            milestones: [
                ThemeMilestone(
                    id: "ms_\(i)", displayName: "Milestone \(i)", description: "Desc",
                    artworkAsset: "art_ms_\(i)", requirements: ResourceBundle(["gold": 100]),
                    constructionSeconds: 1800, skipCostCoins: 50, canSkipWithAd: true,
                    bonuses: [], isPermanentBonus: false
                )
            ]
        )
    }

    let levelColors = (1...levelCount).map { i in
        ThemeLevelColor(levelID: "level_\(i)", primary: "#8B7355", secondary: "#6B5335")
    }

    return MockThemePackage(
        schemaVersion: "1.0",
        gameID: "mock-game",
        displayName: "Mock Game",
        bundleID: "com.test.mock",
        primaryCurrency: "Gold",
        primaryCurrencyIcon: "coin",
        themeColors: ThemeColors(
            background: "#0D0D0F", surface: "#1A1A20", surfaceElevated: "#252530",
            textPrimary: "#F5F5F5", textSecondary: "#A0A0B0", goldAccent: "#FFD700",
            levelColors: levelColors
        ),
        levels: levels,
        events: [],
        characters: [],
        iapProducts: ThemeIAPProducts(
            starterPack: "com.test.mock.starter",
            removeAds: "com.test.mock.remove_ads",
            premiumPass: "com.test.mock.premium_pass"
        ),
        leaderboards: .empty,
        copy: .fixture
    )
}

// MARK: - Test Suites

@Suite("ThemeValidator — Valid Themes")
struct ThemeValidatorValidTests {

    @Test("Minimal valid 4-level theme passes without errors")
    func validThemePasses() throws {
        #expect(throws: Never.self) {
            try ThemeValidator.validate(validTheme())
        }
    }

    @Test("Valid 12-level theme passes")
    func twelveLevel() throws {
        #expect(throws: Never.self) {
            try ThemeValidator.validate(validTheme(levelCount: 12))
        }
    }
}

@Suite("ThemeValidator — Identity Rules")
struct ThemeValidatorIdentityTests {

    @Test("Wrong schemaVersion throws validationFailed")
    func wrongSchemaVersion() {
        let theme = validTheme()
        // Rebuild with wrong version — MockThemePackage is a struct so we can copy-edit
        let broken = MockThemePackage(
            schemaVersion: "9.9", gameID: theme.gameID, displayName: theme.displayName,
            bundleID: theme.bundleID, primaryCurrency: theme.primaryCurrency,
            primaryCurrencyIcon: theme.primaryCurrencyIcon, themeColors: theme.themeColors,
            levels: theme.levels, events: theme.events, characters: theme.characters,
            iapProducts: theme.iapProducts, leaderboards: theme.leaderboards, copy: theme.copy
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("schemaVersion") }
        }
    }

    @Test("Non-kebab-case gameID throws validationFailed")
    func nonKebabGameID() {
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: "My Game!", displayName: "G",
            bundleID: "com.a.b", primaryCurrency: "Gold", primaryCurrencyIcon: "coin",
            themeColors: validTheme().themeColors, levels: validTheme().levels,
            events: [], characters: [], iapProducts: validTheme().iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("kebab") }
        }
    }

    @Test("Invalid bundleID format throws validationFailed")
    func invalidBundleID() {
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: "my-game", displayName: "G",
            bundleID: "notabundleid", primaryCurrency: "Gold", primaryCurrencyIcon: "coin",
            themeColors: validTheme().themeColors, levels: validTheme().levels,
            events: [], characters: [], iapProducts: validTheme().iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("bundleID") }
        }
    }
}

@Suite("ThemeValidator — Level Rules")
struct ThemeValidatorLevelTests {

    @Test("Fewer than 4 levels throws validationFailed")
    func tooFewLevels() {
        let theme = validTheme(levelCount: 3)
        #expect {
            try ThemeValidator.validate(theme)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("at least 4") }
        }
    }

    @Test("More than 12 levels throws validationFailed")
    func tooManyLevels() {
        let theme = validTheme(levelCount: 13)
        #expect {
            try ThemeValidator.validate(theme)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("at most 12") }
        }
    }

    @Test("Level with order gap throws validationFailed")
    func orderGap() {
        let theme = validTheme()
        let levels = theme.levels
        // Remove level 2, creating a gap 1 → 3
        let gapped = [levels[0], levels[2], levels[3]]
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: theme.gameID, displayName: theme.displayName,
            bundleID: theme.bundleID, primaryCurrency: theme.primaryCurrency,
            primaryCurrencyIcon: theme.primaryCurrencyIcon, themeColors: theme.themeColors,
            levels: gapped, events: [], characters: [], iapProducts: theme.iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("no gaps") || $0.contains("expected") || $0.contains("at least 4") }
        }
    }

    @Test("Level with 'gold' in levelResources throws validationFailed")
    func goldInLevelResources() {
        let base = validTheme()
        let badLevel = ThemeLevel(
            id: "level_1", displayName: "L1", order: 1, flavorText: "",
            artworkAsset: "art", advanceRequirement: ResourceBundle(["gold": 10000]),
            levelResources: ["gold"],  // violation
            units: base.levels[0].units, milestones: base.levels[0].milestones
        )
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: base.gameID, displayName: base.displayName,
            bundleID: base.bundleID, primaryCurrency: base.primaryCurrency,
            primaryCurrencyIcon: base.primaryCurrencyIcon, themeColors: base.themeColors,
            levels: [badLevel] + Array(base.levels.dropFirst()),
            events: [], characters: [], iapProducts: base.iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("gold") && $0.contains("reserved") }
        }
    }
}

@Suite("ThemeValidator — Unit Rules")
struct ThemeValidatorUnitTests {

    @Test("Unit with costMultiplier below 1.07 throws validationFailed")
    func costMultiplierTooLow() {
        let base = validTheme()
        var units = base.levels[0].units
        let badUnit = ThemeUnit(
            id: "bad_unit", displayName: "Bad", description: "D", iconAsset: "i",
            baseCost: ResourceBundle(["gold": 10]),
            costMultiplier: Decimal(string: "1.05")!, // too low
            baseProductionPerSecond: ResourceBundle(["gold": 1]),
            managerThreshold: 10,
            upgradeTiers: [
                ThemeUpgradeTier(atCount: 10, multiplier: 2),
                ThemeUpgradeTier(atCount: 25, multiplier: 2),
                ThemeUpgradeTier(atCount: 50, multiplier: 2),
                ThemeUpgradeTier(atCount: 100, multiplier: 2)
            ]
        )
        units[0] = badUnit
        let modifiedLevel = ThemeLevel(
            id: base.levels[0].id, displayName: base.levels[0].displayName, order: 1,
            flavorText: base.levels[0].flavorText, artworkAsset: base.levels[0].artworkAsset,
            advanceRequirement: base.levels[0].advanceRequirement,
            levelResources: [], units: units, milestones: base.levels[0].milestones
        )
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: base.gameID, displayName: base.displayName,
            bundleID: base.bundleID, primaryCurrency: base.primaryCurrency,
            primaryCurrencyIcon: base.primaryCurrencyIcon, themeColors: base.themeColors,
            levels: [modifiedLevel] + Array(base.levels.dropFirst()),
            events: [], characters: [], iapProducts: base.iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("costMultiplier") }
        }
    }

    @Test("Duplicate unit IDs across levels throws validationFailed")
    func duplicateUnitIDs() {
        let base = validTheme()
        // Make level 2's first unit have the same ID as level 1's first unit
        let l1Unit = base.levels[0].units[0]
        var l2Units = base.levels[1].units
        let duplicate = ThemeUnit(
            id: l1Unit.id,  // same ID
            displayName: "Dup", description: "D", iconAsset: "i",
            baseCost: ResourceBundle(["gold": 10]),
            costMultiplier: Decimal(string: "1.15")!,
            baseProductionPerSecond: ResourceBundle(["gold": 1]),
            managerThreshold: 10,
            upgradeTiers: l1Unit.upgradeTiers
        )
        l2Units[0] = duplicate
        let modL2 = ThemeLevel(
            id: base.levels[1].id, displayName: base.levels[1].displayName, order: 2,
            flavorText: base.levels[1].flavorText, artworkAsset: base.levels[1].artworkAsset,
            advanceRequirement: base.levels[1].advanceRequirement,
            levelResources: [], units: l2Units, milestones: base.levels[1].milestones
        )
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: base.gameID, displayName: base.displayName,
            bundleID: base.bundleID, primaryCurrency: base.primaryCurrency,
            primaryCurrencyIcon: base.primaryCurrencyIcon, themeColors: base.themeColors,
            levels: [base.levels[0], modL2] + Array(base.levels.dropFirst(2)),
            events: [], characters: [], iapProducts: base.iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("Duplicate") }
        }
    }
}

@Suite("ThemeValidator — Color Rules")
struct ThemeValidatorColorTests {

    @Test("Invalid hex color throws validationFailed")
    func invalidHexColor() {
        let base = validTheme()
        let brokenColors = ThemeColors(
            background: "not-a-color", // invalid
            surface: base.themeColors.surface,
            surfaceElevated: base.themeColors.surfaceElevated,
            textPrimary: base.themeColors.textPrimary,
            textSecondary: base.themeColors.textSecondary,
            goldAccent: base.themeColors.goldAccent,
            levelColors: base.themeColors.levelColors
        )
        let broken = MockThemePackage(
            schemaVersion: "1.0", gameID: base.gameID, displayName: base.displayName,
            bundleID: base.bundleID, primaryCurrency: base.primaryCurrency,
            primaryCurrencyIcon: base.primaryCurrencyIcon, themeColors: brokenColors,
            levels: base.levels, events: [], characters: [], iapProducts: base.iapProducts,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.contains { $0.contains("background") }
        }
    }
}

@Suite("ThemeValidator — Error Accumulation")
struct ThemeValidatorErrorAccumulationTests {

    @Test("Multiple violations are all reported in a single throw")
    func allErrorsReported() {
        let broken = MockThemePackage(
            schemaVersion: "99.0",    // wrong
            gameID: "INVALID ID",     // not kebab
            displayName: "",          // empty
            bundleID: "invalid",      // no dots
            primaryCurrency: "",      // empty
            primaryCurrencyIcon: "x",
            themeColors: validTheme().themeColors,
            levels: [],               // too few
            events: [], characters: [], iapProducts: .empty,
            leaderboards: .empty, copy: .fixture
        )
        #expect {
            try ThemeValidator.validate(broken)
        } throws: { error in
            guard case EngineError.validationFailed(let errors) = error else { return false }
            return errors.count > 3 // should report schema, gameID, bundleID, levels, etc.
        }
    }
}
