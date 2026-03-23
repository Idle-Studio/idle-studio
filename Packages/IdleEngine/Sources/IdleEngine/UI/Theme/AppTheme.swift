import SwiftUI

// MARK: - AppTheme

/// The runtime theme injected into the SwiftUI environment.
/// All color and copy access in views goes through `@Environment(\.theme)`.
public struct AppTheme: Sendable {
    public let colors: ThemeColors
    public let copy: ThemeCopy
    public let primaryCurrency: String
    public let primaryCurrencyIcon: String

    public init(colors: ThemeColors, copy: ThemeCopy, primaryCurrency: String, primaryCurrencyIcon: String) {
        self.colors = colors
        self.copy = copy
        self.primaryCurrency = primaryCurrency
        self.primaryCurrencyIcon = primaryCurrencyIcon
    }

    /// Build an `AppTheme` from a loaded `ThemePackage`.
    public init(theme: any ThemePackage) {
        self.colors = theme.themeColors
        self.copy = theme.copy
        self.primaryCurrency = theme.primaryCurrency
        self.primaryCurrencyIcon = theme.primaryCurrencyIcon
    }

    // MARK: - Computed SwiftUI Colors

    public var backgroundColor:      Color { Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: colors.background)) }
    public var surfaceColor:          Color { Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: colors.surface)) }
    public var surfaceElevatedColor:  Color { Color(light: Color(hex: "#E8E8F0"), dark: Color(hex: colors.surfaceElevated)) }
    public var textPrimaryColor:      Color { Color(light: Color(hex: "#1C1C1E"), dark: Color(hex: colors.textPrimary)) }
    public var textSecondaryColor:    Color { Color(light: Color(hex: "#6C6C80"), dark: Color(hex: colors.textSecondary)) }
    public var goldAccentColor:       Color { Color(hex: colors.goldAccent) }

    /// Returns the tint for a given level ID, falling back to `goldAccent`.
    public func levelPrimaryColor(for levelID: String) -> Color {
        colors.levelColors.first { $0.levelID == levelID }
            .map { Color(hex: $0.primary) } ?? goldAccentColor
    }

    public func levelSecondaryColor(for levelID: String) -> Color {
        colors.levelColors.first { $0.levelID == levelID }
            .map { Color(hex: $0.secondary) } ?? surfaceElevatedColor
    }

    // MARK: - Universal Rank Medal Colors (gold / silver / bronze — not theme-specific)

    public static let rankGold   = Color(hex: "#FFD700")
    public static let rankSilver = Color(hex: "#C0C0C0")
    public static let rankBronze = Color(hex: "#CD7F32")

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
            onboarding: []
        ),
        primaryCurrency: "gold",
        primaryCurrencyIcon: "dollarsign.circle.fill"
    )
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry public var theme: AppTheme = .placeholder
}

// MARK: - Color+Adaptive

extension Color {
    /// Returns a color that adapts to the current color scheme automatically.
    /// Use this for structural chrome (backgrounds, surfaces, text) so light mode looks correct.
    public init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Color+Hex

extension Color {
    /// Initialize from a 6-digit (#RRGGBB) or 8-digit (#RRGGBBAA) hex string.
    public init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r, g, b, a: UInt64
        switch raw.count {
        case 6:  (r, g, b, a) = ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, 255)
        case 8:  (r, g, b, a) = ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default: (r, g, b, a) = (180, 180, 180, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
