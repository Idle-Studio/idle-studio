import SwiftUI

/// Displays a single milestone with its artwork, name, requirements, and construction status.
/// "Milestone" is the engine term — the displayed noun comes from `theme.copy.milestoneNoun`.
public struct MilestoneCard: View {
    public enum MilestoneState: Sendable, Equatable {
        case locked(ResourceBundle)             // requirements not met
        case available(ResourceBundle)          // requirements met, not started
        case underConstruction(progress: Double)// building (0.0-1.0)
        case completed
    }

    public let milestone: ThemeMilestone
    public let state: MilestoneState
    public let onStart: () -> Void
    public let onSkipWithAd: (() -> Void)?
    public let onSkipWithCoins: (() -> Void)?

    @Environment(\.theme) private var theme

    public init(
        milestone: ThemeMilestone,
        state: MilestoneState,
        onStart: @escaping () -> Void,
        onSkipWithAd: (() -> Void)? = nil,
        onSkipWithCoins: (() -> Void)? = nil
    ) {
        self.milestone = milestone
        self.state = state
        self.onStart = onStart
        self.onSkipWithAd = onSkipWithAd
        self.onSkipWithCoins = onSkipWithCoins
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(theme.textPrimaryColor)
                    Text(milestone.description)
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                stateIndicator
            }

            if case .underConstruction(let p) = state {
                ProgressBar(progress: p, tint: theme.goldAccentColor)
            }

            if case .available = state {
                Button(action: onStart) {
                    Text(theme.copy.startMilestoneButton)
                        .font(Typography.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.goldAccentColor)
                        .foregroundStyle(.black)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Subviews

    private var artwork: some View {
        Image(milestone.artworkAsset)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                if state == .completed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.goldAccentColor)
                        .font(.title2)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(theme.goldAccentColor)
        case .underConstruction:
            Image(systemName: "hourglass")
                .foregroundStyle(theme.textSecondaryColor)
        case .locked(let req):
            requirementLabel(req)
        case .available:
            EmptyView()
        }
    }

    private func requirementLabel(_ req: ResourceBundle) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text(req["gold"].idleFormatted())
        }
        .font(Typography.caption)
        .foregroundStyle(theme.textSecondaryColor)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26, macOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            theme.surfaceColor
        }
    }
}
