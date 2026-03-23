import Foundation
import UserNotifications

// MARK: - Notification Types

public enum NotificationType: String, Sendable {
    case offlineCap     = "offline_cap"
    case dailyQuest     = "daily_quest"
    case weeklyEvent    = "weekly_event"
    case levelReady     = "level_ready"
    case wonderComplete = "wonder_complete"
}

// MARK: - Protocol

/// Schedules and cancels local push notifications.
/// All copy comes from `theme.copy.notifications` — never hardcoded strings.
public protocol NotificationService: Sendable {
    func requestPermission() async -> Bool
    func schedule(_ type: NotificationType, copy: ThemeCopy, fireIn seconds: TimeInterval) async
    func cancel(_ type: NotificationType) async
    func cancelAll() async
}

// MARK: - UNUserNotifications Implementation

public actor LiveNotificationService: NotificationService {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    public func schedule(_ type: NotificationType, copy: ThemeCopy, fireIn seconds: TimeInterval) async {
        await cancel(type)

        let content = UNMutableNotificationContent()
        switch type {
        case .offlineCap:
            content.title = copy.notifications.offlineCapTitle
            content.body  = copy.notifications.offlineCapBody
        case .dailyQuest:
            content.title = copy.notifications.dailyQuestTitle
            content.body  = copy.notifications.dailyQuestBody
        case .weeklyEvent:
            content.title = copy.notifications.weeklyEventTitle
            content.body  = ""
        case .levelReady:
            content.title = copy.notifications.levelReadyTitle
            content.body  = copy.notifications.levelReadyBody
        case .wonderComplete:
            content.title = copy.notifications.wonderCompleteTitle
            content.body  = copy.notifications.wonderCompleteBody
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancel(_ type: NotificationType) async {
        center.removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }

    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    /// Adjusts a fire-in duration to avoid the 22:00–08:00 quiet window.
    /// If the computed fire time falls inside quiet hours, bumps it to 08:00 the next morning.
    /// In the simulator with dev fast-forward the value is returned unchanged (no delay needed).
    public static func quietHoursAdjusted(fireIn seconds: TimeInterval) -> TimeInterval {
        #if targetEnvironment(simulator)
        if GameEngine.devFastForwardEnabled { return seconds }
        #endif
        let fireDate = Date().addingTimeInterval(seconds)
        let cal = Calendar.current
        let hour = cal.component(.hour, from: fireDate)
        // Quiet hours: 22:00 (hour >= 22) or before 08:00 (hour < 8)
        guard hour >= 22 || hour < 8 else { return seconds }
        // Find 08:00 on the next morning
        var components = cal.dateComponents([.year, .month, .day], from: fireDate)
        if hour >= 22 {
            // Bump to next day
            components.day = (components.day ?? 0) + 1
        }
        components.hour = 8
        components.minute = 0
        components.second = 0
        let nextMorning = cal.date(from: components) ?? fireDate
        return max(1, nextMorning.timeIntervalSinceNow)
    }
}
