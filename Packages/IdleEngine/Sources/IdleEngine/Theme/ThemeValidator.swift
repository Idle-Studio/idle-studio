import Foundation

/// Validates a `ThemePackage` against all engine contract rules.
///
/// Two severities, deliberately distinct:
///
/// * **Errors** — the theme is broken. `validate(_:)` throws
///   `EngineError.validationFailed([String])` with the full list, and `GameEngine.loadTheme`
///   refuses the theme. Reserved for defects that make the game unwinnable, unreachable,
///   or rejected by App Review.
/// * **Warnings** — the theme loads and plays, but something is degraded: content that can
///   never be reached, a colour the runtime has to auto-correct, a number close to a
///   precision cliff. Warnings never block a load, because five of the eight shipped
///   Idle Civilizations era accents fail WCAG AA today and promoting that to an error
///   would brick a live game on launch.
///
/// Use `validate(_:)` on the runtime path and `inspect(_:)` (which returns both lists and
/// never throws) from `/validate-theme` and CI.
///
/// Asset existence is checked separately via `validateAssets(theme:availableAssets:)` —
/// the runtime path cannot enumerate the bundle cheaply, but a CLI tool can.
public enum ThemeValidator {

    /// The schema version this engine build supports.
    public static let engineSchemaVersion = "1.0"

    /// Condition types `AchievementEngine.isMet` actually implements. Anything else falls
    /// through its `default:` and returns false forever, so the achievement can never be
    /// earned and no error is ever surfaced at runtime.
    public static let supportedAchievementConditionTypes: Set<String> = [
        "reachLevel", "earnLifetimeGold", "prestigeCount", "completeMilestone",
        "completeMilestoneCount", "ownUnitsTotal", "purchaseUpgradesCount", "totalPlayHours"
    ]

    /// Minimum WCAG contrast ratio for text and for accents that carry live game data.
    public static let minimumContrastRatio: Double = 4.5

    /// Amounts above this are flagged. `Decimal` still holds them, but every consumer that
    /// crosses `NSDecimalNumber.doubleValue` (balance ratios, offline income, leaderboard
    /// scores) loses exactness well before here, and beyond `UInt64.max` the value can no
    /// longer round-trip through the integer paths in the persistence and Game Center
    /// layers at all.
    public static let precisionCeiling = Decimal(UInt64.max)

    // MARK: - Report

    /// Everything a validation pass found, split by severity.
    public struct Report: Sendable, Equatable {
        public let errors: [String]
        public let warnings: [String]

        /// True when nothing blocks the theme from loading. Warnings may still be present.
        public var isValid: Bool { errors.isEmpty }

        public init(errors: [String], warnings: [String]) {
            self.errors = errors
            self.warnings = warnings
        }
    }

    /// Mutable accumulator threaded through every rule so a pass reports everything at once
    /// rather than stopping at the first violation.
    private struct Issues {
        var errors: [String] = []
        var warnings: [String] = []

        mutating func error(_ message: String) { errors.append(message) }
        mutating func warn(_ message: String)  { warnings.append(message) }
    }

    // MARK: - Entry Points

    /// Validate all rules. Collects every violation before throwing so authors see everything
    /// at once. Warnings are not thrown — call `inspect(_:)` to read them.
    public static func validate(_ theme: any ThemePackage) throws {
        let report = inspect(theme)
        guard report.errors.isEmpty else {
            throw EngineError.validationFailed(report.errors)
        }
    }

    /// Run every rule and return both severities without throwing.
    public static func inspect(_ theme: any ThemePackage) -> Report {
        var issues = Issues()
        let index = ThemeIndex(theme)

        validateIdentity(theme, index: index, issues: &issues)
        validateLevels(theme, issues: &issues)
        validateUniqueIDs(theme, issues: &issues)
        validateReferences(theme, index: index, issues: &issues)
        validateEconomy(theme, index: index, issues: &issues)
        validateCopy(theme, issues: &issues)
        validateIAP(theme, issues: &issues)
        validateColors(theme, issues: &issues)
        validateContrast(theme, issues: &issues)

        return Report(errors: issues.errors, warnings: issues.warnings)
    }

    // MARK: - Theme Index

    /// Every ID and produced resource in the theme, resolved once. Referential checks are
    /// all "does this string name something real", and doing that with a linear scan per
    /// reference is quadratic on a 40-unit theme.
    private struct ThemeIndex {
        let unitIDs: Set<String>
        let levelIDs: Set<String>
        let milestoneIDs: Set<String>
        let eraUpgradeIDs: Set<String>
        /// Resource ID → the lowest level order at which some unit produces it.
        let firstProducedOrder: [String: Int]
        let maxLevelOrder: Int
        let milestoneCount: Int
        let eraUpgradeCount: Int
        let primaryCurrency: String

