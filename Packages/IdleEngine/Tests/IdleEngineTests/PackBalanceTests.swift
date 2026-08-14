import Foundation
import Testing
@testable import IdleEngine

/// Locks the shape of the paid-currency ladder.
///
/// The shipped ladder zig-zagged — the $4.99 pack was worse value per dollar than the $0.99
/// pack, and the $19.99 was marginally worse than the $9.99 — so a player who did the
/// arithmetic was punished for spending more. Nothing detected it because the prices live in
/// App Store Connect and the reward fractions live in Swift, and no test ever compared them.
///
/// These tests read the **real** `.storekit` configuration, so they fail if someone reprices a
/// product without revisiting the rewards, or vice versa.
@Suite("Paid pack balance")
struct PackBalanceTests {

    // MARK: - Fixtures

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // IdleEngineTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // IdleEngine
        .deletingLastPathComponent()  // Packages
        .deletingLastPathComponent()  // repo root

    /// Product ID → configured price, parsed from the app's StoreKit configuration.
    private static func configuredPrices(app: String, file: String) throws -> [String: Decimal] {
        let url = repoRoot.appending(path: "apps/\(app)/Resources/\(file)")
        let data = try Data(contentsOf: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        var prices: [String: Decimal] = [:]
        for product in root["products"] as? [[String: Any]] ?? [] {
            guard let id = product["productID"] as? String,
                  let raw = product["displayPrice"] as? String,
                  let price = Decimal(string: raw) else { continue }
            prices[id] = price
        }
        return prices
    }

    private static func civTheme() throws -> JSONThemePackage {
        let url = repoRoot.appending(path: "games/idle-civilizations/idle-civilizations.json")
        return try JSONDecoder().decode(JSONThemePackage.self, from: try Data(contentsOf: url))
    }

    /// The repeatable currency packs, cheapest first. Excludes the starter pack, which is a
    /// one-time offer and is asserted separately.
    private static func ladder(_ iap: ThemeIAPProducts) -> [String] {
        [iap.coins1000, iap.coins5000, iap.coins15000, iap.coins30000, iap.coins75000]
            .compactMap { $0 }
    }

    // MARK: - The core invariant

    @Test("Value per dollar increases with every step up the coin ladder")
    func ladderIsMonotonic() throws {
        let theme = try Self.civTheme()
        let prices = try Self.configuredPrices(
            app: "IdleCivilizations", file: "IdleCivilizations.storekit"
        )
        let resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)

        var previousValuePerDollar: Decimal?
        var previousPrice: Decimal?

        for productID in Self.ladder(theme.iapProducts) {
            let price = try #require(prices[productID], "\(productID) has no configured price")
            let fraction = try #require(
                resolver.packFraction(for: productID),
                "\(productID) is a currency pack but grants nothing"
            )
            #expect(price > 0)
            let valuePerDollar = fraction / price

            if let previousValuePerDollar, let previousPrice {
                #expect(
                    price > previousPrice,
                    "Ladder is not ordered by price — check the product list"
                )
                #expect(
                    valuePerDollar > previousValuePerDollar,
                    """
                    \(productID) at \(price) gives \(valuePerDollar) per dollar, \
                    which is worse than the cheaper pack's \(previousValuePerDollar). \
                    Spending more must never buy less.
                    """
                )
            }
            previousValuePerDollar = valuePerDollar
            previousPrice = price
        }
    }

    @Test("Absolute reward increases with every step up the coin ladder")
    func ladderRewardsIncrease() throws {
        let theme = try Self.civTheme()
        let resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)
        let level = theme.levels.first
        let state = GameState.initial(firstLevelID: level?.id ?? "")

        var previous: Decimal = 0
        for productID in Self.ladder(theme.iapProducts) {
            let reward = resolver.reward(for: productID, state: state, level: level)[theme.primaryCurrency]
            #expect(reward > previous, "\(productID) grants no more than the cheaper pack")
            previous = reward
        }
    }

    @Test("The top pack is a meaningfully better rate than the entry pack")
    func topTierIsWorthIt() throws {
        let theme = try Self.civTheme()
        let prices = try Self.configuredPrices(
            app: "IdleCivilizations", file: "IdleCivilizations.storekit"
        )
        let resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)

        let ladder = Self.ladder(theme.iapProducts)
        let entry = try #require(ladder.first)
        let top = try #require(ladder.last)

        let entryRate = try #require(resolver.packFraction(for: entry)) / #require(prices[entry])
        let topRate = try #require(resolver.packFraction(for: top)) / #require(prices[top])

        // Below ~1.5× the largest pack has no pull; far above ~3× it devalues everything under it.
        #expect(topRate >= entryRate * Decimal(string: "1.5")!)
        #expect(topRate <= entryRate * 3)
    }

    // MARK: - Entitlement products must not be currency packs

    /// `lifetimePack` granted 0.100 — fewer coins than the $9.99 pack, for $29.99 — while
    /// delivering neither the ad-free nor the premium-pass access its description promised.
    /// It is an entitlement; it must not appear in the currency ladder at all.
    @Test("Entitlement products grant no currency",
          arguments: ["lifetimePack", "removeAds", "premiumPass", "premiumPassAnnual"])
    func entitlementsAreNotCurrencyPacks(slot: String) throws {
        let theme = try Self.civTheme()
        let iap = theme.iapProducts
        let resolver = RewardResolver(iap: iap, primaryCurrency: theme.primaryCurrency)

        let productID: String? = switch slot {
        case "lifetimePack":      iap.lifetimePack
        case "removeAds":         iap.removeAds
        case "premiumPass":       iap.premiumPass
        case "premiumPassAnnual": iap.premiumPassAnnual
        default:                  nil
        }
        guard let productID else { return }

        #expect(
            resolver.packFraction(for: productID) == nil,
            "\(slot) is an entitlement and must not grant currency"
        )
    }

    // MARK: - Starter pack

    @Test("The starter pack beats the ladder but stays small in absolute terms")
    func starterPackIsAnAcquisitionOffer() throws {
        let theme = try Self.civTheme()
        let prices = try Self.configuredPrices(
            app: "IdleCivilizations", file: "IdleCivilizations.storekit"
        )
        let resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)

        let starter = try #require(theme.iapProducts.starterPack)
        let starterRate = try #require(resolver.packFraction(for: starter)) / #require(prices[starter])

        let ladderRates = try Self.ladder(theme.iapProducts).map { id in
            try #require(resolver.packFraction(for: id)) / #require(prices[id])
        }
        #expect(starterRate > (ladderRates.max() ?? 0), "Starter pack should be the best rate")

        // …but it must stay a nudge, not a shortcut: well under a tenth of an era.
        let fraction = try #require(resolver.packFraction(for: starter))
        #expect(fraction < Decimal(string: "0.10")!)
    }

    // MARK: - Sanity

    @Test("No pack can ever grant a non-positive amount")
    func packsAlwaysGrantSomething() throws {
        let theme = try Self.civTheme()
        let resolver = RewardResolver(iap: theme.iapProducts, primaryCurrency: theme.primaryCurrency)

        // Every level, so a late-era requirement can't round a small pack down to nothing.
        for level in theme.levels {
            let state = GameState.initial(firstLevelID: level.id)
            for productID in Self.ladder(theme.iapProducts) + [theme.iapProducts.starterPack].compactMap({ $0 }) {
                let amount = resolver.reward(for: productID, state: state, level: level)[theme.primaryCurrency]
                #expect(amount > 0, "\(productID) grants nothing at \(level.id)")
                #expect(!amount.isNaN, "\(productID) overflowed at \(level.id)")
            }
        }
    }
}
