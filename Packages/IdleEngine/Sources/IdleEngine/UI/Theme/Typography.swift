import SwiftUI

/// Fixed type scale for the engine UI.
/// All text in engine components uses these — never raw `Font.system(size:)` calls.
public enum Typography {
    /// Hero numbers (offline income screen, big milestone unlocks).
    public static let hero        = Font.system(size: 48, weight: .black, design: .rounded)
    /// Screen titles and prestige headers.
    public static let display     = Font.system(size: 34, weight: .bold,  design: .rounded)
    /// Section headers and card titles.
    public static let title       = Font.system(size: 22, weight: .semibold)
    /// Unit names, milestone names.
    public static let headline    = Font.system(size: 17, weight: .semibold)
    /// Body text, descriptions.
    public static let body        = Font.system(size: 15, weight: .regular)
    /// Secondary labels, cost hints.
    public static let subheadline = Font.system(size: 13, weight: .regular)
    /// Timestamps, fine print.
    public static let caption     = Font.system(size: 12, weight: .regular)
    /// Production rate ticker and resource bar amounts.
    public static let number      = Font.system(size: 18, weight: .bold, design: .monospaced)
    /// Large resource display (ResourceBar primary amount).
    public static let bigNumber   = Font.system(size: 26, weight: .bold, design: .rounded)
}
