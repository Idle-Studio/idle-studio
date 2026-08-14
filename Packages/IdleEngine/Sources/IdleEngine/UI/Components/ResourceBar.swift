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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// Throttled mirror of the live values, used only for VoiceOver.
    ///
    /// The engine ticks ~10×/sec. Announcing every tick makes the bar re-announce continuously
    /// and effectively traps VoiceOver focus at the top of the main screen, so the spoken value
    /// is refreshed at most once per second. Never populated when VoiceOver is off.
    @State private var announcedAmounts: [String: Decimal] = [:]
    @State private var announcedRates: [String: Decimal] = [:]
    @State private var lastAnnouncedAt: Date = .distantPast

    public init(resources: ResourceBundle, productionRate: ResourceBundle, currentLevelID: String = "") {
        self.resources = resources
        self.productionRate = productionRate
        self.currentLevelID = currentLevelID
    }

    public var body: some View {
        // Hoisted — this was previously recomputed three times per body pass
        // (ForEach, the animation value, and the accessibility label).
        let secondary = secondaryResources

        return HStack(spacing: 0) {
            // Primary chip
            primaryChip
                .frame(maxWidth: .infinity)

            // Secondary chips, each preceded by a divider
            ForEach(secondary, id: \.key) { entry in
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: secondary.map(\.key))
        .accessibilityElement(children: .contain)
        .onAppear { refreshAnnouncedValues() }
        .onChange(of: resources) { _, _ in refreshAnnouncedValues() }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(theme.primaryCurrency)
        .accessibilityValue(spokenValue(for: theme.primaryCurrency))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.key)
        .accessibilityValue(spokenValue(for: entry.key))
    }

    // MARK: - Private

    @ViewBuilder
    private var surfaceBackground: some View {
        // Reduce Transparency substitutes a solid fill behind glass, but the foreground colors
        // were picked against a blurred backdrop — use the opaque theme surface instead.
        if #available(iOS 26, macOS 26, *), !reduceTransparency {
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

    // MARK: - Accessibility

    /// Built only when VoiceOver is actually running — otherwise this is pure formatting work
    /// on every tick for a string nothing will ever read.
    private func spokenValue(for key: String) -> String {
        guard voiceOverEnabled else { return "" }
        let amount = announcedAmounts[key] ?? resources[key]
        let rate   = announcedRates[key] ?? productionRate[key]
        return "\(amount.idleFormatted()), producing \(rate.idleFormatted()) per second"
    }

    private func refreshAnnouncedValues() {
        guard voiceOverEnabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastAnnouncedAt) >= 1.0 else { return }
        lastAnnouncedAt = now
        // Only write when something actually moved — an identical assignment still
        // invalidates the view.
        if announcedAmounts != resources.amounts { announcedAmounts = resources.amounts }
        if announcedRates != productionRate.amounts { announcedRates = productionRate.amounts }
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
