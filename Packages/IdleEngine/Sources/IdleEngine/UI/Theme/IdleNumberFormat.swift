import Foundation

// MARK: - Idle Number Formatting

extension Decimal {
    /// Formats a `Decimal` for idle game display with short suffixes.
    ///
    /// - `< 1,000`          → `"999"`
    /// - `< 1,000,000`      → `"59.2K"`
    /// - `< 1,000,000,000`  → `"4.5M"`
    /// - `< 1e12`           → `"3.1B"`
    /// - `< 1e15`           → `"7.2T"`
    /// - `< 1e18`           → `"1.4Qa"`
    /// - `< 1e21`           → `"2.0Qi"`
    /// - `>= 1e21`          → `"1.0Sx"`
    ///
    /// Always returns a non-negative string. Negative values display as `"0"`.
    public func idleFormatted() -> String {
        let d = NSDecimalNumber(decimal: max(0, self)).doubleValue
        guard d.isFinite else { return "∞" }

        let tiers: [(threshold: Double, suffix: String)] = [
            (1e21, "Sx"), (1e18, "Qi"), (1e15, "Qa"),
            (1e12, "T"),  (1e9,  "B"),  (1e6,  "M"),  (1e3, "K")
        ]

        for (threshold, suffix) in tiers {
            if d >= threshold {
                let v = d / threshold
                let fmt = v >= 100 ? "%.0f%@" : (v >= 10 ? "%.1f%@" : "%.2f%@")
                return String(format: fmt, v, suffix)
            }
        }
        return String(Int(d))
    }

    /// Formats a per-second production rate, e.g. `"+4.5K/s"`.
    public func idleRateFormatted() -> String {
        "+\(idleFormatted())/s"
    }
}
