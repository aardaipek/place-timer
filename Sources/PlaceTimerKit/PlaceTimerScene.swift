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
        let time = DurationFormat.clock(
            coordinator.elapsed,
            showSeconds: coordinator.preferences.showSeconds
        )
        guard coordinator.preferences.showPlaceNameInMenuBar else { return time }
        return "\(DurationFormat.truncate(coordinator.placeName)) · \(time)"
    }
}

/// Uygulamanın tek durum sahibi. Koordinatörü başlatır, izin sihirbazını ve
/// yeni yer sorusunu kendi pencerelerinde gösterir.
@MainActor
public final class PlaceTimerAppDelegate: NSObject, NSApplicationDelegate {
    /// Panelin pencere açtırabilmesi için tek örneğe erişim.
    ///
    /// `NSApp.delegate` bu sınıfı **vermez**: SwiftUI,
    /// `NSApplicationDelegateAdaptor` ile verilen nesneyi kendi
    /// `SwiftUI.AppDelegate` sarmalayıcısının arkasına koyar ve mesajları ona
    /// iletir. `NSApp.delegate as? PlaceTimerAppDelegate` bu yüzden sessizce
    /// `nil` döner — ayarlar düğmesi tam olarak bu yüzden hiçbir şey yapmıyordu.
    public private(set) static weak var shared: PlaceTimerAppDelegate?

    public let coordinator = AppCoordinator()

    private let onboardingWindow = AppWindow(title: "PlaceTimer")
    private let promptWindow = AppWindow(title: "Yeni yer")
    private let settingsWindow = AppWindow(title: "PlaceTimer Ayarları")

    public override init() {
        super.init()
        Self.shared = self
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Yeni yer sorusu yalnızca panelde dursaydı kullanıcının menubar'a
        // tıklaması gerekirdi; soruyu kendi penceresinde öne çıkarıyoruz.
        coordinator.onPromptChange = { [weak self] prompt in
            guard let self else { return }
            guard let prompt else {
                promptWindow.dismiss()
                return
            }
            promptWindow.present {
                PlacePromptView(prompt: prompt, coordinator: self.coordinator)
                    .padding(20)
                    .frame(width: 320)
            }
        }

        Task { @MainActor in
            await coordinator.start()
            if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                presentOnboarding()
            }
        }
    }

    public func presentSettings() {
        settingsWindow.present { [weak self] in
            if let self { SettingsView(coordinator: coordinator) }
        }
    }

    public func presentOnboarding() {
        onboardingWindow.present { [weak self] in
            if let self {
                OnboardingView(coordinator: coordinator) { [weak self] in
                    self?.onboardingWindow.dismiss()
                }
            }
        }
    }
}
