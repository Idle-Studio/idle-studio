import SwiftUI

/// Alliance / social screen. Studio Points, cross-game profile, alliance leaderboards.
public struct SocialScreen: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SocialViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        studioPointsCard
                        charactersSection
                        crossPromoSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Social")
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .task { await viewModel.load() }
        }
    }

    // MARK: - Sections

    private var studioPointsCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.goldAccentColor)

            Text(theme.copy.studioPointsTitle)
                .font(Typography.headline)
                .foregroundStyle(theme.textSecondaryColor)

            Text(Decimal(viewModel.studioPoints).idleFormatted())
                .font(Typography.hero)
                .foregroundStyle(theme.textPrimaryColor)

            Text(theme.copy.studioPointsTagline)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.surfaceColor)
        .clipShape(.rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var charactersSection: some View {
        if !viewModel.unlockedCharacters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(theme.copy.characterNounPlural)
                    .font(Typography.headline)
                    .foregroundStyle(theme.textPrimaryColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.unlockedCharacters) { character in
                            CharacterCard(character: character)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var crossPromoSection: some View {
        if let promo = viewModel.crossPromo {
            VStack(alignment: .leading, spacing: 8) {
                Text(theme.copy.crossPromoTitle)
                    .font(Typography.headline)
                    .foregroundStyle(theme.textPrimaryColor)

                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title)
                        .foregroundStyle(theme.goldAccentColor)
                    VStack(alignment: .leading) {
                        Text(promo.title)
                            .font(Typography.headline)
                            .foregroundStyle(theme.textPrimaryColor)
                        Text(theme.copy.crossPromoAvailableLabel)
                            .font(Typography.caption)
                            .foregroundStyle(theme.textSecondaryColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.textSecondaryColor)
                }
                .padding(14)
                .background(theme.surfaceColor)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }
}

// MARK: - CharacterCard

private struct CharacterCard: View {
    let character: ThemeCharacter
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(character.portraitAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(.circle)
                .overlay { Circle().strokeBorder(theme.goldAccentColor, lineWidth: 2) }
            Text(character.displayName)
                .font(Typography.caption)
                .foregroundStyle(theme.textPrimaryColor)
                .lineLimit(1)
        }
        .frame(width: 88)
        .accessibilityLabel(character.displayName)
    }
}

// MARK: - SocialViewModel

@Observable
@MainActor
final class SocialViewModel {
    var studioPoints: Int = 0
    var unlockedCharacters: [ThemeCharacter] = []

    struct CrossPromo: Sendable { let title: String; let appStoreURL: String }
    var crossPromo: CrossPromo?

    func load() async {
        // Seed from current state, then keep in sync with the engine tick stream.
        if let state = await GameEngine.shared.currentState {
            studioPoints = state.studioPoints
        }
        Task { [weak self] in
            for await state in GameEngine.shared.stateStream() {
                self?.studioPoints = state.studioPoints
            }
        }
    }
}
