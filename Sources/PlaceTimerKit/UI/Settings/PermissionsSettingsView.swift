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
                permissionRow(
                    granted: !coordinator.needsLocationPermission,
                    title: "Konum",
                    detail: "macOS ağ adını yalnızca bu izinle veriyor. "
                        + "İzin olmadan yer tespiti hiç çalışmaz.",
                    action: { coordinator.requestLocationPermission() },
                    pane: .locationServices
                )
                permissionRow(
                    granted: !coordinator.needsNotificationPermission,
                    title: "Bildirimler",
                    detail: "Belirlediğin aralıkta haber verir.",
                    action: { Task { await coordinator.requestNotificationPermission() } },
                    pane: .notifications
                )
                permissionRow(
                    granted: launchesAtLogin,
                    title: "Açılışta başlat",
                    detail: "Bilgisayarı açtığın anda sayması için gerekli.",
                    action: {
                        LoginItem.enable()
                        launchesAtLogin = LoginItem.isEnabled
                    },
                    pane: .loginItems
                )
            }
        }
        .formStyle(.grouped)
        .task {
            // Izinler uygulama disinda da degisebilir; sekme acikken izliyoruz.
            while !Task.isCancelled {
                await coordinator.refreshPermissions()
                launchesAtLogin = LoginItem.isEnabled
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func permissionRow(
        granted: Bool,
        title: String,
        detail: String,
        action: @escaping () -> Void,
        pane: SystemSettings.Pane
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !granted {
                VStack(spacing: 4) {
                    Button("İzin ver", action: action)
                    Button("Ayarlar") { SystemSettings.open(pane) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
