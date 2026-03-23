import Foundation

/// Validates a `ThemePackage` against all engine contract rules.
/// Throws `EngineError.validationFailed([String])` with a full list of every violation found.
/// Run at startup, before `GameEngine.loadTheme`, and via the `/validate-theme` CLI.
public enum ThemeValidator {

    /// The schema version this engine build supports.
    public static let engineSchemaVersion = "1.0"

    /// Validate all rules. Collects every violation before throwing so authors see everything at once.
    public static func validate(_ theme: any ThemePackage) throws {
        var errors: [String] = []

        validateIdentity(theme, errors: &errors)
        validateLevels(theme, errors: &errors)
        validateUnitUniqueness(theme, errors: &errors)
        validateCopy(theme, errors: &errors)
        validateIAP(theme, errors: &errors)
        validateColors(theme, errors: &errors)

        guard errors.isEmpty else {
            throw EngineError.validationFailed(errors)
        }
    }

    // MARK: - Identity

    private static func validateIdentity(_ theme: any ThemePackage, errors: inout [String]) {
        if theme.schemaVersion != engineSchemaVersion {
            errors.append("schemaVersion '\(theme.schemaVersion)' does not match engine version '\(engineSchemaVersion)'")
        }
        if theme.gameID.isEmpty {
            errors.append("gameID must not be empty")
        } else if !isKebabCase(theme.gameID) {
            errors.append("gameID '\(theme.gameID)' must be kebab-case (lowercase alphanumeric and hyphens only)")
        }
        if theme.displayName.isEmpty {
            errors.append("displayName must not be empty")
        }
        if !isValidBundleID(theme.bundleID) {
            errors.append("bundleID '\(theme.bundleID)' must be reverse-domain format (e.g. com.studio.game)")
        }
        if theme.primaryCurrency.isEmpty {
            errors.append("primaryCurrency must not be empty")
        }
    }

    // MARK: - Levels

    private static func validateLevels(_ theme: any ThemePackage, errors: inout [String]) {
        let levels = theme.levels.sorted { $0.order < $1.order }

        if levels.count < 4 {
            errors.append("Theme must have at least 4 levels (found \(levels.count))")
        }
        if levels.count > 12 {
            errors.append("Theme must have at most 12 levels (found \(levels.count))")
        }

        // Sequential order check
        for (idx, level) in levels.enumerated() {
            let expected = idx + 1
            if level.order != expected {
                errors.append("Level '\(level.id)' has order \(level.order) but expected \(expected) — no gaps allowed")
            }
        }

        // Per-level rules
        var previousAdvanceGold: Decimal? = nil
        for level in levels {
            validateLevel(level, errors: &errors)

            // Balance: advance requirements must grow geometrically (at least 10×)
            let advanceGold = level.advanceRequirement["gold"]
            if advanceGold <= 0 {
                errors.append("Level '\(level.id)' advanceRequirement gold must be > 0")
            }
            if let prev = previousAdvanceGold, advanceGold > 0, prev > 0 {
                let ratio = NSDecimalNumber(decimal: advanceGold / prev).doubleValue
                if ratio < 10 {
                    errors.append("Level '\(level.id)' advanceRequirement (\(advanceGold)) is less than 10× previous level (\(prev)) — ratio: \(String(format: "%.1f", ratio))×")
                }
            }
            previousAdvanceGold = advanceGold
        }

        // levelColors: one per level
        let colorLevelIDs = Set(theme.themeColors.levelColors.map { $0.levelID })
        for level in levels where !colorLevelIDs.contains(level.id) {
            errors.append("Missing levelColor entry for level '\(level.id)'")
        }
    }

    private static func validateLevel(_ level: ThemeLevel, errors: inout [String]) {
        if level.units.count < 3 {
            errors.append("Level '\(level.id)' must have at least 3 units (found \(level.units.count))")
        }
        if level.units.count > 10 {
            errors.append("Level '\(level.id)' must have at most 10 units (found \(level.units.count))")
        }
        if level.milestones.isEmpty {
            errors.append("Level '\(level.id)' must have at least 1 milestone")
        }
        if level.levelResources.count > 2 {
            errors.append("Level '\(level.id)' levelResources may have at most 2 entries (found \(level.levelResources.count))")
        }
        if level.levelResources.contains("gold") {
            errors.append("Level '\(level.id)' levelResources must not include 'gold' — it is reserved as the universal primary resource")
        }
        for unit in level.units {
            validateUnit(unit, levelID: level.id, errors: &errors)
        }
        for milestone in level.milestones {
            validateMilestone(milestone, levelID: level.id, errors: &errors)
        }
    }

    // MARK: - Units

