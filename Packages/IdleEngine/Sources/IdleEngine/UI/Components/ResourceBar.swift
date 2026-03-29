import SwiftUI

/// Top card showing all active resources as horizontal stat chips.
/// Primary currency on the left; secondary resources appear to the right separated by dividers.
/// Reads all display values from `@Environment(\.theme)` — zero hardcoded strings.
public struct ResourceBar: View {
    public let resources: ResourceBundle
    public let productionRate: ResourceBundle
    /// Current level ID — used to tint secondary resource chips with the era's accent color.
    public let currentLevelID: String

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(resources: ResourceBundle, productionRate: ResourceBundle, currentLevelID: String = "") {
        self.resources = resources
        self.productionRate = productionRate
        self.currentLevelID = currentLevelID
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Primary chip
            primaryChip
                .frame(maxWidth: .infinity)

            // Secondary chips, each preceded by a divider
            ForEach(secondaryResources, id: \.key) { entry in
                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, 4)
                    .transition(.opacity)

                secondaryChip(entry: entry)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(surfaceBackground)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: secondaryResources.map(\.key))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(resourceAccessibilityLabel)
    }

    // MARK: - Chips

    private var primaryChip: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: theme.primaryCurrencyIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.goldAccentColor)
                    .accessibilityHidden(true)
                Text(theme.primaryCurrency.uppercased())
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondaryColor)
            }

            NumberRoller(value: resources[theme.primaryCurrency])
                .font(Typography.bigNumber)
                .foregroundStyle(theme.goldAccentColor)

            NumberRollerRate(value: productionRate[theme.primaryCurrency])
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor.opacity(0.8))
        }
    }

    private func secondaryChip(entry: (key: String, amount: Decimal, rate: Decimal)) -> some View {
        let eraColor = theme.levelPrimaryColor(for: currentLevelID)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(eraColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(entry.key.uppercased())
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondaryColor)
            }

            NumberRoller(value: entry.amount)
                .font(Typography.bigNumber)
                .foregroundStyle(eraColor)

            NumberRollerRate(value: entry.rate)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor.opacity(0.8))
        }
    }

    // MARK: - Private

    @ViewBuilder
    private var surfaceBackground: some View {
        if #available(iOS 26, macOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
        }
    }

    private var secondaryResources: [(key: String, amount: Decimal, rate: Decimal)] {
        let primaryKey = theme.primaryCurrency
        return productionRate.amounts
            .filter { $0.key != primaryKey && $0.value > 0 }
            .map { key, rate in (key: key, amount: resources[key], rate: rate) }
            .sorted { $0.key < $1.key }
    }

    private var resourceAccessibilityLabel: String {
        let amount = resources[theme.primaryCurrency].idleFormatted()
        let rate   = productionRate[theme.primaryCurrency].idleFormatted()
        var label = "\(theme.primaryCurrency): \(amount), producing \(rate) per second"
        for entry in secondaryResources {
            label += ". \(entry.key): \(entry.amount.idleFormatted()), producing \(entry.rate.idleFormatted()) per second"
        }
        return label
    }
}

// MARK: - Equatable

extension ResourceBar: Equatable {
    public nonisolated static func == (lhs: ResourceBar, rhs: ResourceBar) -> Bool {
        lhs.resources == rhs.resources &&
        lhs.productionRate == rhs.productionRate &&
        lhs.currentLevelID == rhs.currentLevelID
    }
}
