import Foundation

/// Immutable snapshot of all game state. Every mutation returns a new copy.
/// Stored and diffed by the engine — never mutated in place.
public struct GameState: Sendable, Equatable, Codable {

    // MARK: - Progression

    public let currentLevelID: String
    public let resources: ResourceBundle
    /// Counts of each unit owned by ID.
    public let unitCounts: [String: Int]
    /// IDs of milestones the player has completed.
    public let completedMilestoneIDs: Set<String>
    /// IDs of era upgrades the player has purchased this run.
    public let purchasedUpgradeIDs: Set<String>

    // MARK: - Prestige

    /// Accumulated Legacy Tokens across all prestiges.
    public let prestigeTokens: Decimal
    /// How many times the player has prestiged total.
    public let totalPrestigeCount: Int

    // MARK: - Lifetime Stats

    /// Total gold earned across all time (never resets — feeds prestige token formula).
    public let totalLifetimeGold: Decimal

    // MARK: - Session

    public let sessionStartDate: Date
    public let lastSaveDate: Date

    // MARK: - Cross-Game

    /// Studio Points earned across all games. Synced via CloudKit.
    public let studioPoints: Int

    // MARK: - Achievements

    /// IDs of achievements the player has earned. Never resets on prestige.
    public let earnedAchievementIDs: Set<String>
    /// Total real-world seconds spent playing. Never resets on prestige.
    /// Always accumulated in real time — unaffected by dev fast-forward.
    public let totalPlaySeconds: Int

    /// ID of the milestone currently under construction. Nil if none.
    public let inProgressMilestoneID: String?
    /// Wall-clock date when construction finishes. Nil if none in progress.
    public let milestoneConstructionEndDate: Date?

    // MARK: - Init