    private static func validateUnit(_ unit: ThemeUnit, levelID: String, errors: inout [String]) {
        let prefix = "Unit '\(unit.id)' (level '\(levelID)')"

        if unit.id.isEmpty {
            errors.append("\(prefix) id must not be empty")
        }
        if unit.displayName.isEmpty {
            errors.append("\(prefix) displayName must not be empty")
        }

        let mDouble = NSDecimalNumber(decimal: unit.costMultiplier).doubleValue
        if mDouble < 1.07 || mDouble > 1.20 {
            errors.append("\(prefix) costMultiplier \(unit.costMultiplier) must be between 1.07 and 1.20")
        }

        let hasPositiveProduction = unit.baseProductionPerSecond.amounts.values.contains { $0 > 0 }
        if !hasPositiveProduction {
            errors.append("\(prefix) baseProductionPerSecond must be > 0 for at least one resource")
        }

        if unit.managerThreshold < 5 || unit.managerThreshold > 50 {
            errors.append("\(prefix) managerThreshold \(unit.managerThreshold) must be between 5 and 50")
        }

        let tierCounts = Set(unit.upgradeTiers.map { $0.atCount })
        let requiredTiers: Set<Int> = [10, 25, 50, 100]
        let missing = requiredTiers.subtracting(tierCounts)
        if !missing.isEmpty {
            errors.append("\(prefix) missing required upgrade tiers at counts: \(missing.sorted())")
        }
    }

    private static func validateUnitUniqueness(_ theme: any ThemePackage, errors: inout [String]) {
        var seen: [String: String] = [:]
        for level in theme.levels {
            for unit in level.units {
                if let existing = seen[unit.id] {
                    errors.append("Duplicate unit ID '\(unit.id)' found in levels '\(existing)' and '\(level.id)'")
                } else {
                    seen[unit.id] = level.id
                }
            }
        }
    }

    // MARK: - Milestones

    private static func validateMilestone(_ milestone: ThemeMilestone, levelID: String, errors: inout [String]) {
        let prefix = "Milestone '\(milestone.id)' (level '\(levelID)')"

        if milestone.id.isEmpty {
            errors.append("\(prefix) id must not be empty")
        }
        if milestone.displayName.isEmpty {
            errors.append("\(prefix) displayName must not be empty")
        }
        if milestone.constructionSeconds <= 0 {
            errors.append("\(prefix) constructionSeconds must be > 0")
        }
        if milestone.canSkipWithAd && milestone.constructionSeconds > 3600 {
            errors.append("\(prefix) canSkipWithAd is true but constructionSeconds (\(milestone.constructionSeconds)) exceeds 3600s limit")
        }
    }

    // MARK: - Copy

    private static func validateCopy(_ theme: any ThemePackage, errors: inout [String]) {
        let copy = theme.copy

        func requireNonEmpty(_ value: String, _ key: String) {
            if value.isEmpty { errors.append("copy.\(key) must not be empty") }
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
            if value.count >= 100 { errors.append("copy.\(key) must be < 100 characters (found \(value.count))") }
        }
        requireShort(copy.notifications.offlineCapTitle,      "notifications.offlineCapTitle")
        requireShort(copy.notifications.offlineCapBody,       "notifications.offlineCapBody")
        requireShort(copy.notifications.dailyQuestTitle,      "notifications.dailyQuestTitle")
        requireShort(copy.notifications.weeklyEventTitle,     "notifications.weeklyEventTitle")
        requireShort(copy.notifications.levelReadyTitle,      "notifications.levelReadyTitle")
        requireShort(copy.notifications.levelReadyBody,       "notifications.levelReadyBody")
        requireShort(copy.notifications.wonderCompleteTitle,  "notifications.wonderCompleteTitle")
        requireShort(copy.notifications.wonderCompleteBody,   "notifications.wonderCompleteBody")
    }

    // MARK: - IAP

    private static func validateIAP(_ theme: any ThemePackage, errors: inout [String]) {
        let iap = theme.iapProducts
        let prefix = theme.bundleID

        // All non-nil product IDs must start with the bundle ID
        let allIDs: [String?] = [
            iap.starterPack, iap.removeAds, iap.premiumPass, iap.premiumPassAnnual,
            iap.coins1000, iap.coins5000, iap.coins15000, iap.lifetimePack
        ]
        for case let id? in allIDs where !id.hasPrefix(prefix) {
            errors.append("IAP product ID '\(id)' must start with bundleID '\(prefix)'")
        }

        // levelBundles must have one entry per level
        let levelIDs = Set(theme.levels.map { $0.id })
        let bundleKeys = Set(iap.levelBundles.keys)
        let missingBundles = levelIDs.subtracting(bundleKeys)
        for id in missingBundles.sorted() {
            errors.append("iapProducts.levelBundles is missing an entry for level '\(id)'")
        }
    }

    // MARK: - Colors

    private static func validateColors(_ theme: any ThemePackage, errors: inout [String]) {
        let colors = theme.themeColors

        func requireValidHex(_ value: String, _ key: String) {
            if !isValidHex(value) { errors.append("Color \(key) '\(value)' is not a valid hex color (expected #RRGGBB)") }
        }
        requireValidHex(colors.background,      "background")
        requireValidHex(colors.surface,         "surface")
        requireValidHex(colors.surfaceElevated, "surfaceElevated")
        requireValidHex(colors.textPrimary,     "textPrimary")
        requireValidHex(colors.textSecondary,   "textSecondary")
        requireValidHex(colors.goldAccent,      "goldAccent")

        for lc in colors.levelColors {
            requireValidHex(lc.primary,   "levelColors[\(lc.levelID)].primary")
            requireValidHex(lc.secondary, "levelColors[\(lc.levelID)].secondary")
        }
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
}
