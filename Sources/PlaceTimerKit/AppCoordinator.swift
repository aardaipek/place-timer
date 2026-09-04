import AppKit
import CoreLocation
import Foundation
import Observation
import PlaceTimerCore

/// Yeni bir ağ görüldüğünde kullanıcıya sorulacak şey.
public enum PlacePrompt: Sendable, Equatable {
    /// Hiç görülmemiş ağ. `suggestions` haritadan gelen mekân adları,
    /// `mergeCandidates` ise yakında olduğu için aynı yer olabilecek kayıtlar.
    case newNetwork(ssid: String, suggestions: [String], mergeCandidates: [Place])
    /// SSID tanıdık ama koordinat uzak — büyük ihtimalle başka bir şube.
    case possibleBranch(ssid: String, existing: Place, suggestions: [String])

    public var ssid: String {
        switch self {
        case .newNetwork(let ssid, _, _): ssid
        case .possibleBranch(let ssid, _, _): ssid
        }
    }
}

/// Uygulamanın tek durum sahibi: motoru, servisleri ve diski birbirine bağlar.
@MainActor
@Observable
public final class AppCoordinator {
    // MARK: Görünen durum

    public private(set) var placeName: String = "Bilinmeyen yer"
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var activeSeconds: TimeInterval = 0
    public private(set) var todaySessions: [Session] = []
    public private(set) var prompt: PlacePrompt?
    public private(set) var needsLocationPermission: Bool = false
    public private(set) var needsNotificationPermission: Bool = false

    public var currentPlaceID: UUID? { engine.currentSession?.placeID }

    // MARK: Bağımlılıklar

    public let location = LocationService()
    private let notifier = Notifier()
    private let power = PowerMonitor()

    private var engine = SessionEngine()
    private var catalog = PlaceCatalog()
    private var history: [Session] = []

    private let catalogStore: JSONFileStore<PlaceCatalog>
    private let historyStore: JSONFileStore<[Session]>
    private let stateStore: JSONFileStore<AppState>

    private var ticker: Timer?
    private var ticksSinceNetworkCheck = 0
    private var lastWiFi: WiFiSnapshot?
    /// Kullanıcının "şimdilik atla" dediği ağlar; uygulama açık kaldığı
    /// sürece tekrar sorulmaz.
    private var skippedSSIDs: Set<String> = []

    /// Ağ kaç tick'te bir yoklanır. Wi-Fi değişimi anlık algılanmak zorunda
    /// değil; 10 saniyelik gecikme oturum sınırlarını gözle görülür biçimde
    /// bozmaz ve CoreWLAN'ı boş yere yormaz.
    private static let networkCheckInterval = 10

    public init(directory: URL? = nil) {
        let base = directory ?? (try? URL.placeTimerSupportDirectory())
            ?? FileManager.default.temporaryDirectory
        catalogStore = JSONFileStore(url: base.appendingPathComponent("places.json"))
        historyStore = JSONFileStore(url: base.appendingPathComponent("sessions.json"))
        stateStore = JSONFileStore(url: base.appendingPathComponent("state.json"))
    }

    // MARK: - Yaşam döngüsü

    public func start() async {
        catalog = (try? catalogStore.load()) ?? PlaceCatalog()
        history = (try? historyStore.load()) ?? []

        location.onAuthorizationChange = { [weak self] _ in
            guard let self else { return }
            refreshPermissionFlags()
            guard location.isAuthorized else { return }
            location.startUpdating()
            // İzin yeni geldi: 10 saniyelik yoklama sırasını bekletmeden
            // yeri hemen çöz, kullanıcı sonucu anında görsün.
            ticksSinceNetworkCheck = Self.networkCheckInterval
        }
        refreshPermissionFlags()
        needsNotificationPermission = await notifier.authorizationStatus() != .authorized

        power.onSleep = { [weak self] in self?.apply(.sleep) }
        power.onWake = { [weak self] in self?.apply(.wake) }
        power.onScreenLocked = { [weak self] in self?.apply(.screenLocked) }
        power.onScreenUnlocked = { [weak self] in self?.apply(.screenUnlocked) }
        power.start()

        if location.isAuthorized { location.startUpdating() }

        let state = (try? stateStore.load()) ?? AppState()
        let restored = SessionEngine.restored(from: state, now: Date())
        engine = restored.engine
        handle(effects: restored.effects)

        startTicking()
        refreshDisplay()
    }

    public func requestLocationPermission() {
        location.requestAuthorization()
    }

    public func requestNotificationPermission() async {
        await notifier.requestAuthorization()
        await refreshPermissions()
    }

    /// İzin durumları uygulama dışında da değişebilir (Sistem Ayarları'ndan),
    /// bu yüzden dışarıdan tazelenebilir olmalı.
    public func refreshPermissions() async {
        needsLocationPermission = !location.isAuthorized
        needsNotificationPermission = await notifier.authorizationStatus() != .authorized
    }

    private func refreshPermissionFlags() {
        needsLocationPermission = !location.isAuthorized
    }

