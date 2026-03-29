import Foundation

// MARK: - Protocol

/// The complete contract a game must satisfy to run on the IdleEngine.
/// Every game is a JSON file that decodes into a type conforming to this protocol.
/// The engine contains ZERO hardcoded display strings, colors, or game vocabulary.
public protocol ThemePackage: Sendable {
    /// Must match `ThemeValidator.engineSchemaVersion`. Validated at startup.
    var schemaVersion: String { get }
    var gameID: String { get }
    var displayName: String { get }
    var bundleID: String { get }
    var primaryCurrency: String { get }
    var primaryCurrencyIcon: String { get }
    var themeColors: ThemeColors { get }

    /// Ordered progression stages (eras, cuisines, divisions — theme decides the word).
    var levels: [ThemeLevel] { get }

    var events: [ThemeEvent] { get }
    var characters: [ThemeCharacter] { get }
    var iapProducts: ThemeIAPProducts { get }
    var leaderboards: ThemeLeaderboards { get }
    var copy: ThemeCopy { get }

    /// All achievements defined for this game. Empty by default — games opt in via JSON.
    var achievements: [ThemeAchievement] { get }
    /// ID of the milestone that must be completed before prestige is available.
    /// nil = only the legacy token check applies.
    var prestigeRequirementMilestoneID: String? { get }
}

public extension ThemePackage {
    var achievements: [ThemeAchievement] { [] }
    var prestigeRequirementMilestoneID: String? { nil }
}

// MARK: - Protocol Extensions

public extension ThemePackage {
    /// All units across all levels, in level order.
    var allUnits: [ThemeUnit] {
        levels.sorted { $0.order < $1.order }.flatMap { $0.units }
    }

    /// All milestones across all levels, in level order.
    var allMilestones: [ThemeMilestone] {
        levels.sorted { $0.order < $1.order }.flatMap { $0.milestones }
    }

    /// The first level in progression order.
    var initialLevel: ThemeLevel? {
        levels.min(by: { $0.order < $1.order })
    }

    func unit(id: String) -> ThemeUnit? {
        levels.flatMap { $0.units }.first { $0.id == id }
    }

    func level(id: String) -> ThemeLevel? {
        levels.first { $0.id == id }
    }

    func milestone(id: String) -> ThemeMilestone? {
        levels.flatMap { $0.milestones }.first { $0.id == id }
    }

    func nextLevel(after levelID: String) -> ThemeLevel? {
        let sorted = levels.sorted { $0.order < $1.order }
        guard let idx = sorted.firstIndex(where: { $0.id == levelID }),
              idx + 1 < sorted.count else { return nil }
        return sorted[idx + 1]
    }
}

// MARK: - ThemeLevel

public struct ThemeLevel: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    /// Sequential 1-based order. No gaps allowed.
    public let order: Int
    public let flavorText: String
    public let artworkAsset: String
    /// Ambient audio filename (no extension) in the app bundle, e.g. "ambient_stone_age".
    /// nil = no ambient audio for this era.
    public let soundAsset: String?
    /// Gold (or other resources) required to advance past this level.
    public let advanceRequirement: ResourceBundle
    /// IDs of secondary resources available in this level (max 2, never "gold").
    public let levelResources: [String]
    public let units: [ThemeUnit]
    public let milestones: [ThemeMilestone]
    /// Permanent upgrades purchasable with this era's secondary resource.
    public let eraUpgrades: [ThemeEraUpgrade]

    public init(
        id: String, displayName: String, order: Int, flavorText: String,
        artworkAsset: String, soundAsset: String? = nil, advanceRequirement: ResourceBundle,
        levelResources: [String], units: [ThemeUnit], milestones: [ThemeMilestone],
        eraUpgrades: [ThemeEraUpgrade] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.order = order
        self.flavorText = flavorText
        self.artworkAsset = artworkAsset
        self.soundAsset = soundAsset
        self.advanceRequirement = advanceRequirement
        self.levelResources = levelResources
        self.units = units
        self.milestones = milestones
        self.eraUpgrades = eraUpgrades
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        order = try c.decode(Int.self, forKey: .order)
        flavorText = try c.decode(String.self, forKey: .flavorText)
        artworkAsset = try c.decode(String.self, forKey: .artworkAsset)
        soundAsset = try c.decodeIfPresent(String.self, forKey: .soundAsset)
        advanceRequirement = try c.decode(ResourceBundle.self, forKey: .advanceRequirement)
        levelResources = try c.decode([String].self, forKey: .levelResources)
        units = try c.decode([ThemeUnit].self, forKey: .units)
        milestones = try c.decode([ThemeMilestone].self, forKey: .milestones)
        eraUpgrades = try c.decodeIfPresent([ThemeEraUpgrade].self, forKey: .eraUpgrades) ?? []
    }
}

