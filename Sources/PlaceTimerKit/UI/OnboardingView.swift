import CoreLocation
import SwiftUI

/// Karşılama sihirbazı: izinleri tek tek, sırayla ister.
///
/// İzinleri aynı anda istemek diyaloglardan birinin bastırılmasına yol
/// açıyordu; ayrıca izin bir kez reddedildiğinde macOS diyaloğu hiç
/// göstermiyor, o yüzden her adımda Sistem Ayarları'na çıkış var.
public struct OnboardingView: View {
    @Bindable var coordinator: AppCoordinator
    let onFinish: () -> Void

    @State private var step: Step = .location
    @State private var didRequest: Set<Step> = []
    @State private var launchesAtLogin = LoginItem.isEnabled

    public init(coordinator: AppCoordinator, onFinish: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onFinish = onFinish
    }

    enum Step: Int, CaseIterable {
        case location = 1, notifications, launchAtLogin, done

        var title: String {
            switch self {
            case .location: "Konum izni"
            case .notifications: "Bildirim izni"
            case .launchAtLogin: "Açılışta başlat"
            case .done: "Hazır"
            }
        }

        var detail: String {
            switch self {
            case .location:
                "macOS, bağlı olduğun Wi-Fi ağının adını yalnızca bu izinle "
                    + "veriyor. Bulunduğun yeri tanımanın tek yolu bu — izin "
                    + "olmadan uygulama hiçbir şey sayamaz."
            case .notifications:
                "Bir yerde her saat dolduğunda kısa bir bildirim gönderir. "
                    + "Kalkma vaktini kaçırmamak için."
            case .launchAtLogin:
                "Bilgisayarı açtığın anda sayması için uygulamanın kendiliğinden "
                    + "başlaması gerekiyor."
            case .done:
                "Her şey hazır. Menubar'daki saate tıklayarak panele "
                    + "ulaşabilirsin."
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading
            stepCard
            Spacer(minLength: 0)
            controls
        }
        .padding(28)
        .frame(width: 460, height: 340)
        .task { await advanceIfSatisfied() }
        // İzin durumu uygulama dışında da değişebilir (Sistem Ayarları'ndan);
        // pencere açıkken düzenli olarak yeniden bakıyoruz.
        .task(id: step) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await coordinator.refreshPermissions()
                launchesAtLogin = LoginItem.isEnabled
                await advanceIfSatisfied()
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PlaceTimer")
                    .font(.largeTitle.weight(.light))
                Text("Nerede ne kadar oturduğunu kendiliğinden takip eder.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if step != .done {
                Text("Adım \(step.rawValue)/3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isSatisfied(step) ? "checkmark.circle.fill" : icon(step))
                    .foregroundStyle(isSatisfied(step) ? .green : .accentColor)
                    .font(.title2)
                Text(step.title).font(.title3.weight(.medium))
            }
            Text(step.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if step != .done {
                HStack(spacing: 10) {
                    Button(primaryTitle) { performPrimaryAction() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSatisfied(step))

                    if didRequest.contains(step) && !isSatisfied(step) {
                        Button("Sistem Ayarları'nı aç") {
                            SystemSettings.open(settingsPane(for: step))
                        }
                    }
                }
                if didRequest.contains(step) && !isSatisfied(step) {
                    Text(fallbackHint)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var controls: some View {
        HStack {
            if step != .location && step != .done {
                Button("Geri") { step = Step(rawValue: step.rawValue - 1) ?? .location }
                    .buttonStyle(.borderless)
            }
            Spacer()
            if step == .done {
                Button("Bitti") { onFinish() }
                    .buttonStyle(.borderedProminent)
            } else if isSatisfied(step) {
                Button("Devam") { goToNextStep() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Bu adımı atla") { goToNextStep() }
                    .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Adım mantığı

    private func isSatisfied(_ step: Step) -> Bool {
        switch step {
        case .location: !coordinator.needsLocationPermission
        case .notifications: !coordinator.needsNotificationPermission
        case .launchAtLogin: launchesAtLogin
        case .done: true
        }
    }

    private func icon(_ step: Step) -> String {
        switch step {
        case .location: "location.circle"
        case .notifications: "bell.circle"
        case .launchAtLogin: "power.circle"
        case .done: "checkmark.circle"
        }
    }

    private func settingsPane(for step: Step) -> SystemSettings.Pane {
        switch step {
        case .location: .locationServices
        case .notifications: .notifications
        default: .loginItems
        }
    }

    private var primaryTitle: String {
        switch step {
        case .location: "Konum iznini iste"
        case .notifications: "Bildirim iznini iste"
        case .launchAtLogin: "Açılışta başlat"
        case .done: ""
        }
    }

    private var fallbackHint: String {
        switch step {
        case .location:
            "Diyalog çıkmadıysa izin daha önce reddedilmiş olabilir. "
                + "Gizlilik ve Güvenlik › Konum Servisleri listesinden "
                + "PlaceTimer'ı işaretle."
        case .notifications:
            "Bildirimler listesinden PlaceTimer'ı bulup uyarılara izin ver."
        default:
            "Genel › Giriş Öğeleri listesinden PlaceTimer'ı aç."
        }
    }

    private func performPrimaryAction() {
        didRequest.insert(step)
        switch step {
        case .location:
            coordinator.requestLocationPermission()
        case .notifications:
            Task { await coordinator.requestNotificationPermission() }
        case .launchAtLogin:
            LoginItem.enable()
            launchesAtLogin = LoginItem.isEnabled
        case .done:
            break
        }
    }

    private func goToNextStep() {
        step = Step(rawValue: step.rawValue + 1) ?? .done
    }

    private func advanceIfSatisfied() async {
        guard step != .done, isSatisfied(step) else { return }
        // Yalnızca kullanıcı o adımı bizzat tetiklediyse kendiliğinden ilerle;
        // zaten verilmiş izinler yüzünden ekranı atlamak kafa karıştırır.
        guard didRequest.contains(step) else { return }
        try? await Task.sleep(for: .milliseconds(600))
        goToNextStep()
    }
}
