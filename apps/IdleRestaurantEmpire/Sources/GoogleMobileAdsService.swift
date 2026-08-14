import Foundation
import GoogleMobileAds
import AppTrackingTransparency
import UserMessagingPlatform
import UIKit
import IdleEngine

// MARK: - GoogleMobileAdsService
//
// Concrete AdService implementation for the IdleRestaurantEmpire app target.
//
// Setup checklist (do once in Xcode):
//   1. File > Add Package Dependency → https://github.com/googleads/swift-package-manager-google-mobile-ads
//      Pin to version 11.x. Link GoogleMobileAds AND UserMessagingPlatform to the app target
//      (NOT IdleEngine — the engine must stay SDK-free).
//   2. Add GADApplicationIdentifier to Info.plist (value from the AdMob dashboard).
//   3. Add NSUserTrackingUsageDescription to Info.plist for the ATT prompt text.
//
// The whole type is `@MainActor`. It used to be a plain `final class` marked
// `@unchecked Sendable` with six `nonisolated(unsafe)` properties and a header comment
// claiming "all mutations happen on MainActor" — which was false for seven methods.
// `preloadAds()` launches four concurrent loads in a task group, and each resumed on the
// cooperative pool and wrote the same dictionary, so three threads mutated one `Dictionary`
// with no synchronisation. The AdMob SDK requires main-thread calls anyway, which is why
// the old code was littered with `DispatchQueue.main.async`.
@MainActor
final class GoogleMobileAdsService: AdService {

    // MARK: - Ad Unit IDs

    // TODO: Replace with real AdMob unit IDs before release. `ca-app-pub-3940256099942544`
    // is Google's public demo publisher — it serves test ads and earns nothing. The
    // `usesTestAdUnits` guard below stops a Release build from silently shipping them.
    private static let rewardedOfflineUnitID     = "ca-app-pub-3940256099942544/1712485313"
    private static let rewardedBottleneckUnitID  = "ca-app-pub-3940256099942544/1712485313"
    private static let interstitialUnitID        = "ca-app-pub-3940256099942544/4411468910"
    private static let bannerUnitID              = "ca-app-pub-3940256099942544/2934735716"

    /// Google's documented sample publisher prefix.
    private static let testPublisherPrefix = "ca-app-pub-3940256099942544"

    /// True while the target still points at Google's demo inventory.
    private static var usesTestAdUnits: Bool {
        rewardedOfflineUnitID.hasPrefix(testPublisherPrefix)
            || interstitialUnitID.hasPrefix(testPublisherPrefix)
            || bannerUnitID.hasPrefix(testPublisherPrefix)
    }

    // MARK: - State

    /// Ad-free entitlement is owned by `EntitlementStore`, which resolves it across every
    /// product that promises it — Remove Ads, the lifetime pack, and both subscription
    /// tiers. This class used to compare against a single injected product ID, so three of
    /// the four paid products that advertise ad-free play never suppressed a single ad. In
    /// this app the injected ID was also a scaffold placeholder that matched nothing at all.
    var adsRemoved: Bool { EntitlementStore.shared.isAdFree }

    private var loadedRewardedAds: [AdPlacement: GADRewardedAd] = [:]
    private var loadedInterstitials: [AdPlacement: GADInterstitialAd] = [:]

    // Interstitial rate limiting (per MONETIZATION.md rules)
    private let sessionStart = Date()
    private var sessionInterstitialCount = 0
    private var lastInterstitialDate: Date?

    // Keep the active delegate alive for the duration of interstitial presentation
    private var activeInterstitialDelegate: InterstitialDelegate?

    private var bannerView: GADBannerView?
    private var hasStarted = false

    init() {}

    // MARK: - Startup

    /// Requests consent, then ATT, then initialises the SDK — in that order.
    ///
    /// Must be called once the scene is active. It used to run from the `@main` App struct's
    /// stored-property initialiser, before the scene reached `.active`, where
    /// `requestTrackingAuthorization` returns `.denied` immediately without presenting any
    /// UI. Whether the prompt appeared at all was a race, and losing it meant every user was
    /// silently treated as opted out while the app still declared `NSUserTrackingUsageDescription`.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        // Requesting test ads from a production build violates AdMob policy and can get the
        // account suspended. Fail closed: serve no ads at all until real units are wired.
        #if !DEBUG
        if Self.usesTestAdUnits {
            assertionFailure("Release build still configured with Google's test AdMob unit IDs.")
            return
        }
        #endif

        await EntitlementStore.shared.refresh()
        guard !adsRemoved else { return }

        // 1. Google-certified consent (EEA/UK). Required since January 2024 for serving ads
        //    to European users. The UMP SDK shipped inside the binary as a transitive
        //    dependency of GoogleMobileAds and was never called — there was no consent gate
        //    of any kind.
        await requestConsentIfNeeded()