    private func startTicking() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.tick() }
        }
    }

    // MARK: - Saniyelik döngü

    private func tick() {
        let now = Date()
        apply(.tick(idleSeconds: IdleReader.idleSeconds()), at: now)

        ticksSinceNetworkCheck += 1
        if ticksSinceNetworkCheck >= Self.networkCheckInterval {
            ticksSinceNetworkCheck = 0
            checkNetwork(at: now)
            persistState(at: now)
        }
        refreshDisplay(now: now)
    }

    private func checkNetwork(at now: Date) {
        // İzin yoksa CoreWLAN ağ adını gizler; "Wi-Fi yok" ile karışmasın diye
        // bu durumda hiç sorgulamıyoruz.
        guard location.isAuthorized else { return }

        let snapshot = WiFiReader.snapshot()
        defer { lastWiFi = snapshot }

        switch catalog.resolve(ssid: snapshot.ssid, coordinate: location.coordinate) {
        case .matched(let place):
            if let bssid = snapshot.bssid, !place.bssids.contains(bssid) {
                catalog.attach(ssid: snapshot.ssid ?? "", bssid: bssid, to: place.id)
                persistCatalog()
            }
            prompt = nil
            apply(.placeResolved(.known(place.id)), at: now)

        case .noNetwork:
            apply(.placeResolved(.unknown), at: now)

        case .possibleBranch(let existing):
            apply(.placeResolved(.unknown), at: now)
            Task { await askAboutBranch(snapshot: snapshot, existing: existing) }

        case .unknownNetwork(let nearby):
            apply(.placeResolved(.unknown), at: now)
            Task { await askAboutNewNetwork(snapshot: snapshot, nearby: nearby) }
        }
    }

    private func apply(_ event: SessionEvent, at now: Date = Date()) {
        handle(effects: engine.handle(event, at: now))
    }

    private func handle(effects: [SessionEffect]) {
        for effect in effects {
            switch effect {
            case .sessionStarted:
                persistState(at: Date())
            case .sessionEnded(let session):
                history.append(session)
                try? historyStore.save(history)
            case .hourMarkReached(let hours, let placeID):
                let name = placeID.flatMap { catalog.place(id: $0)?.displayName }
                notifier.notifyHourMark(hours: hours, placeName: name ?? "Bilinmeyen yer")
            }
        }
    }

    // MARK: - Yeni yer soruları

    private func askAboutNewNetwork(snapshot: WiFiSnapshot, nearby: [Place]) async {
        guard let ssid = snapshot.ssid, !skippedSSIDs.contains(ssid),
              prompt?.ssid != ssid
        else { return }
        let suggestions = await suggestions()
        prompt = .newNetwork(ssid: ssid, suggestions: suggestions, mergeCandidates: nearby)
    }

    private func askAboutBranch(snapshot: WiFiSnapshot, existing: Place) async {
        guard let ssid = snapshot.ssid, !skippedSSIDs.contains(ssid),
              prompt?.ssid != ssid
        else { return }
        let suggestions = await suggestions()
        prompt = .possibleBranch(ssid: ssid, existing: existing, suggestions: suggestions)
    }

    private func suggestions() async -> [String] {
        guard let coordinate = location.coordinate else { return [] }
        return await location.nearbyPlaceNames(around: coordinate)
    }

    /// Sorulan ağ için yeni bir yer oluşturur.
    public func createPlace(named name: String) {
        guard let prompt else { return }
        let place = Place(
            ssids: [prompt.ssid],
            bssids: lastWiFi?.bssid.map { [$0] } ?? [],
            displayName: name,
            latitude: location.coordinate?.latitude,
            longitude: location.coordinate?.longitude,
            createdAt: Date()
        )
        catalog.add(place)
        persistCatalog()
        self.prompt = nil
        apply(.placeResolved(.known(place.id)))
        refreshDisplay()
    }

    /// Sorulan ağı zaten kayıtlı bir yere ekler (router'ın ikinci bandı gibi).
    public func mergeIntoPlace(_ placeID: UUID) {
        guard let prompt else { return }
        catalog.attach(ssid: prompt.ssid, bssid: lastWiFi?.bssid, to: placeID)
        persistCatalog()
        self.prompt = nil
        apply(.placeResolved(.known(placeID)))
        refreshDisplay()
    }

    public func skipPrompt() {
        guard let prompt else { return }
        skippedSSIDs.insert(prompt.ssid)
        self.prompt = nil
    }

    public func renameCurrentPlace(to name: String) {
        guard let placeID = currentPlaceID else { return }
        catalog.rename(placeID, to: name)
        persistCatalog()
        refreshDisplay()
    }

    public func placeName(for placeID: UUID?) -> String {
        placeID.flatMap { catalog.place(id: $0)?.displayName } ?? "Bilinmeyen yer"
    }

    // MARK: - Diske yazma ve görüntü

    private func persistCatalog() {
        try? catalogStore.save(catalog)
    }

    private func persistState(at now: Date) {
        try? stateStore.save(
            AppState(currentSession: engine.currentSession, lastHeartbeatAt: now)
        )
    }

    private func refreshDisplay(now: Date = Date()) {
        elapsed = engine.elapsed(at: now)
        activeSeconds = engine.activeSeconds
        placeName = placeName(for: engine.currentSession?.placeID)

        let calendar = Calendar.current
        var todays = history.filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
        if let current = engine.currentSession,
           calendar.isDate(current.startedAt, inSameDayAs: now) {
            todays.append(current)
        }
        todaySessions = todays.sorted { $0.startedAt < $1.startedAt }
    }

    public func quit() {
        persistState(at: Date())
        ticker?.invalidate()
        power.stop()
        NSApplication.shared.terminate(nil)
    }
}