    public init(
        currentLevelID: String,
        resources: ResourceBundle,
        unitCounts: [String: Int],
        completedMilestoneIDs: Set<String>,
        purchasedUpgradeIDs: Set<String> = [],
        prestigeTokens: Decimal,
        totalPrestigeCount: Int,
        totalLifetimeGold: Decimal,
        sessionStartDate: Date,
        lastSaveDate: Date,
        studioPoints: Int,
        earnedAchievementIDs: Set<String> = [],
        totalPlaySeconds: Int = 0,
        inProgressMilestoneID: String? = nil,
        milestoneConstructionEndDate: Date? = nil
    ) {
        self.currentLevelID = currentLevelID
        self.resources = resources
        self.unitCounts = unitCounts
        self.completedMilestoneIDs = completedMilestoneIDs
        self.purchasedUpgradeIDs = purchasedUpgradeIDs
        self.prestigeTokens = prestigeTokens
        self.totalPrestigeCount = totalPrestigeCount
        self.totalLifetimeGold = totalLifetimeGold
        self.sessionStartDate = sessionStartDate
        self.lastSaveDate = lastSaveDate
        self.studioPoints = studioPoints
        self.earnedAchievementIDs = earnedAchievementIDs
        self.totalPlaySeconds = totalPlaySeconds
        self.inProgressMilestoneID = inProgressMilestoneID
        self.milestoneConstructionEndDate = milestoneConstructionEndDate
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentLevelID = try c.decode(String.self, forKey: .currentLevelID)
        resources = try c.decode(ResourceBundle.self, forKey: .resources)
        unitCounts = try c.decode([String: Int].self, forKey: .unitCounts)
        completedMilestoneIDs = try c.decode(Set<String>.self, forKey: .completedMilestoneIDs)
        purchasedUpgradeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .purchasedUpgradeIDs) ?? []
        prestigeTokens = try c.decode(Decimal.self, forKey: .prestigeTokens)
        totalPrestigeCount = try c.decode(Int.self, forKey: .totalPrestigeCount)
        totalLifetimeGold = try c.decode(Decimal.self, forKey: .totalLifetimeGold)
        sessionStartDate = try c.decode(Date.self, forKey: .sessionStartDate)
        lastSaveDate = try c.decode(Date.self, forKey: .lastSaveDate)
        studioPoints = try c.decode(Int.self, forKey: .studioPoints)
        earnedAchievementIDs = try c.decodeIfPresent(Set<String>.self, forKey: .earnedAchievementIDs) ?? []
        totalPlaySeconds = try c.decodeIfPresent(Int.self, forKey: .totalPlaySeconds) ?? 0
        inProgressMilestoneID = try c.decodeIfPresent(String.self, forKey: .inProgressMilestoneID)
        milestoneConstructionEndDate = try c.decodeIfPresent(Date.self, forKey: .milestoneConstructionEndDate)
    }

    /// Sets are written as *sorted* arrays.
    ///
    /// `JSONEncoder.outputFormatting = [.sortedKeys]` orders object keys but not array
    /// elements, and `Set` has no inherent order — so re-encoding unchanged state produced
    /// different bytes every time. That makes saves undiffable, defeats byte comparison, and
    /// makes CloudKit treat an untouched record as modified on every single write.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(currentLevelID, forKey: .currentLevelID)
        try c.encode(resources, forKey: .resources)
        try c.encode(unitCounts, forKey: .unitCounts)
        try c.encode(completedMilestoneIDs.sorted(), forKey: .completedMilestoneIDs)
        try c.encode(purchasedUpgradeIDs.sorted(), forKey: .purchasedUpgradeIDs)
        try c.encode(prestigeTokens, forKey: .prestigeTokens)
        try c.encode(totalPrestigeCount, forKey: .totalPrestigeCount)
        try c.encode(totalLifetimeGold, forKey: .totalLifetimeGold)
        try c.encode(sessionStartDate, forKey: .sessionStartDate)
        try c.encode(lastSaveDate, forKey: .lastSaveDate)
        try c.encode(studioPoints, forKey: .studioPoints)
        try c.encode(earnedAchievementIDs.sorted(), forKey: .earnedAchievementIDs)
        try c.encode(totalPlaySeconds, forKey: .totalPlaySeconds)
        try c.encodeIfPresent(inProgressMilestoneID, forKey: .inProgressMilestoneID)
        try c.encodeIfPresent(milestoneConstructionEndDate, forKey: .milestoneConstructionEndDate)
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case currentLevelID
        case resources
        case unitCounts
        case completedMilestoneIDs
        case purchasedUpgradeIDs
        case prestigeTokens
        case totalPrestigeCount
        case totalLifetimeGold
        case sessionStartDate
        case lastSaveDate
        case studioPoints
        case earnedAchievementIDs
        case totalPlaySeconds
        case inProgressMilestoneID
        case milestoneConstructionEndDate
    }

    // MARK: - Convenience

    public func unitCount(id: String) -> Int {
        unitCounts[id] ?? 0
    }

    // MARK: - Mutations (all return new instances)

    /// Stamps `lastSaveDate`. Called by the persistence layer immediately before writing.
    ///
    /// `lastSaveDate` used to be re-stamped by every mutation including `applying(production:)`,
    /// which runs on every tick. That made `newState != oldState` unconditionally true, so the
    /// view models' equality guards could never succeed and `GameplayScreen.body` re-evaluated
    /// 10×/second forever. The timestamp describes when state was persisted, so only the
    /// persistence layer should set it.
    public func markingSaved(at date: Date = Date()) -> GameState {
        GameState(
            currentLevelID: currentLevelID,
            resources: resources,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: date,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Adds `production` to resources. Tracks lifetime primary-currency earnings separately.
    ///
    /// - Parameter primaryCurrency: The theme's primary currency key (`theme.primaryCurrency`).
    ///   Lifetime earnings of this resource feed the prestige token formula. This used to be
    ///   the hardcoded literal `"gold"`, which silently froze prestige progression and the
    ///   leaderboard score for any theme that named its currency anything else.
    public func applying(production: ResourceBundle, primaryCurrency: String) -> GameState {
        // Only credit lifetime earnings for genuine income. Negative production is reachable
        // (a refunded cost, a clock-skew offline settlement) and must never reduce a lifetime
        // total that prestige tokens and leaderboard rank are derived from.
        let earned = production[primaryCurrency]
        let lifetimeDelta = earned > 0 ? earned : 0
        return GameState(
            currentLevelID: currentLevelID,
            resources: resources + production,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold + lifetimeDelta,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Deducts `cost` and increments unit count.
    ///
    /// `quantity` must be positive; a non-positive value is a no-op. `GameEngine.purchaseUnit`
    /// rejects it earlier, but a negative count here would poison every subsequent cost
    /// calculation for that unit, so the invariant is enforced in both places.
    public func purchasing(unitID: String, quantity: Int, cost: ResourceBundle) -> GameState {
        guard quantity > 0 else { return self }
        var newCounts = unitCounts
        newCounts[unitID] = (newCounts[unitID] ?? 0) + quantity
        return GameState(
            currentLevelID: currentLevelID,
            resources: resources - cost,
            unitCounts: newCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Deducts `cost` and records the era upgrade as purchased.
    public func purchasing(upgradeID: String, cost: ResourceBundle) -> GameState {
        var newUpgrades = purchasedUpgradeIDs
        newUpgrades.insert(upgradeID)
        return GameState(
            currentLevelID: currentLevelID,
            resources: resources - cost,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: newUpgrades,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Marks a milestone completed. Awards +25 Studio Points. Clears any in-progress construction.
    public func completing(milestoneID: String) -> GameState {
        var newMilestones = completedMilestoneIDs
        newMilestones.insert(milestoneID)
        return GameState(
            currentLevelID: currentLevelID,
            resources: resources,
            unitCounts: unitCounts,
            completedMilestoneIDs: newMilestones,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints + 25,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: nil,
            milestoneConstructionEndDate: nil
        )
    }

    /// Moves to the next level. Resources and units carry over. Awards +50 Studio Points. Clears any in-progress construction.
    public func advancingLevel(to levelID: String) -> GameState {
        GameState(
            currentLevelID: levelID,
            resources: resources,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints + 50,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: nil,
            milestoneConstructionEndDate: nil
        )
    }

    /// Prestige reset: clears resources, units, and upgrades. Accumulates tokens, restarts from first level.
    /// earnedAchievementIDs and totalPlaySeconds are never reset — they track lifetime progress.
    /// Clears any in-progress construction.
    public func applying(prestige newTokens: Decimal, firstLevelID: String, keepingMilestoneIDs: Set<String>) -> GameState {
        GameState(
            currentLevelID: firstLevelID,
            resources: .zero,
            unitCounts: [:],
            completedMilestoneIDs: keepingMilestoneIDs,
            purchasedUpgradeIDs: [],
            prestigeTokens: prestigeTokens + newTokens,
            totalPrestigeCount: totalPrestigeCount + 1,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: Date(),
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: nil,
            milestoneConstructionEndDate: nil
        )
    }

    /// Awards an achievement. No-op if already earned.
    public func earning(achievementID: String) -> GameState {
        guard !earnedAchievementIDs.contains(achievementID) else { return self }
        var newIDs = earnedAchievementIDs
        newIDs.insert(achievementID)
        return GameState(
            currentLevelID: currentLevelID,
            resources: resources,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: newIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Adds real-world play seconds. Used by the tick loop; not affected by dev fast-forward.
    public func addingPlayTime(seconds: Int) -> GameState {
        GameState(
            currentLevelID: currentLevelID,
            resources: resources,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds + seconds,
            inProgressMilestoneID: inProgressMilestoneID,
            milestoneConstructionEndDate: milestoneConstructionEndDate
        )
    }

    /// Deducts `cost`, sets the in-progress milestone and its end date.
    public func startingMilestone(id: String, cost: ResourceBundle, endDate: Date) -> GameState {
        GameState(
            currentLevelID: currentLevelID,
            resources: resources - cost,
            unitCounts: unitCounts,
            completedMilestoneIDs: completedMilestoneIDs,
            purchasedUpgradeIDs: purchasedUpgradeIDs,
            prestigeTokens: prestigeTokens,
            totalPrestigeCount: totalPrestigeCount,
            totalLifetimeGold: totalLifetimeGold,
            sessionStartDate: sessionStartDate,
            lastSaveDate: lastSaveDate,
            studioPoints: studioPoints,
            earnedAchievementIDs: earnedAchievementIDs,
            totalPlaySeconds: totalPlaySeconds,
            inProgressMilestoneID: id,
            milestoneConstructionEndDate: endDate
        )
    }
}

// MARK: - Factory

public extension GameState {
    /// Clean initial state for a fresh game start.
    static func initial(firstLevelID: String) -> GameState {
        GameState(
            currentLevelID: firstLevelID,
            resources: .zero,
            unitCounts: [:],
            completedMilestoneIDs: [],
            prestigeTokens: 0,
            totalPrestigeCount: 0,
            totalLifetimeGold: 0,
            sessionStartDate: Date(),
            lastSaveDate: Date(),
            studioPoints: 0
        )
    }
}