        init(_ theme: any ThemePackage) {
            var units: Set<String> = []
            var levels: Set<String> = []
            var milestones: Set<String> = []
            var upgrades: Set<String> = []
            var produced: [String: Int] = [:]
            var maxOrder = 0
            var milestoneTotal = 0
            var upgradeTotal = 0

            for level in theme.levels {
                levels.insert(level.id)
                maxOrder = max(maxOrder, level.order)
                for unit in level.units {
                    units.insert(unit.id)
                    for (resource, amount) in unit.baseProductionPerSecond.amounts where amount > 0 {
                        produced[resource] = min(produced[resource] ?? level.order, level.order)
                    }
                }
                for milestone in level.milestones {
                    milestones.insert(milestone.id)
                    milestoneTotal += 1
                }
                for upgrade in level.eraUpgrades {
                    upgrades.insert(upgrade.id)
                    upgradeTotal += 1
                }
            }

            self.unitIDs = units
            self.levelIDs = levels
            self.milestoneIDs = milestones
            self.eraUpgradeIDs = upgrades
            self.firstProducedOrder = produced
            self.maxLevelOrder = maxOrder
            self.milestoneCount = milestoneTotal
            self.eraUpgradeCount = upgradeTotal
            self.primaryCurrency = theme.primaryCurrency
        }

        /// A resource is spendable at `order` if the primary currency names it, or some unit
        /// at or before that level produces it.
        func isSpendable(_ resource: String, atOrder order: Int) -> Bool {
            if resource == primaryCurrency { return true }
            guard let firstOrder = firstProducedOrder[resource] else { return false }
            return firstOrder <= order
        }

        /// A resource exists at all if anything produces it, or it is the primary currency.
        func exists(_ resource: String) -> Bool {
            resource == primaryCurrency || firstProducedOrder[resource] != nil
        }
    }

    // MARK: - Identity

    private static func validateIdentity(_ theme: any ThemePackage, index: ThemeIndex, issues: inout Issues) {
        if theme.schemaVersion != engineSchemaVersion {
            issues.error("schemaVersion '\(theme.schemaVersion)' does not match engine version '\(engineSchemaVersion)'")
        }
        if theme.gameID.isEmpty {
            issues.error("gameID must not be empty")
        } else if !isKebabCase(theme.gameID) {
            issues.error("gameID '\(theme.gameID)' must be kebab-case (lowercase alphanumeric and hyphens only)")
        }
        if theme.displayName.isEmpty {
            issues.error("displayName must not be empty")
        }
        if !isValidBundleID(theme.bundleID) {
            issues.error("bundleID '\(theme.bundleID)' must be reverse-domain format (e.g. com.studio.game)")
        }
        if theme.primaryCurrency.isEmpty {
            issues.error("primaryCurrency must not be empty")
        } else if !theme.levels.isEmpty, index.firstProducedOrder[theme.primaryCurrency] == nil {
            // Resource IDs are matched by exact string everywhere in the engine, so a
            // primaryCurrency of "Gold" against production keyed "gold" means the currency
            // the whole economy is denominated in never accrues.
            issues.error("primaryCurrency '\(theme.primaryCurrency)' is not produced by any unit — resource IDs are case-sensitive")
        }
    }

    // MARK: - Levels

    private static func validateLevels(_ theme: any ThemePackage, issues: inout Issues) {
        let levels = theme.levels.sorted { $0.order < $1.order }

        if levels.count < 4 {
            issues.error("Theme must have at least 4 levels (found \(levels.count))")
        }
        if levels.count > 12 {
            issues.error("Theme must have at most 12 levels (found \(levels.count))")
        }

        // Sequential order check
        for (idx, level) in levels.enumerated() {
            let expected = idx + 1
            if level.order != expected {
                issues.error("Level '\(level.id)' has order \(level.order) but expected \(expected) — no gaps allowed")
            }
        }

        // Per-level rules
        var previousAdvanceGold: Decimal? = nil
        for level in levels {
            validateLevel(level, issues: &issues)

            // Balance: advance requirements must grow geometrically (at least 10×)
            let advanceGold = level.advanceRequirement[theme.primaryCurrency]
            if advanceGold <= 0 {
                issues.error("Level '\(level.id)' advanceRequirement gold must be > 0")
            }
            if let prev = previousAdvanceGold, advanceGold > 0, prev > 0 {
                let ratio = NSDecimalNumber(decimal: advanceGold / prev).doubleValue
                if ratio < 10 {
                    issues.error("Level '\(level.id)' advanceRequirement (\(advanceGold)) is less than 10× previous level (\(prev)) — ratio: \(String(format: "%.1f", ratio))×")
                }
            }
            previousAdvanceGold = advanceGold
        }

        // levelColors: one per level
        let colorLevelIDs = Set(theme.themeColors.levelColors.map { $0.levelID })
        for level in levels where !colorLevelIDs.contains(level.id) {
            issues.error("Missing levelColor entry for level '\(level.id)'")
        }
        // …and no stray entries pointing at levels that do not exist.
        let levelIDs = Set(levels.map { $0.id })
        for lc in theme.themeColors.levelColors where !levelIDs.contains(lc.levelID) {
            issues.error("levelColors entry references unknown level '\(lc.levelID)'")
        }
    }

