import UIKit

/// Stateless haptic feedback helpers. All methods are no-ops when haptics are disabled in Settings.
@MainActor public enum HapticsService {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    // Treat "never set" as enabled (default true).
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics_enabled") == nil
            || UserDefaults.standard.bool(forKey: "haptics_enabled")
    }
}
