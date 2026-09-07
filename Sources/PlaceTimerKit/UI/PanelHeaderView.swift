import PlaceTimerCore
import SwiftUI

/// Panelin üst satırı: bulunulan yer ve iki kontrol.
///
/// Oturum kontrolleri artık açılıp kapanan bir bölüm değil, gerçek bir menü.
/// Açılır bölümün durumu `@State`'ti ve panel her açılışta yeniden kurulduğu
/// için kullanıcının açık bıraktığı kontroller her seferinde kapanıyordu;
/// ayrıca "Çıkış" panelin dibinde tek başına asılı kalıyordu. Menü ikisini de
/// çözer ve saklanacak bir durum bırakmaz.
struct PanelHeaderView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: Design.small) {
            Circle()
                .fill(PlaceColor.color(for: coordinator.currentPlaceID))
                .frame(width: Design.dotSize, height: Design.dotSize)
                .accessibilityHidden(true)

            Text(coordinator.placeName)
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: Design.small)

            Menu("Oturum kontrolleri", systemImage: "ellipsis") {
                Button("Sayacı sıfırla", action: coordinator.endCurrentSession)

                Menu("Yeri değiştir") {
                    ForEach(coordinator.knownPlaces) { place in
                        Button(place.displayName) { changePlace(to: place) }
                    }
                }
                .disabled(coordinator.knownPlaces.isEmpty)

                Divider()

                Button("Çıkış", action: coordinator.quit)
            }
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .buttonStyle(.glass)
            .menuIndicator(.hidden)
            .fixedSize()

            Button("Ayarlar", systemImage: "gearshape", action: openSettings)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
    }

    private func changePlace(to place: Place) {
        coordinator.overrideCurrentPlace(place.id)
    }

    private func openSettings() {
        PlaceTimerAppDelegate.shared?.presentSettings()
    }
}

#Preview {
    PanelHeaderView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .padding()
        .frame(width: Design.panelWidth)
}
