import PlaceTimerCore
import SwiftUI

/// Ayarlar penceresi.
///
/// Sistemin kenar çubuğu (`NavigationSplitView`): macOS 26'da yüzen cam panel,
/// pencere düğmeleri içinde, seçim vurgusu ve klavye gezinmesi sistemden.
/// Kendi çizdiğimiz kabuk denendi; ne cam paneli ne de düğmelerin yerini
/// sistemle tutturabildi, ayrı bir kart gibi duruyordu.
///
/// Pencerenin boyu bölümden bölüme değişmesin diye araç çubuğu sabit:
/// `AppWindow` her zaman boş bir araç çubuğu kuruyor ve SwiftUI'nin araç
/// çubuğu köprüsü kapalı. Eskiden yalnızca İstatistik araç çubuğuna düğme
/// koyuyordu; araç çubuğu yalnızca o bölümde var olduğu için pencere 20 punto
/// uzuyor, kapatma düğmeleri 10 punto kayıyordu (ölçüldü). Bölümlerin kendi
/// kontrolleri bu yüzden içerikte.
public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var tab: SettingsTab = .genel
    @State private var stats = StatsNavigation()

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        // Görünürlük sabit: araç çubuğu köprüsü kapalıyken split view kenar
        // çubuğunu kendiliğinden daraltıyordu (ölçüldü, sütun ağaçta yoktu).
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsTab.allCases, selection: $tab) { bolum in
                Label {
                    Text(bolum.title)
                } icon: {
                    SettingsIcon(tab: bolum)
                }
                .tag(bolum)
            }
            .navigationSplitViewColumnWidth(
                min: Design.settingsSidebarWidth,
                ideal: Design.settingsSidebarWidth,
                max: Design.settingsSidebarWidth
            )
            .frame(minWidth: Design.settingsSidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            pane
                .navigationTitle(tab.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Sabit `frame` yok: pencerenin boyunu `AppWindow` koyuyor. Görünüm
        // kendine 560 punto ayırınca split view başlık çubuğunun payını
        // üstüne ekleyip 593'e çıkıyor, altı pencereden taşıyordu (ölçüldü).
        .onChange(of: coordinator.requestedSettingsTab, initial: true) { _, istenen in
            guard let istenen else { return }
            tab = istenen
            coordinator.requestedSettingsTab = nil
        }
    }

    @ViewBuilder
    private var pane: some View {
        switch tab {
        case .genel: GeneralSettingsView(coordinator: coordinator)
        case .yerler: PlacesSettingsView(coordinator: coordinator)
        case .izinler: PermissionsSettingsView(coordinator: coordinator)
        case .istatistik: StatisticsSettingsView(coordinator: coordinator, navigation: stats)
        case .hakkinda: AboutSettingsView(coordinator: coordinator)
        }
    }
}

/// Sistem Ayarları'ndaki gibi renkli kare içinde simge.
private struct SettingsIcon: View {
    let tab: SettingsTab

    var body: some View {
        Image(systemName: tab.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(tab.tint.gradient, in: .rect(cornerRadius: 5))
    }
}

#Preview {
    SettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
}
