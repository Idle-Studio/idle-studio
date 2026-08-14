import SwiftUI
import StoreKit

/// IAP shop. Product IDs come from `theme.iapProducts` — no hardcoded identifiers.
public struct ShopScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.adService) private var adService
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
                                .accessibilityLabel(Text("Loading store"))
                        } else if let error = viewModel.loadErrorMessage {
                            storeUnavailableState(error)
                        } else if viewModel.hasNoProducts {
                            sandboxEmptyState
                        } else {
                            premiumPassSection
                            coinPacksSection
                            oneTimeSection
                            if !adService.adsRemoved {
                                freeCoinsAdSection
                            }
                        }
                        // Rendered unconditionally. These used to live inside
                        // `premiumPassSection`, which is gated on products loading — so a
                        // network failure removed the Privacy Policy and Terms links from
                        // the entire app except the one-time onboarding paywall.
                        PolicyLinks(
                            privacyPolicyURL: theme.copy.privacyPolicyURL,
                            termsOfUseURL: theme.copy.termsOfUseURL
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle(theme.copy.premiumPassName)
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            #endif
            .task { await viewModel.loadProducts() }
            .overlay(alignment: .top) {
                if let message = viewModel.message {
                    HStack(spacing: 8) {
                        Image(systemName: message.isError ? "exclamationmark.circle.fill" : "clock.fill")
                            .foregroundStyle(message.isError ? .orange : theme.goldAccentColor)
                            .accessibilityHidden(true)
                        Text(message.text)
                            .font(Typography.subheadline)
                            .foregroundStyle(theme.textPrimaryColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.surfaceElevatedColor, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityLabel(message.text)
                }
            }
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
    private var oneTimeSection: some View {
        let items = [viewModel.removeAds, viewModel.lifetimePack].compactMap { $0 }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("One-time")
                ForEach(items, id: \.id) { product in
                    ProductRow(product: product, isPrimary: false,
                               isOwned: viewModel.isOwned(product),
                               rewardLabel: viewModel.rewardLabels[product.id], badge: nil) {
                        viewModel.purchase(product)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var freeCoinsAdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Free")
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch Ad for Coins")
                        .font(Typography.headline)
                        .foregroundStyle(theme.textPrimaryColor)
                    Text(viewModel.freeCoinsAdSubtitle)
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                }
                Spacer()
                Button {
                    Task { await viewModel.watchAdForCoins(adService: adService) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                        Text("Watch")
                    }
                    .font(Typography.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(viewModel.freeCoinsAdAvailable ? theme.surfaceElevatedColor : theme.surfaceColor)
                    .foregroundStyle(viewModel.freeCoinsAdAvailable ? theme.textPrimaryColor : theme.textSecondaryColor)
                    .clipShape(.capsule)
                }
                .disabled(!viewModel.freeCoinsAdAvailable)
            }
            .padding(14)
            .background(theme.surfaceColor)
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    /// Shown when `Product.products(for:)` threw — the common transient case (offline,
    /// App Store outage). Distinct from "the store returned nothing", and retryable
    /// without relaunching the app.
    private func storeUnavailableState(_ reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(theme.textSecondaryColor)
                .accessibilityHidden(true)
            Text("The store isn't available right now")
                .font(Typography.headline)
                .foregroundStyle(theme.textPrimaryColor)
                .multilineTextAlignment(.center)
            Text(reason)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.loadProducts() }
            } label: {
                Text("Try Again")
                    .font(Typography.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
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
    enum LoadState: Equatable {
        case idle
        case loading
        /// Products fetched successfully. `isEmpty` distinguishes "none configured" from a failure.
        case loaded
        /// Fetch threw — network, App Store outage, products not yet approved. Retryable.
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    var premiumPass: Product?         // monthly subscription
    var premiumPassAnnual: Product?   // annual subscription
    var coinPacks: [Product] = []
    var removeAds: Product?
    var lifetimePack: Product?
    var rewardLabels: [String: String] = [:]
    private(set) var freeCoinsAdAvailable = true
    private(set) var freeCoinsAdSubtitle = ""
    private(set) var message: IdleGameViewModel.TransientMessage?

    private var gameID = ""
    private var resolver: RewardResolver?
    private var primaryCurrency = "gold"
    private var freeCoinsAdCooldownKey: String { "freeCoinsAdLastDate_\(gameID)" }
    private static let freeCoinsAdCooldown: TimeInterval = 3600 // 1 hour
    /// Rewarded-ad payout, as a fraction of the current level's advance requirement.
    private static let freeCoinsAdFraction = Decimal(string: "0.005")!

    @ObservationIgnored private var messageTask: Task<Void, Never>?

    deinit { messageTask?.cancel() }

    var isLoading: Bool { loadState == .loading }

    /// True only when the store genuinely returned nothing — not when the fetch failed.
    var hasNoProducts: Bool {
        loadState == .loaded && premiumPass == nil && premiumPassAnnual == nil
            && coinPacks.isEmpty && removeAds == nil && lifetimePack == nil
    }

    var loadErrorMessage: String? {
        if case .failed(let reason) = loadState { return reason }
        return nil
    }

    /// Entitlements come from the shared store so the badge here can never disagree with
    /// whether ads are actually suppressed.
    func isOwned(_ product: Product) -> Bool {
        EntitlementStore.shared.owns(product.id)
    }

    func loadProducts() async {
        guard let theme = await GameEngine.shared.currentTheme else { return }
        loadState = .loading

        let iap = theme.iapProducts
        gameID = theme.gameID
        primaryCurrency = theme.primaryCurrency
        resolver = RewardResolver(iap: iap, primaryCurrency: theme.primaryCurrency)

        let allIDs = [iap.starterPack, iap.removeAds, iap.premiumPass,
                      iap.premiumPassAnnual, iap.coins1000, iap.coins5000,
                      iap.coins15000, iap.coins30000, iap.coins75000, iap.lifetimePack]
            .compactMap { $0 }

        do {
            let products = try await Product.products(for: Set(allIDs))
            premiumPass       = products.first { $0.id == iap.premiumPass }
            premiumPassAnnual = products.first { $0.id == iap.premiumPassAnnual }
            removeAds         = products.first { $0.id == iap.removeAds }
            lifetimePack      = products.first { $0.id == iap.lifetimePack }
            coinPacks         = products
                .filter { [iap.coins1000, iap.coins5000, iap.coins15000,
                           iap.coins30000, iap.coins75000, iap.starterPack].contains($0.id) }
                .sorted { $0.price < $1.price }

            await refreshRewardLabels(products: products)
            loadState = .loaded
        } catch {
            // This used to be an empty `catch {}`, so a player in airplane mode was shown a
            // developer-facing "In-app purchases are not configured for this environment"
            // dead end with no retry.
            loadState = .failed(error.localizedDescription)
        }

        await EntitlementStore.shared.refresh()
        refreshFreeCoinsAdState()
    }

    private func refreshRewardLabels(products: [Product]) async {
        guard let resolver,
              let state = await GameEngine.shared.currentState,
              let theme = await GameEngine.shared.currentTheme else { return }
        let level = theme.level(id: state.currentLevelID)
        var labels: [String: String] = [:]
        for product in products {
            let reward = resolver.reward(for: product.id, state: state, level: level)
            let amount = reward[primaryCurrency]
            guard amount > 0 else { continue }
            labels[product.id] = "= \(amount.idleFormatted())"
        }
        rewardLabels = labels
    }

    // MARK: - Purchasing

    func purchase(_ product: Product) {
        Task {
            let outcome = await PurchaseCoordinator.shared.purchase(product)
            switch outcome {
            case .success(let granted):
                let amount = granted[primaryCurrency]
                if amount > 0 {
                    NotificationCenter.default.post(
                        name: .iapRewardReceived, object: nil,
                        userInfo: [primaryCurrency: amount]
                    )
                }
                await refreshRewardLabels(products: [product])
            case .cancelled:
                break
            case .pending:
                // Ask to Buy / parental approval. Previously indistinguishable from a dead
                // button, so children tapped Buy repeatedly with no acknowledgement at all.
                present(String(localized: "Waiting for approval. You'll get your purchase once it's approved."), isError: false)
            case .failed(let reason):
                present(reason, isError: true)
            }
        }
    }

    // MARK: - Rewarded Ads

    func watchAdForCoins(adService: any AdService) async {
        guard freeCoinsAdAvailable else { return }
        let reward = try? await adService.showRewardedAd(placement: .freeCoins)
        guard reward != nil else {
            // Ad no-fill is routine — offline, no regional inventory, frequency cap. Silence
            // here read as a broken button, and players tapped it repeatedly.
            present(String(localized: "No ad is available right now. Please try again shortly."), isError: true)
            return
        }
        guard let resolver,
              let state = await GameEngine.shared.currentState,
              let theme = await GameEngine.shared.currentTheme else { return }

        let bundle = resolver.adReward(
            fraction: Self.freeCoinsAdFraction,
            level: theme.level(id: state.currentLevelID)
        )
        guard bundle != .zero else { return }

        await GameEngine.shared.awardResources(bundle)
        NotificationCenter.default.post(
            name: .iapRewardReceived, object: nil,
            userInfo: [primaryCurrency: bundle[primaryCurrency]]
        )
        NotificationCenter.default.post(name: .engineStateShouldPersist, object: nil)
        UserDefaults.standard.set(Date(), forKey: freeCoinsAdCooldownKey)
        refreshFreeCoinsAdState()
    }

    private func refreshFreeCoinsAdState() {
        let last = UserDefaults.standard.object(forKey: freeCoinsAdCooldownKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.freeCoinsAdCooldown {
            freeCoinsAdAvailable = false
            let remaining = Int((Self.freeCoinsAdCooldown - Date().timeIntervalSince(last)) / 60)
            freeCoinsAdSubtitle = String(localized: "Available in \(remaining)m")
        } else {
            freeCoinsAdAvailable = true
            freeCoinsAdSubtitle = String(localized: "Watch a short ad for a bonus")
        }
    }

    // MARK: - Messages

    private func present(_ text: String, isError: Bool) {
        messageTask?.cancel()
        withAnimation { message = IdleGameViewModel.TransientMessage(text: text, isError: isError) }
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { self?.message = nil }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let iapRewardReceived = Notification.Name("IdleEngine.iapRewardReceived")
    /// Posted after any grant the player earned or paid for, so the root view persists
    /// immediately instead of waiting up to 30 seconds for the next autosave.
    static let engineStateShouldPersist = Notification.Name("IdleEngine.engineStateShouldPersist")
}
