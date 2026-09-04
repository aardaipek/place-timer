import SwiftUI

/// İlk açılışta gösterilen karşılama ekranı.
///
/// İzinler opsiyonel değil: konum izni olmadan macOS ağ adını gizler, yani
/// yer tespiti tamamen çalışmaz.
public struct OnboardingView: View {
    @Bindable var coordinator: AppCoordinator
    let onFinish: () -> Void

    public init(coordinator: AppCoordinator, onFinish: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onFinish = onFinish
    }

    @State private var launchesAtLogin = LoginItem.isEnabled

    private var isReady: Bool {
        !coordinator.needsLocationPermission
            && !coordinator.needsNotificationPermission
            && launchesAtLogin
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PlaceTimer")
                    .font(.largeTitle.weight(.light))
                Text("Nerede ne kadar oturduğunu kendiliğinden takip eder.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    granted: !coordinator.needsLocationPermission,
                    icon: "location",
                    title: "Konum",
                    detail: "macOS, Wi-Fi ağının adını yalnızca bu izinle veriyor. "
                        + "Yerini tanımanın ve mekân ismi önermenin tek yolu."
                )
                permissionRow(
                    granted: !coordinator.needsNotificationPermission,
                    icon: "bell",
                    title: "Bildirimler",
                    detail: "Bir yerde her saat dolduğunda haber verir."
                )
                permissionRow(
                    granted: launchesAtLogin,
                    icon: "power",
                    title: "Açılışta başlat",
                    detail: "Bilgisayarı açtığın anda sayması için gerekli."
                )
            }

            HStack {
                if isReady {
                    Label("Hazır", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("İzinleri ver") {
                        Task {
                            await coordinator.requestPermissions()
                            LoginItem.enable()
                            launchesAtLogin = LoginItem.isEnabled
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button(isReady ? "Başla" : "Sonra") { onFinish() }
            }

            Text("Menubar'daki saate tıklayarak her zaman ulaşabilirsin.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 440)
    }

    private func permissionRow(
        granted: Bool,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .foregroundStyle(granted ? .green : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
