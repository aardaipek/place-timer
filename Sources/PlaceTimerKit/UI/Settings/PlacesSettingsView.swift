import PlaceTimerCore
import SwiftUI

/// Kayıtlı yerler.
///
/// Eskiden `NavigationSplitView`'dı. Tercih penceresi genişliğinde iki sütun
/// demek, solda üç beş satırlık bir liste ve sağda çoğu zaman "Yer seçilmedi"
/// yazan boş bir sütun demekti: pencerenin yarısı hiçbir şey göstermiyordu.
/// Bir tercih sekmesinin içine tam bir gezinme yığını koymak ayrıca sekmenin
/// kendi başlık çubuğuyla yarışan ikinci bir kabuk üretiyordu.
///
/// Tek sütun ve satır içinde açılan ayrıntı aynı işi boş alan bırakmadan
/// yapar; seçili olmayan yerler de görünür kalır.
struct PlacesSettingsView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        if coordinator.knownPlaces.isEmpty {
            ContentUnavailableView {
                Label("Kayıtlı yer yok", systemImage: "mappin.slash")
            } description: {
                Text(
                    "Tanımadığı bir Wi-Fi ağına bağlandığında PlaceTimer burayı "
                        + "sorar; verdiğin ad buraya düşer."
                )
            }
        } else {
            Form {
                Section {
                    ForEach(coordinator.knownPlaces) { place in
                        PlaceRowView(coordinator: coordinator, place: place)
                    }
                } header: {
                    Text("Kayıtlı yerler")
                } footer: {
                    Text(
                        "Bir yer birden çok ağ tutabilir: router'lar 2.4 ve 5 GHz "
                            + "bantlarını çoğu zaman ayrı adlarla yayınlar."
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    PlacesSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
