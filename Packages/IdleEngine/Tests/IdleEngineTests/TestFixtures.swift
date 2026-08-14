import Foundation
@testable import IdleEngine

// MARK: - ThemeUnit fixture

extension ThemeUnit {
    /// Standard test unit: 10g base cost, ×1.15 multiplier, 0.1g/s production.
    static let campfire = ThemeUnit(
        id: "campfire",
        displayName: "Campfire",
        description: "Test unit",
        iconAsset: "unit_campfire",
        baseCost: ResourceBundle(["gold": 10]),
        costMultiplier: Decimal(string: "1.15")!,
        baseProductionPerSecond: ResourceBundle(["gold": Decimal(string: "0.1")!]),
        managerThreshold: 10,
        upgradeTiers: [
            ThemeUpgradeTier(atCount: 10,  multiplier: Decimal(string: "1.5")!),
            ThemeUpgradeTier(atCount: 25,  multiplier: 2),
            ThemeUpgradeTier(atCount: 50,  multiplier: 3),
            ThemeUpgradeTier(atCount: 100, multiplier: 6)
        ]
    )

    /// Simple unit with round numbers: 10g cost, ×2.0 multiplier, 1g/s production.
    static let simpleUnit = ThemeUnit(
        id: "simple",
        displayName: "Simple",
        description: "Round numbers unit",
        iconAsset: "unit_simple",
        baseCost: ResourceBundle(["gold": 10]),
        costMultiplier: 2,
        baseProductionPerSecond: ResourceBundle(["gold": 1]),
        managerThreshold: 10,
        upgradeTiers: [
            ThemeUpgradeTier(atCount: 10,  multiplier: Decimal(string: "1.5")!),
            ThemeUpgradeTier(atCount: 25,  multiplier: 2),
            ThemeUpgradeTier(atCount: 50,  multiplier: 3),
            ThemeUpgradeTier(atCount: 100, multiplier: 6)
        ]
    )
}

// MARK: - MockThemePackage

/// Minimal in-memory ThemePackage for tests that need a full theme.
struct MockThemePackage: ThemePackage {
    let schemaVersion: String
    let gameID: String
    let displayName: String
    let bundleID: String
    let primaryCurrency: String
    let primaryCurrencyIcon: String
    let themeColors: ThemeColors
    let levels: [ThemeLevel]
    let events: [ThemeEvent]
    let characters: [ThemeCharacter]
    let iapProducts: ThemeIAPProducts
    let leaderboards: ThemeLeaderboards
    let copy: ThemeCopy
}

extension MockThemePackage {
    /// Two-level theme with one regular and one permanent milestone.
    static func fixture(permanentMilestoneID: String? = nil) -> MockThemePackage {
        let regularMilestone = ThemeMilestone(
            id: permanentMilestoneID ?? "milestone_regular",
            displayName: "Test Milestone",
            description: "A test milestone",
            artworkAsset: "ms_test",
            requirements: ResourceBundle(["gold": 1000]),
            constructionSeconds: 1800,
            skipCostCoins: 50,
            canSkipWithAd: true,
            bonuses: [],
            isPermanentBonus: permanentMilestoneID != nil
        )
        let transientMilestone = ThemeMilestone(
            id: "colosseum",
            displayName: "Colosseum",
            description: "Resets on prestige",
            artworkAsset: "ms_colosseum",
            requirements: ResourceBundle(["gold": 5000]),
            constructionSeconds: 3600,
            skipCostCoins: 100,
            canSkipWithAd: true,
            bonuses: [],
            isPermanentBonus: false
        )
        let level1 = ThemeLevel(
            id: "level_1",
            displayName: "Level One",
            order: 1,
            flavorText: "The beginning.",
            artworkAsset: "level_1_art",
            advanceRequirement: ResourceBundle(["gold": 1000]),
            levelResources: [],
            units: [.campfire],
            milestones: [regularMilestone, transientMilestone]
        )
        let level2 = ThemeLevel(
            id: "level_2",
            displayName: "Level Two",
            order: 2,
            flavorText: "Things pick up.",
            artworkAsset: "level_2_art",
            advanceRequirement: ResourceBundle(["gold": 100_000]),
            levelResources: [],
            units: [.simpleUnit],
            milestones: []
        )
        return MockThemePackage(
            schemaVersion: "1.0",
            gameID: "mock-game",
            displayName: "Mock Game",
            bundleID: "com.test.mock",
            primaryCurrency: "gold",
            primaryCurrencyIcon: "coin",
            themeColors: .fixture,
            levels: [level1, level2],
            events: [],
            characters: [],
            iapProducts: .empty,
            leaderboards: .empty,
            copy: .fixture
        )
    }
}

