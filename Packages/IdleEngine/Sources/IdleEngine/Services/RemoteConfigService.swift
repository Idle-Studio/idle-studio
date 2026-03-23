import Foundation

// MARK: - Config Keys

/// All Remote Config keys the engine reads. Fixed set — no magic strings elsewhere.
public enum RemoteConfigKey: String, Sendable {
    /// JSON string describing a cross-promo card to show in Settings. Nil = no promo active.
    case crossPromo          = "cross_promo"
    /// Override the offline income cap in seconds. Falls back to engine default (28800).
    case offlineCapOverride  = "offline_cap_seconds"
    /// Emergency kill-switch for an IAP product ID.
    case iapKillSwitch       = "iap_kill_switch"
    /// Feature flag: enable the new event system.
    case eventsEnabled       = "events_enabled"
    /// A/B test variant for the shop screen layout.
    case shopVariant         = "shop_variant"
}

// MARK: - Protocol

/// Firebase Remote Config (or any remote config provider).
/// The Firebase SDK is added in the app target — this protocol is the boundary.
public protocol RemoteConfigService: Sendable {
    /// Fetch latest values from the server and activate them.
    func fetchAndActivate() async throws
    func string(forKey key: RemoteConfigKey) async -> String?
    func bool(forKey key: RemoteConfigKey) async -> Bool
    func int(forKey key: RemoteConfigKey) async -> Int?
    func double(forKey key: RemoteConfigKey) async -> Double?
}

// MARK: - In-Memory stub (use until Firebase is wired)

/// Returns hard-coded defaults. Replace with `FirebaseRemoteConfigService` once Firebase is added.
public actor InMemoryRemoteConfigService: RemoteConfigService {
    private var values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public func fetchAndActivate() async throws {}

    public func string(forKey key: RemoteConfigKey) -> String? {
        values[key.rawValue]
    }

    public func bool(forKey key: RemoteConfigKey) -> Bool {
        values[key.rawValue].flatMap { Bool($0) } ?? false
    }

    public func int(forKey key: RemoteConfigKey) -> Int? {
        values[key.rawValue].flatMap { Int($0) }
    }

    public func double(forKey key: RemoteConfigKey) -> Double? {
        values[key.rawValue].flatMap { Double($0) }
    }
}
