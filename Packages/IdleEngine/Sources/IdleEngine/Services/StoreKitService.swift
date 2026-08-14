import Foundation
import StoreKit

// MARK: - Protocol

/// Handles all StoreKit 2 operations. Product IDs are always read from the active theme.
public protocol StoreKitService: Sendable {
    /// Fetch products by their App Store Connect product IDs.
    func fetchProducts(ids: [String]) async throws -> [Product]
    /// Purchase a product. Returns the verified transaction, or nil if cancelled/pending.
    func purchase(_ product: Product) async throws -> StoreKit.Transaction?
    /// Restore completed purchases (non-consumables and subscriptions).
    func restorePurchases() async throws
    /// Whether a specific product is currently entitled.
    ///
    /// - Important: this answers "does the player own *this exact product*", which is almost
    ///   never the right question. Ad-free status comes from four different products and
    ///   subscriptions resolve by group, so per-product checks are how three of the four paid
    ///   ad-free offers ended up suppressing no ads at all. Use `EntitlementStore` for any
    ///   entitlement decision; this remains for diagnostics only.
    func isEntitled(productID: String) async -> Bool
    /// Async stream of transactions that complete (including from other devices via Family Sharing).
    var transactionUpdates: AsyncStream<StoreKit.Transaction> { get }
}

// MARK: - Live StoreKit 2 Implementation

public final class LiveStoreKitService: StoreKitService, @unchecked Sendable {
    public nonisolated let transactionUpdates: AsyncStream<StoreKit.Transaction>
    private let updateContinuation: AsyncStream<StoreKit.Transaction>.Continuation
    private var updateTask: Task<Void, Never>?

    public init() {
        (transactionUpdates, updateContinuation) = AsyncStream.makeStream(
            of: StoreKit.Transaction.self,
            bufferingPolicy: .unbounded
        )
        startListeningForTransactionUpdates()
    }

    deinit {
        updateTask?.cancel()
        updateContinuation.finish()
    }

    public func fetchProducts(ids: [String]) async throws -> [Product] {
        try await Product.products(for: ids)
    }

    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    public func restorePurchases() async throws {
        try await AppStore.sync()
    }

    public func isEntitled(productID: String) async -> Bool {
        await isEntitlementActive(for: productID)
    }

    private func isEntitlementActive(for productID: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.productID == productID,
                  tx.revocationDate == nil else { continue }
            if let expiry = tx.expirationDate {
                return expiry > .now
            }
            return true
        }
        return false
    }

    private func startListeningForTransactionUpdates() {
        updateTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                self?.updateContinuation.yield(tx)
            }
        }
    }
}
