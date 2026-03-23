import Foundation

/// The game loop. A global actor — all game state mutations are isolated here.
///
/// Usage in a game target:
/// ```swift
/// await GameEngine.shared.loadTheme(myTheme)
/// for await state in GameEngine.shared.stateStream { ... }
/// ```
///
/// ViewModels observe `stateStream` from `@MainActor`.
/// Service layer calls player action methods with `await GameEngine.shared.purchaseUnit(...)`.
@globalActor
public actor GameEngine {

    // MARK: - Singleton

    public static let shared = GameEngine()

    // MARK: - State

    private var _state: GameState?
    private var _theme: (any ThemePackage)?
    private var tickTask: Task<Void, Never>?
    /// Accumulates 100ms ticks; adds 1 real-time second every 10 ticks.
    private var playTimeTickAccumulator = 0

    // MARK: - Tick Rate

    /// 100 ms ticks = 10 ticks/second. Idle games don't need sub-100ms precision.
    static let tickInterval: Duration = .milliseconds(100)
    static let tickIntervalSeconds: Decimal = Decimal(string: "0.1")!

    // MARK: - Observable State Stream

    /// Each call returns a fresh `AsyncStream<GameState>` for that subscriber.
    /// Multiple ViewModels can each call `stateStream()` independently — all receive
    /// every tick (multicast). The stream yields the current state immediately on subscribe.
    ///
    /// ```swift
    /// for await state in GameEngine.shared.stateStream() { self.state = state }
    /// ```
    private var _subscribers: [UUID: AsyncStream<GameState>.Continuation] = [:]

    /// Create a new per-subscriber stream. Nonisolated so callers don't need `await`.
    public nonisolated func stateStream() -> AsyncStream<GameState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<GameState>.makeStream(
            of: GameState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [id] _ in
            Task { await GameEngine.shared.removeSubscriber(id: id) }
        }
        Task { await GameEngine.shared.addSubscriber(id: id, continuation: continuation) }
        return stream
    }

    func addSubscriber(id: UUID, continuation: AsyncStream<GameState>.Continuation) {
        _subscribers[id] = continuation
        if let state = _state { continuation.yield(state) }
    }

    func removeSubscriber(id: UUID) {
        _subscribers[id] = nil
    }

    // MARK: - Init

    private init() {}

    deinit { tickTask?.cancel() }

    // MARK: - Lifecycle

    /// Load a theme and optional saved state, then start the tick loop.
    /// Validates the theme via `ThemeValidator` before accepting it — throws on invalid JSON.
    /// Call this once from the app's entry point after loading `[theme].json`.
    public func loadTheme(_ theme: any ThemePackage, savedState: GameState? = nil) throws {
        try ThemeValidator.validate(theme)
        _theme = theme
        let firstLevelID = theme.initialLevel?.id ?? ""
        _state = savedState ?? GameState.initial(firstLevelID: firstLevelID)
        emitState()
        startTickLoop()
    }

    // MARK: - Player Actions

    /// Purchase `quantity` of the unit identified by `id`.
    public func purchaseUnit(id: String, quantity: Int = 1) throws {
        let (state, theme) = try requireStateAndTheme()
        guard let unit = theme.unit(id: id) else {
            throw EngineError.unknownUnit(id)
        }
        let eraUpgrades = theme.level(id: state.currentLevelID)?.eraUpgrades ?? []
        let discount = EconomyCalculator.eraCostMultiplier(purchasedIDs: state.purchasedUpgradeIDs, upgrades: eraUpgrades)
        let cost = EconomyCalculator.bulkBuyCost(
            unit: unit,
            currentCount: state.unitCount(id: id),
            quantity: quantity,
            discountMultiplier: discount
        )
        guard state.resources.canAfford(cost) else {
            throw EngineError.insufficientResources
        }
        _state = state.purchasing(unitID: id, quantity: quantity, cost: cost)
        emitState()
    }

    /// Purchase a one-time era upgrade with the current era's secondary resource.
    public func purchaseEraUpgrade(id: String) throws {
        let (state, theme) = try requireStateAndTheme()
        guard let level = theme.level(id: state.currentLevelID),
              let upgrade = level.eraUpgrades.first(where: { $0.id == id }) else {
            throw EngineError.unknownUnit(id)
        }
        guard !state.purchasedUpgradeIDs.contains(id) else {
            throw EngineError.alreadyCompleted(id)
        }
        guard state.resources.canAfford(upgrade.cost) else {
            throw EngineError.insufficientResources
        }
        _state = state.purchasing(upgradeID: id, cost: upgrade.cost)
        emitState()
    }

    /// Advance to the next level. Requires the current level's `advanceRequirement` to be met
    /// and all of the current level's milestones to be completed.
    public func advanceLevel() throws {
        let (state, theme) = try requireStateAndTheme()
        guard let current = theme.level(id: state.currentLevelID) else {
            throw EngineError.unknownLevel(state.currentLevelID)
        }
        guard state.resources.canAfford(current.advanceRequirement) else {
            throw EngineError.insufficientResources
        }
        guard current.milestones.allSatisfy({ state.completedMilestoneIDs.contains($0.id) }) else {
            throw EngineError.milestonesIncomplete
        }
        guard let next = theme.nextLevel(after: state.currentLevelID) else {
            throw EngineError.noNextLevel
        }
        _state = state.advancingLevel(to: next.id)
        emitState()
    }

    /// Mark a milestone as completed (e.g. construction finished).
    public func completeMilestone(id: String) throws {
        let (state, _) = try requireStateAndTheme()
        guard !state.completedMilestoneIDs.contains(id) else {
            throw EngineError.alreadyCompleted(id)
        }
        _state = state.completing(milestoneID: id)
        emitState()
    }

    /// Begin construction of a milestone. Deducts requirements and starts the countdown.
    /// In the simulator with dev fast-forward, construction time is divided by `devSpeedMultiplier`.
    public func startMilestone(id: String) throws {
        let (state, theme) = try requireStateAndTheme()
        guard let milestone = theme.milestone(id: id) else {
            throw EngineError.unknownUnit(id)
        }
        guard !state.completedMilestoneIDs.contains(id) else {
            throw EngineError.alreadyCompleted(id)
        }
        guard state.inProgressMilestoneID == nil else {
            throw EngineError.constructionInProgress
        }
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

    /// Perform a prestige reset. Requires at least 1 token to be earnable
    /// and the theme's gate milestone to be completed (if one is defined).
    public func prestige() throws {
        let (state, theme) = try requireStateAndTheme()
        guard PrestigeSystem.canPrestige(state: state, theme: theme) else {
            throw EngineError.prestigeNotAvailable
        }
        let newTokens = PrestigeSystem.tokensEarned(from: state)
        let keptMilestones = PrestigeSystem.persistentMilestoneIDs(state: state, theme: theme)
        let firstLevelID = theme.initialLevel?.id ?? ""
        _state = state.applying(
            prestige: newTokens,
            firstLevelID: firstLevelID,
            keepingMilestoneIDs: keptMilestones
        )
        emitState()
    }

    /// Award arbitrary resources — used for IAP purchases and other one-time grants.
    public func awardResources(_ bundle: ResourceBundle) {
        guard let state = _state else { return }
        _state = state.applying(production: bundle)
        emitState()
    }

    /// Award a manual tap — earns 1 second of production (minimum 1 gold).
    public func manualTap() throws {
        let (state, theme) = try requireStateAndTheme()
        let eraUpgrades = theme.level(id: state.currentLevelID)?.eraUpgrades ?? []
        let rate = EconomyCalculator.productionRate(state: state, units: theme.allUnits, eraUpgrades: eraUpgrades)
        let earned = rate["gold"]
        let reward = ResourceBundle(["gold": max(1, earned)])
        _state = state.applying(production: reward)
        emitState()
    }

    /// Calculate and collect offline income from `lastActiveDate` to now.
    /// Applies the earned resources to state and returns the result for display.
    @discardableResult
    public func collectOfflineIncome(lastActiveDate: Date) throws -> OfflineResult {
        let (state, theme) = try requireStateAndTheme()
        let eraUpgrades = theme.level(id: state.currentLevelID)?.eraUpgrades ?? []
        let elapsed = Date().timeIntervalSince(lastActiveDate)
        let result = OfflineCalculator.calculate(
            state: state,
            units: theme.allUnits,
            awayDuration: elapsed,
            eraUpgrades: eraUpgrades
        )
        _state = state.applying(production: result.earnedResources)
        emitState()
        return result
    }

    // MARK: - Tick Loop

    private func startTickLoop() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                self.tick()
            }
        }
    }

    private func tick() {
        guard let state = _state, let theme = _theme else { return }
        let eraUpgrades = theme.level(id: state.currentLevelID)?.eraUpgrades ?? []
        let rate = EconomyCalculator.productionRate(state: state, units: theme.allUnits, eraUpgrades: eraUpgrades)

        // Accumulate real-world play time — never multiplied by dev speed.
        playTimeTickAccumulator += 1
        let addSecond = playTimeTickAccumulator >= 10
        if addSecond { playTimeTickAccumulator = 0 }

        #if targetEnvironment(simulator)
        let speedMul = GameEngine.devFastForwardEnabled ? GameEngine.devSpeedMultiplier : 1
        var next = state.applying(production: rate * Self.tickIntervalSeconds * speedMul)
        #else
        var next = state.applying(production: rate * Self.tickIntervalSeconds)
        #endif
        if addSecond { next = next.addingPlayTime(seconds: 1) }
        // Auto-complete milestone construction when timer expires.
        if let milestoneID = next.inProgressMilestoneID,
           let endDate = next.milestoneConstructionEndDate,
           Date() >= endDate {
            next = next.completing(milestoneID: milestoneID)
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

    // MARK: - Internal

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
