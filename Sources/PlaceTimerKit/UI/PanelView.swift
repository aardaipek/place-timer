import AppKit
import PlaceTimerCore
import SwiftUI

public struct PanelView: View {
    @Bindable var coordinator: AppCoordinator
    @Namespace private var glassNamespace
    @State private var showsControls = false

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let prompt = coordinator.prompt {
                PlacePromptView(prompt: prompt, coordinator: coordinator)
            } else {
                header
                counterAndControls
                if !coordinator.todaySegments.isEmpty { stripCard }
            }
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(PlaceColor.color(for: coordinator.currentPlaceID))
                .frame(width: 8, height: 8)
            Text(coordinator.placeName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.snappy) { showsControls.toggle() }
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.glass)
            .help("Oturum kontrolleri")

            Button {
                PlaceTimerAppDelegate.shared?.presentSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.glass)
            .help("Ayarlar")
        }
    }

    /// Sayaç ve kontroller **tek bir** cam kabında; `⋯` açılınca birbirlerine
    /// dönüşürler. `glassEffectID` eşleşmesi yalnızca aynı kap içinde çalışır —
    /// kontrolleri kabın dışında bırakmak morph'u sessizce iptal ederdi.
    ///
    /// Cam yalnızca üstte yüzen bu katmanlara uygulanıyor; arka plana ya da
    /// liste satırlarına değil.
    private var counterAndControls: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        DurationFormat.clock(
                            coordinator.elapsed,
                            showSeconds: coordinator.preferences.showSeconds
                        )
                    )
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                    Text(altSatir)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .glassEffectID("counter", in: glassNamespace)

                if showsControls { controls }
            }
        }
    }

    private var altSatir: String {
        let aktif = DurationFormat.readable(coordinator.activeSeconds)
        let bugun = DurationFormat.readable(coordinator.todayHereSeconds)
        return "Aktif \(aktif) · Bugün burada \(bugun)"
    }

    private var stripCard: some View {
        DayStripView(segments: coordinator.todaySegments, now: Date())
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("Sayacı sıfırla") { coordinator.endCurrentSession() }
                .buttonStyle(.glass)

            Menu("Yeri değiştir") {
                ForEach(coordinator.knownPlaces) { place in
                    Button(place.displayName) {
                        coordinator.overrideCurrentPlace(place.id)
                    }
                }
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .disabled(coordinator.knownPlaces.isEmpty)
        }
        .glassEffectID("controls", in: glassNamespace)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                Button {
                    PlaceTimerAppDelegate.shared?.presentOnboarding()
                } label: {
                    Label(eksikIzin, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Çıkış") { coordinator.quit() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eksikIzin: String {
        coordinator.needsLocationPermission ? "Konum izni gerekli" : "Bildirim izni gerekli"
    }
}
