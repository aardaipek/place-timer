import PlaceTimerCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var coordinator: AppCoordinator

    /// Tercihler koordinatörde `private(set)`: her değişiklik
    /// `updatePreferences` üzerinden geçmeli ki diske yazılsın ve motorun
    /// yapılandırması güncellensin. Gövde içinde elle `Binding` kurmak yerine
    /// yerel bir taslak tutuluyor; değişim `onChange` ile koordinatöre geçiyor.
    @State private var draft = Preferences()
    @State private var launchesAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("Görünüm") {
                Toggle("Saniyeleri göster", isOn: $draft.showSeconds)
                Toggle("Menubar'da yerin adını göster", isOn: $draft.showPlaceNameInMenuBar)
            }

            Section {
                Picker(
                    "Oturumu sıfırlayan uyku süresi",
                    selection: $draft.sessionResetSleepThreshold
                ) {
                    ForEach(ThresholdOption.sleep) { Text($0.title).tag($0.seconds) }
                }

                Picker(
                    "Aktif sayacı durduran hareketsizlik",
                    selection: $draft.idleThreshold
                ) {
                    ForEach(ThresholdOption.idle) { Text($0.title).tag($0.seconds) }
                }

                Picker("Bildirim sıklığı", selection: $draft.notificationInterval) {
                    ForEach(NotificationInterval.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            } header: {
                Text("Davranış")
            } footer: {
                Text("Uyku eşiğinden kısa molalar oturumu bozmaz — kahve molası gibi.")
                    .foregroundStyle(.secondary)
            }

            Section("Başlangıç") {
                Toggle("Açılışta başlat", isOn: $launchesAtLogin)
            }
        }
        .formStyle(.grouped)
        .task {
            draft = coordinator.preferences
            launchesAtLogin = LoginItem.isEnabled
        }
        .onChange(of: draft) { _, yeni in
            guard yeni != coordinator.preferences else { return }
            coordinator.updatePreferences(yeni)
        }
        .onChange(of: launchesAtLogin) { _, yeni in
            updateLoginItem(to: yeni)
        }
    }

    /// Kayit basarisiz olabilir (SMAppService hata atar); anahtar bu yuzden
    /// istegin degil gercek durumun pesine takiliyor. Gercek durum istenenle
    /// ayni ciktiginda `onChange` yeniden tetiklenmez, dongu olusmaz.
    private func updateLoginItem(to enabled: Bool) {
        guard enabled != LoginItem.isEnabled else { return }
        if enabled { LoginItem.enable() } else { LoginItem.disable() }
        launchesAtLogin = LoginItem.isEnabled
    }
}

#Preview {
    GeneralSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
}
