import Foundation

// MARK: - Idle Number Formatting

extension Decimal {
    /// Short-suffix tiers, descending. Contiguous ×1000 steps so `d / threshold` is always < 1000.
    /// Allocated once — `idleFormatted()` is called for every resource chip on every tick.
    private static let idleTiers: [(threshold: Double, suffix: String)] = [
        (1e63, "Vg"),  (1e60, "NoDc"), (1e57, "OcDc"), (1e54, "SpDc"), (1e51, "SxDc"),
        (1e48, "QiDc"), (1e45, "QaDc"), (1e42, "TDc"), (1e39, "DDc"), (1e36, "UDc"),
        (1e33, "Dc"),  (1e30, "No"),   (1e27, "Oc"),   (1e24, "Sp"),  (1e21, "Sx"),
        (1e18, "Qi"),  (1e15, "Qa"),   (1e12, "T"),    (1e9,  "B"),   (1e6,  "M"),
        (1e3,  "K")
    ]

    /// Formats a `Decimal` for idle game display with short suffixes.
    ///
    /// - `< 1,000`          → `"999"`
    /// - `< 1,000,000`      → `"59.2K"`
    /// - `< 1,000,000,000`  → `"4.5M"`
    /// - `< 1e12`           → `"3.1B"`
    /// - `< 1e15`           → `"7.2T"`
    /// - `< 1e18`           → `"1.4Qa"`
    /// - `< 1e21`           → `"2.0Qi"`
    /// - `< 1e24`           → `"1.0Sx"`
    /// - … through `Vg` (1e63)
    /// - `>= 1e66`          → `"8.0e66"` (scientific fallback, keeps output length bounded)
    ///
    /// Always returns a non-negative string. Negative values display as `"0"`.
    /// `NaN` returns `"—"` — a distinct placeholder so economy bugs are visible rather than
    /// masquerading as a legitimate `"∞"`.
    public func idleFormatted() -> String {
        // Must precede `max(0, …)` — comparing against NaN is always false, so `max` would
        // silently yield 0 and hide the bad value.
        guard !isNaN else { return "—" }

        let raw = NSDecimalNumber(decimal: max(0, self)).doubleValue
        guard !raw.isNaN else { return "—" }
        guard raw.isFinite else { return "∞" }

        // Round before tiering so 999.9 becomes "1.00K" rather than "999".
        let d = raw.rounded()

        // Above the last tier — scientific notation, e.g. "8.0e66". Keeps length bounded.
        // Built from mantissa + exponent rather than "%e" so the output is identical on
        // every platform and locale (Apple's localized "%e" emits an uppercase "E+").
        if d >= Decimal.idleTiers[0].threshold * 1e3 {
            var exponent = Int(floor(log10(d)))
            var mantissa = d / pow(10, Double(exponent))
            if mantissa >= 9.95 { mantissa /= 10; exponent += 1 }   // 9.99… rounds up to 10.0
            return String(format: "%.1fe%d", locale: Locale.current, mantissa, exponent)
        }

        for (index, tier) in Decimal.idleTiers.enumerated() {
            guard d >= tier.threshold else { continue }
            var (threshold, suffix) = tier
            var v = d / threshold
            // "%.0f" would render 999.7 as "1000K" — promote to the next tier instead.
            if v >= 999.5, index > 0 {
                (threshold, suffix) = Decimal.idleTiers[index - 1]
                v = d / threshold
            }
            let fmt = v >= 100 ? "%.0f%@" : (v >= 10 ? "%.1f%@" : "%.2f%@")
            return String(format: fmt, locale: Locale.current, v, suffix)
        }

        return String(format: "%.0f", locale: Locale.current, d)
    }

    /// Formats a per-second production rate, e.g. `"+4.5K/s"`.
    public func idleRateFormatted() -> String {
        "+\(idleFormatted())/s"
    }
}
