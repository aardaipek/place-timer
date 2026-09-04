import AppKit
import PlaceTimerCore
import SwiftUI

/// Menubar sahnesi.
///
/// Koordinatörü kendi yaratmaz, dışarıdan alır: uygulamanın tek durum sahibi
/// `PlaceTimerAppDelegate`'tir. Sahne de kendi örneğini yaratsaydı iki ayrı
/// oturum motoru çalışırdı.
public struct PlaceTimerScene: Scene {
    private let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some Scene {
        MenuBarExtra {
            PanelView(coordinator: coordinator)
        } label: {
            Text(menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        guard !coordinator.needsLocationPermission else { return "◷ İzin gerekli" }
        let name = DurationFormat.truncate(coordinator.placeName)
        return "\(name) · \(DurationFormat.clock(coordinator.elapsed))"
    }
}

/// Karşılama ekranını taşıyan pencere.
///
/// SwiftUI'nin `Window` sahnesi açılışta koşullu gösterime elverişli olmadığı
/// için pencereyi doğrudan AppKit ile yönetiyoruz.
@MainActor
public final class OnboardingWindowPresenter {
    public static let shared = OnboardingWindowPresenter()
    private var window: NSWindow?

    private init() {}

    public func present(coordinator: AppCoordinator) {
        // LSUIElement uygulamalar one gelemez; TCC diyalogunun gorunmesi icin
        // pencere acikken gecici olarak normal uygulama gibi davraniyoruz.
        NSApp.setActivationPolicy(.regular)

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: OnboardingView(coordinator: coordinator) { [weak self] in
                self?.dismiss()
            }
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "PlaceTimer"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    public func dismiss() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Uygulamanın tek durum sahibi. Koordinatörü başlatır ve izin eksikse
/// karşılama ekranını gösterir.
@MainActor
public final class PlaceTimerAppDelegate: NSObject, NSApplicationDelegate {
    public let coordinator = AppCoordinator()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await coordinator.start()
            if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                OnboardingWindowPresenter.shared.present(coordinator: coordinator)
            }
        }
    }
}
