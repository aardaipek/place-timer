import Foundation
import UserNotifications

/// Saat başı bildirimleri.
@MainActor
public final class Notifier {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    public func notifyHourMark(hours: Int, placeName: String) {
        let content = UNMutableNotificationContent()
        content.title = placeName
        content.body = hours == 1
            ? "1 saat oldu."
            : "\(hours) saat oldu."
        content.sound = .default

        center.add(
            UNNotificationRequest(
                identifier: "hour-mark-\(hours)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        )
    }
}