    private static func validateLevel(_ level: ThemeLevel, issues: inout Issues) {
        if level.units.count < 3 {
            issues.error("Level '\(level.id)' must have at least 3 units (found \(level.units.count))")
        }
        if level.units.count > 10 {
            issues.error("Level '\(level.id)' must have at most 10 units (found \(level.units.count))")
        }
        if level.milestones.isEmpty {
            issues.error("Level '\(level.id)' must have at least 1 milestone")
        }
        if level.levelResources.count > 2 {
            issues.error("Level '\(level.id)' levelResources may have at most 2 entries (found \(level.levelResources.count))")
        }
        if level.levelResources.contains("gold") {
            issues.error("Level '\(level.id)' levelResources must not include 'gold' — it is reserved as the universal primary resource")
        }
        for unit in level.units {
            validateUnit(unit, levelID: level.id, issues: &issues)
        }
        for milestone in level.milestones {
            validateMilestone(milestone, levelID: level.id, issues: &issues)
        }
    }

    // MARK: - Units

    private static func validateUnit(_ unit: ThemeUnit, levelID: String, issues: inout Issues) {
        let prefix = "Unit '\(unit.id)' (level '\(levelID)')"

        if unit.id.isEmpty {
            issues.error("\(prefix) id must not be empty")
        }
        if unit.displayName.isEmpty {
            issues.error("\(prefix) displayName must not be empty")
        }

        let mDouble = NSDecimalNumber(decimal: unit.costMultiplier).doubleValue
        if mDouble < 1.07 || mDouble > 1.20 {
            issues.error("\(prefix) costMultiplier \(unit.costMultiplier) must be between 1.07 and 1.20")
        }

        let hasPositiveProduction = unit.baseProductionPerSecond.amounts.values.contains { $0 > 0 }
        if !hasPositiveProduction {
            issues.error("\(prefix) baseProductionPerSecond must be > 0 for at least one resource")
        }

        if unit.managerThreshold < 5 || unit.managerThreshold > 50 {
            issues.error("\(prefix) managerThreshold \(unit.managerThreshold) must be between 5 and 50")
        }

        let tierCounts = Set(unit.upgradeTiers.map { $0.atCount })
        let requiredTiers: Set<Int> = [10, 25, 50, 100]
        let missing = requiredTiers.subtracting(tierCounts)
        if !missing.isEmpty {
            issues.error("\(prefix) missing required upgrade tiers at counts: \(missing.sorted())")
        }
    }

    // MARK: - Milestones

    private static func validateMilestone(_ milestone: ThemeMilestone, levelID: String, issues: inout Issues) {
        let prefix = "Milestone '\(milestone.id)' (level '\(levelID)')"

        if milestone.id.isEmpty {
            issues.error("\(prefix) id must not be empty")
        }
        if milestone.displayName.isEmpty {
            issues.error("\(prefix) displayName must not be empty")
        }
        if milestone.constructionSeconds <= 0 {
            issues.error("\(prefix) constructionSeconds must be > 0")
        }
        if milestone.canSkipWithAd && milestone.constructionSeconds > 3600 {
            issues.error("\(prefix) canSkipWithAd is true but constructionSeconds (\(milestone.constructionSeconds)) exceeds 3600s limit")
        }
    }

    // MARK: - Unique IDs

