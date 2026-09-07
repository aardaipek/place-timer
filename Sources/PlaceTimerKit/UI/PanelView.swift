import PlaceTimerCore
import SwiftUI

/// Menubar paneli.
///
/// Panelin kendisi zaten bir kart; içindeki her bölümü ayrıca yuvarlatılmış
/// bir kutuya koymak hiyerarşiyi yok ediyordu — üç iç içe kart, üçü de aynı
/// yarıçapta ve aynı dolguda, hiçbiri diğerinden önemli görünmüyordu.
/// Bölümler artık yalnızca boşlukla ayrılıyor. Cam da yalnızca gerçekten
/// yüzen şeyde, yani üstteki düğmelerde kaldı: düz zemine oturan statik bir
/// metin bloğunun arkasında kıracak bir şey olmadığı için `glassEffect` orada
/// yalnızca gri bir kutu üretiyordu.
public struct PanelView: View {
    @Bindable var coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Design.large) {
                if let prompt = coordinator.prompt {
                    PlacePromptView(prompt: prompt, coordinator: coordinator)
                } else {
                    PanelHeaderView(coordinator: coordinator)
                    PanelSummaryView(coordinator: coordinator)
                }

                if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                    PanelPermissionNotice(coordinator: coordinator)
                }
            }
            .padding(Design.large)

            // Şerit panelin tabanında uçtan uca durur; bu yüzden üstteki
            // yatay dolgunun dışında kalıyor.
            if coordinator.prompt == nil, coordinator.todaySegments.count > 1 {
                DayStripView(segments: coordinator.todaySegments, now: Date())
                    .padding(.bottom, Design.large)
            }
        }
        .frame(width: Design.panelWidth)
    }
}

#Preview {
    PanelView(coordinator: AppCoordinator(directory: .temporaryDirectory))
}
