import SwiftUI
import StoreKit

/// IAP shop. Product IDs come from `theme.iapProducts` — no hardcoded identifiers.
public struct ShopScreen: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = ShopViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(theme.goldAccentColor)
                                .padding(.top, 60)
                        } else if viewModel.hasNoProducts {
                            sandboxEmptyState
                        } else {
                            premiumPassSection
                            coinPacksSection
                            removeAdsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(theme.copy.premiumPassName)
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .task { await viewModel.loadProducts() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var premiumPassSection: some View {
        let hasPass = viewModel.premiumPass != nil || viewModel.premiumPassAnnual != nil
        if hasPass {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Premium Pass")
                if let annual = viewModel.premiumPassAnnual {
                    ProductRow(product: annual, isPrimary: true, isOwned: viewModel.isOwned(annual),
                               rewardLabel: viewModel.rewardLabels[annual.id], badge: "Best Value") {
                        viewModel.purchase(annual)
                    }
                }
                if let monthly = viewModel.premiumPass {
                    ProductRow(product: monthly, isPrimary: false, isOwned: viewModel.isOwned(monthly),
                               rewardLabel: viewModel.rewardLabels[monthly.id], badge: nil) {
                        viewModel.purchase(monthly)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coinPacksSection: some View {
        if !viewModel.coinPacks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Coin Packs")
                ForEach(viewModel.coinPacks, id: \.id) { product in
                    ProductRow(product: product, isPrimary: false, isOwned: viewModel.isOwned(product), rewardLabel: viewModel.rewardLabels[product.id], badge: nil) {
                        viewModel.purchase(product)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var removeAdsSection: some View {
        if let removeAds = viewModel.removeAds {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("One-time")
                ProductRow(product: removeAds, isPrimary: false, isOwned: viewModel.isOwned(removeAds), rewardLabel: nil, badge: nil) {
                    viewModel.purchase(removeAds)
                }
            }
        }
    }

    private var sandboxEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(theme.goldAccentColor)
                .padding(.top, 60)
            Text("Store Unavailable")
                .font(Typography.headline)
                .foregroundStyle(theme.textPrimaryColor)
            Text("In-app purchases are not configured for this environment. Products will appear here once the app is connected to App Store Connect.")
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.headline)
            .foregroundStyle(theme.textSecondaryColor)
    }
}

// MARK: - ProductRow

private struct ProductRow: View {
    let product: Product
    let isPrimary: Bool
    let isOwned: Bool
    let rewardLabel: String?
    let badge: String?
    let onBuy: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(product.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(theme.textPrimaryColor)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.goldAccentColor)
                            .foregroundStyle(.black)
                            .clipShape(.capsule)
                    }
                }
                Text(product.description)
                    .font(Typography.caption)
                    .foregroundStyle(theme.textSecondaryColor)
                    .lineLimit(2)
                if let rewardLabel {
                    Text(rewardLabel)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(theme.goldAccentColor)
                }
            }
            Spacer()
            if isOwned {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Active")
                        .font(Typography.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(Color.green)
                .clipShape(.capsule)
            } else {
                Button(action: onBuy) {
                    Text(product.displayPrice)
                        .font(Typography.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isPrimary ? theme.goldAccentColor : theme.surfaceElevatedColor)
                        .foregroundStyle(isPrimary ? .black : theme.textPrimaryColor)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(14)
        .background(theme.surfaceColor)
        .clipShape(.rect(cornerRadius: 14))
    }
}

// MARK: - ShopViewModel

@Observable
@MainActor
final class ShopViewModel {
    var isLoading = false
    var premiumPass: Product?         // monthly subscription
    var premiumPassAnnual: Product?   // annual subscription
    var coinPacks: [Product] = []
    var removeAds: Product?
    var rewardLabels: [String: String] = [:]
    private(set) var activeProductIDs: Set<String> = []

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    deinit { updatesTask?.cancel() }

    var hasNoProducts: Bool { premiumPass == nil && premiumPassAnnual == nil && coinPacks.isEmpty && removeAds == nil }

    func isOwned(_ product: Product) -> Bool {
        activeProductIDs.contains(product.id)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        guard let theme = await GameEngine.shared.currentTheme else { return }
        let iap = theme.iapProducts
        let allIDs = [iap.starterPack, iap.removeAds, iap.premiumPass,
                      iap.premiumPassAnnual, iap.coins1000, iap.coins5000,
                      iap.coins15000, iap.lifetimePack]
            .compactMap { $0 } + Array(iap.levelBundles.values)
        do {
            let products = try await Product.products(for: Set(allIDs))
            premiumPass       = products.first { $0.id == iap.premiumPass }
            premiumPassAnnual = products.first { $0.id == iap.premiumPassAnnual }
            removeAds   = products.first { $0.id == iap.removeAds }
            coinPacks   = products
                .filter { [iap.coins1000, iap.coins5000, iap.coins15000, iap.starterPack].contains($0.id) }
                .sorted  { $0.price < $1.price }
            for product in products where Self.packFractions[product.id] != nil {
                let amount = await scaledReward(for: product.id)
                rewardLabels[product.id] = "= \(amount.idleFormatted()) gold"
            }
        } catch { }

        await refreshEntitlements()
        startObservingTransactionUpdates()
    }

    private func refreshEntitlements() async {
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue else { continue }
            owned.insert(transaction.productID)
        }
        activeProductIDs = owned
    }

    private func startObservingTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? result.payloadValue else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    // Fraction of the current level's advanceRequirement["gold"] to award
    private static let packFractions: [String: Double] = [
        "com.idlestudio.idleciv.starter_pack":    0.015,
        "com.idlestudio.idleciv.coins.1000":      0.010,
        "com.idlestudio.idleciv.coins.5000":      0.050,
        "com.idlestudio.idleciv.coins.15000":     0.150,
        "com.idlestudio.idleciv.patron_lifetime": 0.100,
    ]

    func scaledReward(for productID: String) async -> Decimal {
        guard let fraction = Self.packFractions[productID] else { return 0 }
        guard let state = await GameEngine.shared.currentState,
              let theme = await GameEngine.shared.currentTheme,
              let level = theme.level(id: state.currentLevelID) else {
            return roundToSignificantFigures(Decimal(fraction) * 50_000, figures: 3)
        }
        let req = level.advanceRequirement["gold"]
        guard req > 0 else {
            // Fallback: use a sensible Stone Age baseline (50K req × fraction)
            return roundToSignificantFigures(Decimal(fraction) * 50_000, figures: 3)
        }
        return roundToSignificantFigures(req * Decimal(fraction), figures: 3)
    }

    private func roundToSignificantFigures(_ value: Decimal, figures: Int) -> Decimal {
        guard value > 0 else { return 0 }
        let d = NSDecimalNumber(decimal: value).doubleValue
        let magnitude = pow(10.0, floor(log10(d)) - Double(figures - 1))
        return Decimal(round(d / magnitude) * magnitude)
    }

    func purchase(_ product: Product) {
        Task {
            guard let result = try? await product.purchase(),
                  case .success(let verification) = result,
                  let transaction = try? verification.payloadValue else { return }
            await transaction.finish()
            let coins = await scaledReward(for: product.id)
            if coins > 0 {
                await GameEngine.shared.awardResources(ResourceBundle(["gold": coins]))
                NotificationCenter.default.post(
                    name: .iapRewardReceived,
                    object: nil,
                    userInfo: ["gold": coins]
                )
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let iapRewardReceived = Notification.Name("IdleEngine.iapRewardReceived")
}
