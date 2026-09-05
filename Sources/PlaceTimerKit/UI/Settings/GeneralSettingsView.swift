import PlaceTimerCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var launchesAtLogin = LoginItem.isEnabled

    /// Eşikler serbest sayı değil, birkaç makul seçenek. Kullanıcının
    /// "37 dakika" girmesine izin vermek karar yükünü artırır, karşılığı yok.
    private let sleepOptions: [(String, TimeInterval)] = [
        ("30 dakika", 30 * 60), ("1 saat", 60 * 60),
        ("2 saat", 2 * 60 * 60), ("4 saat", 4 * 60 * 60),
    ]
    private let idleOptions: [(String, TimeInterval)] = [
        ("2 dakika", 2 * 60), ("5 dakika", 5 * 60),
        ("10 dakika", 10 * 60), ("15 dakika", 15 * 60),
    ]

    var body: some View {
        Form {
            Section("Görünüm") {
                Toggle(
                    "Saniyeleri göster",
                    isOn: preferenceBinding(coordinator, \.showSeconds)
                )
                Toggle(
                    "Menubar'da yerin adını göster",
                    isOn: preferenceBinding(coordinator, \.showPlaceNameInMenuBar)
                )
            }

            Section("Davranış") {
                Picker(
                    "Oturumu sıfırlayan uyku süresi",
                    selection: preferenceBinding(coordinator, \.sessionResetSleepThreshold)
                ) {
                    ForEach(sleepOptions, id: \.1) { Text($0.0).tag($0.1) }
                }
                Text("Bu süreden kısa uykular oturumu bozmaz — kahve molası gibi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    "Aktif sayacı durduran hareketsizlik",
                    selection: preferenceBinding(coordinator, \.idleThreshold)
                ) {
                    ForEach(idleOptions, id: \.1) { Text($0.0).tag($0.1) }
                }

                Picker(
                    "Bildirim sıklığı",
                    selection: preferenceBinding(coordinator, \.notificationInterval)
                ) {
                    ForEach(NotificationInterval.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            }

            Section("Başlangıç") {
                Toggle("Açılışta başlat", isOn: Binding(
                    get: { launchesAtLogin },
                    set: { yeni in
                        if yeni { LoginItem.enable() } else { LoginItem.disable() }
                        launchesAtLogin = LoginItem.isEnabled
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .onAppear { launchesAtLogin = LoginItem.isEnabled }
    }
}
