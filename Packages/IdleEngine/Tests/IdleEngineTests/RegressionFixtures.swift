import Foundation
@testable import IdleEngine

/// Self-contained fixtures for the regression suites.
///
/// Deliberately does **not** reuse `TestFixtures.swift`. These suites exist to lock in
/// specific defects that reached production, so they must keep failing for those reasons
/// alone — never because a fixture shared with the general-purpose suites drifted.
enum RegressionFixtures {

    // MARK: - Constants

    /// Mid-range cost multiplier — inside the validator's 1.07…1.20 band.
    static let standardCostMultiplier = Decimal(string: "1.15")!

    /// The count at which `Decimal` exponentiation of a 1.15 multiplier overflows to NaN.
    /// Costs at or beyond this are NaN, and `ResourceBundle.canAfford` must reject them.
    static let decimalOverflowUnitCount = 2_728

    // MARK: - Units

    /// A unit that satisfies every `ThemeValidator` rule.
    static func unit(
        id: String,
        baseCost: Decimal = 10,
        production: Decimal = 1,
        costMultiplier: Decimal = Decimal(string: "1.15")!,
        resource: String = "gold"
    ) -> ThemeUnit {
        ThemeUnit(
            id: id,
            displayName: "Unit \(id)",
            description: "Regression fixture unit",
            iconAsset: "icon_\(id)",
            baseCost: ResourceBundle([resource: baseCost]),
            costMultiplier: costMultiplier,
            baseProductionPerSecond: ResourceBundle([resource: production]),
            managerThreshold: 10,
            upgradeTiers: [
                ThemeUpgradeTier(atCount: 10, multiplier: Decimal(string: "1.5")!),
                ThemeUpgradeTier(atCount: 25, multiplier: 2),
                ThemeUpgradeTier(atCount: 50, multiplier: 3),
                ThemeUpgradeTier(atCount: 100, multiplier: 6)
            ]
        )
    }

    /// 10 gold base cost, ×1.15 scaling, 0.1 gold/s.
    static let campfire = unit(id: "campfire", baseCost: 10, production: Decimal(string: "0.1")!)

    /// Two plain 1 gold/s units, used to prove milestone bonus scoping.
    static let bonusUnitA = unit(id: "bonus_a", baseCost: 10, production: 1)
    static let bonusUnitB = unit(id: "bonus_b", baseCost: 10, production: 1)

    // MARK: - Milestones

    static func milestone(
        id: String,
        requirements: ResourceBundle = ResourceBundle(["gold": 1_000]),
        constructionSeconds: Int = 1_800,
        skipCostCoins: Int = 50,
        canSkipWithAd: Bool = true,
        bonuses: [ThemeBonus] = [],
        isPermanentBonus: Bool = false
    ) -> ThemeMilestone {
        ThemeMilestone(
            id: id,
            displayName: "Milestone \(id)",
            description: "Regression fixture milestone",
            artworkAsset: "ms_\(id)",
            requirements: requirements,
            constructionSeconds: constructionSeconds,
            skipCostCoins: skipCostCoins,
            canSkipWithAd: canSkipWithAd,
            bonuses: bonuses,
            isPermanentBonus: isPermanentBonus
        )
    }

    // MARK: - Theme

    /// ID of the level-1 milestone the theme marks ad-skippable.
    static let adSkippableMilestoneID = "wonder_skippable"
    /// ID of the level-1 milestone the theme marks **not** ad-skippable — the long
    /// late-game construction that must stay behind the coin sink.
    static let adLockedMilestoneID = "wonder_ad_locked"
    static let adSkippableSkipCost = 75
    static let adLockedSkipCost = 900

    /// First purchasable unit of level 1.
    static let firstUnitID = "unit_1_a"

    /// A four-level theme that passes `ThemeValidator.validate` unmodified.
    ///
    /// Four levels is the validator's minimum; the advance requirements step by exactly
    /// 10× because anything less is rejected as a balance error.
    static func validTheme(
        gameID: String = "regression-game",
        achievements: [ThemeAchievement] = [],
        prestigeRequirementMilestoneID: String? = nil
    ) -> JSONThemePackage {
        let levelIDs = (1...4).map { "level_\($0)" }
        var levels: [ThemeLevel] = []
        var advanceGold: Decimal = 1_000

        for (index, levelID) in levelIDs.enumerated() {
            let order = index + 1
            let units = ["a", "b", "c"].map { suffix in
                unit(id: "unit_\(order)_\(suffix)", baseCost: Decimal(10 * order), production: Decimal(order))
            }
            let milestones: [ThemeMilestone]
            if order == 1 {
                milestones = [
                    milestone(
                        id: adSkippableMilestoneID,
                        requirements: ResourceBundle(["gold": 500]),
                        constructionSeconds: 1_800,
                        skipCostCoins: adSkippableSkipCost,
                        canSkipWithAd: true
                    ),
                    milestone(
                        id: adLockedMilestoneID,
                        requirements: ResourceBundle(["gold": 800]),
                        // 20 hours — the prestige-gate shape. Never ad-skippable.
                        constructionSeconds: 72_000,
                        skipCostCoins: adLockedSkipCost,
                        canSkipWithAd: false,
                        isPermanentBonus: true
                    )
                ]
            } else {
                milestones = [
                    milestone(
                        id: "wonder_\(order)",
                        requirements: ResourceBundle(["gold": advanceGold / 2]),
                        constructionSeconds: 3_600,
                        skipCostCoins: 100 * order,
                        canSkipWithAd: true
                    )
                ]
            }

            levels.append(
                ThemeLevel(
                    id: levelID,
                    displayName: "Level \(order)",
                    order: order,
                    flavorText: "Stage \(order).",
                    artworkAsset: "art_\(levelID)",
                    advanceRequirement: ResourceBundle(["gold": advanceGold]),
                    levelResources: [],
                    units: units,
                    milestones: milestones
                )
            )
            advanceGold *= 10
        }

        return JSONThemePackage(
            schemaVersion: ThemeValidator.engineSchemaVersion,
            gameID: gameID,
            displayName: "Regression Game",
            bundleID: "com.test.regression",
            primaryCurrency: "gold",
            primaryCurrencyIcon: "coin",
            themeColors: colors(levelIDs: levelIDs),
            levels: levels,
            events: [],
            characters: [],
            iapProducts: .empty,
            leaderboards: .empty,
            copy: copy,
            achievements: achievements,
            prestigeRequirementMilestoneID: prestigeRequirementMilestoneID
        )
    }

