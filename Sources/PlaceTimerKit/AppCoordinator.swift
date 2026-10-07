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
    public private(set) var canUndo = false
    public private(set) var suggestions: [Suggestion] = []
    public private(set) var todayTotalSeconds: TimeInterval = 0
    /// Bugün kaç farklı yerde bulunuldu; tek yerse panel "Bugün burada"yı
    /// "Bugün toplam"ın tekrarı olarak göstermez.
    public private(set) var placesTodayCount: Int = 0

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
    private let suggestionStore: JSONFileStore<SuggestionState>
    private var suggestionState = SuggestionState()

    private var ticker: Timer?
    private var ticksSinceNetworkCheck = 0
    private var lastWiFi: WiFiSnapshot?
    /// Kullanıcının "şimdilik atla" dediği ağlar; uygulama açık kaldığı
    /// sürece tekrar sorulmaz.
    private var skippedSSIDs: Set<String> = []
    /// Kullanıcının "burası aslında şurası" düzeltmesi; geçerli olduğu sürece
    /// katalog eşleşmesini bastırır.
    private var manualSelection: ManualPlaceSelection?

    /// Son elle düzeltmeden önceki hâl. Tek adımlık geri alma yeterli: kullanıcı
    /// bir şeyi yanlış birleştirdiğinde hemen fark eder.
    private var undoSnapshot: (history: [Session], current: Session?)?

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
        suggestionStore = JSONFileStore(url: base.appendingPathComponent("suggestions.json"))
    }

    // MARK: - Yaşam döngüsü

    public func start() async {
        catalog = (try? catalogStore.load()) ?? PlaceCatalog()
        history = (try? historyStore.load()) ?? []
        suggestionState = (try? suggestionStore.load()) ?? SuggestionState()
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
        refreshSuggestions()
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
        // Motor oturumu kendisi değiştirdiyse eski anlık görüntü geçersiz.
        let changesSessions = effects.contains { effect in
            if case .markReached = effect { return false }
            return true
        }
        if changesSessions {
            undoSnapshot = nil
            canUndo = false
        }
        for effect in effects {
            switch effect {
            case .sessionStarted:
                persistState(at: Date())
            case .sessionEnded(let session):
                history.append(session)
                persistHistory()
                refreshSuggestions()
            case .sessionResumed(_, let replacing):
                history.removeAll { replacing.contains($0.id) }
                persistHistory()
                persistState(at: Date())
                refreshSuggestions()
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
        apply(.placeChosen(place.id))
        refreshDisplay()
        refreshSuggestions()
    }

    /// Sorulan ağı zaten kayıtlı bir yere ekler (router'ın ikinci bandı gibi).
    public func mergeIntoPlace(_ placeID: UUID) {
        guard let prompt else { return }
        catalog.attach(ssid: prompt.ssid, bssid: lastWiFi?.bssid, to: placeID)
        persistCatalog()
        self.prompt = nil
        apply(.placeChosen(placeID))
        refreshDisplay()
        refreshSuggestions()
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
        refreshSuggestions()
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
        refreshSuggestions()
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
        apply(.placeChosen(placeID))
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
        refreshSuggestions()
    }

    public func removePlace(_ placeID: UUID) {
        catalog.remove(placeID)
        if manualSelection?.placeID == placeID { manualSelection = nil }
        persistCatalog()
        refreshDisplay()
        refreshSuggestions()
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
        refreshSuggestions()
    }

    // MARK: - Oturum düzeltmeleri

    /// Süren oturum; listede silinemez olarak işaretlenir.
    public var currentSessionID: UUID? { engine.currentSession?.id }

    public func session(id: UUID) -> Session? {
        allSessions.first { $0.id == id }
    }

    public func previousSession(of id: UUID) -> Session? {
        SessionHistory.previous(of: id, in: allSessions)
    }

    /// Yanlış açılmış oturumları siler. Açık oturum silinmez: paneldeki
    /// "Sayacı sıfırla" onu kapatıp yenisini açar.
    public func deleteSessions(_ ids: Set<UUID>) {
        let removable = ids.subtracting([engine.currentSession?.id].compactMap { $0 })
        guard !removable.isEmpty else { return }
        recordUndo()
        history.removeAll { removable.contains($0.id) }
        commitHistoryEdit()
    }

    public func deleteSession(_ id: UUID) {
        deleteSessions([id])
    }

    @discardableResult
    public func mergeSessions(_ ids: Set<UUID>) -> SessionHistory.EditError? {
        switch SessionHistory.merge(ids, in: allSessions) {
        case .failure(let error):
            return error
        case .success(let merged):
            recordUndo()
            apply(edited: merged)
            return nil
        }
    }

    @discardableResult
    public func mergeWithPrevious(_ id: UUID) -> SessionHistory.EditError? {
        guard let previous = previousSession(of: id) else { return .tooFew }
        return mergeSessions([previous.id, id])
    }

    public func validateEdit(_ session: Session) -> SessionHistory.EditError? {
        if case .failure(let error) = SessionHistory.update(session, in: allSessions, now: Date()) {
            return error
        }
        return nil
    }

    @discardableResult
    public func updateSession(_ session: Session) -> SessionHistory.EditError? {
        switch SessionHistory.update(session, in: allSessions, now: Date()) {
        case .failure(let error):
            return error
        case .success(let updated):
            recordUndo()
            apply(edited: updated)
            return nil
        }
    }

    public func undoLastEdit() {
        guard let snapshot = undoSnapshot else { return }
        history = snapshot.history
        if let current = snapshot.current { engine.replaceCurrentSession(current) }
        undoSnapshot = nil
        canUndo = false
        commitHistoryEdit()
    }

    private func recordUndo() {
        undoSnapshot = (history, engine.currentSession)
        canUndo = true
    }

    /// Düzeltilmiş tam listeyi (geçmiş + açık oturum) geri dağıtır.
    private func apply(edited sessions: [Session]) {
        if let open = sessions.first(where: { $0.endedAt == nil }) {
            engine.replaceCurrentSession(open)
        }
        history = sessions.filter { $0.endedAt != nil }
        commitHistoryEdit()
    }

    private func commitHistoryEdit() {
        engine.forgetRecent()
        persistHistory()
        persistState(at: Date())
        refreshDisplay()
        refreshSuggestions()
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
        suggestionState = SuggestionState()
        engine = SessionEngine(
            configuration: EngineConfiguration(preferences: preferences)
        )
        apply(.wake)

        persistCatalog()
        persistHistory()
        persistState(at: Date())
        persistSuggestionState()
        refreshSuggestions()
        refreshDisplay()
    }

    // MARK: - İstatistik

    public func totals(in period: StatsPeriod) -> [PlaceTotal] {
        placeTotals(from: allSessions, in: period, now: Date())
    }

    public func totalSeconds(in period: StatsPeriod) -> TimeInterval {
        PlaceTimerCore.totalSeconds(from: allSessions, in: period.interval, now: Date())
    }

    public func previousTotalSeconds(for period: StatsPeriod) -> TimeInterval {
        previousComparableTotal(from: allSessions, for: period, now: Date())
    }

    public func dailyTotals(in period: StatsPeriod) -> [DayTotal] {
        PlaceTimerCore.dailyTotals(from: allSessions, in: period, now: Date())
    }

    public func sessionDays(in period: StatsPeriod) -> [SessionDay] {
        PlaceTimerCore.sessionDays(from: allSessions, in: period, now: Date())
    }

    public func segments(on day: Date) -> [DaySegment] {
        daySegments(from: allSessions, on: day, now: Date())
    }

    public func csv(in period: StatsPeriod) -> String {
        sessionsCSV(allSessions, in: period, now: Date()) { placeName(for: $0) }
    }

    /// Geçmiş ve açık oturum birlikte; istatistik ikisini de saymalı.
    private var allSessions: [Session] {
        guard let current = engine.currentSession else { return history }
        return history + [current]
    }

    // MARK: - Öneriler

    /// Kullanıcı aynı türden aralığı üç kez birleştirdiyse ve eşik 1 saatin
    /// altındaysa, ara eşiğini büyütmeyi önermek mantıklı.
    public var offersLongerGap: Bool {
        suggestionState.acceptedSplits >= 3 && preferences.gapThreshold < 3600
    }

    public func apply(_ suggestion: Suggestion) {
        switch suggestion {
        case .samePlace(let keep, let merge):
            mergePlace(merge, into: keep)
        case .splitSession(let first, let second):
            if mergeSessions([first, second]) == nil {
                suggestionState.acceptedSplits += 1
            } else {
                // Artık uygulanamıyor (arada başka oturum oluştu): bir daha sorma.
                suggestionState.dismissed.insert(suggestion.id)
            }
        case .emptySession(let id):
            deleteSession(id)
        }
        persistSuggestionState()
        refreshSuggestions()
    }

    public func dismiss(_ suggestion: Suggestion) {
        suggestionState.dismissed.insert(suggestion.id)
        persistSuggestionState()
        refreshSuggestions()
    }

    public func applyAllSuggestions() {
        // Her uygulama listeyi yeniden kurar; sınır, uygulanamayan bir öneride
        // sonsuz döngüye karşı.
        for _ in 0..<200 {
            guard let next = suggestions.first else { break }
            apply(next)
        }
    }

    public func adoptLongerGap() {
        var updated = preferences
        updated.gapThreshold = 3600
        suggestionState.acceptedSplits = 0
        persistSuggestionState()
        updatePreferences(updated)
    }

    private func refreshSuggestions() {
        suggestions = PlaceTimerCore.suggestions(
            places: catalog.places,
            sessions: allSessions,
            dismissed: suggestionState.dismissed,
            gapThreshold: preferences.gapThreshold
        )
    }

    private func persistSuggestionState() {
        try? suggestionStore.save(suggestionState)
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
            AppState(
                currentSession: engine.currentSession,
                lastHeartbeatAt: now,
                recentlyEnded: engine.recentlyEnded
            )
        )
    }

    private func refreshDisplay(now: Date = Date()) {
        elapsed = engine.elapsed(at: now)
        placeName = placeName(for: engine.currentSession?.placeID)

        let today = StatsPeriod.containing(now, scope: .day)
        let todayTotals = placeTotals(from: allSessions, in: today, now: now)
        todaySegments = daySegments(from: allSessions, on: now, now: now)
        todayTotalSeconds = todayTotals.reduce(0) { $0 + $1.totalSeconds }
        placesTodayCount = todayTotals.count
        todayHereSeconds = todayTotals
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
