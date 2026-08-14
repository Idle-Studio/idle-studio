import Foundation
import StoreKit

// MARK: - Reward Resolution

/// Maps a StoreKit product ID to the in-game reward it grants.
///
/// Theme-agnostic: it matches by *semantic slot* in `ThemeIAPProducts`, never by a
/// hardcoded product identifier, so a new game only has to fill in the JSON.
public struct RewardResolver: Sendable {
    private let iap: ThemeIAPProducts
    private let primaryCurrency: String

    public init(iap: ThemeIAPProducts, primaryCurrency: String) {
        self.iap = iap
        self.primaryCurrency = primaryCurrency
    }

    /// Fraction of the current level's advance requirement granted by a currency pack.
    /// `nil` for products that are entitlements rather than currency.
    ///
    /// **Value per dollar rises monotonically with price.** The previous ladder zig-zagged:
    /// the $4.99 pack was worse value than the $0.99 pack (0.99× vs 1.00×) and the $19.99 was
    /// marginally worse than the $9.99, so a player doing the arithmetic was punished for
    /// spending more. Multipliers relative to the entry pack are now
    /// 1.00× / 1.25× / 1.50× / 1.80× / 2.20×.
    ///
    /// The starter pack sits above the whole ladder at 2.50×. That is deliberate — it is a
    /// one-time acquisition offer worth 2.5% of an era, so it cannot cannibalise the ladder
    /// the way a repeatable pack at that rate would.
    ///
    /// `lifetimePack` is deliberately absent. It is an entitlement (permanent ad-free +
    /// premium pass), not a currency pack. It used to grant 0.100 — fewer coins than the
    /// $9.99 pack for $29.99, making the most expensive non-subscription product the worst
    /// value in the shop while delivering neither of the two things its description promised.
    public func packFraction(for productID: String) -> Decimal? {
        switch productID {
        case iap.starterPack: return Decimal(string: "0.025")   // $0.99  · 2.50× (one-time)
        case iap.coins1000:   return Decimal(string: "0.010")   // $0.99  · 1.00×
        case iap.coins5000:   return Decimal(string: "0.063")   // $4.99  · 1.25×
        case iap.coins15000:  return Decimal(string: "0.151")   // $9.99  · 1.50×
        case iap.coins30000:  return Decimal(string: "0.363")   // $19.99 · 1.80×
        case iap.coins75000:  return Decimal(string: "0.889")   // $39.99 · 2.20×
        default:              return nil
        }
    }

    /// Currency granted by `productID` against the player's current progression.
    public func reward(for productID: String, state: GameState, level: ThemeLevel?) -> ResourceBundle {
        guard let fraction = packFraction(for: productID) else { return .zero }
        let requirement = level?.advanceRequirement[primaryCurrency] ?? 0
        let base = requirement > 0 ? requirement : 50_000
        let amount = Self.roundToSignificantFigures(base * fraction, figures: 3)
        guard amount > 0 else { return .zero }
        return ResourceBundle([primaryCurrency: amount])
    }

    /// Currency granted by a rewarded ad, expressed as a fraction of the level requirement.
    public func adReward(fraction: Decimal, level: ThemeLevel?) -> ResourceBundle {
        let requirement = level?.advanceRequirement[primaryCurrency] ?? 0
        let base = requirement > 0 ? requirement : 50_000
        let amount = Self.roundToSignificantFigures(base * fraction, figures: 3)
        guard amount > 0 else { return .zero }
        return ResourceBundle([primaryCurrency: amount])
    }

    static func roundToSignificantFigures(_ value: Decimal, figures: Int) -> Decimal {
        guard value > 0 else { return 0 }
        var rounded = Decimal()
        var input = value
        // Round in Decimal space. The previous implementation round-tripped through `Double`,
        // which is lossy above 2^53 — and the Space Age advance requirement alone is 8e18.
        let exponent = max(0, value.exponentBase10 - (figures - 1))
        NSDecimalRound(&rounded, &input, -exponent, .plain)
        return rounded
    }
}

private extension Decimal {
    /// Base-10 exponent of the most significant digit.
    var exponentBase10: Int {
        guard self > 0 else { return 0 }
        var digits = 0
        var value = self
        let ten = Decimal(10)
        while value >= ten {
            value /= ten
            digits += 1
            if digits > 200 { break }
        }
        return digits
    }
}

