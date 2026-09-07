import PlaceTimerCore
import SwiftUI

public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var tab: SettingsTab = .genel

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView(selection: $tab) {
            Tab("Genel", systemImage: "gearshape", value: SettingsTab.genel) {
                GeneralSettingsView(coordinator: coordinator)
            }
            Tab("Yerler", systemImage: "mappin.and.ellipse", value: SettingsTab.yerler) {
                PlacesSettingsView(coordinator: coordinator)
            }
            Tab("İzinler", systemImage: "lock.shield", value: SettingsTab.izinler) {
                PermissionsSettingsView(coordinator: coordinator)
            }
            Tab("İstatistik", systemImage: "chart.bar", value: SettingsTab.istatistik) {
                StatisticsSettingsView(coordinator: coordinator)
            }
        }
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
    }
}

#Preview {
    SettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
}
