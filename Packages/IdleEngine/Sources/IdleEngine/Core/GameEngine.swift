import Foundation

/// The game loop. A global actor — all game state mutations are isolated here.
///
/// Usage in a game target:
/// ```swift
/// try await GameEngine.shared.loadTheme(myTheme)
/// for await state in await GameEngine.shared.stateStream() { ... }
/// ```
///
/// ViewModels observe `stateStream()` from `@MainActor`.
/// Service layer calls player action methods with `await GameEngine.shared.purchaseUnit(...)`.
@globalActor
public actor GameEngine {

    // MARK: - Singleton

    public static let shared = GameEngine()

    // MARK: - State

    private var _state: GameState?
    private var _theme: (any ThemePackage)?
    private var tickTask: Task<Void, Never>?
    /// Accumulates fractional seconds; adds whole seconds of real play time as they elapse.
    private var playTimeAccumulator: TimeInterval = 0
    /// Wall-clock stamp of the previous tick, used to credit real elapsed time.
    private var lastTickDate: Date?

    // MARK: - Cached Theme Derivations

    // `ThemePackage.allUnits` / `allMilestones` / `nextLevel(after:)` are computed properties
    // that re-sort `levels` and re-flatMap on every access. They were being called from the
    // tick loop, so an immutable value was rebuilt 10×/second — ~3,600 retain/release per
    // second for data that cannot change while a theme is loaded.
    private var cachedAllUnits: [ThemeUnit] = []
    private var cachedAllMilestones: [ThemeMilestone] = []
    private var cachedAllEraUpgrades: [ThemeEraUpgrade] = []
    private var levelsByID: [String: ThemeLevel] = [:]
    private var orderedLevels: [ThemeLevel] = []
    private var primaryCurrency: String = "gold"

    /// Memoised production rate. Invalidated by any mutation that can change it.
    /// Recomputing it every tick cost ~560 dictionary allocations for an answer that is
    /// identical on better than 99.9% of ticks.
    private var cachedRate: ResourceBundle?
    private var cachedMilestoneBonuses: EconomyCalculator.MilestoneBonuses?

    // MARK: - Tick Rate

    /// 100 ms ticks = 10 ticks/second. Idle games don't need sub-100ms precision.
    static let tickInterval: Duration = .milliseconds(100)

    /// Upper bound on the wall-clock delta credited by a single tick. Absorbs scheduler
    /// stalls and debugger pauses; anything longer is offline time and is settled by
    /// `collectOfflineIncome` instead.
    static let maxTickDelta: TimeInterval = 1.0

    // MARK: - Observable State Stream

    /// Each call returns a fresh `AsyncStream<GameState>` for that subscriber.
    /// Multiple ViewModels can each call `stateStream()` independently — all receive
    /// every tick (multicast). The stream yields the current state immediately on subscribe.
    ///
    /// ```swift
    /// for await state in await GameEngine.shared.stateStream() { self.state = state }
    /// ```
    private var _subscribers: [UUID: AsyncStream<GameState>.Continuation] = [:]

    /// Create a new per-subscriber stream.
    ///
    /// Actor-isolated on purpose. The previous version was `nonisolated` and registered the
    /// subscriber from a detached `Task`, racing a second detached `Task` created by
    /// `onTermination`. Swift makes no ordering guarantee between separately-created tasks,
    /// so a stream that terminated promptly — which ordinary tab switching causes — could
    /// run the removal first and then have the registration re-insert a dead continuation
    /// that was never cleaned up. Registering synchronously here makes the reorder
    /// impossible and lets the first value actually be delivered on subscribe.
    public func stateStream() -> AsyncStream<GameState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<GameState>.makeStream(
            of: GameState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        _subscribers[id] = continuation
        if let state = _state { continuation.yield(state) }
        continuation.onTermination = { [id] _ in
            Task { await GameEngine.shared.removeSubscriber(id: id) }
        }
        return stream
    }

    func removeSubscriber(id: UUID) {
        _subscribers[id] = nil
    }

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    /// Load a theme and optional saved state, then start the tick loop.
    /// Validates the theme via `ThemeValidator` before accepting it — throws on invalid JSON.
    /// Call this once from the app's entry point after loading `[theme].json`.
    public func loadTheme(_ theme: any ThemePackage, savedState: GameState? = nil) throws {
        try ThemeValidator.validate(theme)
        _theme = theme

        orderedLevels = theme.levels.sorted { $0.order < $1.order }
        cachedAllUnits = orderedLevels.flatMap(\.units)
        cachedAllMilestones = orderedLevels.flatMap(\.milestones)
        cachedAllEraUpgrades = orderedLevels.flatMap(\.eraUpgrades)
        levelsByID = Dictionary(orderedLevels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        primaryCurrency = theme.primaryCurrency

        let firstLevelID = orderedLevels.first?.id ?? ""
        _state = savedState ?? GameState.initial(firstLevelID: firstLevelID)
        invalidateDerivedValues()
        emitState()
        startTickLoop()
    }

    // MARK: - Player Actions

    /// Purchase `quantity` of the unit identified by `id`.
    ///
    /// Pass `quantity: .max` sentinel semantics via `maxAffordable(unitID:)` — this method
    /// requires a concrete positive quantity. A non-positive quantity used to flow straight
    /// through: `bulkBuyCost` returned `.zero` for it, an empty bundle is trivially
    /// affordable, and the unit count went negative — after which `decimalPow` on a negative
    /// exponent returned 0 and every subsequent purchase of that unit was free.
    public func purchaseUnit(id: String, quantity: Int = 1) throws {
        guard quantity > 0 else { throw EngineError.invalidQuantity(quantity) }
        let (state, _) = try requireStateAndTheme()
        guard let unit = unit(id: id) else { throw EngineError.unknownUnit(id) }

        let discount = EconomyCalculator.eraCostMultiplier(
            purchasedIDs: state.purchasedUpgradeIDs, upgrades: cachedAllEraUpgrades
        )
        let cost = EconomyCalculator.bulkBuyCost(
            unit: unit,
            currentCount: state.unitCount(id: id),
            quantity: quantity,
            discountMultiplier: discount
        )
        guard state.resources.canAfford(cost) else { throw EngineError.insufficientResources }

        _state = state.purchasing(unitID: id, quantity: quantity, cost: cost)
        invalidateDerivedValues()
        emitState()
    }

    /// Largest quantity of `unitID` the player can currently afford. 0 if none.
    /// Resolves the "Buy MAX" affordance — the UI must never pass a sentinel to `purchaseUnit`.
    public func maxAffordable(unitID: String) -> Int {
        guard let state = _state, let unit = unit(id: unitID) else { return 0 }
        let discount = EconomyCalculator.eraCostMultiplier(
            purchasedIDs: state.purchasedUpgradeIDs, upgrades: cachedAllEraUpgrades
        )
        return EconomyCalculator.maxAffordable(
            unit: unit,
            currentCount: state.unitCount(id: unitID),
            resources: state.resources,
            discountMultiplier: discount
        )
    }

    /// Purchase a one-time era upgrade with the current era's secondary resource.
    public func purchaseEraUpgrade(id: String) throws {
        let (state, _) = try requireStateAndTheme()
        guard let upgrade = cachedAllEraUpgrades.first(where: { $0.id == id }) else {
            throw EngineError.unknownUnit(id)
        }
        guard !state.purchasedUpgradeIDs.contains(id) else { throw EngineError.alreadyCompleted(id) }
        guard state.resources.canAfford(upgrade.cost) else { throw EngineError.insufficientResources }

        _state = state.purchasing(upgradeID: id, cost: upgrade.cost)
        invalidateDerivedValues()
        emitState()
    }

    /// Advance to the next level. Requires the current level's `advanceRequirement` to be met
    /// and all of the current level's milestones to be completed.
    public func advanceLevel() throws {
        let (state, _) = try requireStateAndTheme()
        guard let current = levelsByID[state.currentLevelID] else {
            throw EngineError.unknownLevel(state.currentLevelID)
        }
        guard state.resources.canAfford(current.advanceRequirement) else {
            throw EngineError.insufficientResources
        }
        guard current.milestones.allSatisfy({ state.completedMilestoneIDs.contains($0.id) }) else {
            throw EngineError.milestonesIncomplete
        }
        guard let next = nextLevel(after: state.currentLevelID) else { throw EngineError.noNextLevel }

        _state = state.advancingLevel(to: next.id)
        invalidateDerivedValues()
        emitState()
    }

    /// Mark the in-progress milestone as completed early (an ad skip or a coin skip).
    ///
    /// Requires the milestone to actually be under construction. Without that check this was
    /// an ungated public "grant me this milestone" call: it verified only that the milestone
    /// was not already complete, never that its requirements had been paid.
    public func completeMilestone(id: String) throws {
        let (state, _) = try requireStateAndTheme()
        guard !state.completedMilestoneIDs.contains(id) else { throw EngineError.alreadyCompleted(id) }
        guard state.inProgressMilestoneID == id else { throw EngineError.constructionInProgress }

        _state = state.completing(milestoneID: id)
        invalidateDerivedValues()
        emitState()
    }

    /// Begin construction of a milestone. Deducts requirements and starts the countdown.
    /// In the simulator with dev fast-forward, construction time is divided by `devSpeedMultiplier`.
    public func startMilestone(id: String) throws {
        let (state, _) = try requireStateAndTheme()
        guard let milestone = milestone(id: id) else { throw EngineError.unknownUnit(id) }
        guard !state.completedMilestoneIDs.contains(id) else { throw EngineError.alreadyCompleted(id) }
        guard state.inProgressMilestoneID == nil else { throw EngineError.constructionInProgress }
        guard state.resources.canAfford(milestone.requirements) else {
            throw EngineError.insufficientResources
        }

        #if targetEnvironment(simulator)
        let durationSeconds: Double
        if GameEngine.devFastForwardEnabled {
            durationSeconds = Double(milestone.constructionSeconds) / Double(truncating: GameEngine.devSpeedMultiplier as NSDecimalNumber)
        } else {
            durationSeconds = Double(milestone.constructionSeconds)
        }
        #else
        let durationSeconds = Double(milestone.constructionSeconds)
        #endif

        let endDate = Date().addingTimeInterval(durationSeconds)
        _state = state.startingMilestone(id: id, cost: milestone.requirements, endDate: endDate)
        emitState()
    }

    /// Whether `milestoneID` may be skipped by watching a rewarded ad, per the theme.
    /// The UI must consult this — the flag exists precisely to keep long late-game
    /// construction behind the coin sink rather than a free 30-second ad.
    public func canSkipWithAd(milestoneID: String) -> Bool {
        milestone(id: milestoneID)?.canSkipWithAd ?? false
    }

    /// Coin cost to skip `milestoneID` immediately, per the theme. 0 when not skippable.
    public func skipCostCoins(milestoneID: String) -> Int {
        milestone(id: milestoneID)?.skipCostCoins ?? 0
    }

    /// Perform a prestige reset. Requires at least 1 token to be earnable
    /// and the theme's gate milestone to be completed (if one is defined).
    public func prestige() throws {
        let (state, theme) = try requireStateAndTheme()
        guard PrestigeSystem.canPrestige(state: state, theme: theme) else {
            throw EngineError.prestigeNotAvailable
        }
        let newTokens = PrestigeSystem.tokensEarned(from: state)
        let keptMilestones = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        let firstLevelID = orderedLevels.first?.id ?? ""

        _state = state.applying(
            prestige: newTokens,
            firstLevelID: firstLevelID,
            keepingMilestoneIDs: keptMilestones
        )
        invalidateDerivedValues()
        emitState()
    }

    /// Award arbitrary resources — used for IAP purchases and other one-time grants.
    public func awardResources(_ bundle: ResourceBundle) {
        guard let state = _state else { return }
        _state = state.applying(production: bundle, primaryCurrency: primaryCurrency)
        emitState()
    }

    /// Award a manual tap — earns 1 second of production (minimum 1 unit of the primary currency).
    public func manualTap() throws {
        let (state, _) = try requireStateAndTheme()
        let earned = currentRate()[primaryCurrency]
        let reward = ResourceBundle([primaryCurrency: max(1, earned)])
        _state = state.applying(production: reward, primaryCurrency: primaryCurrency)
        emitState()
    }

    /// Calculate and collect offline income from `lastActiveDate` to now.
    /// Applies the earned resources to state and returns the result for display.
    @discardableResult
    public func collectOfflineIncome(lastActiveDate: Date) throws -> OfflineResult {
        let (state, _) = try requireStateAndTheme()
        let elapsed = Date().timeIntervalSince(lastActiveDate)
        let result = OfflineCalculator.calculate(
            state: state,
            units: cachedAllUnits,
            awayDuration: elapsed,
            eraUpgrades: cachedAllEraUpgrades
        )
        guard result.earnedResources != .zero else { return result }

        _state = state.applying(production: result.earnedResources, primaryCurrency: primaryCurrency)
        emitState()
        return result
    }

    // MARK: - Tick Loop

    private func startTickLoop() {
        tickTask?.cancel()
        lastTickDate = Date()
        // `.utility` on purpose. This used to inherit `.userInitiated` from the SwiftUI
        // `.task` that started it, so a 10 Hz allocation-heavy loop competed with the main
        // thread for performance cores and kept the CPU out of deep idle states.
        tickTask = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                guard let self else { return }
                await self.tick()
            }
        }
    }

    /// Suspend simulation. Call when the app leaves the foreground so the loop stops
    /// consuming the limited background execution budget.
    public func pauseTicking() {
        tickTask?.cancel()
        tickTask = nil
        lastTickDate = nil
    }

    /// Resume simulation after `pauseTicking()`. Safe to call when already running.
    public func resumeTicking() {
        guard tickTask == nil, _state != nil, _theme != nil else { return }
        startTickLoop()
    }

    private func tick() {
        guard let state = _state, _theme != nil else { return }

        // Credit real elapsed time. `Task.sleep` guarantees a *minimum*, so crediting a flat
        // 0.1 s per tick systematically under-paid production by 5–7% (measured) and made
        // `totalPlaySeconds` drift by the same factor.
        let now = Date()
        let rawDelta = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now
        let delta = min(max(0, rawDelta), Self.maxTickDelta)
        guard delta > 0 else { return }

        let rate = currentRate()

        #if targetEnvironment(simulator)
        let speedMultiplier = GameEngine.devFastForwardEnabled ? GameEngine.devSpeedMultiplier : 1
        var next = state.applying(
            production: rate * Decimal(delta) * speedMultiplier, primaryCurrency: primaryCurrency
        )
        #else
        var next = state.applying(production: rate * Decimal(delta), primaryCurrency: primaryCurrency)
        #endif

        // Real-world play time — never scaled by dev speed.
        playTimeAccumulator += delta
        if playTimeAccumulator >= 1 {
            let wholeSeconds = Int(playTimeAccumulator)
            playTimeAccumulator -= TimeInterval(wholeSeconds)
            next = next.addingPlayTime(seconds: wholeSeconds)
        }

        // Auto-complete milestone construction when the timer expires.
        if let milestoneID = next.inProgressMilestoneID,
           let endDate = next.milestoneConstructionEndDate,
           now >= endDate {
            next = next.completing(milestoneID: milestoneID)
            invalidateDerivedValues()
        }

        _state = next
        emitState()
    }

    // MARK: - Dev Fast-Forward (simulator only)

    #if targetEnvironment(simulator)
    /// Speed multiplier applied to every tick in the simulator when fast-forward is enabled.
    public static let devSpeedMultiplier: Decimal = 1000

    /// Persisted toggle — defaults to `true` so fast-forward is on by default in the simulator.
    public static var devFastForwardEnabled: Bool {
        get {
            let key = "dev_fast_forward_enabled"
            return UserDefaults.standard.object(forKey: key) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "dev_fast_forward_enabled")
        }
    }
    #endif

    // MARK: - Public Accessors

    /// The currently loaded theme, or `nil` if no theme has been loaded yet.
    public var currentTheme: (any ThemePackage)? { _theme }

    /// The current game state snapshot, or `nil` if no theme has been loaded yet.
    public var currentState: GameState? { _state }

    /// Every unit across every level, in level order. Cached at theme load.
    public var allUnits: [ThemeUnit] { cachedAllUnits }

    /// Every era upgrade across every level. Cached at theme load.
    public var allEraUpgrades: [ThemeEraUpgrade] { cachedAllEraUpgrades }

    /// Current total production per second, including milestone bonuses.
    public func productionRate() -> ResourceBundle { currentRate() }

    // MARK: - Internal

    private func unit(id: String) -> ThemeUnit? {
        cachedAllUnits.first { $0.id == id }
    }

    private func milestone(id: String) -> ThemeMilestone? {
        cachedAllMilestones.first { $0.id == id }
    }

    private func nextLevel(after levelID: String) -> ThemeLevel? {
        guard let index = orderedLevels.firstIndex(where: { $0.id == levelID }),
              index + 1 < orderedLevels.count else { return nil }
        return orderedLevels[index + 1]
    }

    /// Memoised production rate for the current state.
    private func currentRate() -> ResourceBundle {
        if let cachedRate { return cachedRate }
        guard let state = _state else { return .zero }

        let bonuses: EconomyCalculator.MilestoneBonuses
        if let cachedMilestoneBonuses {
            bonuses = cachedMilestoneBonuses
        } else {
            bonuses = EconomyCalculator.milestoneBonuses(
                completedIDs: state.completedMilestoneIDs, milestones: cachedAllMilestones
            )
            cachedMilestoneBonuses = bonuses
        }

        // Era upgrades from EVERY level, not just the current one. `purchasedUpgradeIDs`
        // persists across an advance, but passing only the new level's definitions made the
        // intersection empty — so every upgrade bought in a previous era silently stopped
        // applying, dropping production by up to 67% at the moment the player progressed.
        let rate = EconomyCalculator.productionRate(
            state: state,
            units: cachedAllUnits,
            eraUpgrades: cachedAllEraUpgrades,
            milestoneBonuses: bonuses
        )
        cachedRate = rate
        return rate
    }

    /// Drop memoised values that depend on units, upgrades, milestones, or prestige.
    private func invalidateDerivedValues() {
        cachedRate = nil
        cachedMilestoneBonuses = nil
    }

    private func emitState() {
        guard var state = _state, let theme = _theme else { return }
        // Award any newly-satisfied achievements before broadcasting.
        let newAchievements = AchievementEngine.check(state: state, theme: theme)
        if !newAchievements.isEmpty {
            for id in newAchievements { state = state.earning(achievementID: id) }
            _state = state
        }
        for continuation in _subscribers.values { continuation.yield(state) }
    }

    private func requireStateAndTheme() throws -> (GameState, any ThemePackage) {
        guard let state = _state, let theme = _theme else {
            throw EngineError.themeNotLoaded
        }
        return (state, theme)
    }
}
