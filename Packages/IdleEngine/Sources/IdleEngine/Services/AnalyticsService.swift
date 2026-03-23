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
