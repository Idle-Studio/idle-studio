import Foundation
import GoogleMobileAds
import AppTrackingTransparency
import StoreKit
import UIKit
import IdleEngine

// MARK: - GoogleMobileAdsService
//
// Concrete AdService implementation for the IdleCivilizations app target.
//
// Setup checklist (do once in Xcode):
//   1. File > Add Package Dependency → https://github.com/googleads/swift-package-manager-google-mobile-ads
//      Pin to version 11.x or later. Link GoogleMobileAds to the app target (NOT IdleEngine).
//   2. Add GADApplicationIdentifier to Info.plist (value from AdMob dashboard).
//   3. Replace the test ad unit IDs below with real IDs from AdMob once ready for production.
//   4. Add NSUserTrackingUsageDescription to Info.plist for ATT prompt text.

final class GoogleMobileAdsService: AdService, @unchecked Sendable {

    // MARK: - Test Ad Unit IDs (replace with real IDs from Remote Config in production)

    private static let rewardedUnitID     = "ca-app-pub-3940256099942544/1712485313"
    private static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: - State (all mutations happen on MainActor via Task { @MainActor in … })

    nonisolated(unsafe) private(set) var adsRemoved = false

    nonisolated(unsafe) private var loadedRewardedAds: [AdPlacement: GADRewardedAd] = [:]
    nonisolated(unsafe) private var loadedInterstitials: [AdPlacement: GADInterstitialAd] = [:]

    // Interstitial rate limiting (per MONETIZATION.md rules)
    private let sessionStart = Date()
    nonisolated(unsafe) private var sessionInterstitialCount = 0
    nonisolated(unsafe) private var lastInterstitialDate: Date?

    // Keep the active delegate alive for the duration of interstitial presentation
    nonisolated(unsafe) private var activeInterstitialDelegate: InterstitialDelegate?

    private let removeAdsProductID: String

    // MARK: - Init

    init(removeAdsProductID: String) {
        self.removeAdsProductID = removeAdsProductID
        Task { @MainActor in await self.configure() }
    }

    // MARK: - Setup

    @MainActor
    private func configure() async {
        // Check remove-ads entitlement before starting SDK
        await refreshAdsRemovedStatus()
        guard !adsRemoved else { return }

        // ATT consent prompt (must happen before SDK init on iOS 14+)
        if #available(iOS 14, *) {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        // Initialize AdMob SDK
        await GADMobileAds.sharedInstance().start()

        // Observe future transactions (e.g., remove-ads purchase completing mid-session)
        Task {
            for await result in Transaction.updates {
                guard case .verified(let tx) = result,
                      tx.productID == removeAdsProductID,
                      tx.revocationDate == nil else { continue }
                await MainActor.run { self.adsRemoved = true }
            }
        }
    }

    private func refreshAdsRemovedStatus() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.productID == removeAdsProductID,
                  tx.revocationDate == nil else { continue }
            adsRemoved = true
            return
        }
    }

    // MARK: - AdService: Rewarded

    func loadRewardedAd(placement: AdPlacement) async throws {
        let ad: GADRewardedAd = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                GADRewardedAd.load(withAdUnitID: Self.rewardedUnitID, request: GADRequest()) { ad, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let ad {
                        continuation.resume(returning: ad)
                    } else {
                        continuation.resume(throwing: AdServiceError.loadFailed)
                    }
                }
            }
        }
        loadedRewardedAds[placement] = ad
    }

    func showRewardedAd(placement: AdPlacement) async throws -> AdReward? {
        guard !adsRemoved else { return nil }
        guard let ad = loadedRewardedAds[placement] else { throw AdServiceError.adNotReady }
        loadedRewardedAds[placement] = nil

        var earnedReward: GADAdReward?
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                guard let vc = self.rootViewController else {
                    continuation.resume(throwing: AdServiceError.noViewController)
                    return
                }
                ad.present(fromRootViewController: vc) {
                    earnedReward = ad.adReward
                    continuation.resume()
                }
            }
        }

        // Preload next ad for the same placement in the background
        Task { try? await self.loadRewardedAd(placement: placement) }

        guard let reward = earnedReward else { return nil }
        return AdReward(
            placement: placement,
            rewardType: reward.type,
            rewardAmount: Int(truncating: reward.amount)
        )
    }

    // MARK: - AdService: Interstitial

    func loadInterstitial(placement: AdPlacement) async throws {
        let ad: GADInterstitialAd = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                GADInterstitialAd.load(withAdUnitID: Self.interstitialUnitID, request: GADRequest()) { ad, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let ad {
                        continuation.resume(returning: ad)
                    } else {
                        continuation.resume(throwing: AdServiceError.loadFailed)
                    }
                }
            }
        }
        loadedInterstitials[placement] = ad
    }

    func showInterstitial(placement: AdPlacement) async throws {
        guard !adsRemoved, canShowInterstitial() else { return }

        // Load on demand if not preloaded
        if loadedInterstitials[placement] == nil {
            try await loadInterstitial(placement: placement)
        }
        guard let ad = loadedInterstitials[placement] else { return }
        loadedInterstitials[placement] = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController else {
                    continuation.resume()
                    return
                }
                let delegate = InterstitialDelegate { continuation.resume() }
                self.activeInterstitialDelegate = delegate
                ad.fullScreenContentDelegate = delegate
                ad.present(fromRootViewController: vc)
            }
        }

        activeInterstitialDelegate = nil
        recordInterstitialShown()
        Task { try? await self.loadInterstitial(placement: placement) }
    }

    // MARK: - Rate Limiting

    private func canShowInterstitial() -> Bool {
        // Rule: not in the first 20 minutes of a session
        guard Date().timeIntervalSince(sessionStart) > 20 * 60 else { return false }
        // Rule: max 2 interstitials per session
        guard sessionInterstitialCount < 2 else { return false }
        // Rule: minimum 5 minutes between interstitials
        if let last = lastInterstitialDate {
            guard Date().timeIntervalSince(last) >= 5 * 60 else { return false }
        }
        return true
    }

    private func recordInterstitialShown() {
        sessionInterstitialCount += 1
        lastInterstitialDate = Date()
    }

    // MARK: - Root View Controller

    @MainActor
    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow?
            .rootViewController
    }
}

// MARK: - InterstitialDelegate

private final class InterstitialDelegate: NSObject, GADFullScreenContentDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismiss()
    }
}

// MARK: - Errors

enum AdServiceError: Error {
    case adNotReady
    case noViewController
    case loadFailed
}
