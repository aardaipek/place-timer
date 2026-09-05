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

    public func notifyMark(elapsed: TimeInterval, placeName: String) {
        let content = UNMutableNotificationContent()
        content.title = placeName
        content.body = "\(DurationFormat.readable(elapsed)) oldu."
        content.sound = .default

        center.add(
            UNNotificationRequest(
                identifier: "mark-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        )
    }
}