// MARK: - ThemeEraUpgrade

/// A one-time purchasable upgrade for an era, bought with its secondary resource.
/// Effects stack multiplicatively with all other bonuses.
public struct ThemeEraUpgrade: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    /// Cost in secondary resources (e.g. `{"bronze": 500}`).
    public let cost: ResourceBundle
    /// Multiplier applied to all unit production this era. 1.0 = no effect.
    public let productionMultiplier: Decimal
    /// Fraction by which all unit costs are reduced. 0.0 = no discount, 0.15 = −15%.
    public let costDiscountFraction: Decimal
    /// Multiplier applied to offline income duration cap. 1.0 = no effect.
    public let offlineMultiplier: Decimal

    public init(
        id: String, displayName: String, description: String,
        cost: ResourceBundle,
        productionMultiplier: Decimal = 1,
        costDiscountFraction: Decimal = 0,
        offlineMultiplier: Decimal = 1
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.cost = cost
        self.productionMultiplier = productionMultiplier
        self.costDiscountFraction = costDiscountFraction
        self.offlineMultiplier = offlineMultiplier
    }
}

// MARK: - ThemeUnit

public struct ThemeUnit: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let iconAsset: String
    public let baseCost: ResourceBundle
    /// Per-unit cost scaling factor. Engine validates 1.07–1.20.
    public let costMultiplier: Decimal
    public let baseProductionPerSecond: ResourceBundle
    /// Unit auto-runs when owned count reaches this threshold.
    public let managerThreshold: Int
    /// Production multiplier tiers applied cumulatively.
    public let upgradeTiers: [ThemeUpgradeTier]

    public init(
        id: String, displayName: String, description: String, iconAsset: String,
        baseCost: ResourceBundle, costMultiplier: Decimal,
        baseProductionPerSecond: ResourceBundle, managerThreshold: Int,
        upgradeTiers: [ThemeUpgradeTier]
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.iconAsset = iconAsset
        self.baseCost = baseCost
        self.costMultiplier = costMultiplier
        self.baseProductionPerSecond = baseProductionPerSecond
        self.managerThreshold = managerThreshold
        self.upgradeTiers = upgradeTiers
    }
}

public struct ThemeUpgradeTier: Sendable, Equatable, Codable {
    /// Unit count at which this tier activates.
    public let atCount: Int
    /// Multiplier applied to production when this tier is active.
    public let multiplier: Decimal

    public init(atCount: Int, multiplier: Decimal) {
        self.atCount = atCount
        self.multiplier = multiplier
    }
}

// MARK: - ThemeMilestone

public struct ThemeMilestone: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let artworkAsset: String
    public let requirements: ResourceBundle
    public let constructionSeconds: Int
    public let skipCostCoins: Int
    public let canSkipWithAd: Bool
    public let bonuses: [ThemeBonus]
    /// If true, this milestone's bonuses survive a prestige reset.
    public let isPermanentBonus: Bool

    public init(
        id: String, displayName: String, description: String, artworkAsset: String,
        requirements: ResourceBundle, constructionSeconds: Int, skipCostCoins: Int,
        canSkipWithAd: Bool, bonuses: [ThemeBonus], isPermanentBonus: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.artworkAsset = artworkAsset
        self.requirements = requirements
        self.constructionSeconds = constructionSeconds
        self.skipCostCoins = skipCostCoins
        self.canSkipWithAd = canSkipWithAd
        self.bonuses = bonuses
        self.isPermanentBonus = isPermanentBonus
    }
}

public struct ThemeBonus: Sendable, Equatable, Codable {
    public enum BonusType: String, Sendable, Equatable, Codable {
        case multiply
        case add
    }
    public enum BonusScope: String, Sendable, Equatable, Codable {
        case level
        case global
        case unit
    }
    public let type: BonusType
    public let scope: BonusScope
    public let resource: String
    public let value: Decimal
    /// Non-nil when scope == .unit — restricts bonus to a specific unit ID.
    public let unitID: String?

