import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AppTheme

/// The runtime theme injected into the SwiftUI environment.
/// All color and copy access in views goes through `@Environment(\.theme)`.
///
/// Every `Color` is resolved once, in `init`. They used to be computed properties, so a
/// single `GameplayScreen.body` pass — which runs on every tick — performed ~30 colour
/// lookups, each allocating a dynamic `UIColor` around two `Color(hex:)` parses, and each
/// of those allocating a `String` and an Objective-C `Scanner`. That was roughly 1,500
/// main-thread allocations per second to re-derive constants.
public struct AppTheme: Sendable {
    public let colors: ThemeColors
    public let copy: ThemeCopy
    public let primaryCurrency: String
    public let primaryCurrencyIcon: String

    // MARK: - Resolved Colors

    public let backgroundColor: Color
    public let surfaceColor: Color
    public let surfaceElevatedColor: Color
    public let textPrimaryColor: Color
    public let textSecondaryColor: Color
    public let goldAccentColor: Color

    private let levelPrimaryColors: [String: Color]
    private let levelSecondaryColors: [String: Color]

    public init(colors: ThemeColors, copy: ThemeCopy, primaryCurrency: String, primaryCurrencyIcon: String) {
        self.colors = colors
        self.copy = copy
        self.primaryCurrency = primaryCurrency
        self.primaryCurrencyIcon = primaryCurrencyIcon

        let lightSurface = HexColor(hex: "#FFFFFF")
        let darkSurface = HexColor(hex: colors.surface)

        self.backgroundColor = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: colors.background))
        self.surfaceColor = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: colors.surface))
        self.surfaceElevatedColor = Color(light: Color(hex: "#E8E8F0"), dark: Color(hex: colors.surfaceElevated))
        self.textPrimaryColor = Color(light: Color(hex: "#1C1C1E"), dark: Color(hex: colors.textPrimary))
        self.textSecondaryColor = Color(light: Color(hex: "#6C6C80"), dark: Color(hex: colors.textSecondary))

        // The accent was the one structural colour never wrapped in `Color(light:dark:)`.
        // #FFD700 on a white surface is 1.40:1 — it fails AA, AA-large, and legibility — and
        // it drives the primary resource counter, every cost label, leaderboard scores, and
        // the shop's reward text. Every Light Mode player saw the game's core number as
        // near-white on white.
        //
        // The theme may supply an explicit `goldAccentLight`; otherwise the dark-mode value
        // is darkened until it clears AA against white. Deriving it means existing themes are
        // fixed without a content change, and a new theme cannot reintroduce the bug.
        let accent = HexColor(hex: colors.goldAccent)
        let accentLight = colors.goldAccentLight.map { HexColor(hex: $0) }
            ?? accent.darkened(toContrast: 4.5, against: lightSurface)
        self.goldAccentColor = Color(light: accentLight.color, dark: accent.color)

        // Level accents get the same treatment in both directions: darkened for the light
        // surface, lightened for the dark one. Five of the eight shipped era accents failed
        // AA against the dark surface — Space Age at 1.93:1 — and they carry live game data
        // such as the secondary-resource counter and era progress percentage.
        var primaries: [String: Color] = [:]
        var secondaries: [String: Color] = [:]
        for entry in colors.levelColors {
            let primary = HexColor(hex: entry.primary)
            primaries[entry.levelID] = Color(
                light: primary.darkened(toContrast: 4.5, against: lightSurface).color,
                dark: primary.lightened(toContrast: 4.5, against: darkSurface).color
            )
            let secondary = HexColor(hex: entry.secondary)
            secondaries[entry.levelID] = Color(
                light: secondary.darkened(toContrast: 3.0, against: lightSurface).color,
                dark: secondary.lightened(toContrast: 3.0, against: darkSurface).color
            )
        }
        self.levelPrimaryColors = primaries
        self.levelSecondaryColors = secondaries
    }

    /// Build an `AppTheme` from a loaded `ThemePackage`.
    public init(theme: any ThemePackage) {
        self.init(
            colors: theme.themeColors,
            copy: theme.copy,
            primaryCurrency: theme.primaryCurrency,
            primaryCurrencyIcon: theme.primaryCurrencyIcon
        )
    }

    /// Returns the tint for a given level ID, falling back to `goldAccent`.
    public func levelPrimaryColor(for levelID: String) -> Color {
        levelPrimaryColors[levelID] ?? goldAccentColor
    }

    public func levelSecondaryColor(for levelID: String) -> Color {
        levelSecondaryColors[levelID] ?? surfaceElevatedColor
    }

    // MARK: - Universal Rank Medal Colors (gold / silver / bronze — not theme-specific)

    /// Medal tints, darkened for light mode so rank numerals stay legible on a white row.
    public static let rankGold = Color(
        light: HexColor(hex: "#FFD700").darkened(toContrast: 4.5, against: HexColor(hex: "#FFFFFF")).color,
        dark: Color(hex: "#FFD700")
    )
    public static let rankSilver = Color(
        light: HexColor(hex: "#C0C0C0").darkened(toContrast: 4.5, against: HexColor(hex: "#FFFFFF")).color,
        dark: Color(hex: "#C0C0C0")
    )
    public static let rankBronze = Color(
        light: HexColor(hex: "#CD7F32").darkened(toContrast: 4.5, against: HexColor(hex: "#FFFFFF")).color,
        dark: Color(hex: "#CD7F32")
    )

    // MARK: - Placeholder (used before theme is loaded)

    public static let placeholder = AppTheme(
        colors: ThemeColors(
            background: "#0D0D0F", surface: "#1A1A20", surfaceElevated: "#252530",
            textPrimary: "#F5F5F5", textSecondary: "#A0A0B0", goldAccent: "#FFD700",
            levelColors: []
        ),
        copy: ThemeCopy(
            unitNoun: "Unit", unitNounPlural: "Units", levelNoun: "Level",
            milestoneNoun: "Milestone", characterNoun: "Character", characterNounPlural: "Characters",
            premiumPassName: "Premium Pass", advanceVerb: "Advance",
            prestigeTitle: "New Level!",
            startMilestoneButton: "Build Milestone",
            continueButton: "Continue",
            levelCompleteSubtitle: "Level Complete!",
            leaderboardEmptyState: "No leaderboard data yet",
            studioPointsTitle: "Studio Points",
            studioPointsTagline: "Earn points across all studio games",
            crossPromoTitle: "New Game",
            crossPromoAvailableLabel: "Available now",
            leaderboardTabLabel: "Leaderboard",
            socialTabLabel: "Social",
            settingsTabLabel: "Settings",
            offlineSheet: ThemeCopy.OfflineSheetCopy(
                title: "Welcome back!", body: "Resources earned while you were away.",
                collectButton: "Collect", doubleButton: "Double it!",
                capNote: "Income was capped at %dh"
            ),
            notifications: ThemeCopy.NotificationsCopy(
                offlineCapTitle: "", offlineCapBody: "",
                dailyQuestTitle: "", dailyQuestBody: "",
                weeklyEventTitle: "", levelReadyTitle: "", levelReadyBody: ""
            ),
            notificationPermission: ThemeCopy.NotificationPermissionCopy(
                title: "Stay ahead", body: "Get notified when resources cap.",
                enableButton: "Enable", laterButton: "Later"
            ),
            onboarding: [],
            onboardingCopy: .default
        ),
        primaryCurrency: "gold",
        primaryCurrencyIcon: "dollarsign.circle.fill"
    )
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry public var theme: AppTheme = .placeholder
}

