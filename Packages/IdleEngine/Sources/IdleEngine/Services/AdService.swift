import Foundation

// MARK: - Types

public enum AdPlacement: String, Sendable {
    /// Rewarded ad shown when player wants to double offline income.
    case doubleOfflineIncome = "double_offline"
    /// Rewarded ad shown to skip milestone construction timer.
    case skipMilestone       = "skip_milestone"
    /// Interstitial shown at natural breakpoints (level advance, app resume).
    case levelAdvance        = "level_advance"
    /// Rewarded ad shown in the shop for free coins.
    case freeCoins           = "free_coins"
}

public struct AdReward: Sendable {
    public let placement: AdPlacement
    public let rewardType: String
    public let rewardAmount: Int

    public init(placement: AdPlacement, rewardType: String, rewardAmount: Int) {
        self.placement = placement
        self.rewardType = rewardType
        self.rewardAmount = rewardAmount
    }
}

// MARK: - Protocol

/// Ad mediation via AdMob (or any provider).
/// The AdMob SDK is added as an external dependency in the app target — not in this package.
/// This protocol is the boundary: the app target creates a concrete implementation and injects it.
public protocol AdService: Sendable {
    /// Load (prefetch) a rewarded ad for the given placement.
    func loadRewardedAd(placement: AdPlacement) async throws
    /// Show a rewarded ad. Returns the reward if the user watched it fully.
    func showRewardedAd(placement: AdPlacement) async throws -> AdReward?
    /// Load (prefetch) an interstitial ad.
    func loadInterstitial(placement: AdPlacement) async throws
    /// Show an interstitial ad.
    func showInterstitial(placement: AdPlacement) async throws
    /// True if the player has purchased ad removal.
    var adsRemoved: Bool { get }
}

// MARK: - Environment Key

extension EnvironmentValues {
    /// Inject a concrete `AdService` from the app target. Defaults to `NoOpAdService`.
    @Entry public var adService: any AdService = NoOpAdService()
}

// MARK: - No-op stub

/// Stub used until the AdMob SDK is wired in the app target.
public struct NoOpAdService: AdService, Sendable {
    public let adsRemoved: Bool

    public init(adsRemoved: Bool = false) {
        self.adsRemoved = adsRemoved
    }

    public func loadRewardedAd(placement: AdPlacement) async throws {}
    public func showRewardedAd(placement: AdPlacement) async throws -> AdReward? { nil }
    public func loadInterstitial(placement: AdPlacement) async throws {}
    public func showInterstitial(placement: AdPlacement) async throws {}
}
