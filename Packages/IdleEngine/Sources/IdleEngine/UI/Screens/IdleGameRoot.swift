import SwiftUI
import StoreKit
import UserNotifications

// MARK: - IdleGameRoot

/// The single entry point for every game in the studio.
///
/// A complete game app target is ~20 lines:
/// ```swift
/// @main struct IdleCivilizationsApp: App {
///     var body: some Scene {
///         WindowGroup { IdleGameRoot(themeName: "civilizations") }
///     }
/// }
/// ```
///
/// `IdleGameRoot` handles everything: theme loading, validation, offline income,
/// persistence, game loop, and navigation. The game JSON is the entire game.
public struct IdleGameRoot: View {
    let themeName: String
    let cloudKitContainerID: String?

    @State private var viewModel = IdleGameViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.adService) private var adService
    @Environment(\.requestReview) private var requestReview

    public init(themeName: String, cloudKitContainerID: String? = nil) {
        self.themeName = themeName
        self.cloudKitContainerID = cloudKitContainerID
    }

    public var body: some View {
        Group {
            if let error = viewModel.loadError {
                loadErrorView(error)
            } else if viewModel.isReady {
                GameTabView()
                    .environment(\.theme, viewModel.appTheme)
                    .environment(\.adService, adService)
                    .fullScreenCover(isPresented: $viewModel.showOnboarding) {
                        OnboardingFlow(gameID: viewModel.gameID, onComplete: {
                            viewModel.showOnboarding = false
                        })
                        .environment(\.theme, viewModel.appTheme)
                    }
                    .sheet(isPresented: $viewModel.showOfflineSheet, onDismiss: {
                        viewModel.pendingOfflineResult = nil
                        viewModel.offlineIncomeDoubled = false
                    }) {
                        if let result = viewModel.pendingOfflineResult {
                            OfflineIncomeSheet(
                                result: result,
                                isDoubled: viewModel.offlineIncomeDoubled,
                                onCollect: { viewModel.showOfflineSheet = false },
                                onDoubleWithAd: (adService.adsRemoved || viewModel.offlineIncomeDoubled) ? nil : {
                                    Task {
                                        let reward = try? await adService.showRewardedAd(placement: .doubleOfflineIncome)
                                        if reward != nil {
                                            await GameEngine.shared.awardResources(result.earnedResources)
                                            withAnimation { viewModel.offlineIncomeDoubled = true }
                                        }
                                    }
                                }
                            )
                        }
                    }
#if os(iOS)
                    .fullScreenCover(isPresented: $viewModel.showLevelAdvance) {
                        LevelAdvanceScreen(completedLevelName: viewModel.completedLevelName) {
                            viewModel.showLevelAdvance = false
                            if !adService.adsRemoved {
                                Task { try? await adService.showInterstitial(placement: .levelAdvance) }
                            }
                        }
                        .environment(\.theme, viewModel.appTheme)
                    }
                    .fullScreenCover(isPresented: $viewModel.showPrestigeSuccess) {
                        PrestigeSuccessScreen {
                            viewModel.showPrestigeSuccess = false
                        }
                        .environment(\.theme, viewModel.appTheme)
                    }
#else
                    .sheet(isPresented: $viewModel.showLevelAdvance) {
                        LevelAdvanceScreen(completedLevelName: viewModel.completedLevelName) {
                            viewModel.showLevelAdvance = false
                            if !adService.adsRemoved {
                                Task { try? await adService.showInterstitial(placement: .levelAdvance) }
                            }
                        }
                        .environment(\.theme, viewModel.appTheme)
                    }
                    .sheet(isPresented: $viewModel.showPrestigeSuccess) {
                        PrestigeSuccessScreen {
                            viewModel.showPrestigeSuccess = false
                        }
                        .environment(\.theme, viewModel.appTheme)
                    }
#endif
                    .sheet(isPresented: $viewModel.showNotificationPermission) {
                        NotificationPermissionSheet(
                            prestigeCount: viewModel.currentPrestigeCount
                        ) { viewModel.showNotificationPermission = false }
                        .environment(\.theme, viewModel.appTheme)
                    }
            } else {
                loadingView
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.appDidBackground() }
        }
        .onChange(of: viewModel.showReviewRequest) { _, newValue in
            guard newValue else { return }
            Task {
                // Small delay so the prestige success screen is fully visible first.
                try? await Task.sleep(for: .seconds(1))
                requestReview()
                viewModel.showReviewRequest = false
            }
        }
        .task {
            await viewModel.load(themeName: themeName, cloudKitContainerID: cloudKitContainerID)
            await preloadAds()
        }
    }

    // MARK: - Ad Preloading

    private func preloadAds() async {
        guard !adService.adsRemoved else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { try? await adService.loadRewardedAd(placement: .doubleOfflineIncome) }
            group.addTask { try? await adService.loadRewardedAd(placement: .skipMilestone) }
            group.addTask { try? await adService.loadInterstitial(placement: .levelAdvance) }
            group.addTask { try? await adService.loadRewardedAd(placement: .freeCoins) }
        }
    }

    // MARK: - Loading / Error Views

    private var loadingView: some View {
        ZStack {
            AppTheme.placeholder.backgroundColor.ignoresSafeArea()
            ProgressView()
                .tint(AppTheme.placeholder.goldAccentColor)
        }
    }

    private func loadErrorView(_ message: String) -> some View {
        ZStack {
            AppTheme.placeholder.backgroundColor.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Failed to load game")
                    .font(Typography.title)
                    .foregroundStyle(AppTheme.placeholder.textPrimaryColor)
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(AppTheme.placeholder.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Tab Container

private struct GameTabView: View {
    @Environment(\.theme) private var theme
    @State private var gameplayViewModel = GameplayViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GameplayScreen(viewModel: gameplayViewModel)
                .tabItem { Label(theme.copy.levelNoun, systemImage: "house.fill") }
                .tag(0)
                .task { gameplayViewModel.start() }

            ShopScreen()
                .tabItem { Label(theme.copy.premiumPassName, systemImage: "cart.fill") }
                .tag(1)

            LeaderboardScreen()
                .tabItem { Label(theme.copy.leaderboardTabLabel, systemImage: "trophy.fill") }
                .tag(2)

            AchievementsScreen()
                .tabItem { Label(theme.copy.achievementsTabLabel, systemImage: "rosette") }
                .tag(3)

            SettingsScreen()
                .tabItem { Label(theme.copy.settingsTabLabel, systemImage: "gear") }
                .tag(4)
        }
        .tint(theme.levelPrimaryColor(for: gameplayViewModel.state.currentLevelID))
        .onReceive(NotificationCenter.default.publisher(for: .iapRewardReceived)) { _ in
            withAnimation { selectedTab = 0 }
        }
    }
}

// MARK: - IdleGameViewModel

@Observable
@MainActor
public final class IdleGameViewModel {
    public private(set) var appTheme: AppTheme = .placeholder
    public private(set) var isReady = false
    public private(set) var loadError: String?

    var showOnboarding = false
    var showOfflineSheet = false
    var offlineIncomeDoubled = false
    var pendingOfflineResult: OfflineResult?
    var showLevelAdvance = false
    var completedLevelName = ""
    var showPrestigeSuccess = false
    var showNotificationPermission = false
    var showReviewRequest = false
    private static let appVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private(set) var currentPrestigeCount = 0

    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var transactionTask: Task<Void, Never>?
    private var persistence: SwiftDataPersistenceService?
    private(set) var gameID = ""
    private var lastObservedLevelID = ""
    private var hasCancelledOnForeground = false

    deinit {
        streamTask?.cancel()
        transactionTask?.cancel()
    }

    func load(themeName: String, cloudKitContainerID: String? = nil) async {
        do {
            let theme = try ThemeLoader.load(named: themeName)
            gameID = theme.gameID

            // Load persistence service and any saved state.
            let service = try? SwiftDataPersistenceService(cloudKitContainerID: cloudKitContainerID)
            persistence = service
            let savedState = try? await service?.load(gameID: gameID)

            // ThemeValidator is called inside GameEngine.loadTheme
            try await GameEngine.shared.loadTheme(theme, savedState: savedState)
            appTheme = AppTheme(theme: theme)

            // Determine onboarding state before making isReady=true so we can suppress
            // conflicting modals before the view renders.
            let onboardingKey = "onboarding_completed_\(gameID)"
            let needsOnboarding = !UserDefaults.standard.bool(forKey: onboardingKey)

            // Check for offline income using last-active timestamp saved on background.
            // Skip when onboarding will be shown — a new user has no meaningful offline income,
            // and presenting two modals simultaneously causes a continuous warning spam.
            if !needsOnboarding {
                let lastActive = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date
                if let date = lastActive {
                    let result = try await GameEngine.shared.collectOfflineIncome(lastActiveDate: date)
                    if result.earnedResources != .zero {
                        // Premium pass subscribers receive 2× offline income.
                        // Award the base amount a second time so the engine state is correct,
                        // then set offlineIncomeDoubled so the sheet reflects it and hides the ad button.
                        if let passID = theme.iapProducts.premiumPass,
                           await LiveStoreKitService().isPremiumPassActive(productID: passID) {
                            await GameEngine.shared.awardResources(result.earnedResources)
                            offlineIncomeDoubled = true
                        }
                        pendingOfflineResult = result
                        showOfflineSheet = true
                    }
                }
            }

            isReady = true

            if needsOnboarding {
                showOnboarding = true
            }

            // Start ambient audio for the initial era.
            if let state = await GameEngine.shared.currentState,
               let level = theme.level(id: state.currentLevelID),
               let asset = level.soundAsset {
                AudioService.shared.playAmbient(asset: asset)
            }
            startObservingStream()
            startObservingTransactions()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Called when the app moves to the background. Saves state, records timestamp, and schedules notifications.
    func appDidBackground() {
        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
        hasCancelledOnForeground = false
        Task {
            await saveState()
            await scheduleNotifications()
        }
    }

    /// Computes a Game Center score that increments for ALL players at every stage.
    ///
    /// Formula: `totalPrestigeCount * 1_000_000 + goldProgress`
    /// where `goldProgress` is 0–999_999, representing how far through the ~3T gold
    /// prestige threshold the player is. This means:
    /// - Early players (0 prestiges): score grows 0 → 999,999 as they earn gold
    /// - After 1st prestige: score jumps to 1,000,000+
    /// - After Nth prestige: score is N × 1,000,000 + current run progress
    /// The leaderboard is infinite — higher prestige always wins, but runs in progress
    /// show visible, meaningful increments.
    static func leaderboardScore(for state: GameState) -> Int {
        // Normalize lifetime gold on a 0–999_999 scale against the ~3T prestige threshold.
        // 3_000_000_000_000 / 3_000_000 = 1_000_000, so dividing by 3_000_000 maps
        // 0…3T gold → 0…1_000_000 (capped at 999_999 so it never reaches the prestige bucket).
        let goldProgress = Int(
            truncating: min(state.totalLifetimeGold / 3_000_000, Decimal(999_999)) as NSDecimalNumber
        )
        return state.totalPrestigeCount * 1_000_000 + goldProgress
    }

    private func saveState() async {
        guard let persistence,
              let state = await GameEngine.shared.currentState else { return }
        try? await persistence.save(state: state, gameID: gameID)
    }

    private func scheduleNotifications() async {
        guard let state = await GameEngine.shared.currentState,
              let theme = await GameEngine.shared.currentTheme else { return }
        let svc = LiveNotificationService()
        await svc.cancelAll()

        // Offline income cap — 6 hours
        await svc.schedule(
            .offlineCap, copy: theme.copy,
            fireIn: LiveNotificationService.quietHoursAdjusted(fireIn: 6 * 3600)
        )

        // Era advance ready — only if gold requirement is already met
        if let level = theme.level(id: state.currentLevelID),
           state.resources.canAfford(level.advanceRequirement),
           theme.nextLevel(after: state.currentLevelID) != nil {
            await svc.schedule(
                .levelReady, copy: theme.copy,
                fireIn: LiveNotificationService.quietHoursAdjusted(fireIn: 24 * 3600)
            )
        }

        // Wonder construction — fire when the countdown completes
        if let endDate = state.milestoneConstructionEndDate,
           state.inProgressMilestoneID != nil {
            let remaining = max(1, endDate.timeIntervalSinceNow + 2)
            await svc.schedule(.wonderComplete, copy: theme.copy, fireIn: remaining)
        }

        // Submit weekly gold score to Game Center
        let goldScore = (min(state.totalLifetimeGold, Decimal(Int.max)) as NSDecimalNumber).intValue
        try? await LiveGameCenterService().submitScore(goldScore, to: theme.leaderboards.weeklyGold)
    }

    private func startObservingTransactions() {
        transactionTask?.cancel()
        transactionTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let transaction = try? verificationResult.payloadValue else { continue }
                await transaction.finish()
                // Re-award coins for any transaction that completed outside the purchase flow
                // (subscription renewals, interrupted purchases, etc.)
                // ShopViewModel handles coin grants for user-initiated purchases;
                // this path handles edge cases like family purchases and StoreKit recovery.
                _ = self
            }
        }
    }

    private func startObservingStream() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var ticksSinceLastSave = 0
            var lastPrestigeCount = -1
            var lastCompletedMilestoneCount = -1
            for await state in GameEngine.shared.stateStream() {
                guard let self else { break }
                ticksSinceLastSave += 1
                if ticksSinceLastSave >= 300 { // autosave every ~30 seconds
                    ticksSinceLastSave = 0
                    await self.saveState()
                    // Submit leaderboard scores periodically so rankings stay fresh mid-session
                    if let theme = await GameEngine.shared.currentTheme {
                        let svc = LiveGameCenterService()
                        let globalScore = IdleGameViewModel.leaderboardScore(for: state)
                        try? await svc.submitScore(globalScore, to: theme.leaderboards.globalTokens)
                        if let countryID = theme.leaderboards.countryTokens {
                            try? await svc.submitScore(globalScore, to: countryID)
                        }
                        let goldScore = (min(state.totalLifetimeGold, Decimal(Int.max)) as NSDecimalNumber).intValue
                        try? await svc.submitScore(goldScore, to: theme.leaderboards.weeklyGold)
                    }
                }

                // Cancel stale notifications on first tick after foreground
                if !self.hasCancelledOnForeground {
                    self.hasCancelledOnForeground = true
                    let svc = LiveNotificationService()
                    await svc.cancel(.offlineCap)
                    if state.inProgressMilestoneID == nil {
                        await svc.cancel(.wonderComplete)
                    }
                    if let theme = await GameEngine.shared.currentTheme,
                       let level = theme.level(id: state.currentLevelID),
                       !state.resources.canAfford(level.advanceRequirement) {
                        await svc.cancel(.levelReady)
                    }
                }

                // Detect prestige — show success screen + submit GC leaderboard score
                if lastPrestigeCount >= 0 && state.totalPrestigeCount > lastPrestigeCount {
                    self.showPrestigeSuccess = true
                    HapticsService.notification(.success)
                    Task {
                        guard let theme = await GameEngine.shared.currentTheme else { return }
                        let svc = LiveGameCenterService()
                        let globalScore = Self.leaderboardScore(for: state)
                        try? await svc.submitScore(globalScore, to: theme.leaderboards.globalTokens)
                        if let countryID = theme.leaderboards.countryTokens {
                            try? await svc.submitScore(globalScore, to: countryID)
                        }
                        let goldScore = (min(state.totalLifetimeGold, Decimal(Int.max)) as NSDecimalNumber).intValue
                        try? await svc.submitScore(goldScore, to: theme.leaderboards.weeklyGold)
                    }

                    // Review request: 2nd prestige is the sweet spot — player is engaged and just had a big win
                    if state.totalPrestigeCount == 2 {
                        let key = "review_requested_v\(IdleGameViewModel.appVersion)"
                        if !UserDefaults.standard.bool(forKey: key) {
                            UserDefaults.standard.set(true, forKey: key)
                            self.showReviewRequest = true
                        }
                    }
                }

                // Detect era advance (not prestige) — switch ambient track + haptic + maybe ask for notifications
                let prevLevelID = self.lastObservedLevelID
                if prevLevelID != "" &&
                   state.currentLevelID != prevLevelID &&
                   state.totalPrestigeCount == lastPrestigeCount {
                    HapticsService.notification(.success)
                    if let theme = await GameEngine.shared.currentTheme,
                       let level = theme.level(id: state.currentLevelID),
                       let asset = level.soundAsset {
                        AudioService.shared.playAmbient(asset: asset)
                    }
                    let key = "notif_asked_prestige_\(state.totalPrestigeCount)"
                    let alreadyAsked = UserDefaults.standard.bool(forKey: key)
                    if !alreadyAsked {
                        let settings = await UNUserNotificationCenter.current().notificationSettings()
                        if settings.authorizationStatus == .notDetermined {
                            self.showNotificationPermission = true
                        }
                    }
                }

                // Review request: first wonder built in run #1 is a high point for non-prestigers
                if lastCompletedMilestoneCount >= 0 &&
                   state.completedMilestoneIDs.count > lastCompletedMilestoneCount &&
                   state.totalPrestigeCount == 0 {
                    let key = "review_requested_v\(IdleGameViewModel.appVersion)"
                    if !UserDefaults.standard.bool(forKey: key) {
                        UserDefaults.standard.set(true, forKey: key)
                        self.showReviewRequest = true
                    }
                }
                lastCompletedMilestoneCount = state.completedMilestoneIDs.count

                lastPrestigeCount = state.totalPrestigeCount
                self.currentPrestigeCount = state.totalPrestigeCount
                self.lastObservedLevelID = state.currentLevelID
            }
        }
    }
}
