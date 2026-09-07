import PlaceTimerCore
import SwiftUI

/// Karşılama sihirbazının kalıcı karşılığı. Sihirbaz bir kez akar; bu sekme
/// izin durumunu her zaman gösterir ve düzeltme yolunu açık tutar.
struct PermissionsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var launchesAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    granted: !coordinator.needsLocationPermission,
                    title: "Konum",
                    detail: "macOS ağ adını yalnızca bu izinle veriyor. "
                        + "İzin olmadan yer tespiti hiç çalışmaz.",
                    pane: .locationServices,
                    action: coordinator.requestLocationPermission
                )
                PermissionRow(
                    granted: !coordinator.needsNotificationPermission,
                    title: "Bildirimler",
                    detail: "Belirlediğin aralıkta haber verir.",
                    pane: .notifications,
                    action: requestNotifications
                )
                PermissionRow(
                    granted: launchesAtLogin,
                    title: "Açılışta başlat",
                    detail: "Bilgisayarı açtığın anda sayması için gerekli.",
                    pane: .loginItems,
                    action: enableLoginItem
                )
            }
        }
        .formStyle(.grouped)
        .task(watchPermissions)
    }

    /// Izinler uygulama disinda da degisebilir (Sistem Ayarlari'ndan); sekme
    /// acik kaldigi surece izleniyor.
    @Sendable
    private func watchPermissions() async {
        while !Task.isCancelled {
            await coordinator.refreshPermissions()
            launchesAtLogin = LoginItem.isEnabled
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func requestNotifications() {
        Task { await coordinator.requestNotificationPermission() }
    }

    private func enableLoginItem() {
        LoginItem.enable()
        launchesAtLogin = LoginItem.isEnabled
    }
}

#Preview {
    PermissionsSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
}
