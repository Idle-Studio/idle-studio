import SwiftUI

/// Displays a `Decimal` value using idle formatting, animating smoothly between changes.
/// Uses `contentTransition(.numericText())` for the iOS 17+ rolling-number effect.
/// Respects the Reduce Motion accessibility setting — updates snap instantly when enabled.
///
/// The animation is keyed on the *formatted string*, not the raw `Decimal`. The engine ticks
/// ~10×/sec but the displayed string changes far less often; animating on the `Decimal` started
/// a fresh 0.35s spring every 100ms (four overlapping springs per roller, permanently) and
/// frequently animated between two identical strings.
public struct NumberRoller: View {
    public let value: Decimal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Decimal) {
        self.value = value
    }

    public var body: some View {
        let text = value.idleFormatted()
        return Text(text)
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: false))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: text)
    }
}

// MARK: - Rate Variant

/// Variant that prepends "+" and appends "/s".
public struct NumberRollerRate: View {
    public let value: Decimal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Decimal) {
        self.value = value
    }

    public var body: some View {
        let text = value.idleRateFormatted()
        return Text(text)
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: false))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: text)
    }
}