    /// Every ID namespace in the theme. Duplicates are silent data loss: lookups are
    /// `first(where:)`, so the second entry is unreachable and its artwork, bonuses and
    /// unlock conditions never apply.
    private static func validateUniqueIDs(_ theme: any ThemePackage, issues: inout Issues) {
        func checkDuplicates<T>(_ items: [T], kind: String, id: (T) -> String, owner: (T) -> String? = { _ in nil }) {
            var seen: [String: String?] = [:]
            for item in items {
                let itemID = id(item)
                if let existingOwner = seen[itemID] {
                    if let owner = owner(item), let existingOwner, !existingOwner.isEmpty {
                        issues.error("Duplicate \(kind) ID '\(itemID)' found in levels '\(existingOwner)' and '\(owner)'")
                    } else {
                        issues.error("Duplicate \(kind) ID '\(itemID)'")
                    }
                } else {
                    seen[itemID] = owner(item)
                }
            }
        }

        let levels = theme.levels
        checkDuplicates(levels, kind: "level", id: { $0.id })
        checkDuplicates(
            levels.flatMap { level in level.units.map { (unit: $0, level: level.id) } },
            kind: "unit", id: { $0.unit.id }, owner: { $0.level }
        )
        checkDuplicates(
            levels.flatMap { level in level.milestones.map { (milestone: $0, level: level.id) } },
            kind: "milestone", id: { $0.milestone.id }, owner: { $0.level }
        )
        checkDuplicates(
            levels.flatMap { level in level.eraUpgrades.map { (upgrade: $0, level: level.id) } },
            kind: "eraUpgrade", id: { $0.upgrade.id }, owner: { $0.level }
        )
        checkDuplicates(theme.achievements, kind: "achievement", id: { $0.id })
        checkDuplicates(theme.characters,   kind: "character",   id: { $0.id })
        checkDuplicates(theme.events,       kind: "event",       id: { $0.id })
    }

    // MARK: - Referential Integrity

    /// Every ID reference in the theme must resolve. None of these fail loudly at runtime:
    /// a dangling reference is a `nil` lookup that silently does nothing forever.
    private static func validateReferences(_ theme: any ThemePackage, index: ThemeIndex, issues: inout Issues) {
        // Prestige gate — an unresolvable gate makes prestige permanently unreachable, and
        // `PrestigeSystem` has no way to report that to the player.
        if let gateID = theme.prestigeRequirementMilestoneID {
            if !index.milestoneIDs.contains(gateID) {
                issues.error("prestigeRequirementMilestoneID '\(gateID)' does not match any milestone — prestige would be permanently unreachable")
            }
        } else if !theme.levels.isEmpty {
            issues.warn("prestigeRequirementMilestoneID is not set — prestige is gated only by the legacy-token threshold")
        }

        // Milestone bonuses
        for level in theme.levels {
            for milestone in level.milestones {
                let prefix = "Milestone '\(milestone.id)' bonus"
                for bonus in milestone.bonuses {
                    if bonus.scope == .unit {
                        guard let unitID = bonus.unitID else {
                            issues.error("\(prefix) has scope 'unit' but no unitID — EconomyCalculator skips it entirely")
                            continue
                        }
                        if !index.unitIDs.contains(unitID) {
                            issues.error("\(prefix) references unknown unit '\(unitID)'")
                        }
                    } else if bonus.unitID != nil {
                        issues.warn("\(prefix) sets unitID '\(bonus.unitID ?? "")' but scope is '\(bonus.scope.rawValue)' — the unitID is ignored")
                    }
                    if !index.exists(bonus.resource) {
                        issues.error("\(prefix) targets resource '\(bonus.resource)' which no unit produces and which is not the primary currency")
                    }
                }
            }
        }

        // Characters
        for character in theme.characters {
            let prefix = "Character '\(character.id)'"
            for bonus in character.bonuses where !index.unitIDs.contains(bonus.unitID) {
                issues.error("\(prefix) bonus references unknown unit '\(bonus.unitID)'")
            }
            if let levelID = character.unlockCondition.levelID, !index.levelIDs.contains(levelID) {
                issues.error("\(prefix) unlockCondition references unknown level '\(levelID)'")
            }
            if let milestoneID = character.unlockCondition.milestoneID, !index.milestoneIDs.contains(milestoneID) {
                issues.error("\(prefix) unlockCondition references unknown milestone '\(milestoneID)'")
            }
            if character.unlockCondition.levelID == nil && character.unlockCondition.milestoneID == nil {
                issues.warn("\(prefix) unlockCondition '\(character.unlockCondition.type)' names neither a level nor a milestone — nothing can unlock it")
            }
        }

        // Achievements
        for achievement in theme.achievements {
            validateAchievement(achievement, index: index, issues: &issues)
        }

        // Events
        for event in theme.events {
            let prefix = "Event '\(event.id)'"
            for bonus in event.bonuses where !index.exists(bonus.resource) {
                issues.error("\(prefix) bonus targets resource '\(bonus.resource)' which no unit produces and which is not the primary currency")
            }
            if event.eligibleFromLevelOrder > index.maxLevelOrder {
                issues.error("\(prefix) eligibleFromLevelOrder \(event.eligibleFromLevelOrder) exceeds the highest level order (\(index.maxLevelOrder)) — no player can ever enter it")
            }
        }
    }

