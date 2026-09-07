import PlaceTimerCore
import SwiftUI

struct PlacesSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var selection: UUID?

    /// `HSplitView` yerine `NavigationSplitView`: eskisi `TabView` icinde kendi
    /// ideal yuksekligine buzusup pencerenin altina yapisiyordu ve her iki
    /// sutuna elle `maxHeight: .infinity` vermek gerekiyordu.
    var body: some View {
        NavigationSplitView {
            List(coordinator.knownPlaces, selection: $selection) { place in
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.displayName)
                    Text("\(place.ssids.count) ağ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(place.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            if let place = secili {
                PlaceDetailView(coordinator: coordinator, place: place)
            } else {
                ContentUnavailableView(
                    "Yer seçilmedi",
                    systemImage: "mappin.slash",
                    description: Text("Soldaki listeden bir yer seç.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var secili: Place? {
        coordinator.knownPlaces.first { $0.id == selection }
    }
}

#Preview {
    PlacesSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
}