    public init(type: BonusType, scope: BonusScope, resource: String, value: Decimal, unitID: String? = nil) {
        self.type = type
        self.scope = scope
        self.resource = resource
        self.value = value
        self.unitID = unitID
    }
}

// MARK: - ThemeEvent

public struct ThemeEvent: Sendable, Equatable, Codable, Identifiable {
    public enum EventType: String, Sendable, Equatable, Codable {
        case weekly
        case seasonal
    }
    public let id: String
    public let displayName: String
    public let type: EventType
    public let durationSeconds: Int
    /// Minimum level order required to participate.
    public let eligibleFromLevelOrder: Int
    public let bonuses: [ThemeEventBonus]
    /// Analytics field used to rank this event's leaderboard.
    public let leaderboardMetric: String
    public let rewards: ThemeEventRewards

    public init(
        id: String, displayName: String, type: EventType, durationSeconds: Int,
        eligibleFromLevelOrder: Int, bonuses: [ThemeEventBonus],
        leaderboardMetric: String, rewards: ThemeEventRewards
    ) {
        self.id = id
        self.displayName = displayName
        self.type = type
        self.durationSeconds = durationSeconds
        self.eligibleFromLevelOrder = eligibleFromLevelOrder
        self.bonuses = bonuses
        self.leaderboardMetric = leaderboardMetric
        self.rewards = rewards
    }
}

public struct ThemeEventBonus: Sendable, Equatable, Codable {
    public let resource: String
    public let multiplier: Decimal

    public init(resource: String, multiplier: Decimal) {
        self.resource = resource
        self.multiplier = multiplier
    }
}

public struct ThemeEventRewards: Sendable, Equatable, Codable {
    public let top25pct: ThemeEventReward?
    public let top10pct: ThemeEventReward?
    public let top1pct: ThemeEventReward?

    public init(top25pct: ThemeEventReward? = nil, top10pct: ThemeEventReward? = nil, top1pct: ThemeEventReward? = nil) {
        self.top25pct = top25pct
        self.top10pct = top10pct
        self.top1pct = top1pct
    }
}

public struct ThemeEventReward: Sendable, Equatable, Codable {
    public let type: String
    public let id: String

    public init(type: String, id: String) {
        self.type = type
        self.id = id
    }
}

// MARK: - ThemeCharacter

public struct ThemeCharacter: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let portraitAsset: String
    public let unlockCondition: ThemeUnlockCondition
    public let bonuses: [ThemeCharacterBonus]
    public let quote: String

    public init(
        id: String, displayName: String, portraitAsset: String,
        unlockCondition: ThemeUnlockCondition, bonuses: [ThemeCharacterBonus], quote: String
    ) {
        self.id = id
        self.displayName = displayName
        self.portraitAsset = portraitAsset
        self.unlockCondition = unlockCondition
        self.bonuses = bonuses
        self.quote = quote
    }
}

public struct ThemeUnlockCondition: Sendable, Equatable, Codable {
    public let type: String
    public let levelID: String?
    public let milestoneID: String?

    public init(type: String, levelID: String? = nil, milestoneID: String? = nil) {
        self.type = type
        self.levelID = levelID
        self.milestoneID = milestoneID
    }
}

public struct ThemeCharacterBonus: Sendable, Equatable, Codable {
    public let unitID: String
    public let multiplier: Decimal

    public init(unitID: String, multiplier: Decimal) {
        self.unitID = unitID
        self.multiplier = multiplier
    }
}

// MARK: - ThemeIAPProducts

public struct ThemeIAPProducts: Sendable, Equatable, Codable {
    public let starterPack: String?
    public let removeAds: String?
    public let premiumPass: String?
    public let premiumPassAnnual: String?
    public let coins1000: String?
    public let coins5000: String?
    public let coins15000: String?
    public let coins30000: String?
    public let coins75000: String?
    public let lifetimePack: String?

    public init(
        starterPack: String? = nil, removeAds: String? = nil,
        premiumPass: String? = nil, premiumPassAnnual: String? = nil,
        coins1000: String? = nil, coins5000: String? = nil,
        coins15000: String? = nil, coins30000: String? = nil,
        coins75000: String? = nil, lifetimePack: String? = nil
    ) {
        self.starterPack = starterPack
        self.removeAds = removeAds
        self.premiumPass = premiumPass
        self.premiumPassAnnual = premiumPassAnnual
        self.coins1000 = coins1000
        self.coins5000 = coins5000
        self.coins15000 = coins15000
        self.coins30000 = coins30000
        self.coins75000 = coins75000
        self.lifetimePack = lifetimePack
    }

