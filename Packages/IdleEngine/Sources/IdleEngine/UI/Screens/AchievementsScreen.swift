import SwiftUI

// MARK: - AchievementsScreen

/// Activity-app-style achievement browser with category filter chips and badge grid.
/// Replaces the Social tab.
public struct AchievementsScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = AchievementsViewModel()
    @State private var selectedCategory: AchievementCategory? = nil   // nil = All

    public init() {}

    private var filteredAchievements: [ThemeAchievement] {
        guard let cat = selectedCategory else { return viewModel.achievements }
        return viewModel.achievements.filter { $0.category == cat }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 16)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Summary header
                        summaryHeader
                            .padding()

                        Section {
                            // Badge grid
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(filteredAchievements) { achievement in
                                    BadgeView(
                                        achievement: achievement,
                                        isEarned: viewModel.earnedIDs.contains(achievement.id)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedCategory)
                        } header: {
                            categoryFilterRow
                        }
                    }
                }
            }
            .navigationTitle(theme.copy.achievementsTabLabel)
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .task { await viewModel.load() }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            // Earned progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.earnedCount) / \(viewModel.totalCount) Earned")
                        .font(Typography.title)
                        .foregroundStyle(theme.textPrimaryColor)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.surfaceColor)
                                .frame(height: 8)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: viewModel.totalCount > 0
                                        ? geo.size.width * CGFloat(viewModel.earnedCount) / CGFloat(viewModel.totalCount)
                                        : 0,
                                    height: 8
                                )
                                .animation(reduceMotion ? nil : .spring(response: 0.6), value: viewModel.earnedCount)
                        }
                    }
                    .frame(height: 8)
                    .accessibilityLabel("Achievements progress")
                    .accessibilityValue("\(viewModel.earnedCount) of \(viewModel.totalCount) earned")
                }

                Spacer()

                // Studio Points pill
                VStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(theme.goldAccentColor)
                        .accessibilityHidden(true)
                    Text("\(viewModel.studioPoints)")
                        .font(Typography.bigNumber)
                        .foregroundStyle(theme.goldAccentColor)
                    Text(theme.copy.studioPointsTitle)
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.surfaceColor)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.studioPoints) \(theme.copy.studioPointsTitle)")
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", category: nil)
                ForEach(AchievementCategory.allCases, id: \.self) { cat in
                    filterChip(label: cat.displayName, category: cat)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(theme.backgroundColor)
    }

    private func filterChip(label: String, category: AchievementCategory?) -> some View {
        let selected = selectedCategory == category
        return Button {
            if reduceMotion {
                selectedCategory = category
            } else {
                withAnimation { selectedCategory = category }
            }
        } label: {
            HStack(spacing: 5) {
                if let cat = category {
                    Image(systemName: cat.iconSymbol)
                        .font(.caption2.weight(.semibold))
                }
                Text(label)
                    .font(Typography.caption.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(selected
                          ? LinearGradient(colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [theme.surfaceColor, theme.surfaceColor], startPoint: .leading, endPoint: .trailing))
            )
            .foregroundStyle(selected ? .white : theme.textSecondaryColor)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - AchievementsViewModel

@Observable
@MainActor
final class AchievementsViewModel {
    var achievements: [ThemeAchievement] = []
    var earnedIDs: Set<String> = []
    var studioPoints: Int = 0

    var earnedCount: Int { earnedIDs.count }
    var totalCount: Int { achievements.count }

    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    deinit { streamTask?.cancel() }

    func load() async {
        let theme = await GameEngine.shared.currentTheme
        achievements = theme?.achievements ?? []
        // Start observing state for live updates
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            for await state in GameEngine.shared.stateStream() {
                self?.earnedIDs = state.earnedAchievementIDs
                self?.studioPoints = state.studioPoints
            }
        }
    }
}
