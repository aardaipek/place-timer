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
            Section {
                Toggle("Saniyeleri göster", isOn: $draft.showSeconds)
                Toggle("Yerin adını göster", isOn: $draft.showPlaceNameInMenuBar)
            } header: {
                Text("Menubar")
            } footer: {
                menuBarPreview
            }

            Section {
                Picker("Uyku eşiği", selection: $draft.sessionResetSleepThreshold) {
                    ForEach(ThresholdOption.sleep) { Text($0.title).tag($0.seconds) }
                }

                Picker("Hareketsizlik eşiği", selection: $draft.idleThreshold) {
                    ForEach(ThresholdOption.idle) { Text($0.title).tag($0.seconds) }
                }
            } header: {
                Text("Oturum")
            } footer: {
                sessionFooter
            }

            Section {
                Picker("Sıklık", selection: $draft.notificationInterval) {
                    ForEach(NotificationInterval.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            } header: {
                Text("Bildirimler")
            } footer: {
                notificationFooter
            }

            Section {
                Toggle("Açılışta başlat", isOn: $launchesAtLogin)
            } header: {
                Text("Başlangıç")
            } footer: {
                Text(
                    "Kapalıyken PlaceTimer'ı elle açmadığın sürece günün ilk "
                        + "saatleri kaydedilmez."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    /// İki anahtarın ne yaptığını anlatmak yerine gösteriyoruz: buradaki
    /// başlık menubar'daki metnin ta kendisi, aynı işlevden üretiliyor.
    private var menuBarPreview: some View {
        HStack(spacing: Design.small) {
            Text("Şöyle görünür")
                .foregroundStyle(.secondary)

            Spacer(minLength: Design.small)

            Text(
                MenuBarTitle.text(
                    placeName: coordinator.placeName,
                    elapsed: coordinator.elapsed,
                    preferences: draft
                )
            )
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, Design.small)
            .padding(.vertical, Design.tight)
            .glassEffect(in: .capsule)
        }
        .animation(.snappy, value: draft)
    }

    /// "Hemen" eşiği ötekilerden başka bir şey anlatıyor; açıklama da onunla
    /// birlikte değişiyor. Sabit bir metin ya birini ya ötekini yanlış anlatırdı.
    @ViewBuilder
    private var sessionFooter: some View {
        if draft.sessionResetSleepThreshold == 0 {
            Text(
                "Kapağı kapattığın an oturum biter; kapalı geçen süre hiçbir yere "
                    + "yazılmaz. Hareketsizlik eşiği ise aktif çalışma sayacının ne "
                    + "zaman duracağını belirler."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(
                "Uyku eşiği oturumun ne zaman kapanacağını, hareketsizlik eşiği "
                    + "aktif çalışma sayacının ne zaman duracağını belirler. "
                    + "Eşikten kısa molalar — kahve almak, tuvalet — oturumu bozmaz."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var notificationFooter: some View {
        if draft.notificationInterval == .off {
            Text("Kapalıyken hiç hatırlatma gelmez; sayaç yine de işler.")
                .foregroundStyle(.secondary)
        } else if coordinator.needsNotificationPermission {
            Label(
                "Bildirim izni yok; İzinler sekmesinden verilene kadar bu ayar etkisiz.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Bulunduğun yerde ne kadar oturduğunu bu aralıkla hatırlatır.")
                .foregroundStyle(.secondary)
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
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
