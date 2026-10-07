import AppKit
import Foundation

/// Sistem uykusu ve uyanmayı dinler.
///
/// Ekranın kararması ve kilit bilinçli olarak dinlenmiyor: ikisi de uyanık bir
/// Mac'te `IdleReader`'ın süresini büyütür ve motorun ara kuralına oradan
/// girer. Uyku sayılsalardı agent'ı bekleyen kullanıcının oturumu bölünürdü.
@MainActor
public final class PowerMonitor {
    public var onSleep: (() -> Void)?
    public var onWake: (() -> Void)?

    private var observations: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    public init() {}

    public func start() {
        guard observations.isEmpty else { return }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.onSleep?() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.onWake?() }
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