    private static func validateAchievement(_ achievement: ThemeAchievement, index: ThemeIndex, issues: inout Issues) {
        let prefix = "Achievement '\(achievement.id)'"
        let condition = achievement.condition

        guard supportedAchievementConditionTypes.contains(condition.type) else {
            issues.error("\(prefix) condition type '\(condition.type)' is not handled by AchievementEngine — it can never be earned. Supported: \(supportedAchievementConditionTypes.sorted().joined(separator: ", "))")
            return
        }

        // Each type reads exactly one payload field, and `AchievementEngine` returns false
        // when it is missing — so an absent field is as dead as an unknown type.
        switch condition.type {
        case "reachLevel":
            guard let order = condition.levelOrder else {
                issues.error("\(prefix) condition 'reachLevel' requires levelOrder")
                return
            }
            if order < 1 || order > index.maxLevelOrder {
                issues.error("\(prefix) condition levelOrder \(order) is outside the theme's level range 1…\(index.maxLevelOrder)")
            }

        case "earnLifetimeGold":
            if condition.goldAmount == nil {
                issues.error("\(prefix) condition 'earnLifetimeGold' requires goldAmount")
            }

        case "completeMilestone":
            guard let milestoneID = condition.milestoneID else {
                issues.error("\(prefix) condition 'completeMilestone' requires milestoneID")
                return
            }
            if !index.milestoneIDs.contains(milestoneID) {
                issues.error("\(prefix) condition references unknown milestone '\(milestoneID)'")
            }

        case "completeMilestoneCount":
            guard let count = condition.count else {
                issues.error("\(prefix) condition 'completeMilestoneCount' requires count")
                return
            }
            if count > index.milestoneCount {
                issues.error("\(prefix) condition requires \(count) milestones but the theme defines \(index.milestoneCount)")
            }

        case "purchaseUpgradesCount":
            guard let count = condition.count else {
                issues.error("\(prefix) condition 'purchaseUpgradesCount' requires count")
                return
            }
            if count > index.eraUpgradeCount {
                issues.error("\(prefix) condition requires \(count) upgrades but the theme defines \(index.eraUpgradeCount) eraUpgrades")
            }

        case "prestigeCount", "ownUnitsTotal":
            if condition.count == nil {
                issues.error("\(prefix) condition '\(condition.type)' requires count")
            }

        case "totalPlayHours":
            if condition.playHours == nil {
                issues.error("\(prefix) condition 'totalPlayHours' requires playHours")
            }

        default:
            break
        }

        if achievement.badgeColors.count != 2 {
            issues.error("\(prefix) badgeColors must have exactly 2 entries (found \(achievement.badgeColors.count))")
        }
        for (idx, hex) in achievement.badgeColors.enumerated() where !isValidHex(hex) {
            issues.error("\(prefix) badgeColors[\(idx)] '\(hex)' is not a valid hex color (expected #RRGGBB)")
        }
        if achievement.iconSymbol.isEmpty {
            issues.error("\(prefix) iconSymbol must not be empty")
        }
    }

    // MARK: - Economy

