import AppKit
import Foundation

/// Uyku/uyanma ve ekran kilidi olaylarını dinler.
///
/// Uyku bildirimleri `NSWorkspace`ten, kilit bildirimleri ise sistemin
/// dağıtılmış bildirim merkezinden gelir — ikisi ayrı kaynaklardır.
@MainActor
public final class PowerMonitor {
    public var onSleep: (() -> Void)?
    public var onWake: (() -> Void)?
    public var onScreenLocked: (() -> Void)?
    public var onScreenUnlocked: (() -> Void)?

    private var observations: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    public init() {}

    public func start() {
        guard observations.isEmpty else { return }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.onSleep?() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.onWake?() }
        // Kapak kapanması ayrı bir bildirim; uyku ile aynı muamele görür.
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.onSleep?() }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.onWake?() }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) {
            $0.onScreenLocked?()
        }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) {
            $0.onScreenUnlocked?()
        }
    }

    public func stop() {
        for observation in observations {
            observation.center.removeObserver(observation.token)
        }
        observations.removeAll()
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        handler: @escaping @MainActor (PowerMonitor) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observations.append((center, token))
    }
}
