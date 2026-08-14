import SwiftUI

/// Game Center leaderboard screen. Leaderboard IDs come from `theme.leaderboards`.
public struct LeaderboardScreen: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = LeaderboardViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Scope picker
                    Picker("Scope", selection: $viewModel.selectedScope) {
                        Text("Global").tag(LeaderboardScope.global)
                        Text("This Week").tag(LeaderboardScope.thisWeek)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .onChange(of: viewModel.selectedScope) { _, _ in
                        Task { await viewModel.load() }
                    }

                    Group {
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                                .tint(theme.goldAccentColor)
                            Spacer()
                        } else if viewModel.entries.isEmpty {
                            emptyState
                        } else {
                            entriesList
                        }
                    }
                }
            }
            .navigationTitle(theme.copy.leaderboardTabLabel)
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            #endif
            #if DEBUG && os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isHidingLocalScore ? "Show My Score" : "Hide My Score") {
                        viewModel.toggleHideLocalScore()
                    }
                }
            }
            #endif
            .task { await viewModel.load() }
        }
    }

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.entries) { entry in
                    LeaderboardRow(entry: entry)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(theme.textSecondaryColor)
            Text(viewModel.isGameCenterUnavailable
                 ? "Sign in to Game Center to view the leaderboard."
                 : theme.copy.leaderboardEmptyState)
                .font(Typography.body)
                .foregroundStyle(theme.textSecondaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - LeaderboardRow

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(entry.rank)")
                .font(Typography.number)
                .foregroundStyle(rankColor)
                .frame(width: 44, alignment: .leading)

            Text(entry.playerName)
                .font(Typography.body)
                .foregroundStyle(theme.textPrimaryColor)
                .lineLimit(1)

            Spacer()

            Text(Decimal(entry.score).idleFormatted())
                .font(Typography.number)
                .foregroundStyle(theme.goldAccentColor)
                .monospacedDigit()
        }
        .padding(12)
        .background(entry.isLocalPlayer ? theme.goldAccentColor.opacity(0.1) : theme.surfaceColor)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            if entry.isLocalPlayer {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.goldAccentColor.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return AppTheme.rankGold
        case 2: return AppTheme.rankSilver
        case 3: return AppTheme.rankBronze
        default: return theme.textSecondaryColor
        }
    }
}

// MARK: - LeaderboardViewModel

@Observable
@MainActor
final class LeaderboardViewModel {
    var isLoading = false
    var entries: [LeaderboardEntry] = []
    var selectedScope: LeaderboardScope = .global
    var isGameCenterUnavailable = false

    #if DEBUG
    private(set) var isHidingLocalScore: Bool = UserDefaults.standard.bool(forKey: "debug.leaderboard.hideLocalScore")
    #endif

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let theme = await GameEngine.shared.currentTheme else { return }

        let svc = LiveGameCenterService()
        let authenticated = await svc.authenticate()
        guard authenticated else {
            isGameCenterUnavailable = true
            return
        }
        isGameCenterUnavailable = false

        // Submit current scores so the local player always appears in the leaderboard.
        // Skipped in debug when hiding the local score — Game Center ignores lower scores
        // anyway (best-score policy), so the only reliable way to "reset" for testing is
        // to stop submitting and filter the local entry out of the results.
        #if DEBUG
        let shouldSubmit = !isHidingLocalScore
        #else
        let shouldSubmit = true
        #endif
        if shouldSubmit, let state = await GameEngine.shared.currentState {
            let goldScore = (min(state.totalLifetimeGold, Decimal(Int.max)) as NSDecimalNumber).intValue
            try? await svc.submitScore(goldScore, to: theme.leaderboards.weeklyGold)
            let globalScore = IdleGameViewModel.leaderboardScore(for: state)
            try? await svc.submitScore(globalScore, to: theme.leaderboards.globalTokens)
            if let countryID = theme.leaderboards.countryTokens {
                try? await svc.submitScore(globalScore, to: countryID)
            }
        }

        var fetched = (try? await svc.fetchLeaderboard(id: theme.leaderboards.globalTokens, scope: selectedScope)) ?? []
        #if DEBUG
        if isHidingLocalScore {
            fetched = fetched.filter { !$0.isLocalPlayer }
        }
        #endif
        entries = fetched
    }

    #if DEBUG
    func toggleHideLocalScore() {
        isHidingLocalScore.toggle()
        UserDefaults.standard.set(isHidingLocalScore, forKey: "debug.leaderboard.hideLocalScore")
        Task { await load() }
    }
    #endif
}