// MARK: - HexColor

/// Parsed sRGB color with WCAG contrast math. Kept as plain components so contrast can be
/// computed and corrected before a SwiftUI `Color` is ever constructed.
public struct HexColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses `#RRGGBB` or `#RRGGBBAA`. Falls back to mid-grey on malformed input.
    public init(hex: String) {
        var value: UInt64 = 0
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: raw).scanHexInt64(&value)
        let r, g, b, a: UInt64
        switch raw.count {
        case 6:  (r, g, b, a) = ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, 255)
        case 8:  (r, g, b, a) = ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default: (r, g, b, a) = (180, 180, 180, 255)
        }
        self.init(
            red: Double(r) / 255, green: Double(g) / 255,
            blue: Double(b) / 255, alpha: Double(a) / 255
        )
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// WCAG 2.1 relative luminance.
    public var relativeLuminance: Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// WCAG 2.1 contrast ratio against `other`, in the range 1...21.
    public func contrastRatio(against other: HexColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Blends toward black until the contrast ratio against `background` reaches `target`.
    /// Returns the original color when it already passes, or pure black when unreachable.
    public func darkened(toContrast target: Double, against background: HexColor) -> HexColor {
        guard contrastRatio(against: background) < target else { return self }
        var best = HexColor(red: 0, green: 0, blue: 0, alpha: alpha)
        // 40 steps is well below the precision at which 8-bit channels differ.
        for step in 1...40 {
            let factor = 1 - Double(step) / 40
            let candidate = HexColor(
                red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha
            )
            if candidate.contrastRatio(against: background) >= target {
                best = candidate
                break
            }
        }
        return best
    }

    /// Blends toward white until the contrast ratio against `background` reaches `target`.
    /// Returns the original color when it already passes, or pure white when unreachable.
    public func lightened(toContrast target: Double, against background: HexColor) -> HexColor {
        guard contrastRatio(against: background) < target else { return self }
        var best = HexColor(red: 1, green: 1, blue: 1, alpha: alpha)
        for step in 1...40 {
            let t = Double(step) / 40
            let candidate = HexColor(
                red: red + (1 - red) * t,
                green: green + (1 - green) * t,
                blue: blue + (1 - blue) * t,
                alpha: alpha
            )
            if candidate.contrastRatio(against: background) >= target {
                best = candidate
                break
            }
        }
        return best
    }
}

// MARK: - Color+Adaptive

extension Color {
    /// Returns a color that adapts to the current color scheme automatically.
    /// Use this for structural chrome (backgrounds, surfaces, text) so light mode looks correct.
    public init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
        #else
        self = dark
        #endif
    }
}

// MARK: - Color+Hex

extension Color {
    /// Initialize from a 6-digit (#RRGGBB) or 8-digit (#RRGGBBAA) hex string.
    public init(hex: String) {
        self = HexColor(hex: hex).color
    }
}
