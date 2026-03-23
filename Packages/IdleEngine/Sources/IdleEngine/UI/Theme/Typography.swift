import SwiftUI

/// Dynamic Type-aware type scale for the engine UI.
/// All text in engine components uses these — never raw `Font.system(size:)` calls.
/// Using standard text styles ensures all fonts scale with the user's preferred text size,
/// including Accessibility → Larger Text settings up to ~310%.
public enum Typography {
    /// Hero numbers (offline income screen, big milestone unlocks).
    public static let hero        = Font.system(.largeTitle, design: .rounded, weight: .black)
    /// Screen titles and prestige headers.
    public static let display     = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Section headers and card titles.
    public static let title       = Font.system(.title2, design: .default, weight: .semibold)
    /// Unit names, milestone names.
    public static let headline    = Font.system(.headline, design: .default, weight: .semibold)
    /// Body text, descriptions.
    public static let body        = Font.system(.subheadline, design: .default, weight: .regular)
    /// Secondary labels, cost hints.
    public static let subheadline = Font.system(.footnote, design: .default, weight: .regular)
    /// Timestamps, fine print.
    public static let caption     = Font.system(.caption, design: .default, weight: .regular)
    /// Production rate ticker and resource bar amounts.
    public static let number      = Font.system(.body, design: .monospaced, weight: .bold)
    /// Large resource display (ResourceBar primary amount).
    public static let bigNumber   = Font.system(.title3, design: .rounded, weight: .bold)
}