    public static let empty = ThemeIAPProducts()
}

// MARK: - ThemeLeaderboards

public struct ThemeLeaderboards: Sendable, Equatable, Codable {
    public let globalTokens: String
    public let weeklyGold: String
    public let countryTokens: String?

    public init(globalTokens: String, weeklyGold: String, countryTokens: String? = nil) {
        self.globalTokens = globalTokens
        self.weeklyGold = weeklyGold
        self.countryTokens = countryTokens
    }

    public static let empty = ThemeLeaderboards(globalTokens: "", weeklyGold: "")
}

// MARK: - ThemeAchievement

/// A badge-style achievement the player can unlock. Evaluated automatically by the engine.
public struct ThemeAchievement: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let category: AchievementCategory
    /// SF Symbol name for the badge icon.
    public let iconSymbol: String
    /// Two hex color strings used for the badge gradient, e.g. ["#F59E0B", "#D97706"].
    public let badgeColors: [String]
    public let condition: AchievementCondition
    /// If true, the badge is hidden until earned.
    public let isSecret: Bool

    public init(
        id: String, displayName: String, description: String,
        category: AchievementCategory, iconSymbol: String, badgeColors: [String],
        condition: AchievementCondition, isSecret: Bool = false
    ) {
        self.id = id; self.displayName = displayName; self.description = description
        self.category = category; self.iconSymbol = iconSymbol; self.badgeColors = badgeColors
        self.condition = condition; self.isSecret = isSecret
    }
}

public enum AchievementCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case progression, economy, prestige, wonders, collector, dedication

    public var displayName: String {
        switch self {
        case .progression: return "Progression"
        case .economy:     return "Economy"
        case .prestige:    return "Prestige"
        case .wonders:     return "Wonders"
        case .collector:   return "Collector"
        case .dedication:  return "Dedication"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .progression: return "arrow.up.forward.circle.fill"
        case .economy:     return "dollarsign.circle.fill"
        case .prestige:    return "crown.fill"
        case .wonders:     return "building.columns.fill"
        case .collector:   return "square.grid.2x2.fill"
        case .dedication:  return "clock.fill"
        }
    }
}

/// Condition that must be satisfied for an achievement to be awarded.
/// Uses a flat struct with optional fields to stay cleanly Codable.
public struct AchievementCondition: Sendable, Equatable, Codable {
    /// Condition type. One of: "reachLevel", "earnLifetimeGold", "prestigeCount",
    /// "completeMilestone", "completeMilestoneCount", "ownUnitsTotal",
    /// "purchaseUpgradesCount", "totalPlayHours"
    public let type: String
    /// For "reachLevel": minimum level order (1-based).
    public let levelOrder: Int?
    /// For "earnLifetimeGold": gold threshold.
    public let goldAmount: Decimal?
    /// For "prestigeCount", "completeMilestoneCount", "ownUnitsTotal", "purchaseUpgradesCount".
    public let count: Int?
    /// For "completeMilestone": specific milestone ID.
    public let milestoneID: String?
    /// For "totalPlayHours": hours of real play time.
    public let playHours: Int?

    public init(
        type: String, levelOrder: Int? = nil, goldAmount: Decimal? = nil,
        count: Int? = nil, milestoneID: String? = nil, playHours: Int? = nil
    ) {
        self.type = type; self.levelOrder = levelOrder; self.goldAmount = goldAmount
        self.count = count; self.milestoneID = milestoneID; self.playHours = playHours
    }
}

// MARK: - ThemeColors

public struct ThemeColors: Sendable, Equatable, Codable {
    /// Hex color strings (e.g. "#0D0D0F"). Must pass WCAG AA contrast.
    public let background: String
    public let surface: String
    public let surfaceElevated: String
    public let textPrimary: String
    public let textSecondary: String
    public let goldAccent: String
    /// One entry per level, applied to the UI when that level is active.
    public let levelColors: [ThemeLevelColor]

