import SwiftUI

/// Eksik izin uyarısı. Yalnızca gerçekten eksik izin varken görünür.
struct PanelPermissionNotice: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        Button(eksikIzin, systemImage: "exclamationmark.triangle.fill", action: openOnboarding)
            .buttonStyle(.borderless)
            .font(.callout)
            .foregroundStyle(.orange)
    }

    private var eksikIzin: String {
        coordinator.needsLocationPermission ? "Konum izni gerekli" : "Bildirim izni gerekli"
    }

    private func openOnboarding() {
        PlaceTimerAppDelegate.shared?.presentOnboarding()
    }
}
