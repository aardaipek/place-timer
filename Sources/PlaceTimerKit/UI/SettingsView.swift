import PlaceTimerCore
import SwiftUI

/// Ayarlar penceresi.
///
/// Eskiden `TabView`'dı. Kendi penceremizin içinde `TabView` sekmeleri
/// içeriğin tepesine basıyor: üstte pencere başlığı, hemen altında sekme
/// şeridi — iki katlı bir kabuk ve eski System Preferences görüntüsü.
/// (Sekmeleri başlık çubuğuna taşıyan `Settings` sahnesi bu uygulamada
/// çalışmıyor; nedeni `PlaceTimerAppDelegate`'te yazılı.)
///
/// Kenar çubuğu hem bu çift başlığı kaldırıyor hem de bölüm adlarını
/// kısaltmadan gösteriyor: dört simgenin altına sıkışan metinler yerine
/// okunur bir liste. Seçili bölümün adı pencere başlığına da geçiyor.
public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var tab: SettingsTab = .genel

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $tab) { bolum in
                Label(bolum.title, systemImage: bolum.symbol)
                    .tag(bolum)
            }
            .navigationSplitViewColumnWidth(Design.settingsSidebarWidth)
        } detail: {
            pane
                .navigationTitle(tab.title)
                .frame(minWidth: Design.settingsPaneWidth, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
    }

    @ViewBuilder
    private var pane: some View {
        switch tab {
        case .genel: GeneralSettingsView(coordinator: coordinator)
        case .yerler: PlacesSettingsView(coordinator: coordinator)
        case .izinler: PermissionsSettingsView(coordinator: coordinator)
        case .istatistik: StatisticsSettingsView(coordinator: coordinator)
        }
    }
}

#Preview {
    SettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
}