    /// Soft-lock and numeric-sanity rules. A cost denominated in a resource nothing produces
    /// is an unwinnable game, and the UI shows it as an ordinary unaffordable price.
    private static func validateEconomy(_ theme: any ThemePackage, index: ThemeIndex, issues: inout Issues) {
        for level in theme.levels {
            let order = level.order

            func checkSpendable(_ bundle: ResourceBundle, _ what: String) {
                for resource in bundle.amounts.keys where !index.isSpendable(resource, atOrder: order) {
                    if index.exists(resource) {
                        let firstOrder = index.firstProducedOrder[resource] ?? 0
                        issues.error("\(what) costs '\(resource)', which is first produced at level order \(firstOrder) — after this level (order \(order))")
                    } else {
                        issues.error("\(what) costs '\(resource)', which no unit produces and which is not the primary currency — unreachable")
                    }
                }
            }

            checkNumbers(level.advanceRequirement, "Level '\(level.id)' advanceRequirement", issues: &issues)
            checkSpendable(level.advanceRequirement, "Level '\(level.id)' advanceRequirement")

            for unit in level.units {
                checkNumbers(unit.baseCost, "Unit '\(unit.id)' baseCost", issues: &issues)
                checkNumbers(unit.baseProductionPerSecond, "Unit '\(unit.id)' baseProductionPerSecond", issues: &issues)
                checkSpendable(unit.baseCost, "Unit '\(unit.id)' baseCost")
            }
            for milestone in level.milestones {
                checkNumbers(milestone.requirements, "Milestone '\(milestone.id)' requirements", issues: &issues)
                checkSpendable(milestone.requirements, "Milestone '\(milestone.id)' requirements")
            }
            for upgrade in level.eraUpgrades {
                checkNumbers(upgrade.cost, "EraUpgrade '\(upgrade.id)' cost", issues: &issues)
                checkSpendable(upgrade.cost, "EraUpgrade '\(upgrade.id)' cost")
            }

            // `levelResources` drives the level's secondary-resource HUD. An entry no unit in
            // the level produces leaves a counter pinned at zero — a warning, not an error,
            // because a resource carried over from an earlier level is a legitimate design
            // (Idle Civilizations shows 'faith' across two eras).
            for resource in level.levelResources {
                let producedHere = level.units.contains { unit in
                    (unit.baseProductionPerSecond.amounts[resource] ?? 0) > 0
                }
                if !producedHere {
                    if index.isSpendable(resource, atOrder: order) {
                        issues.warn("Level '\(level.id)' lists levelResource '\(resource)' but no unit in this level produces it")
                    } else {
                        issues.error("Level '\(level.id)' lists levelResource '\(resource)' which no unit produces at or before this level")
                    }
                }
            }
        }
    }

    /// NaN and non-finite amounts survive JSON decoding and then poison every comparison —
    /// `canAfford` treats NaN as unaffordable, so the item is simply never purchasable.
    private static func checkNumbers(_ bundle: ResourceBundle, _ what: String, issues: inout Issues) {
        for (resource, amount) in bundle.amounts {
            if amount.isNaN || !amount.isFinite {
                issues.error("\(what) has a non-finite amount for '\(resource)'")
                continue
            }
            if amount < 0 {
                issues.error("\(what) has a negative amount for '\(resource)' (\(amount))")
                continue
            }
            if amount > precisionCeiling {
                issues.warn("\(what) amount for '\(resource)' (\(amount)) exceeds UInt64.max — precision is lost wherever the value crosses Double or an integer API")
            }
        }
    }

    // MARK: - Copy

    private static func validateCopy(_ theme: any ThemePackage, issues: inout Issues) {
        let copy = theme.copy

        func requireNonEmpty(_ value: String, _ key: String) {
            if value.isEmpty { issues.error("copy.\(key) must not be empty") }
        }
        requireNonEmpty(copy.unitNoun,        "unitNoun")
        requireNonEmpty(copy.unitNounPlural,  "unitNounPlural")
        requireNonEmpty(copy.levelNoun,       "levelNoun")
        requireNonEmpty(copy.milestoneNoun,   "milestoneNoun")
        requireNonEmpty(copy.characterNoun,   "characterNoun")
        requireNonEmpty(copy.premiumPassName, "premiumPassName")
        requireNonEmpty(copy.advanceVerb,     "advanceVerb")
        requireNonEmpty(copy.prestigeTitle,   "prestigeTitle")

        requireNonEmpty(copy.offlineSheet.title,         "offlineSheet.title")
        requireNonEmpty(copy.offlineSheet.collectButton, "offlineSheet.collectButton")

        // Notification strings must be < 100 characters (iOS notification limit)
        func requireShort(_ value: String, _ key: String) {
            if value.count >= 100 { issues.error("copy.\(key) must be < 100 characters (found \(value.count))") }
        }
        requireShort(copy.notifications.offlineCapTitle,      "notifications.offlineCapTitle")
        requireShort(copy.notifications.offlineCapBody,       "notifications.offlineCapBody")
        requireShort(copy.notifications.dailyQuestTitle,      "notifications.dailyQuestTitle")
        requireShort(copy.notifications.weeklyEventTitle,     "notifications.weeklyEventTitle")
        requireShort(copy.notifications.levelReadyTitle,      "notifications.levelReadyTitle")
        requireShort(copy.notifications.levelReadyBody,       "notifications.levelReadyBody")
        requireShort(copy.notifications.wonderCompleteTitle,  "notifications.wonderCompleteTitle")
        requireShort(copy.notifications.wonderCompleteBody,   "notifications.wonderCompleteBody")

        validateLegalURLs(copy, issues: &issues)
    }