    public init(
        background: String, surface: String, surfaceElevated: String,
        textPrimary: String, textSecondary: String, goldAccent: String,
        levelColors: [ThemeLevelColor]
    ) {
        self.background = background
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.goldAccent = goldAccent
        self.levelColors = levelColors
    }
}

public struct ThemeLevelColor: Sendable, Equatable, Codable {
    public let levelID: String
    public let primary: String
    public let secondary: String

    public init(levelID: String, primary: String, secondary: String) {
        self.levelID = levelID
        self.primary = primary
        self.secondary = secondary
    }
}

// MARK: - ThemeCopy

/// All user-facing strings. Engine never hardcodes display text.
public struct ThemeCopy: Sendable, Equatable, Codable {
    // Vocabulary — theme maps engine terms to game vocabulary
    public let unitNoun: String
    public let unitNounPlural: String
    public let levelNoun: String
    public let milestoneNoun: String
    public let characterNoun: String
    public let characterNounPlural: String
    public let premiumPassName: String
    public let advanceVerb: String
    public let prestigeTitle: String

    // UI labels — all user-visible strings that appear in engine screens
    public let startMilestoneButton: String     // e.g. "Build Wonder", "Place Order"
    public let continueButton: String           // e.g. "Continue"
    public let levelCompleteSubtitle: String    // e.g. "Era Complete!", "Cuisine Mastered!"
    public let leaderboardEmptyState: String    // e.g. "No leaderboard data yet"
    public let studioPointsTitle: String        // e.g. "Studio Points"
    public let studioPointsTagline: String      // e.g. "Earn points across all studio games"
    public let crossPromoTitle: String          // e.g. "New Game"
    public let crossPromoAvailableLabel: String // e.g. "Available now"
    public let leaderboardTabLabel: String      // e.g. "Leaderboard"
    public let socialTabLabel: String           // e.g. "Social"
    public let settingsTabLabel: String         // e.g. "Settings"
    public let achievementsTabLabel: String     // e.g. "Achievements"

    public let offlineSheet: OfflineSheetCopy
    public let prestigeSheet: PrestigeSheetCopy
    public let notifications: NotificationsCopy
    public let notificationPermission: NotificationPermissionCopy
    public let onboarding: [OnboardingStep]

