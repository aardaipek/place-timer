import AppKit
import PlaceTimerCore
import SwiftUI

/// Ayarlar penceresi.
///
/// Önce `TabView`, sonra `NavigationSplitView` + pencere araç çubuğuydu. İkisi
/// de bölümler arasında kabuğu oynatıyordu: İstatistik araç çubuğuna kendi
/// düğmelerini koyunca başlık çubuğu yalnızca o bölümde kalınlaşıyor, kapatma
/// düğmeleri büyüyüp yer değiştiriyor, içerik aşağı kayıyordu. Araç çubuğu
/// içeriğe göre değişen bir şey; sabit kalması gereken kabuğu ona bağlamak
/// her bölüm geçişini bir yeniden yerleşime çeviriyordu.
///
/// Şimdi kabuğun tamamı bizim: pencerede araç çubuğu yok, ölçü sabit. Kenar
/// çubuğu yüzen bir cam panel, sağda sabit yükseklikte bir başlık. Bölümün
/// kendi kontrolleri (istatistiğin dönem seçimi) başlığın sağındaki yuvaya
/// oturuyor; yuva boşken de aynı yükseklikte. Geçişte değişen tek şey içerik.
public struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var tab: SettingsTab = .genel
    @State private var stats = StatsNavigation()
    @Namespace private var selectionNamespace

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                pane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(tab)
                    .transition(.opacity)
            }
            .frame(width: Design.settingsPaneWidth)
        }
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
        .background(.background)
        .ignoresSafeArea()
        .animation(.snappy(duration: 0.2), value: tab)
        .onChange(of: coordinator.requestedSettingsTab, initial: true) { _, istenen in
            guard let istenen else { return }
            tab = istenen
            coordinator.requestedSettingsTab = nil
        }
    }

    // MARK: - Kenar çubuğu

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Design.tight) {
            // Pencere düğmeleri bu boşluğun üstünde duruyor.
            Color.clear.frame(height: Design.settingsTitlebarInset)

            appBadge
                .padding(.horizontal, Design.small)
                .padding(.bottom, Design.medium)

            ForEach(SettingsTab.allCases) { bolum in
                sidebarRow(bolum)
            }

            Spacer(minLength: 0)

            Text("Sürüm \(version)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Design.small)
        }
        .padding(Design.small)
        .frame(width: Design.settingsSidebarWidth - Design.small * 2, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        // Cam, altında hafif bir zemin ve ince bir kenarla: koyu temada cam
        // pencere zeminiyle neredeyse aynı tonda kalıp kayboluyordu.
        .background(.primary.opacity(0.04), in: .rect(cornerRadius: Design.settingsSidebarRadius))
        .glassEffect(.regular, in: .rect(cornerRadius: Design.settingsSidebarRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Design.settingsSidebarRadius)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .padding(Design.small)
    }

    private var appBadge: some View {
        HStack(spacing: Design.small) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("PlaceTimer")
                    .font(.headline)
                Text("Bugün \(DurationFormat.readable(coordinator.todayTotalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func sidebarRow(_ bolum: SettingsTab) -> some View {
        let selected = bolum == tab
        return Button {
            tab = bolum
        } label: {
            HStack(spacing: Design.small) {
                Image(systemName: bolum.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(bolum.tint.gradient, in: .rect(cornerRadius: 6))
                Text(bolum.title)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Design.small)
            .frame(height: 32)
            .contentShape(.rect)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.08))
                        .matchedGeometryEffect(id: "secim", in: selectionNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(bolum.shortcut, modifiers: .command)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Başlık

    /// Yüksekliği sabit; istatistiğin kontrolleri yokken de aynı. İçerik bu
    /// sayede bölümler arasında bir punto bile kaymıyor.
    private var header: some View {
        HStack(spacing: Design.medium) {
            Text(tab.title)
                .font(.title2.weight(.semibold))
                .contentTransition(.opacity)
            Spacer(minLength: Design.small)
            if tab == .istatistik {
                StatsHeaderControls(navigation: stats, coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Design.large)
        .padding(.bottom, Design.small)
        .frame(height: Design.settingsHeaderHeight, alignment: .bottom)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
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

#Preview {
    SettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
}
