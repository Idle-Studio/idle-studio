import SwiftUI
import StoreKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

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
    @Environment(\.openURL) private var openURL

    public init(themeName: String, cloudKitContainerID: String? = nil) {
        self.themeName = themeName
        self.cloudKitContainerID = cloudKitContainerID
    }

    public var body: some View {
        Group {
            if let failure = viewModel.loadFailure {
                loadErrorView(failure)
            } else if viewModel.isReady {
                readyBody
            } else {
                loadingView
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.appDidBecomeActive()
            case .inactive:
                // Save here too. `.background` is not guaranteed to arrive before the process
                // is suspended or killed, and `.inactive` fires first for every transition.
                viewModel.appWillResignActive()
            case .background:
                viewModel.appDidBackground()
            @unknown default:
                break
            }
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
            // Consent → ATT → SDK init, in that order, and only now that the scene is active.
            await adService.start()
            await preloadAds()
        }
        .onReceive(NotificationCenter.default.publisher(for: .engineStateShouldPersist)) { _ in
            // Any grant the player earned or paid for persists immediately rather than
            // waiting up to 30 seconds for the next autosave window.
            Task { await viewModel.saveNow() }
        }
    }

    // MARK: - Ready

    @ViewBuilder
    private var readyBody: some View {
        GameTabView()
            .environment(\.theme, viewModel.appTheme)
            .environment(\.adService, adService)
            .modifier(OnboardingPresenter(viewModel: viewModel))
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
                                guard reward != nil else {
                                    viewModel.presentMessage(
                                        String(localized: "No ad is available right now. Please try again shortly."),
                                        isError: true
                                    )
                                    return
                                }
                                await GameEngine.shared.awardResources(result.earnedResources)
                                // Persist immediately. Autosave is 30s away, and a grant lost
                                // to a force-quit is indistinguishable from a broken reward.
                                await viewModel.saveNow()
                                withAnimation { viewModel.offlineIncomeDoubled = true }
                            }
                        }
                    )
                }
            }
            .modifier(
                LevelAdvancePresenter(viewModel: viewModel, adService: adService)
            )
            .modifier(PrestigeSuccessPresenter(viewModel: viewModel))
            .sheet(isPresented: $viewModel.showNotificationPermission) {
                NotificationPermissionSheet(
                    prestigeCount: viewModel.currentPrestigeCount
                ) { viewModel.showNotificationPermission = false }
                .environment(\.theme, viewModel.appTheme)
            }
            .overlay(alignment: .top) { messageBanner }
    }

    /// Single surface for engine and store errors.
    ///
    /// Every fallible action used to be `try?`, so a failed purchase, a declined payment, an
    /// unavailable ad, and a rejected era advance were all indistinguishable from a dead
    /// button. Players concluded the game was broken.
    @ViewBuilder
    private var messageBanner: some View {
        if let message = viewModel.transientMessage {
            HStack(spacing: 8) {
                Image(systemName: message.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(message.isError ? .orange : .green)
                Text(message.text)
                    .font(Typography.subheadline)
                    .foregroundStyle(viewModel.appTheme.textPrimaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(viewModel.appTheme.surfaceElevatedColor, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .padding(.horizontal, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(message.text)
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
                .accessibilityLabel(Text("Loading game"))
        }
    }

    private func loadErrorView(_ failure: IdleGameViewModel.LoadFailure) -> some View {
        ZStack {
            AppTheme.placeholder.backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text(failure.title)
                        .font(Typography.title)
                        .foregroundStyle(AppTheme.placeholder.textPrimaryColor)
                        .multilineTextAlignment(.center)
                    Text(failure.message)
                        .font(Typography.body)
                        .foregroundStyle(AppTheme.placeholder.textSecondaryColor)
                        .multilineTextAlignment(.center)
                    if let suggestion = failure.suggestion {
                        Text(suggestion)
                            .font(Typography.caption)
                            .foregroundStyle(AppTheme.placeholder.textSecondaryColor)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task {
                                await viewModel.load(
                                    themeName: themeName, cloudKitContainerID: cloudKitContainerID
                                )
                            }
                        } label: {
                            Text("Try Again")
                                .font(Typography.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        // The one screen a player cannot reach Settings from — so the support
                        // path has to live here too. Without it their only option is a cold
                        // email, which is exactly how this class of bug reached us.
                        if let supportURL = viewModel.supportURL {
                            Button {
                                openURL(supportURL)
                            } label: {
                                Text("Contact Support")
                                    .font(Typography.subheadline)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8)

                    if failure.isRecoverableSave {
                        Text(verbatim: failure.diagnosticDetail)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(AppTheme.placeholder.textSecondaryColor)
                            .textSelection(.enabled)
                            .padding(.top, 12)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
            }
        }
    }
}

// MARK: - Platform-Specific Presenters

/// `fullScreenCover` is unavailable on macOS; these keep the call site readable.
private struct OnboardingPresenter: ViewModifier {
    @Bindable var viewModel: IdleGameViewModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $viewModel.showOnboarding) { sheet }
        #else
        content.sheet(isPresented: $viewModel.showOnboarding) { sheet }
        #endif
    }

    private var sheet: some View {
        OnboardingFlow(gameID: viewModel.gameID, onComplete: {
            viewModel.completeOnboarding()
        })
        .environment(\.theme, viewModel.appTheme)
    }
}

private struct LevelAdvancePresenter: ViewModifier {
    @Bindable var viewModel: IdleGameViewModel
    let adService: any AdService

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $viewModel.showLevelAdvance) { sheet }
        #else
        content.sheet(isPresented: $viewModel.showLevelAdvance) { sheet }
        #endif
    }

    private var sheet: some View {
        LevelAdvanceScreen(completedLevelName: viewModel.completedLevelName) {
            viewModel.showLevelAdvance = false
            if !adService.adsRemoved {
                Task { try? await adService.showInterstitial(placement: .levelAdvance) }
            }
        }
        .environment(\.theme, viewModel.appTheme)
    }
}

private struct PrestigeSuccessPresenter: ViewModifier {
    @Bindable var viewModel: IdleGameViewModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $viewModel.showPrestigeSuccess) { sheet }
        #else
        content.sheet(isPresented: $viewModel.showPrestigeSuccess) { sheet }
        #endif
    }

    private var sheet: some View {
        PrestigeSuccessScreen {
            viewModel.showPrestigeSuccess = false
        }
        .environment(\.theme, viewModel.appTheme)
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

            MilestonesScreen()
                .tabItem { Label(theme.copy.milestoneNoun, systemImage: "building.columns.fill") }
                .tag(1)

            ShopScreen()
                .tabItem { Label(theme.copy.premiumPassName, systemImage: "cart.fill") }
                .tag(2)

            LeaderboardScreen()
                .tabItem { Label(theme.copy.leaderboardTabLabel, systemImage: "trophy.fill") }
                .tag(3)

            AchievementsScreen()
                .tabItem { Label(theme.copy.achievementsTabLabel, systemImage: "rosette") }
                .tag(4)

            SettingsScreen()
                .tabItem { Label(theme.copy.settingsTabLabel, systemImage: "gear") }
                .tag(5)
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

    // MARK: Load Failure

    public struct LoadFailure: Equatable, Sendable {
        public let title: String
        public let message: String
        public let suggestion: String?
        /// True when a real save exists on disk that we refused to overwrite.
        public let isRecoverableSave: Bool
        public let diagnosticDetail: String
    }

    public struct TransientMessage: Equatable, Sendable {
        public let text: String
        public let isError: Bool
    }

    public private(set) var appTheme: AppTheme = .placeholder
    public private(set) var isReady = false
    public private(set) var loadFailure: LoadFailure?
    public private(set) var transientMessage: TransientMessage?
    public private(set) var supportURL: URL?

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

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var persistence: SwiftDataPersistenceService?
    @ObservationIgnored private var lastAutosave: Date = .distantPast
    private(set) var gameID = ""
    private var lastObservedLevelID = ""
    private var hasCancelledOnForeground = false
    private var hasLoadedOnce = false

    /// Wall-clock autosave interval. This used to be a count of stream elements, but the
    /// stream drops elements under back-pressure, so the real interval silently stretched.
    private static let autosaveInterval: TimeInterval = 30

    deinit {
        streamTask?.cancel()
        messageTask?.cancel()
    }

    // MARK: - Load

    func load(themeName: String, cloudKitContainerID: String? = nil) async {
        loadFailure = nil

        let theme: any ThemePackage
        do {
            theme = try ThemeLoader.load(named: themeName)
        } catch {
            loadFailure = LoadFailure(
                title: String(localized: "Couldn't start the game"),
                message: error.localizedDescription,
                suggestion: (error as? LocalizedError)?.recoverySuggestion,
                isRecoverableSave: false,
                diagnosticDetail: "\(error)"
            )
            return
        }

        gameID = theme.gameID
        supportURL = URL(string: theme.copy.supportURL ?? "")

        // Open the store. A failure here is fatal to the session on purpose: the alternative
        // is what shipped — a game that plays perfectly and silently discards every second
        // of progress, with no error and no telemetry.
        if persistence == nil {
            do {
                persistence = try SwiftDataPersistenceService(
                    cloudKitContainerID: cloudKitContainerID,
                    onCloudKitFailure: { error in
                        Analytics.record(.cloudSyncUnavailable(reason: "\(error)"))
                    }
                )
            } catch {
                Analytics.record(.persistenceUnavailable(reason: "\(error)"))
                loadFailure = LoadFailure(
                    title: String(localized: "Can't access your saved game"),
                    message: String(localized: "Your progress can't be saved on this device right now, so we've stopped before you lose any."),
                    suggestion: String(localized: "Check that your device has free storage, then try again."),
                    isRecoverableSave: false,
                    diagnosticDetail: "\(error)"
                )
                return
            }
        }

        // Load the save. `nil` means "genuinely new player"; a throw means a real save exists
        // that we could not read, and starting fresh would let the 30-second autosave destroy
        // it. Refuse instead.
        var savedState: GameState?
        do {
            savedState = try await persistence?.load(gameID: gameID)
        } catch {
            Analytics.record(.saveCorrupted(reason: "\(error)"))
            loadFailure = LoadFailure(
                title: String(localized: "Your saved game couldn't be read"),
                message: String(localized: "We found your save but couldn't open it. We have not overwritten it — your progress may still be recoverable, so please don't delete the app."),
                suggestion: String(localized: "Contact support with the details below and we'll help."),
                isRecoverableSave: true,
                diagnosticDetail: "\(error)"
            )
            return
        }

        let onboardingKey = "onboarding_completed_\(gameID)"
        // A restored CloudKit save means this is a returning player even when UserDefaults
        // was wiped by a reinstall. Without this check, someone whose Space Age empire had
        // just synced back was shown "Welcome, Great Leader" and the subscription paywall.
        let hasRealProgress = (savedState?.totalLifetimeGold ?? 0) > 0
        let needsOnboarding = !UserDefaults.standard.bool(forKey: onboardingKey) && !hasRealProgress
        if hasRealProgress { UserDefaults.standard.set(true, forKey: onboardingKey) }

        // Data-loss canary: onboarding is complete but nothing loaded. By definition someone
        // lost progress. This is the alert that should have existed.
        if savedState == nil && UserDefaults.standard.bool(forKey: onboardingKey) {
            Analytics.record(.progressLossDetected(reason: "no save for onboarded player \(gameID)"))
        }

        do {
            try await GameEngine.shared.loadTheme(theme, savedState: savedState)
        } catch {
            loadFailure = LoadFailure(
                title: String(localized: "Couldn't start the game"),
                message: error.localizedDescription,
                suggestion: (error as? LocalizedError)?.recoverySuggestion,
                isRecoverableSave: false,
                diagnosticDetail: "\(error)"
            )
            return
        }

        appTheme = AppTheme(theme: theme)

        // Single owner of `Transaction.updates` for the whole app. There used to be six
        // independent iterators, three of which raced to `finish()` transactions that none
        // of them granted — so any purchase arriving outside the direct buy flow (Ask to Buy,
        // Family Sharing, interrupted-purchase recovery) was acknowledged and dropped.
        PurchaseCoordinator.shared.configure(theme: theme) { [weak self] _ in
            await self?.saveNow()
        }

        if !needsOnboarding {
            await settleOfflineIncome(savedState: savedState, theme: theme)
        }

        isReady = true
        if needsOnboarding { showOnboarding = true }

        // Start ambient audio for the initial era.
        if let state = await GameEngine.shared.currentState,
           let level = theme.level(id: state.currentLevelID),
           let asset = level.soundAsset {
            AudioService.shared.playAmbient(asset: asset)
        }

        if !hasLoadedOnce {
            hasLoadedOnce = true
            startObservingStream()
        }
    }

    /// Credits time away and presents the reward sheet.
    ///
    /// Prefers the persisted `lastSaveDate` over the UserDefaults timestamp. The two are
    /// independent clocks that desync whenever the app dies without a clean background
    /// transition, and only `lastSaveDate` is atomic with the state it describes.
    private func settleOfflineIncome(savedState: GameState?, theme: any ThemePackage) async {
        let defaultsDate = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date
        guard let reference = savedState?.lastSaveDate ?? defaultsDate else { return }

        let result: OfflineResult
        do {
            result = try await GameEngine.shared.collectOfflineIncome(lastActiveDate: reference)
        } catch {
            return
        }
        guard result.earnedResources != .zero else { return }

        if await entitlements.hasPremiumPass(theme: theme) {
            await GameEngine.shared.awardResources(result.earnedResources)
            offlineIncomeDoubled = true
        }
        pendingOfflineResult = result
        showOfflineSheet = true
        await saveNow()
    }

    @ObservationIgnored private let entitlements = EntitlementStore.shared

    // MARK: - Onboarding

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed_\(gameID)")
        showOnboarding = false
        Task { await settleOfflineIncomeAfterOnboarding() }
    }

    private func settleOfflineIncomeAfterOnboarding() async {
        guard let theme = await GameEngine.shared.currentTheme else { return }
        await settleOfflineIncome(savedState: await GameEngine.shared.currentState, theme: theme)
    }

    // MARK: - Messages

    func presentMessage(_ text: String, isError: Bool) {
        messageTask?.cancel()
        withAnimation { transientMessage = TransientMessage(text: text, isError: isError) }
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { self?.transientMessage = nil }
        }
    }

    // MARK: - Scene Phase

    func appDidBecomeActive() {
        Task {
            // A subscription can lapse while the app is backgrounded. Without this the app
            // would keep suppressing ads until the next cold launch.
            await EntitlementStore.shared.refresh()
            await GameEngine.shared.resumeTicking()
            // Settle time away even when the process was never killed. iOS suspends the app
            // so the tick loop produces nothing while backgrounded; without this the player
            // lost the entire gap unless they happened to be evicted from memory.
            if isReady, let theme = await GameEngine.shared.currentTheme {
                await settleOfflineIncome(
                    savedState: await GameEngine.shared.currentState, theme: theme
                )
            }
        }
    }

    func appWillResignActive() {
        Task { await saveNow() }
    }

    /// Called when the app moves to the background. Saves state, records timestamp, and
    /// schedules notifications.
    func appDidBackground() {
        hasCancelledOnForeground = false
        Task {
            await withBackgroundTaskAssertion { [weak self] in
                guard let self else { return }
                await self.saveNow()
                await GameEngine.shared.pauseTicking()
                await self.scheduleNotifications()
            }
        }
    }

    /// Keeps the process alive long enough for the save to land.
    ///
    /// The save awaits a hop to the engine actor, a JSON encode, a fetch, and a SQLite write
    /// that CloudKit may extend. Racing suspension with no assertion meant the write could
    /// simply not complete.
    private func withBackgroundTaskAssertion(_ work: @escaping @Sendable () async -> Void) async {
        #if canImport(UIKit) && !os(watchOS)
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "SaveGameState")
        await work()
        if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
        #else
        await work()
        #endif
    }

    // MARK: - Persistence

    /// Persists immediately. Call after any grant the player paid for — real money or an ad
    /// view — rather than waiting for the next autosave window.
    func saveNow() async {
        guard let persistence, let state = await GameEngine.shared.currentState else { return }
        do {
            try await persistence.save(state: state, gameID: gameID)
            lastAutosave = Date()
            UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
        } catch {
            Analytics.record(.saveFailed(reason: "\(error)"))
            presentMessage(
                String(localized: "Your progress couldn't be saved. Please check your storage."),
                isError: true
            )
        }
    }

    /// Permanently erases this game's saved data. Backs the Settings "Delete My Data" row.
    func deleteAllData() async throws {
        guard let persistence else { return }
        try await persistence.deleteAll(gameID: gameID)
        UserDefaults.standard.removeObject(forKey: "onboarding_completed_\(gameID)")
        UserDefaults.standard.removeObject(forKey: "lastActiveDate")
    }

    // MARK: - Leaderboards

    /// Computes a Game Center score that increments for ALL players at every stage.
    ///
    /// Formula: `totalPrestigeCount * 1_000_000 + goldProgress`
    /// where `goldProgress` is 0–999_999, representing how far through the ~3T gold
    /// prestige threshold the player is.
    static func leaderboardScore(for state: GameState) -> Int {
        let goldProgress = Int(
            truncating: min(max(0, state.totalLifetimeGold / 3_000_000), Decimal(999_999)) as NSDecimalNumber
        )
        return state.totalPrestigeCount * 1_000_000 + goldProgress
    }

    private func submitScores(for state: GameState, theme: any ThemePackage) async {
        let svc = LiveGameCenterService()
        let globalScore = Self.leaderboardScore(for: state)
        try? await svc.submitScore(globalScore, to: theme.leaderboards.globalTokens)
        if let countryID = theme.leaderboards.countryTokens {
            try? await svc.submitScore(globalScore, to: countryID)
        }
        let capped = min(max(0, state.totalLifetimeGold), Decimal(Int.max))
        try? await svc.submitScore((capped as NSDecimalNumber).intValue, to: theme.leaderboards.weeklyGold)
    }

    private func scheduleNotifications() async {
        guard let state = await GameEngine.shared.currentState,
              let theme = await GameEngine.shared.currentTheme else { return }
        let svc = LiveNotificationService()
        await svc.cancelAll()

        await svc.schedule(
            .offlineCap, copy: theme.copy,
            fireIn: LiveNotificationService.quietHoursAdjusted(fireIn: OfflineCalculator.maxCapSeconds)
        )

        if let level = theme.level(id: state.currentLevelID),
           state.resources.canAfford(level.advanceRequirement),
           theme.nextLevel(after: state.currentLevelID) != nil {
            await svc.schedule(
                .levelReady, copy: theme.copy,
                fireIn: LiveNotificationService.quietHoursAdjusted(fireIn: 24 * 3600)
            )
        }

        if let endDate = state.milestoneConstructionEndDate, state.inProgressMilestoneID != nil {
            let remaining = max(1, endDate.timeIntervalSinceNow + 2)
            await svc.schedule(.wonderComplete, copy: theme.copy, fireIn: remaining)
        }

        await submitScores(for: state, theme: theme)
    }

    // MARK: - State Observation

    private func startObservingStream() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var lastPrestigeCount = -1
            var lastCompletedMilestoneCount = -1

            for await state in await GameEngine.shared.stateStream() {
                guard let self else { break }

                if Date().timeIntervalSince(self.lastAutosave) >= Self.autosaveInterval {
                    await self.saveNow()
                    if let theme = await GameEngine.shared.currentTheme {
                        // Detached so a slow GameKit round-trip doesn't stall the loop and
                        // cause the engine to drop states we still need to inspect below.
                        Task.detached { [weak self] in
                            await self?.submitScores(for: state, theme: theme)
                        }
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
                    await self.saveNow()
                    if let theme = await GameEngine.shared.currentTheme {
                        Task.detached { [weak self] in
                            await self?.submitScores(for: state, theme: theme)
                        }
                    }

                    if state.totalPrestigeCount == 2 {
                        let key = "review_requested_v\(IdleGameViewModel.appVersion)"
                        if !UserDefaults.standard.bool(forKey: key) {
                            UserDefaults.standard.set(true, forKey: key)
                            self.showReviewRequest = true
                        }
                    }
                }

                // Detect era advance (not prestige) — celebration, ambient track, haptic
                let previousLevelID = self.lastObservedLevelID
                if !previousLevelID.isEmpty,
                   state.currentLevelID != previousLevelID,
                   state.totalPrestigeCount == lastPrestigeCount {
                    HapticsService.notification(.success)

                    // Present the celebration. `showLevelAdvance` was declared and never set,
                    // so `LevelAdvanceScreen` — a finished, animated, Reduce-Motion-aware
                    // screen — was unreachable, and the biggest beat in the game (roughly
                    // eight times per run) produced only a haptic. It also gated the
                    // `levelAdvance` interstitial, so that ad placement never filled.
                    if let theme = await GameEngine.shared.currentTheme {
                        self.completedLevelName =
                            theme.level(id: previousLevelID)?.displayName ?? ""
                        self.showLevelAdvance = true

                        if let level = theme.level(id: state.currentLevelID),
                           let asset = level.soundAsset {
                            AudioService.shared.playAmbient(asset: asset)
                        }
                    }
                    await self.saveNow()

                    let key = "notif_asked_prestige_\(state.totalPrestigeCount)"
                    if !UserDefaults.standard.bool(forKey: key) {
                        let settings = await UNUserNotificationCenter.current().notificationSettings()
                        if settings.authorizationStatus == .notDetermined {
                            UserDefaults.standard.set(true, forKey: key)
                            self.showNotificationPermission = true
                        }
                    }
                }

                // Review request: first milestone built in run #1 is a high point
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
