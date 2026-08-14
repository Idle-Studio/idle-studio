import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Stateless haptic feedback helpers. All methods are no-ops when haptics are disabled in Settings,
/// and on platforms without a haptic engine.
///
/// The feedback styles are declared here rather than re-exporting `UIImpactFeedbackGenerator`'s,
/// so the engine's public API stays platform-neutral and the package builds (and therefore
/// tests) on macOS.
@MainActor public enum HapticsService {

    public enum ImpactStyle: Sendable {
        case light, medium, heavy, soft, rigid
    }

    public enum NotificationStyle: Sendable {
        case success, warning, error
    }

    public static func impact(_ style: ImpactStyle) {
        guard isEnabled else { return }
        #if canImport(UIKit) && !os(watchOS)
        UIImpactFeedbackGenerator(style: style.uiKitStyle).impactOccurred()
        #endif
    }

    public static func notification(_ type: NotificationStyle) {
        guard isEnabled else { return }
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(type.uiKitType)
        #endif
    }

    // Treat "never set" as enabled (default true).
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics_enabled") == nil
            || UserDefaults.standard.bool(forKey: "haptics_enabled")
    }
}

#if canImport(UIKit) && !os(watchOS)
private extension HapticsService.ImpactStyle {
    var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:  return .light
        case .medium: return .medium
        case .heavy:  return .heavy
        case .soft:   return .soft
        case .rigid:  return .rigid
        }
    }
}

private extension HapticsService.NotificationStyle {
    var uiKitType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .error:   return .error
        }
    }
}
#endif
