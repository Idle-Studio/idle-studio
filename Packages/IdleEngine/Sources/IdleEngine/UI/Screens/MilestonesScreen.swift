import SwiftUI

// MARK: - MilestonesViewModel

@Observable
@MainActor
public final class MilestonesViewModel {
    public private(set) var state: GameState = .initial(firstLevelID: "")
    private var theme: (any ThemePackage)?

    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    public init() {}
    deinit { streamTask?.cancel() }

    func start() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            let loadedTheme = await GameEngine.shared.currentTheme
            self?.theme = loadedTheme
            for await newState in GameEngine.shared.stateStream() {
                self?.state = newState
            }
        }
    }

    var currentMilestones: [ThemeMilestone] {
        theme?.level(id: state.currentLevelID)?.milestones ?? []
    }

    func cardState(for milestone: ThemeMilestone) -> MilestoneCard.MilestoneState {
        if state.completedMilestoneIDs.contains(milestone.id) {
            return .completed
        }
        if state.inProgressMilestoneID == milestone.id,
           let endDate = state.milestoneConstructionEndDate {
            let total = Double(milestone.constructionSeconds)
            let remaining = max(0, endDate.timeIntervalSinceNow)
            let progress = total > 0 ? 1.0 - (remaining / total) : 1.0
            return .underConstruction(progress: progress)
        }
        if state.resources.canAfford(milestone.requirements) {
            return .available(milestone.requirements)
        }
        return .locked(milestone.requirements)
    }

    /// Remaining construction time as a human-readable string.
    func remainingTime(for milestone: ThemeMilestone) -> String? {
        guard state.inProgressMilestoneID == milestone.id,
              let endDate = state.milestoneConstructionEndDate else { return nil }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, seconds) }
        return String(format: "%ds", seconds)
    }

    func startMilestone(id: String) {
        Task { try? await GameEngine.shared.startMilestone(id: id) }
    }

    var levelDisplayName: String {
        theme?.level(id: state.currentLevelID)?.displayName ?? ""
    }
}

// MARK: - MilestonesScreen

public struct MilestonesScreen: View {
    @State private var viewModel = MilestonesViewModel()
    @Environment(\.theme) private var theme

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                if viewModel.currentMilestones.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Era header
                            HStack {
                                Text(viewModel.levelDisplayName)
                                    .font(Typography.caption)
                                    .foregroundStyle(theme.textSecondaryColor)
                                Spacer()
                                let completed = viewModel.currentMilestones.filter {
                                    viewModel.state.completedMilestoneIDs.contains($0.id)
                                }.count
                                Text("\(completed)/\(viewModel.currentMilestones.count)")
                                    .font(Typography.caption)
                                    .foregroundStyle(theme.textSecondaryColor)
                            }
                            .padding(.horizontal, 4)

                            ForEach(viewModel.currentMilestones) { milestone in
                                VStack(spacing: 0) {
                                    MilestoneCard(
                                        milestone: milestone,
                                        state: viewModel.cardState(for: milestone),
                                        onStart: { viewModel.startMilestone(id: milestone.id) }
                                    )

                                    // Show countdown timer below card when under construction
                                    if let timeLeft = viewModel.remainingTime(for: milestone) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "hourglass")
                                                .font(.caption)
                                            Text(timeLeft)
                                                .font(Typography.caption.monospacedDigit())
                                        }
                                        .foregroundStyle(theme.textSecondaryColor)
                                        .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(theme.copy.milestoneNoun + "s")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { viewModel.start() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 44))
                .foregroundStyle(theme.textSecondaryColor)
            Text("No \(theme.copy.milestoneNoun)s in this era")
                .font(Typography.body)
                .foregroundStyle(theme.textSecondaryColor)
        }
    }
}