    /// Both links are rendered with `URL(string:)` and dropped when that returns nil, so a
    /// missing privacy policy does not fail — it silently removes the link from the paywall,
    /// which is an App Store rejection rather than a visible bug.
    private static func validateLegalURLs(_ copy: ThemeCopy, issues: inout Issues) {
        if copy.privacyPolicyURL.isEmpty {
            issues.error("copy.privacyPolicyURL must not be empty — the Privacy Policy link is silently omitted from the paywall without it, which App Review rejects")
        } else if !isParseableURL(copy.privacyPolicyURL) {
            issues.error("copy.privacyPolicyURL '\(copy.privacyPolicyURL)' is not a parseable absolute URL")
        }

        if copy.termsOfUseURL.isEmpty {
            issues.error("copy.termsOfUseURL must not be empty")
        } else if !isParseableURL(copy.termsOfUseURL) {
            issues.error("copy.termsOfUseURL '\(copy.termsOfUseURL)' is not a parseable absolute URL")
        }

        if let support = copy.supportURL {
            if support.isEmpty || !isParseableURL(support) {
                issues.error("copy.supportURL '\(support)' is not a parseable absolute URL")
            }
        } else {
            issues.warn("copy.supportURL is not set — Settings and the load-failure screen have no in-app support path")
        }
    }

    // MARK: - IAP

    private static func validateIAP(_ theme: any ThemePackage, issues: inout Issues) {
        let iap = theme.iapProducts
        let prefix = theme.bundleID

        // All non-nil product IDs must start with the bundle ID
        let allIDs: [String?] = [
            iap.starterPack, iap.removeAds, iap.premiumPass, iap.premiumPassAnnual,
            iap.coins1000, iap.coins5000, iap.coins15000, iap.coins30000,
            iap.coins75000, iap.lifetimePack
        ]
        for case let id? in allIDs where !id.hasPrefix(prefix) {
            issues.error("IAP product ID '\(id)' must start with bundleID '\(prefix)'")
        }

        // Auto-renewing products are sold on the onboarding paywall. When the theme omits
        // `onboardingCopy`, `ThemeCopy` decodes the engine's generic `.default` — so the
        // paywall sells a subscription under placeholder copy with no hero artwork.
        let hasSubscription = iap.premiumPass != nil || iap.premiumPassAnnual != nil
        if hasSubscription && theme.copy.onboardingCopy == .default {
            issues.error("iapProducts declares a subscription but copy.onboardingCopy is missing — the paywall would sell it with the engine's placeholder copy")
        }
    }

    // MARK: - Colors

    private static func validateColors(_ theme: any ThemePackage, issues: inout Issues) {
        let colors = theme.themeColors

        func requireValidHex(_ value: String, _ key: String) {
            if !isValidHex(value) { issues.error("Color \(key) '\(value)' is not a valid hex color (expected #RRGGBB)") }
        }
        requireValidHex(colors.background,      "background")
        requireValidHex(colors.surface,         "surface")
        requireValidHex(colors.surfaceElevated, "surfaceElevated")
        requireValidHex(colors.textPrimary,     "textPrimary")
        requireValidHex(colors.textSecondary,   "textSecondary")
        requireValidHex(colors.goldAccent,      "goldAccent")
        if let goldAccentLight = colors.goldAccentLight {
            requireValidHex(goldAccentLight, "goldAccentLight")
        }

        for lc in colors.levelColors {
            requireValidHex(lc.primary,   "levelColors[\(lc.levelID)].primary")
            requireValidHex(lc.secondary, "levelColors[\(lc.levelID)].secondary")
        }
    }

    /// Real WCAG AA checking, using the same `HexColor` math `AppTheme` uses at runtime.
    ///
    /// Warnings, not errors: `AppTheme` darkens or lightens anything that fails before it
    /// ever reaches the screen, so a failing value is a request for the runtime to pick a
    /// colour the designer did not choose — not a broken game. Five of Idle Civilizations'
    /// eight shipped era accents fail today; making this an error would refuse to load a
    /// live game.
    private static func validateContrast(_ theme: any ThemePackage, issues: inout Issues) {
        let colors = theme.themeColors
        guard isValidHex(colors.background), isValidHex(colors.surface) else { return }

        let background = HexColor(hex: colors.background)
        let surface = HexColor(hex: colors.surface)

        func checkText(_ hex: String, _ key: String, against other: HexColor, _ otherKey: String) {
            guard isValidHex(hex) else { return }
            let ratio = HexColor(hex: hex).contrastRatio(against: other)
            if ratio < minimumContrastRatio {
                issues.warn(String(format: "Contrast: %@ '%@' on %@ is %.2f:1 — below WCAG AA %.1f:1", key, hex, otherKey, ratio, minimumContrastRatio))
            }
        }
        checkText(colors.textPrimary,   "textPrimary",   against: background, "background")
        checkText(colors.textPrimary,   "textPrimary",   against: surface,    "surface")
        checkText(colors.textSecondary, "textSecondary", against: background, "background")
        checkText(colors.textSecondary, "textSecondary", against: surface,    "surface")

        // Level accents carry live game data — the secondary-resource counter and the era
        // progress percentage — so they are held to the text threshold, not the 3:1 one.
        for lc in colors.levelColors {
            checkText(lc.primary, "levelColors[\(lc.levelID)].primary", against: surface, "surface")
        }
    }