    public init(
        unitNoun: String, unitNounPlural: String, levelNoun: String,
        milestoneNoun: String, characterNoun: String, characterNounPlural: String, premiumPassName: String,
        advanceVerb: String, prestigeTitle: String,
        startMilestoneButton: String, continueButton: String, levelCompleteSubtitle: String,
        leaderboardEmptyState: String, studioPointsTitle: String, studioPointsTagline: String,
        crossPromoTitle: String, crossPromoAvailableLabel: String,
        leaderboardTabLabel: String, socialTabLabel: String, settingsTabLabel: String,
        achievementsTabLabel: String = "Achievements",
        offlineSheet: OfflineSheetCopy, prestigeSheet: PrestigeSheetCopy = .default,
        notifications: NotificationsCopy,
        notificationPermission: NotificationPermissionCopy, onboarding: [OnboardingStep]
    ) {
        self.unitNoun = unitNoun
        self.unitNounPlural = unitNounPlural
        self.levelNoun = levelNoun
        self.milestoneNoun = milestoneNoun
        self.characterNoun = characterNoun
        self.characterNounPlural = characterNounPlural
        self.premiumPassName = premiumPassName
        self.advanceVerb = advanceVerb
        self.prestigeTitle = prestigeTitle
        self.startMilestoneButton = startMilestoneButton
        self.continueButton = continueButton
        self.levelCompleteSubtitle = levelCompleteSubtitle
        self.leaderboardEmptyState = leaderboardEmptyState
        self.studioPointsTitle = studioPointsTitle
        self.studioPointsTagline = studioPointsTagline
        self.crossPromoTitle = crossPromoTitle
        self.crossPromoAvailableLabel = crossPromoAvailableLabel
        self.leaderboardTabLabel = leaderboardTabLabel
        self.socialTabLabel = socialTabLabel
        self.settingsTabLabel = settingsTabLabel
        self.achievementsTabLabel = achievementsTabLabel
        self.offlineSheet = offlineSheet
        self.prestigeSheet = prestigeSheet
        self.notifications = notifications
        self.notificationPermission = notificationPermission
        self.onboarding = onboarding
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unitNoun = try c.decode(String.self, forKey: .unitNoun)
        unitNounPlural = try c.decode(String.self, forKey: .unitNounPlural)
        levelNoun = try c.decode(String.self, forKey: .levelNoun)
        milestoneNoun = try c.decode(String.self, forKey: .milestoneNoun)
        characterNoun = try c.decode(String.self, forKey: .characterNoun)
        characterNounPlural = try c.decode(String.self, forKey: .characterNounPlural)
        premiumPassName = try c.decode(String.self, forKey: .premiumPassName)
        advanceVerb = try c.decode(String.self, forKey: .advanceVerb)
        prestigeTitle = try c.decode(String.self, forKey: .prestigeTitle)
        startMilestoneButton = try c.decode(String.self, forKey: .startMilestoneButton)
        continueButton = try c.decode(String.self, forKey: .continueButton)
        levelCompleteSubtitle = try c.decode(String.self, forKey: .levelCompleteSubtitle)
        leaderboardEmptyState = try c.decode(String.self, forKey: .leaderboardEmptyState)
        studioPointsTitle = try c.decode(String.self, forKey: .studioPointsTitle)
        studioPointsTagline = try c.decode(String.self, forKey: .studioPointsTagline)
        crossPromoTitle = try c.decode(String.self, forKey: .crossPromoTitle)
        crossPromoAvailableLabel = try c.decode(String.self, forKey: .crossPromoAvailableLabel)
        leaderboardTabLabel = try c.decode(String.self, forKey: .leaderboardTabLabel)
        socialTabLabel = try c.decode(String.self, forKey: .socialTabLabel)
        settingsTabLabel = try c.decode(String.self, forKey: .settingsTabLabel)
        achievementsTabLabel = try c.decodeIfPresent(String.self, forKey: .achievementsTabLabel) ?? "Achievements"
        offlineSheet = try c.decode(OfflineSheetCopy.self, forKey: .offlineSheet)
        prestigeSheet = try c.decodeIfPresent(PrestigeSheetCopy.self, forKey: .prestigeSheet) ?? .default
        notifications = try c.decode(NotificationsCopy.self, forKey: .notifications)
        notificationPermission = try c.decode(NotificationPermissionCopy.self, forKey: .notificationPermission)
        onboarding = try c.decode([OnboardingStep].self, forKey: .onboarding)
    }

    public struct OfflineSheetCopy: Sendable, Equatable, Codable {
        public let title: String
        public let body: String
        public let collectButton: String
        public let doubleButton: String
        /// C-style format string with one `%d` placeholder for the hour count.
        /// e.g. `"Income was capped at %dh"`.
        public let capNote: String

        public init(title: String, body: String, collectButton: String, doubleButton: String, capNote: String) {
            self.title = title
            self.body = body
            self.collectButton = collectButton
            self.doubleButton = doubleButton
            self.capNote = capNote
        }
    }

    public struct PrestigeSheetCopy: Sendable, Equatable, Codable {
        public let title: String
        public let subtitle: String
        public let description: String
        public let persistsNote: String
        public let tokensLabel: String
        public let multiplierLabel: String
        public let confirmButton: String
        public let cancelButton: String
        /// C-style format string with one `%@` placeholder for the gate milestone name.
        public let lockedHint: String

        public init(
            title: String, subtitle: String, description: String, persistsNote: String,
            tokensLabel: String, multiplierLabel: String,
            confirmButton: String, cancelButton: String, lockedHint: String
        ) {
            self.title = title; self.subtitle = subtitle; self.description = description
            self.persistsNote = persistsNote; self.tokensLabel = tokensLabel
            self.multiplierLabel = multiplierLabel; self.confirmButton = confirmButton
            self.cancelButton = cancelButton; self.lockedHint = lockedHint
        }

        public static let `default` = PrestigeSheetCopy(
            title: "New Beginning",
            subtitle: "Start again, stronger than before",
            description: "Resources, buildings, and upgrades will be lost.",
            persistsNote: "Permanent Wonders and Legacy Tokens carry over.",
            tokensLabel: "Legacy Tokens Earned",
            multiplierLabel: "New Production Bonus",
            confirmButton: "Reset & Ascend",
            cancelButton: "Not Yet",
            lockedHint: "Complete %@ to unlock"
        )
    }

