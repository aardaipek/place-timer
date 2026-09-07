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
        MenuBarTitle.text(
            placeName: coordinator.placeName,
            elapsed: coordinator.elapsed,
            preferences: coordinator.preferences,
            needsLocationPermission: coordinator.needsLocationPermission
        )
    }
}

/// Uygulamanın tek durum sahibi. Koordinatörü başlatır, izin sihirbazını,
/// ayarları ve yeni yer sorusunu kendi pencerelerinde gösterir.
///
/// Ayarlar için SwiftUI'nin `Settings` sahnesi denendi ve **çalışmıyor**:
/// sahne uygulama menüsüne "Settings…" öğesini ekliyor, ama `LSUIElement`
/// bir uygulamada — ne o menü öğesine tıklandığında ne de
/// `showSettingsWindow:` eylemi gönderildiğinde — pencere sunuluyor. Dock
/// simgesi olmayan uygulama etkinleşemediği için sahne sessizce hiçbir şey
/// yapmıyor. `AppWindow` etkinleştirme politikasını geçici olarak `.regular`
/// yapıp pencereyi kendi açtığı için bu uygulamada çalışan tek yol o.
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
    private let settingsWindow = AppWindow(title: "Ayarlar")

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