// MARK: - Grant Ledger

/// Durable record of which StoreKit transactions have already been granted.
///
/// Without this, a transaction redelivered by StoreKit — a restore, a Family Sharing
/// approval, an interrupted purchase recovered at next launch, a subscription renewal —
/// either pays out a second time or, if `finish()` ran first, never pays out at all.
actor GrantLedger {
    private let defaultsKey: String
    private var granted: Set<UInt64>
    /// Bounded so the record cannot grow without limit over a long-lived install.
    private static let maxEntries = 500

    init(gameID: String) {
        self.defaultsKey = "granted_transaction_ids_\(gameID)"
        let stored = UserDefaults.standard.array(forKey: defaultsKey) as? [NSNumber] ?? []
        self.granted = Set(stored.map { $0.uint64Value })
    }

    func hasGranted(_ id: UInt64) -> Bool {
        granted.contains(id)
    }

    /// Records `id` as granted and persists synchronously.
    /// Must be called *before* `Transaction.finish()`, so a crash in between replays the
    /// grant rather than losing it.
    func record(_ id: UInt64) {
        granted.insert(id)
        if granted.count > Self.maxEntries {
            granted = Set(granted.sorted().suffix(Self.maxEntries))
        }
        UserDefaults.standard.set(granted.map { NSNumber(value: $0) }, forKey: defaultsKey)
    }
}

// MARK: - Entitlement Store

/// Single source of truth for what the player has paid for.
///
/// Entitlement used to be decided per-call-site against one hardcoded product ID, so three
/// of the four products that promise ad-free play never suppressed a single ad, and annual
/// subscribers received none of the benefits the paywall sells them. Subscriptions are now
/// resolved by *group*, which is what `Transaction.currentEntitlements` actually yields.
@Observable
@MainActor
public final class EntitlementStore {
    public static let shared = EntitlementStore()

    /// True once `refresh()` has completed at least once.
    ///
    /// Until then we cannot know what the player owns, and the two possible mistakes are not
    /// symmetric: briefly hiding a free rewarded-ad offer costs nothing, while showing an ad
    /// to someone who paid to remove them is the exact complaint that generates refunds.
    public private(set) var hasResolved = false

    /// Whether ads must be suppressed. Fails closed — treats "not yet known" as ad-free.
    public var isAdFree: Bool { !hasResolved || ownsAdFreeProduct }

    public private(set) var hasPremiumPass = false
    public private(set) var ownedProductIDs: Set<String> = []
    private var ownsAdFreeProduct = false

    @ObservationIgnored private var iap: ThemeIAPProducts?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    private init() {}

    public func configure(iap: ThemeIAPProducts) {
        self.iap = iap
    }

    /// Product IDs that grant permanent ad removal.
    private var adFreeProductIDs: Set<String> {
        guard let iap else { return [] }
        return Set([iap.removeAds, iap.lifetimePack, iap.premiumPass, iap.premiumPassAnnual].compactMap { $0 })
    }

    /// Product IDs that grant premium-pass benefits (2× offline income and friends).
    private var premiumProductIDs: Set<String> {
        guard let iap else { return [] }
        return Set([iap.premiumPass, iap.premiumPassAnnual, iap.lifetimePack].compactMap { $0 })
    }

    /// Recomputes every entitlement from `Transaction.currentEntitlements`.
    public func refresh() async {
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            // Only `.verified` counts. Three call sites previously used `try? payloadValue`,
            // which silently accepts an unverified transaction.
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry <= .now { continue }
            owned.insert(transaction.productID)
        }
        ownedProductIDs = owned
        ownsAdFreeProduct = !owned.isDisjoint(with: adFreeProductIDs)
        hasPremiumPass = !owned.isDisjoint(with: premiumProductIDs)
        // Set last and unconditionally: a StoreKit failure must not pin the app into the
        // "unknown" state forever, which would permanently hide rewarded ads from free users.
        hasResolved = true
    }

    public func owns(_ productID: String) -> Bool {
        ownedProductIDs.contains(productID)
    }

    /// Convenience for callers that only have a theme to hand.
    public func hasPremiumPass(theme: any ThemePackage) async -> Bool {
        if iap == nil { configure(iap: theme.iapProducts) }
        if ownedProductIDs.isEmpty { await refresh() }
        return hasPremiumPass
    }
}

