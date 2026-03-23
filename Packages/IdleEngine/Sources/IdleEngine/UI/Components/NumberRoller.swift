import SwiftUI

/// Displays a `Decimal` value using idle formatting, animating smoothly between changes.
/// Uses `contentTransition(.numericText())` for the iOS 17+ rolling-number effect.
/// Respects the Reduce Motion accessibility setting — updates snap instantly when enabled.
public struct NumberRoller: View {
    public let value: Decimal

    @State private var displayed: Decimal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Decimal) {
        self.value = value
        self._displayed = State(initialValue: value)
    }

    public var body: some View {
        Text(displayed.idleFormatted())
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: false))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: displayed)
            .onChange(of: value) { _, newValue in
                displayed = newValue
            }
    }
}

// MARK: - Rate Variant

/// Variant that prepends "+" and appends "/s".
public struct NumberRollerRate: View {
    public let value: Decimal

    @State private var displayed: Decimal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Decimal) {
        self.value = value
        self._displayed = State(initialValue: value)
    }

    public var body: some View {
        Text(displayed.idleRateFormatted())
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: false))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: displayed)
            .onChange(of: value) { _, newValue in
                displayed = newValue
            }
    }
}
