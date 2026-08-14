import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    /// Request consent, request tracking authorization, then initialise the ad SDK.
    ///
    /// Call once the scene is `.active` — never from an initialiser. `ATTrackingManager`
    /// returns `.denied` without presenting anything when the app is not yet active, so
    /// starting from a stored-property initialiser silently opts every user out.
    @MainActor func start() async

    /// True when the user's region entitles them to revisit their ad-consent choice.
    /// Drives whether Settings shows a privacy-options row, which Google requires.
    @MainActor var isPrivacyOptionsRequired: Bool { get }

    /// Re-presents the consent form so the user can change their choice.
    @MainActor func presentPrivacyOptions() async

    /// Load (prefetch) a rewarded ad for the given placement.
    func loadRewardedAd(placement: AdPlacement) async throws
    /// Show a rewarded ad. Returns the reward if the user watched it fully.
    func showRewardedAd(placement: AdPlacement) async throws -> AdReward?
    /// Load (prefetch) an interstitial ad.
    func loadInterstitial(placement: AdPlacement) async throws
    /// Show an interstitial ad.
    func showInterstitial(placement: AdPlacement) async throws
    #if canImport(UIKit)
    /// Show a banner ad anchored to the bottom of the screen.
    @MainActor func showBanner(in viewController: UIViewController)
    #endif
    /// Hide and remove the banner ad.
    @MainActor func hideBanner()
    /// True if the player has ad-free entitlement — from Remove Ads, the lifetime pack,
    /// or an active subscription.
    ///
    /// `@MainActor` is load-bearing. This is read from SwiftUI view bodies on every render
    /// while the concrete AdMob implementation updated it from a StoreKit listener running
    /// on the cooperative pool — an unsynchronised cross-thread read of mutable state.
    /// Isolating the requirement forces implementations to be main-actor confined.
    @MainActor var adsRemoved: Bool { get }
}

// MARK: - Defaults

public extension AdService {
    /// Implementations without a consent SDK (previews, tests, the no-op stub) opt out.
    @MainActor func start() async {}
    @MainActor var isPrivacyOptionsRequired: Bool { false }
    @MainActor func presentPrivacyOptions() async {}
}

// MARK: - Environment Key

extension EnvironmentValues {
    /// Inject a concrete `AdService` from the app target. Defaults to `NoOpAdService`.
    @Entry public var adService: any AdService = NoOpAdService()
}

// MARK: - No-op stub

/// Stub used until the AdMob SDK is wired in the app target.
public struct NoOpAdService: AdService, Sendable {
    private let adsRemovedValue: Bool

    @MainActor public var adsRemoved: Bool { adsRemovedValue }

    public init(adsRemoved: Bool = false) {
        self.adsRemovedValue = adsRemoved
    }

    public func loadRewardedAd(placement: AdPlacement) async throws {}
    public func showRewardedAd(placement: AdPlacement) async throws -> AdReward? { nil }
    public func loadInterstitial(placement: AdPlacement) async throws {}
    public func showInterstitial(placement: AdPlacement) async throws {}
    #if canImport(UIKit)
    @MainActor public func showBanner(in viewController: UIViewController) {}
    #endif
    @MainActor public func hideBanner() {}
}