    public struct NotificationsCopy: Sendable, Equatable, Codable {
        public let offlineCapTitle: String
        public let offlineCapBody: String
        public let dailyQuestTitle: String
        public let dailyQuestBody: String
        public let weeklyEventTitle: String
        public let levelReadyTitle: String
        public let levelReadyBody: String
        public let wonderCompleteTitle: String
        public let wonderCompleteBody: String

        public init(
            offlineCapTitle: String, offlineCapBody: String,
            dailyQuestTitle: String, dailyQuestBody: String,
            weeklyEventTitle: String, levelReadyTitle: String, levelReadyBody: String,
            wonderCompleteTitle: String = "Wonder Complete!",
            wonderCompleteBody: String = "Your wonder is complete. Come see what you've built!"
        ) {
            self.offlineCapTitle = offlineCapTitle
            self.offlineCapBody = offlineCapBody
            self.dailyQuestTitle = dailyQuestTitle
            self.dailyQuestBody = dailyQuestBody
            self.weeklyEventTitle = weeklyEventTitle
            self.levelReadyTitle = levelReadyTitle
            self.levelReadyBody = levelReadyBody
            self.wonderCompleteTitle = wonderCompleteTitle
            self.wonderCompleteBody = wonderCompleteBody
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            offlineCapTitle    = try c.decode(String.self, forKey: .offlineCapTitle)
            offlineCapBody     = try c.decode(String.self, forKey: .offlineCapBody)
            dailyQuestTitle    = try c.decode(String.self, forKey: .dailyQuestTitle)
            dailyQuestBody     = try c.decode(String.self, forKey: .dailyQuestBody)
            weeklyEventTitle   = try c.decode(String.self, forKey: .weeklyEventTitle)
            levelReadyTitle    = try c.decode(String.self, forKey: .levelReadyTitle)
            levelReadyBody     = try c.decode(String.self, forKey: .levelReadyBody)
            wonderCompleteTitle = try c.decodeIfPresent(String.self, forKey: .wonderCompleteTitle) ?? "Wonder Complete!"
            wonderCompleteBody  = try c.decodeIfPresent(String.self, forKey: .wonderCompleteBody)  ?? "Your wonder is complete. Come see what you've built!"
        }
    }

    public struct NotificationPermissionCopy: Sendable, Equatable, Codable {
        public let title: String
        public let body: String
        public let bulletPoints: [String]
        public let enableButton: String
        public let laterButton: String

        public init(title: String, body: String, bulletPoints: [String] = [], enableButton: String, laterButton: String) {
            self.title = title
            self.body = body
            self.bulletPoints = bulletPoints
            self.enableButton = enableButton
            self.laterButton = laterButton
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title        = try c.decode(String.self, forKey: .title)
            body         = try c.decode(String.self, forKey: .body)
            bulletPoints = try c.decodeIfPresent([String].self, forKey: .bulletPoints) ?? []
            enableButton = try c.decode(String.self, forKey: .enableButton)
            laterButton  = try c.decode(String.self, forKey: .laterButton)
        }
    }

    public struct OnboardingStep: Sendable, Equatable, Codable {
        public let step: Int
        public let title: String
        public let body: String
        public let highlightTarget: String

        public init(step: Int, title: String, body: String, highlightTarget: String) {
            self.step = step
            self.title = title
            self.body = body
            self.highlightTarget = highlightTarget
        }
    }
}

// MARK: - JSONThemePackage (Codable concrete implementation)

/// Decodes a `.json` file from the app bundle into a fully conformant `ThemePackage`.
/// Handles the nested `"theme": { "colors": {...}, "levelColors": [...] }` JSON structure.
public struct JSONThemePackage: ThemePackage, Sendable {
    public let schemaVersion: String
    public let gameID: String
    public let displayName: String
    public let bundleID: String
    public let primaryCurrency: String
    public let primaryCurrencyIcon: String
    public let themeColors: ThemeColors
    public let levels: [ThemeLevel]
    public let events: [ThemeEvent]
    public let characters: [ThemeCharacter]
    public let iapProducts: ThemeIAPProducts
    public let leaderboards: ThemeLeaderboards
    public let copy: ThemeCopy
    public let achievements: [ThemeAchievement]
    public let prestigeRequirementMilestoneID: String?