    // MARK: - Assets

    /// Every asset name the theme references, deduplicated. Useful for generating an
    /// artwork checklist as well as for validation.
    public static func referencedAssets(_ theme: any ThemePackage) -> [(asset: String, source: String)] {
        var result: [(asset: String, source: String)] = []

        for level in theme.levels {
            result.append((level.artworkAsset, "level '\(level.id)'.artworkAsset"))
            if let sound = level.soundAsset {
                result.append((sound, "level '\(level.id)'.soundAsset"))
            }
            for unit in level.units {
                result.append((unit.iconAsset, "unit '\(unit.id)'.iconAsset"))
            }
            for milestone in level.milestones {
                result.append((milestone.artworkAsset, "milestone '\(milestone.id)'.artworkAsset"))
            }
        }
        for character in theme.characters {
            result.append((character.portraitAsset, "character '\(character.id)'.portraitAsset"))
        }
        result.append((theme.copy.onboardingCopy.heroArtworkAsset, "copy.onboardingCopy.heroArtworkAsset"))

        // An empty name means "no asset" everywhere in the engine — never a missing one.
        return result.filter { !$0.asset.isEmpty }
    }

    /// Report every referenced asset that is not in `availableAssets`.
    ///
    /// Kept out of `validate(_:)` on purpose: the runtime path inside `GameEngine.loadTheme`
    /// cannot enumerate an asset catalogue cheaply, but a CLI tool can list the directory
    /// once and pass it in. Returns an empty array when everything resolves.
    ///
    /// - Parameters:
    ///   - theme: The theme to inspect.
    ///   - availableAssets: Asset names without extensions. Build with
    ///     `assetNames(fromDirectoryEntries:)` when starting from a directory listing.
    public static func validateAssets(theme: any ThemePackage, availableAssets: Set<String>) -> [String] {
        referencedAssets(theme)
            .filter { !availableAssets.contains($0.asset) }
            .map { "Missing asset '\($0.asset)' referenced by \($0.source)" }
    }

    /// Normalise a raw directory listing into asset names.
    ///
    /// Strips the wrappers and file extensions an `.xcassets` catalogue and a bundle's loose
    /// audio files use, so a caller can pass `try FileManager.default.contentsOfDirectory(atPath:)`
    /// straight through.
    public static func assetNames(fromDirectoryEntries entries: [String]) -> Set<String> {
        let strippable = [
            ".imageset", ".colorset", ".dataset", ".appiconset", ".symbolset",
            ".mp3", ".m4a", ".wav", ".aiff", ".caf",
            ".png", ".jpg", ".jpeg", ".pdf", ".svg", ".heic"
        ]
        var names: Set<String> = []
        for entry in entries {
            let name = entry.hasSuffix("/") ? String(entry.dropLast()) : entry
            guard name != "Contents.json", !name.hasPrefix(".") else { continue }
            if let suffix = strippable.first(where: { name.lowercased().hasSuffix($0) }) {
                names.insert(String(name.dropLast(suffix.count)))
            } else {
                names.insert(name)
            }
        }
        return names
    }

    // MARK: - String Helpers

    private static func isKebabCase(_ s: String) -> Bool {
        s.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil
    }

    private static func isValidBundleID(_ s: String) -> Bool {
        s.range(of: "^[a-zA-Z0-9]+(\\.[a-zA-Z0-9]+){2,}$", options: .regularExpression) != nil
    }

    private static func isValidHex(_ s: String) -> Bool {
        s.range(of: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", options: .regularExpression) != nil
    }

    /// `URL(string:)` accepts almost any non-empty fragment — "not a url" parses fine and
    /// then fails to open — so a scheme and a host are both required.
    private static func isParseableURL(_ s: String) -> Bool {
        guard let components = URLComponents(string: s), let scheme = components.scheme, !scheme.isEmpty else {
            return false
        }
        if scheme.lowercased() == "mailto" {
            // mailto: puts the address in `path`, not `host`.
            return !(components.path.isEmpty)
        }
        return !(components.host ?? "").isEmpty
    }
}
