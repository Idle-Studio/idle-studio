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

    @State private var viewModel = IdleGameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    public init(themeName: String) {
        self.themeName = themeName
    }

    public var body: some View {
        Group {
            if let error = viewModel.loadError {
                loadErrorView(error)
            } else if viewModel.isReady {
                GameTabView()
                    .environment(\.theme, viewModel.appTheme)
                    .sheet(isPresented: $viewModel.showOfflineSheet) {
                        if let result = viewModel.pendingOfflineResult {
                            OfflineIncomeSheet(result: result) {
                                viewModel.showOfflineSheet = false
                            }
                        }
                    }
#if os(iOS)
                    .fullScreenCover(isPresented: $viewModel.showLevelAdvance) {
                        LevelAdvanceScreen(completedLevelName: viewModel.completedLevelName) {
                            viewModel.showLevelAdvance = false
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
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.appDidBackground() }
        }
        .task { await viewModel.load(themeName: themeName) }
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

    var showOfflineSheet = false
    var pendingOfflineResult: OfflineResult?
    var showLevelAdvance = false
    var completedLevelName = ""
    var showPrestigeSuccess = false
    var showNotificationPermission = false
    private(set) var currentPrestigeCount = 0

    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var transactionTask: Task<Void, Never>?
    private var persistence: SwiftDataPersistenceService?
    private var gameID = ""
    private var lastObservedLevelID = ""
    private var hasCancelledOnForeground = false

    deinit {
        streamTask?.cancel()
        transactionTask?.cancel()
    }

    func load(themeName: String) async {
        do {
            let theme = try ThemeLoader.load(named: themeName)
            gameID = theme.gameID

            // Load persistence service and any saved state.
            let service = try? SwiftDataPersistenceService()
            persistence = service
            let savedState = try? await service?.load(gameID: gameID)

            // ThemeValidator is called inside GameEngine.loadTheme
            try await GameEngine.shared.loadTheme(theme, savedState: savedState)
            appTheme = AppTheme(theme: theme)

            // Check for offline income using last-active timestamp saved on background.
            let lastActive = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date
            if let date = lastActive {
                let result = try await GameEngine.shared.collectOfflineIncome(lastActiveDate: date)
                if result.earnedResources != .zero {
                    pendingOfflineResult = result
                    showOfflineSheet = true
                }
            }

            isReady = true
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
            for await state in GameEngine.shared.stateStream() {
                guard let self else { break }
                ticksSinceLastSave += 1
                if ticksSinceLastSave >= 300 { // autosave every ~30 seconds
                    ticksSinceLastSave = 0
                    await self.saveState()
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
                        let tokenScore = Int(truncating: state.prestigeTokens as NSDecimalNumber)
                        try? await LiveGameCenterService().submitScore(tokenScore, to: theme.leaderboards.globalTokens)
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

                lastPrestigeCount = state.totalPrestigeCount
                self.currentPrestigeCount = state.totalPrestigeCount
                self.lastObservedLevelID = state.currentLevelID
            }
        }
    }
}