    public init(
        schemaVersion: String, gameID: String, displayName: String, bundleID: String,
        primaryCurrency: String, primaryCurrencyIcon: String, themeColors: ThemeColors,
        levels: [ThemeLevel], events: [ThemeEvent], characters: [ThemeCharacter],
        iapProducts: ThemeIAPProducts, leaderboards: ThemeLeaderboards, copy: ThemeCopy,
        achievements: [ThemeAchievement] = [], prestigeRequirementMilestoneID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.gameID = gameID
        self.displayName = displayName
        self.bundleID = bundleID
        self.primaryCurrency = primaryCurrency
        self.primaryCurrencyIcon = primaryCurrencyIcon
        self.themeColors = themeColors
        self.levels = levels
        self.events = events
        self.characters = characters
        self.iapProducts = iapProducts
        self.leaderboards = leaderboards
        self.copy = copy
        self.achievements = achievements
        self.prestigeRequirementMilestoneID = prestigeRequirementMilestoneID
    }
}

extension JSONThemePackage: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, gameID, displayName, bundleID
        case primaryCurrency, primaryCurrencyIcon
        case theme
        case levels, events, characters, iapProducts, leaderboards, copy
        case achievements, prestigeRequirementMilestoneID
    }

    private struct ThemeSection: Codable {
        struct Colors: Codable {
            let background: String
            let surface: String
            let surfaceElevated: String
            let textPrimary: String
            let textSecondary: String
            let goldAccent: String
        }
        let colors: Colors
        let levelColors: [ThemeLevelColor]
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion      = try c.decode(String.self, forKey: .schemaVersion)
        gameID             = try c.decode(String.self, forKey: .gameID)
        displayName        = try c.decode(String.self, forKey: .displayName)
        bundleID           = try c.decode(String.self, forKey: .bundleID)
        primaryCurrency    = try c.decode(String.self, forKey: .primaryCurrency)
        primaryCurrencyIcon = try c.decode(String.self, forKey: .primaryCurrencyIcon)

        let ts = try c.decode(ThemeSection.self, forKey: .theme)
        themeColors = ThemeColors(
            background: ts.colors.background, surface: ts.colors.surface,
            surfaceElevated: ts.colors.surfaceElevated, textPrimary: ts.colors.textPrimary,
            textSecondary: ts.colors.textSecondary, goldAccent: ts.colors.goldAccent,
            levelColors: ts.levelColors
        )

        levels      = try c.decode([ThemeLevel].self,     forKey: .levels)
        events      = try c.decode([ThemeEvent].self,     forKey: .events)
        characters  = try c.decode([ThemeCharacter].self, forKey: .characters)
        iapProducts = try c.decode(ThemeIAPProducts.self, forKey: .iapProducts)
        leaderboards = try c.decode(ThemeLeaderboards.self, forKey: .leaderboards)
        copy        = try c.decode(ThemeCopy.self,        forKey: .copy)
        achievements = try c.decodeIfPresent([ThemeAchievement].self, forKey: .achievements) ?? []
        prestigeRequirementMilestoneID = try c.decodeIfPresent(String.self, forKey: .prestigeRequirementMilestoneID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion,       forKey: .schemaVersion)
        try c.encode(gameID,             forKey: .gameID)
        try c.encode(displayName,        forKey: .displayName)
        try c.encode(bundleID,           forKey: .bundleID)
        try c.encode(primaryCurrency,    forKey: .primaryCurrency)
        try c.encode(primaryCurrencyIcon, forKey: .primaryCurrencyIcon)

        let ts = ThemeSection(
            colors: ThemeSection.Colors(
                background: themeColors.background,
                surface: themeColors.surface,
                surfaceElevated: themeColors.surfaceElevated,
                textPrimary: themeColors.textPrimary,
                textSecondary: themeColors.textSecondary,
                goldAccent: themeColors.goldAccent
            ),
            levelColors: themeColors.levelColors
        )
        try c.encode(ts,           forKey: .theme)
        try c.encode(levels,       forKey: .levels)
        try c.encode(events,       forKey: .events)
        try c.encode(characters,   forKey: .characters)
        try c.encode(iapProducts,  forKey: .iapProducts)
        try c.encode(leaderboards, forKey: .leaderboards)
        try c.encode(copy,         forKey: .copy)
        try c.encode(achievements, forKey: .achievements)
        try c.encodeIfPresent(prestigeRequirementMilestoneID, forKey: .prestigeRequirementMilestoneID)
    }
}