    static func colors(levelIDs: [String]) -> ThemeColors {
        ThemeColors(
            background: "#0D0D0F",
            surface: "#1A1A20",
            surfaceElevated: "#252530",
            textPrimary: "#F5F5F5",
            textSecondary: "#A0A0B0",
            goldAccent: "#FFD700",
            levelColors: levelIDs.map {
                ThemeLevelColor(levelID: $0, primary: "#C0894F", secondary: "#6B4A2A")
            }
        )
    }

    static let copy = ThemeCopy(
        unitNoun: "Building",
        unitNounPlural: "Buildings",
        levelNoun: "Era",
        milestoneNoun: "Wonder",
        characterNoun: "Leader",
        characterNounPlural: "Leaders",
        premiumPassName: "Empire Pass",
        advanceVerb: "Advance",
        prestigeTitle: "New Age",
        startMilestoneButton: "Build Wonder",
        continueButton: "Continue",
        levelCompleteSubtitle: "Era Complete!",
        leaderboardEmptyState: "No leaderboard data yet",
        studioPointsTitle: "Studio Points",
        studioPointsTagline: "Earn points across all studio games",
        crossPromoTitle: "New Game",
        crossPromoAvailableLabel: "Available now",
        leaderboardTabLabel: "Leaderboard",
        socialTabLabel: "Social",
        settingsTabLabel: "Settings",
        offlineSheet: ThemeCopy.OfflineSheetCopy(
            title: "You earned resources!",
            body: "You were away.",
            collectButton: "Collect",
            doubleButton: "Double it!",
            capNote: "Income was capped at %dh"
        ),
        notifications: ThemeCopy.NotificationsCopy(
            offlineCapTitle: "Resources capped!",
            offlineCapBody: "Come collect.",
            dailyQuestTitle: "Daily quests ready!",
            dailyQuestBody: "Complete them for rewards.",
            weeklyEventTitle: "New event!",
            levelReadyTitle: "Ready to advance!",
            levelReadyBody: "You can advance now."
        ),
        notificationPermission: ThemeCopy.NotificationPermissionCopy(
            title: "Stay informed",
            body: "Get notified when you're capped.",
            enableButton: "Enable",
            laterButton: "Later"
        ),
        onboarding: []
    )

    // MARK: - States

    /// Fixed dates so encode/decode comparisons are exact rather than time-dependent.
    static let sessionStart = Date(timeIntervalSince1970: 1_700_000_000)
    static let lastSave = Date(timeIntervalSince1970: 1_700_003_600)
    static let constructionEnd = Date(timeIntervalSince1970: 1_700_007_200)

    /// Unit counts summing to 1,842 — a realistic late-game roster, not a toy one.
    static let populatedUnitCounts: [String: Int] = [
        "campfire": 412,
        "hut": 388,
        "granary": 297,
        "quarry": 265,
        "forge": 231,
        "library": 149,
        "aqueduct": 100
    ]

    /// A deliberately maximal `GameState`: every field non-default, every collection
    /// non-empty, both optionals non-nil, and magnitudes at real endgame scale.
    ///
    /// A round-trip test built on `GameState.initial` proves almost nothing — most fields
    /// are zero or empty, so a dropped field still compares equal.
    static func populatedState() -> GameState {
        GameState(
            currentLevelID: "level_industrial",
            resources: ResourceBundle([
                "gold": Decimal(string: "1e28")!,
                "bronze": Decimal(string: "420000000000")!,
                "iron": Decimal(string: "9870000.5")!,
                "coins": 12_500
            ]),
            unitCounts: populatedUnitCounts,
            completedMilestoneIDs: ["wonder_pyramids", "wonder_colosseum", "wonder_cathedral"],
            purchasedUpgradeIDs: ["upg_bronze_tools", "upg_iron_plows"],
            prestigeTokens: Decimal(string: "18446")!,
            totalPrestigeCount: 37,
            totalLifetimeGold: Decimal(string: "9.87e31")!,
            sessionStartDate: sessionStart,
            lastSaveDate: lastSave,
            studioPoints: 4_275,
            earnedAchievementIDs: ["ach_first_gold", "ach_ten_wonders", "ach_marathon"],
            totalPlaySeconds: 1_234_567,
            inProgressMilestoneID: "wonder_great_wall",
            milestoneConstructionEndDate: constructionEnd
        )
    }

    /// Total units owned in `populatedState()`.
    static let populatedTotalUnits = 1_842

    // MARK: - Coders

    /// Mirrors the date strategy pinned inside `SwiftDataPersistenceService`. If those two
    /// ever diverge, every shipped save becomes unreadable — so the tests use the same pair.
    /// The engine's own coders. Using a parallel copy here is how the two configurations
    /// drift apart, which is the failure mode this fixture exists to guard against.
    static var encoder: JSONEncoder { SwiftDataPersistenceService.encoder }

    static var decoder: JSONDecoder { SwiftDataPersistenceService.decoder }
}
