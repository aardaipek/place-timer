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
    public let coordinator = AppCoordinator()

    private let onboardingWindow = AppWindow(title: "PlaceTimer")
    private let promptWindow = AppWindow(title: "Yeni yer")

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