// MARK: - Purchase Coordinator

/// The single owner of `Transaction.updates` for the whole app.
///
/// There used to be six independent iterators. Three of them raced to call `finish()` and
/// none of them granted anything — one carried a comment describing a re-award whose body
/// was literally `_ = self`. Any purchase arriving outside the direct buy flow was
/// acknowledged to StoreKit and dropped. Ordering here is deliberate:
///
///   resolve reward → grant → **persist** → record in ledger → *then* `finish()`
///
/// The old order finished first, which meant a crash anywhere in the following two awaits
/// left the player charged with nothing to show and no recovery path, because a finished
/// consumable never appears in `Transaction.updates` or `currentEntitlements` again.
@MainActor
public final class PurchaseCoordinator {
    public static let shared = PurchaseCoordinator()

    public enum PurchaseOutcome: Sendable, Equatable {
        case success(granted: ResourceBundle)
        case cancelled
        /// Awaiting Ask-to-Buy / parental approval. The player must be told something happened.
        case pending
        case failed(String)
    }

    private var updatesTask: Task<Void, Never>?
    private var ledger: GrantLedger?
    private var resolver: RewardResolver?
    private var gameID = ""
    /// Invoked after a successful grant so the app can persist and celebrate.
    private var onGrant: (@MainActor (ResourceBundle) async -> Void)?

    private init() {}

    /// Wire up once, after the theme loads.
    public func configure(
        theme: any ThemePackage,
        onGrant: @escaping @MainActor (ResourceBundle) async -> Void
    ) {
        gameID = theme.gameID
        ledger = GrantLedger(gameID: theme.gameID)
        resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)
        self.onGrant = onGrant
        EntitlementStore.shared.configure(iap: theme.iapProducts)

        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                await self.process(transaction)
            }
        }
        Task { await EntitlementStore.shared.refresh() }
    }

    /// Buy `product`, granting and persisting before the transaction is finished.
    public func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    Analytics.record(.iapFailed(productID: product.id, reason: "unverified"))
                    return .failed(String(localized: "That purchase could not be verified."))
                }
                let granted = await process(transaction)
                return .success(granted: granted)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(String(localized: "Something unexpected happened. Please try again."))
            }
        } catch {
            Analytics.record(.iapFailed(productID: product.id, reason: "\(error)"))
            return .failed(error.localizedDescription)
        }
    }

    /// Grants a verified transaction exactly once, then finishes it.
    @discardableResult
    private func process(_ transaction: StoreKit.Transaction) async -> ResourceBundle {
        guard let ledger, let resolver else {
            await transaction.finish()
            return .zero
        }

        // Already paid out on a previous launch — finish and move on.
        if await ledger.hasGranted(transaction.id) {
            await transaction.finish()
            await EntitlementStore.shared.refresh()
            return .zero
        }

        var granted = ResourceBundle.zero
        let state = await GameEngine.shared.currentState
        let theme = await GameEngine.shared.currentTheme
        if let state {
            let level = theme?.level(id: state.currentLevelID)
            granted = resolver.reward(for: transaction.productID, state: state, level: level)
        }

        if granted != .zero {
            await GameEngine.shared.awardResources(granted)
            // Persist BEFORE finishing. Autosave is up to 30 seconds away; a force-quit in
            // that window used to lose a purchase the player had already been charged for.
            await onGrant?(granted)
        }

        await ledger.record(transaction.id)
        await transaction.finish()
        await EntitlementStore.shared.refresh()

        Analytics.record(.iapPurchased(productID: transaction.productID, priceUSD: 0))
        return granted
    }

    /// Restores purchases and refreshes entitlements. Reports what actually happened.
    public func restorePurchases() async -> Result<Int, any Error> {
        do {
            try await AppStore.sync()
            await EntitlementStore.shared.refresh()
            return .success(EntitlementStore.shared.ownedProductIDs.count)
        } catch {
            return .failure(error)
        }
    }
}
