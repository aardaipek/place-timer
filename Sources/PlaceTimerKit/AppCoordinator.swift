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
    public private(set) var prompt: PlacePrompt? {
        didSet {
            guard prompt != oldValue else { return }
            onPromptChange?(prompt)
        }
    }

    /// Yeni yer sorusu belirdiğinde/kaybolduğunda tetiklenir. Soruyu kendi
    /// penceresinde gösterebilmek için uygulama katmanına bırakılıyor.
    public var onPromptChange: ((PlacePrompt?) -> Void)?
    public private(set) var needsLocationPermission: Bool = false
    public private(set) var needsNotificationPermission: Bool = false
    public private(set) var preferences = Preferences()
    public private(set) var todaySegments: [DaySegment] = []
    public private(set) var todayHereSeconds: TimeInterval = 0

    public var currentPlaceID: UUID? { engine.currentSession?.placeID }
    public var sessionStartedAt: Date? { engine.currentSession?.startedAt }

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
    private let preferencesStore: JSONFileStore<Preferences>

    private var ticker: Timer?
    private var ticksSinceNetworkCheck = 0
    private var lastWiFi: WiFiSnapshot?
    /// Kullanıcının "şimdilik atla" dediği ağlar; uygulama açık kaldığı
    /// sürece tekrar sorulmaz.
    private var skippedSSIDs: Set<String> = []
    /// Kullanıcının "burası aslında şurası" düzeltmesi; geçerli olduğu sürece
    /// katalog eşleşmesini bastırır.
    private var manualSelection: ManualPlaceSelection?

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
        preferencesStore = JSONFileStore(
            url: base.appendingPathComponent("preferences.json")
        )
    }

    // MARK: - Yaşam döngüsü

    public func start() async {
        catalog = (try? catalogStore.load()) ?? PlaceCatalog()
        history = (try? historyStore.load()) ?? []
        if let saved = try? preferencesStore.load() {
            preferences = saved
        } else {
            // Ilk acilista varsayilanlari diske yaz: dosya gorunur ve elle
            // duzenlenebilir olsun, kullanici hangi ayarlarin var oldugunu
            // acmadan da gorebilsin.
            preferences = Preferences()
            try? preferencesStore.save(preferences)
        }

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
        let restored = SessionEngine.restored(
            from: state,
            configuration: EngineConfiguration(preferences: preferences),
            now: Date()
        )
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

        // Manuel düzeltme, geçerli olduğu sürece katalog eşleşmesini bastırır.
        if let selection = manualSelection {
            if selection.applies(to: snapshot.ssid) {
                apply(.placeResolved(.known(selection.placeID)), at: now)
                return
            }
            manualSelection = nil
        }

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
                persistHistory()
            case .markReached(_, let elapsed, let placeID):
                notifier.notifyMark(
                    elapsed: elapsed,
                    placeName: placeName(for: placeID)
                )
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

    /// Panelden elle yer oluşturur ve oraya geçer.
    ///
    /// Otomatik akışta yer ancak tanınmayan bir ağ görülünce doğuyordu.
    /// Bilgisayar açıldığında henüz hiçbir ağa bağlanmamışsa ya da yanlış bir
    /// ağa bağlanıp o ağ zaten tanınıyorsa kullanıcının elinde hiçbir yol
    /// kalmıyordu: sayaç işliyor ama yeri değiştiremiyordu.
    ///
    /// O anki ağ yeni yere ancak hiçbir yere ait değilse ekleniyor. Aynı SSID
    /// iki yere birden yazılsaydı katalog eşleşmesi hangisini seçeceğini
    /// bilemezdi; o durumda seçim manuel düzeltme olarak, yani ağ değişene
    /// kadar geçerli kalıyor.
    public func createPlaceManually(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let freeSSID = lastWiFi?.ssid.flatMap { candidate in
            catalog.places.contains { $0.ssids.contains(candidate) } ? nil : candidate
        }

        let place = Place(
            ssids: freeSSID.map { [$0] } ?? [],
            bssids: freeSSID == nil ? [] : (lastWiFi?.bssid.map { [$0] } ?? []),
            displayName: trimmed,
            latitude: location.coordinate?.latitude,
            longitude: location.coordinate?.longitude,
            createdAt: Date()
        )
        catalog.add(place)
        if let freeSSID { skippedSSIDs.remove(freeSSID) }
        persistCatalog()
        overrideCurrentPlace(place.id)
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
        catalog.displayName(for: placeID)
    }

    // MARK: - Ayarlar

    public func updatePreferences(_ preferences: Preferences) {
        self.preferences = preferences
        try? preferencesStore.save(preferences)
        engine.updateConfiguration(
            EngineConfiguration(preferences: preferences), at: Date()
        )
        refreshDisplay()
    }

    // MARK: - Manuel kontrol

    /// Sayacı sıfırlar: oturumu kapatıp aynı yerde yenisini başlatır.
    public func endCurrentSession() {
        apply(.endSessionRequested)
        refreshDisplay()
    }

    /// "Burası aslında şurası" düzeltmesi. Seçim, o anki ağa bağlanır ve ağ
    /// değişene kadar otomatik eşleşmeyi bastırır.
    public func overrideCurrentPlace(_ placeID: UUID) {
        manualSelection = ManualPlaceSelection(placeID: placeID, ssid: lastWiFi?.ssid)
        prompt = nil
        apply(.placeResolved(.known(placeID)))
        refreshDisplay()
    }

    // MARK: - Yer yönetimi

    public var knownPlaces: [Place] {
        catalog.places.sorted { $0.displayName < $1.displayName }
    }

    public func renamePlace(_ placeID: UUID, to name: String) {
        catalog.rename(placeID, to: name)
        persistCatalog()
        refreshDisplay()
    }

    public func removePlace(_ placeID: UUID) {
        catalog.remove(placeID)
        if manualSelection?.placeID == placeID { manualSelection = nil }
        persistCatalog()
        refreshDisplay()
    }

    public func detachSSID(_ ssid: String, from placeID: UUID) {
        catalog.detach(ssid: ssid, from: placeID)
        persistCatalog()
        refreshDisplay()
    }

    /// İki yeri birleştirir: kaynağın ağları, geçmişi ve varsa açık oturumu
    /// hedefe geçer, kaynak katalogdan çıkar.
    ///
    /// Katalogdan silmek tek başına yetmezdi: oturumlar hâlâ eski kimliği
    /// tutar ve istatistikte "Silinmiş yer" diye ayrı bir satır olarak
    /// durmaya devam ederdi.
    public func mergePlace(_ source: UUID, into target: UUID) {
        guard source != target,
            catalog.place(id: source) != nil,
            catalog.place(id: target) != nil
        else { return }

        catalog.merge(source, into: target)
        history = SessionHistory.reassign(history, from: source, to: target)
        engine.reassignPlace(from: source, to: target)
        if let selection = manualSelection, selection.placeID == source {
            manualSelection = ManualPlaceSelection(placeID: target, ssid: selection.ssid)
        }

        persistCatalog()
        persistHistory()
        persistState(at: Date())
        refreshDisplay()
    }

    // MARK: - Oturum düzeltmeleri

    /// Aralığa düşen oturumlar, en yenisi başta; açık oturum da dahil.
    public func sessions(for range: StatsRange) -> [Session] {
        sessionsIn(range, from: allSessions, now: Date())
    }

    /// Süren oturum; listede silinemez olarak işaretlenir.
    public var currentSessionID: UUID? { engine.currentSession?.id }

    /// Yanlış açılmış bir oturumu siler.
    ///
    /// Açık oturum silinmiyor: bir sayacı kendi altından çekmek yerine
    /// paneldeki "Sayacı sıfırla" onu kapatıp yenisini açar, kapanan oturum da
    /// listeye düşüp buradan silinebilir.
    public func deleteSession(_ sessionID: UUID) {
        guard engine.currentSession?.id != sessionID else { return }
        history = SessionHistory.remove(sessionID, from: history)
        persistHistory()
        refreshDisplay()
    }

    // MARK: - Gizlilik

    /// Kayıtlı yerleri ve bütün oturum geçmişini siler; sayaç sıfırdan başlar.
    ///
    /// Tercihler kalıyor: onlar kullanıcının nerede olduğunu değil, uygulamayı
    /// nasıl istediğini anlatıyor. Arayüz de bunu böyle söylüyor.
    public func eraseAllData() {
        catalog = PlaceCatalog()
        history = []
        manualSelection = nil
        skippedSSIDs = []
        prompt = nil
        engine = SessionEngine(
            configuration: EngineConfiguration(preferences: preferences)
        )
        apply(.wake)

        persistCatalog()
        persistHistory()
        persistState(at: Date())
        refreshDisplay()
    }

    // MARK: - İstatistik

    public func totals(for range: StatsRange) -> [PlaceTotal] {
        placeTotals(from: allSessions, range: range, now: Date())
    }

    /// Geçmiş ve açık oturum birlikte; istatistik ikisini de saymalı.
    private var allSessions: [Session] {
        guard let current = engine.currentSession else { return history }
        return history + [current]
    }

    // MARK: - Diske yazma ve görüntü

    private func persistCatalog() {
        try? catalogStore.save(catalog)
    }

    private func persistHistory() {
        try? historyStore.save(history)
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

        todaySegments = daySegments(from: allSessions, on: now)
        todayHereSeconds = placeTotals(from: allSessions, range: .today, now: now)
            .first { $0.placeID == engine.currentSession?.placeID }?
            .totalSeconds ?? 0
    }

    public func quit() {
        persistState(at: Date())
        ticker?.invalidate()
        power.stop()
        NSApplication.shared.terminate(nil)
    }
}
