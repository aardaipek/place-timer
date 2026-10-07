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
                styleChooser
                Toggle("Saniyeleri göster", isOn: $draft.showSeconds)
                Toggle("Yerin adını göster", isOn: $draft.showPlaceNameInMenuBar)
            } header: {
                Text("Menubar")
            } footer: {
                if draft.menuBarStyle == .ring {
                    Text("Halka bulunduğun saatin ne kadarının dolduğunu gösterir; tam saatte yeniden başlar.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Picker("Ara eşiği", selection: $draft.gapThreshold) {
                    ForEach(ThresholdOption.gap) { Text($0.title).tag($0.seconds) }
                }
            } header: {
                Text("Oturum")
            } footer: {
                Text(
                    "Bilgisayardan bu süreden uzun uzak kalırsan oturum, ayrıldığın "
                        + "anda biter. Daha kısa aralar — mutfak, agent'ı beklemek, "
                        + "Wi-Fi kopması — oturumu bozmaz."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    /// Üç görünüm, menubar'daki hâlleriyle yan yana. Anahtarların ne
    /// yaptığını anlatmak yerine gösteriyoruz: kartlardaki görüntü menubar'a
    /// çizilen görüntünün ta kendisi, aynı işlevden üretiliyor.
    private var styleChooser: some View {
        HStack(spacing: Design.small) {
            ForEach(MenuBarStyle.allCases, id: \.self) { style in
                styleCard(style)
            }
        }
        .padding(.vertical, Design.tight)
        .animation(.snappy, value: draft)
    }

    private func styleCard(_ style: MenuBarStyle) -> some View {
        let selected = draft.menuBarStyle == style
        let title = MenuBarTitle.text(
            placeName: coordinator.placeName,
            elapsed: coordinator.elapsed,
            preferences: draft
        )
        let image = MenuBarLabel.image(
            for: title,
            style: style,
            progress: MenuBarStyle.hourProgress(coordinator.elapsed)
        )

        return Button {
            draft.menuBarStyle = style
        } label: {
            VStack(spacing: Design.small) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
                Text(style.displayName)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .padding(Design.small)
            .contentShape(.rect(cornerRadius: 12))
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
