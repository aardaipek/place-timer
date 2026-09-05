import PlaceTimerCore
import SwiftUI

/// `Preferences` alanları için `Binding` üretir.
///
/// Tercihler koordinatörde `private(set)`: her değişiklik `updatePreferences`
/// üzerinden geçmeli ki diske yazılsın ve motorun yapılandırması güncellensin.
/// Doğrudan `@Bindable` kullanmak bu yolu atlardı.
@MainActor
func preferenceBinding<Value>(
    _ coordinator: AppCoordinator,
    _ keyPath: WritableKeyPath<Preferences, Value>
) -> Binding<Value> {
    Binding(
        get: { coordinator.preferences[keyPath: keyPath] },
        set: { newValue in
            var updated = coordinator.preferences
            updated[keyPath: keyPath] = newValue
            coordinator.updatePreferences(updated)
        }
    )
}

public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(coordinator: coordinator)
                .tabItem { Label("Genel", systemImage: "gearshape") }
            PlacesSettingsView(coordinator: coordinator)
                .tabItem { Label("Yerler", systemImage: "mappin.and.ellipse") }
            PermissionsSettingsView(coordinator: coordinator)
                .tabItem { Label("İzinler", systemImage: "lock.shield") }
            StatisticsSettingsView(coordinator: coordinator)
                .tabItem { Label("İstatistik", systemImage: "chart.bar") }
        }
        .frame(width: 540, height: 500)
    }
}