// MARK: - ThemeColors fixture

extension ThemeColors {
    static let fixture = ThemeColors(
        background: "#0D0D0F",
        surface: "#1A1A20",
        surfaceElevated: "#252530",
        textPrimary: "#F5F5F5",
        textSecondary: "#A0A0B0",
        goldAccent: "#FFD700",
        levelColors: []
    )
}

// MARK: - ThemeCopy fixture

extension ThemeCopy {
    static let fixture = ThemeCopy(
        unitNoun: "Building",
        unitNounPlural: "Buildings",
        levelNoun: "Level",
        milestoneNoun: "Milestone",
        characterNoun: "Character",
        characterNounPlural: "Characters",
        premiumPassName: "Premium Pass",
        advanceVerb: "Advance",
        prestigeTitle: "New Level!",
        startMilestoneButton: "Build Milestone",
        continueButton: "Continue",
        levelCompleteSubtitle: "Level Complete!",
        leaderboardEmptyState: "No leaderboard data yet",
        studioPointsTitle: "Studio Points",
        studioPointsTagline: "Earn points across all studio games",
        crossPromoTitle: "New Game",
        crossPromoAvailableLabel: "Available now",
        leaderboardTabLabel: "Leaderboard",
        socialTabLabel: "Social",
        settingsTabLabel: "Settings",
        offlineSheet: OfflineSheetCopy(
            title: "You earned resources!",
            body: "You were away.",
            collectButton: "Collect",
            doubleButton: "Double it!",
            capNote: "Income was capped at %dh"
        ),
        notifications: NotificationsCopy(
            offlineCapTitle: "Resources capped!",
            offlineCapBody: "Come collect.",
            dailyQuestTitle: "Daily quests ready!",
            dailyQuestBody: "Complete them for rewards.",
            weeklyEventTitle: "New event!",
            levelReadyTitle: "Ready to advance!",
            levelReadyBody: "You can advance now."
        ),
        notificationPermission: NotificationPermissionCopy(
            title: "Stay informed",
            body: "Get notified when you're capped.",
            enableButton: "Enable",
            laterButton: "Later"
        ),
        onboarding: [],
        // Explicit paywall copy. The validator rejects a theme that declares a subscription
        // while leaving `onboardingCopy` at the engine default, because that ships a real
        // subscription behind placeholder marketing text.
        onboardingCopy: ThemeCopy.OnboardingCopy(
            welcomeTitle: "Welcome",
            welcomeTagline: "A mock game for tests.",
            beginButton: "Begin",
            heroArtworkAsset: "artwork_level_1",
            paywallTitle: "Go Premium",
            paywallSubtitle: "Unlock everything.",
            paywallBulletPoints: ["2× offline income"],
            paywallSkipButton: "Start for Free",
            paywallRestoreButton: "Restore Purchases",
            paywallBestValueBadge: "Best Value",
            paywallNoProductsMessage: "Store unavailable.",
            paywallMonthlyLabel: "Monthly",
            paywallAnnualLabel: "Annual"
        ),
        privacyPolicyURL: "https://idle-studio.example/privacy",
        termsOfUseURL: "https://idle-studio.example/terms"
    )
}

// MARK: - GameState builder helpers

extension GameState {
    /// Convenience: start from initial and apply gold directly (skips production tick).
    func withGold(_ gold: Decimal) -> GameState {
        applying(production: ResourceBundle(["gold": gold]), primaryCurrency: "gold")
    }

    /// Applies production using "gold" as the primary currency — the default for fixtures.
    func applyingGold(_ bundle: ResourceBundle) -> GameState {
        applying(production: bundle, primaryCurrency: "gold")
    }
}
