import Foundation

// MARK: - Event Types

/// All analytics events fired by the engine. Theme-agnostic — no game vocabulary.
/// Firebase / Amplitude / etc. receive these fixed event names.
public enum AnalyticsEvent: Sendable {
    // Progression
    case levelAdvanced(fromOrder: Int, toOrder: Int)
    case prestigePerformed(tokenCount: Int, runNumber: Int)
    case milestoneCompleted(milestoneID: String)

    // Economy
    case unitPurchased(unitID: String, quantity: Int, totalOwned: Int)
    case offlineIncomeCollected(goldAmount: Decimal, duration: TimeInterval, wasCapped: Bool)
    case resourceCapReached

    // Monetization
    case iapPurchased(productID: String, priceUSD: Decimal)
    case iapFailed(productID: String, reason: String)
    case adWatched(placement: String, rewarded: Bool)
    case adFailed(placement: String)

    // Engagement
    case sessionStart(prestigeTokens: Decimal)
    case sessionEnd(durationSeconds: TimeInterval)
    case notificationPermissionRequested(granted: Bool)
    case pushNotificationTapped(type: String)
    case eventParticipated(eventID: String)
    case characterUnlocked(characterID: String)

    // Studio cross-game
    case studioPointsEarned(amount: Int, source: String)
    case crossPromoTapped(targetGameID: String)

    // Reliability
    //
    // These exist because a defect that destroyed every player's save produced no crash,
    // no log, and no event — the only signal that ever reached the team was one customer
    // email. Anything that can silently lose progress or money must emit here.
    case persistenceUnavailable(reason: String)
    case cloudSyncUnavailable(reason: String)
    case saveFailed(reason: String)
    case saveCorrupted(reason: String)
    /// Canary: the player has completed onboarding, yet no save could be loaded.
    /// This is a data-loss event by definition and should alert.
    case progressLossDetected(reason: String)
    case purchaseGrantFailed(productID: String, reason: String)
}

// MARK: - Protocol

/// Records fixed-schema analytics events. Never receives raw strings as event names.
public protocol AnalyticsService: Sendable {
    func record(_ event: AnalyticsEvent)
    func setUserProperty(key: String, value: String)
}

// MARK: - No-op stub (use until Firebase is wired)

/// Logs events to the console in debug builds. No-op in release.
public struct ConsoleAnalyticsService: AnalyticsService {
    public init() {}

    public func record(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event)")
        #endif
    }

    public func setUserProperty(key: String, value: String) {
        #if DEBUG
        print("[Analytics] userProperty \(key)=\(value)")
        #endif
    }
}

// MARK: - Shared Sink

/// Process-wide analytics sink.
///
/// Engine internals (persistence, the purchase grant path) need to report reliability
/// events from contexts that have no view hierarchy to inject a service through. The app
/// target sets `shared` once at launch — wire it to Crashlytics/Sentry/Firebase there.
public enum Analytics {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _shared: any AnalyticsService = ConsoleAnalyticsService()

    public static var shared: any AnalyticsService {
        get { lock.withLock { _shared } }
        set { lock.withLock { _shared = newValue } }
    }

    public static func record(_ event: AnalyticsEvent) {
        shared.record(event)
    }
}