        // 2. ATT — only meaningful once consent allows personalisation, and only presentable
        //    while the app is active.
        if #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        // 3. Child-safety tagging. The app is rated 4+ and idle games skew young, so ads are
        //    tagged for under-age-of-consent and capped to G-rated content. This lowers eCPM
        //    and is the correct trade for this audience.
        let configuration = GADMobileAds.sharedInstance().requestConfiguration
        configuration.maxAdContentRating = GADMaxAdContentRating.general
        configuration.tagForUnderAgeOfConsent = true

        #if DEBUG
        // Device-specific; the SDK logs it on first run and it resets on reinstall.
        configuration.testDeviceIdentifiers = ["0751d0a5fc31375045771dd35b65c633"]
        #endif

        await GADMobileAds.sharedInstance().start()
    }

    /// Presents the Google-certified consent form when the user's region requires it.
    private func requestConsentIfNeeded() async {
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                if error != nil { continuation.resume(); return }
                Task { @MainActor in
                    guard let root = self.rootViewController else { continuation.resume(); return }
                    UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// True when the user's region entitles them to change consent later. App Store and
    /// Google both expect a re-entry point when this is set — Settings surfaces it.
    var isPrivacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    /// Re-presents the consent form so a user can change their mind. Backed by a Settings row.
    func presentPrivacyOptions() async {
        guard let root = rootViewController else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentForm.presentPrivacyOptionsForm(from: root) { _ in continuation.resume() }
        }
    }

    // MARK: - AdService: Rewarded

    func loadRewardedAd(placement: AdPlacement) async throws {
        guard !adsRemoved else { return }
        let unitID = placement == .doubleOfflineIncome ? Self.rewardedOfflineUnitID : Self.rewardedBottleneckUnitID
        let ad: GADRewardedAd = try await withCheckedThrowingContinuation { continuation in
            GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let ad {
                    continuation.resume(returning: ad)
                } else {
                    continuation.resume(throwing: AdServiceError.loadFailed)
                }
            }
        }
        loadedRewardedAds[placement] = ad
    }

    func showRewardedAd(placement: AdPlacement) async throws -> AdReward? {
        guard !adsRemoved else { return nil }

        if loadedRewardedAds[placement] == nil {
            try await loadRewardedAd(placement: placement)
        }
        guard let ad = loadedRewardedAds[placement] else { throw AdServiceError.adNotReady }
        loadedRewardedAds[placement] = nil

        guard let vc = rootViewController else { throw AdServiceError.noViewController }

        var earnedReward: GADAdReward?
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ad.present(fromRootViewController: vc) {
                earnedReward = ad.adReward
                continuation.resume()
            }
        }

        // Preload the next ad for this placement.
        Task { try? await self.loadRewardedAd(placement: placement) }

        // `earnedReward` is nil when the ad was dismissed early — the caller must not grant.
        guard let reward = earnedReward else { return nil }
        return AdReward(
            placement: placement,
            rewardType: reward.type,
            rewardAmount: Int(truncating: reward.amount)
        )
    }

    // MARK: - AdService: Interstitial

    func loadInterstitial(placement: AdPlacement) async throws {
        guard !adsRemoved else { return }
        let ad: GADInterstitialAd = try await withCheckedThrowingContinuation { continuation in
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
        loadedInterstitials[placement] = ad
    }

    func showInterstitial(placement: AdPlacement) async throws {
        guard !adsRemoved, canShowInterstitial() else { return }

        if loadedInterstitials[placement] == nil {
            try await loadInterstitial(placement: placement)
        }
        guard let ad = loadedInterstitials[placement], let vc = rootViewController else { return }
        loadedInterstitials[placement] = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = InterstitialDelegate { continuation.resume() }
            self.activeInterstitialDelegate = delegate
            ad.fullScreenContentDelegate = delegate
            ad.present(fromRootViewController: vc)
        }

        activeInterstitialDelegate = nil
        recordInterstitialShown()
        Task { try? await self.loadInterstitial(placement: placement) }
    }

    // MARK: - AdService: Banner

    func showBanner(in viewController: UIViewController) {
        guard !adsRemoved else { return }
        if bannerView != nil { return }

        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = Self.bannerUnitID
        banner.rootViewController = viewController
        banner.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor),
            banner.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor)
        ])

        banner.load(GADRequest())
        bannerView = banner
    }

    func hideBanner() {
        bannerView?.removeFromSuperview()
        bannerView = nil
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

    /// Returns the topmost presented view controller so AdMob can present over
    /// whatever is currently on screen (sheets, full-screen covers, etc.).
    /// Using the bare root VC fails silently when a sheet is already presented on it.
    private var rootViewController: UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController
        guard let root else { return nil }
        return topmostViewController(from: root)
    }

    private func topmostViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController, !presented.isBeingDismissed {
            return topmostViewController(from: presented)
        }
        return vc
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

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        onDismiss()
    }
}

// MARK: - Errors

enum AdServiceError: Error {
    case adNotReady
    case noViewController
    case loadFailed
}
