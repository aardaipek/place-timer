import Foundation

/// Oturum durum makinesi.
///
/// Bilinçli olarak hiçbir sistem API'sine dokunmaz: girdileri sade
/// `SessionEvent` değerleri, zaman ise her çağrıya dışarıdan geçirilen bir
/// `Date`'tir. Böylece "90 dakika uyuyup uyandı" gibi senaryolar gerçek zaman
/// beklenmeden test edilebilir.
///
/// Tek kural ara kuralı: uyku, ekranın kararması, kilit ve dokunmamak aynı
/// şeydir. Ara eşikten kısaysa oturum sürer ve ara süreye dahildir; uzunsa
/// oturum aranın başladığı anda kapanır. Agent çalışırken mutfağa giden
/// kullanıcı bilgisayarın başında değildir ama işin içindedir.
public struct SessionEngine: Sendable {
    public private(set) var currentSession: Session?
    /// Son kapanan en fazla iki oturum, eskisi başta. Aynı yere eşik içinde
    /// dönüldüğünde geri açmanın dayanağı; uygulama yeniden başlasa da
    /// çalışsın diye `AppState`'e yazılır.
    public private(set) var recentlyEnded: [Session]
    public private(set) var currentPlace: PlaceRef
    public private(set) var isAsleep: Bool

    public private(set) var configuration: EngineConfiguration

    private var sleepStartedAt: Date?
    /// Uyandıktan sonraki ilk yer çözümlemesine kadar taşınır. Yer uyku
    /// sırasında değiştiyse eski oturum uyanma anında değil, uykuya dalma
    /// anında kapanmalı — yoksa yolda geçen süre yeni yerin hanesine yazılır.
    private var pendingSleepStart: Date?
    /// Uyanık bir Mac'te kullanıcı ara eşiğinden uzun süre dokunmadığı için
    /// oturum kapandı; ilk girdide yeni oturum açılacak.
    private var isAway = false

    /// Kararlılık süresi dolmamış bir yer değişimi adayı.
    private struct PendingPlace: Sendable {
        let placeID: UUID
        let firstSeenAt: Date
    }

    private var pendingPlace: PendingPlace?

    /// - Parameters:
    ///   - restoring: Diskten okunan açık oturum. Uygulama çökse veya
    ///     güncellense bile oturum kaldığı yerden devam eder.
    ///   - recentlyEnded: Diskten okunan son kapanan oturumlar.
    public init(
        configuration: EngineConfiguration = EngineConfiguration(),
        restoring session: Session? = nil,
        recentlyEnded: [Session] = []
    ) {
        self.configuration = configuration
        self.currentSession = session
        self.recentlyEnded = recentlyEnded
        self.currentPlace = session?.placeID.map { PlaceRef.known($0) } ?? .unknown
        self.isAsleep = false
    }

    /// Oturumun o yerde geçirdiği duvar saati süresi.
    public func elapsed(at now: Date) -> TimeInterval {
        currentSession?.elapsed(at: now) ?? 0
    }

    /// Ayarlar değişince yapılandırmayı, açık oturumu bozmadan günceller.
    ///
    /// Bildirim aralığı değişirse geçmiş işaretler dolu sayılır. Aksi halde
    /// saatlikten 30 dakikalığa geçildiğinde o ana kadar birikmiş bütün
    /// bildirimler topluca düşerdi.
    public mutating func updateConfiguration(
        _ configuration: EngineConfiguration,
        at now: Date
    ) {
        let previousInterval = self.configuration.notificationInterval
        self.configuration = configuration

        guard
            configuration.notificationInterval != previousInterval,
            let interval = configuration.notificationInterval, interval > 0,
            var session = currentSession
        else { return }

        let passed = Int(session.elapsed(at: now) / interval)
        session.notifiedMarks = passed >= 1 ? Set(1...passed) : []
        currentSession = session
    }

    @discardableResult
    public mutating func handle(_ event: SessionEvent, at now: Date) -> [SessionEffect] {
        switch event {
        case .wake:
            handleWake(at: now)
        case .sleep:
            handleSleep(at: now)
        case .placeResolved(let place):
            handlePlaceResolved(place, immediate: false, at: now)
        case .placeChosen(let placeID):
            handlePlaceResolved(.known(placeID), immediate: true, at: now)
        case .tick(let idleSeconds):
            handleTick(idleSeconds: idleSeconds, at: now)
        case .endSessionRequested:
            handleEndSessionRequested(at: now)
        }
    }

    // MARK: - Olay işleyicileri

    /// İki yer birleştirildiğinde açık oturumun yer kimliğini taşır.
    ///
    /// `placeResolved` göndermek işe yaramaz: motor onu gerçek bir yer
    /// değişimi sayıp oturumu kapatır. Oysa kullanıcı hiçbir yere gitmedi,
    /// yalnızca iki kaydın aynı yer olduğunu söyledi.
    public mutating func reassignPlace(from source: UUID, to target: UUID) {
        guard source != target else { return }
        if currentSession?.placeID == source { currentSession?.placeID = target }
        if currentPlace == .known(source) { currentPlace = .known(target) }
        for index in recentlyEnded.indices where recentlyEnded[index].placeID == source {
            recentlyEnded[index].placeID = target
        }
    }

    /// Geçmiş elle değiştirildi (silme, birleştirme, düzenleme): motorun
    /// elindeki kopyalar artık güvenilir değil. Silinmiş bir oturumun aynı yere
    /// dönüşte hortlamaması için unutulur.
    public mutating func forgetRecent() {
        recentlyEnded.removeAll()
    }

    /// Açık oturumu elle düzeltilmiş hâliyle değiştirir (birleştirme, saat
    /// düzeltme, geri alma). Son kapananlar da unutulur.
    public mutating func replaceCurrentSession(_ session: Session) {
        currentSession = session
        recentlyEnded.removeAll()
    }

    private mutating func handleWake(at now: Date) -> [SessionEffect] {
        isAsleep = false
        isAway = false

        guard let sleptAt = sleepStartedAt else {
            // Uykudan değil, soğuk başlangıçtan geliyoruz.
            return currentSession == nil ? startSession(at: now) : []
        }
        sleepStartedAt = nil

        if now.timeIntervalSince(sleptAt) > configuration.gapThreshold {
            var effects = endSession(at: sleptAt)
            effects += startSession(at: now)
            return effects
        }

        // Kısa ara: oturum sürüyor, ama yerin değişmediğini henüz bilmiyoruz.
        pendingSleepStart = sleptAt
        return currentSession == nil ? startSession(at: now) : []
    }

    /// Oturumu kapatıp aynı yerde hemen yenisini açar.
    ///
    /// Takibi büsbütün durdurmuyoruz: otomatik bir takipçinin izlemeyi
    /// bırakması tuhaf olurdu. Amaç yanlış başlamış bir sayacı düzeltmek.
    private mutating func handleEndSessionRequested(at now: Date) -> [SessionEffect] {
        guard currentSession != nil else { return [] }
        var effects = endSession(at: now)
        // Kullanıcı açıkça bitirdi: bu oturum geri açılmamalı.
        recentlyEnded.removeAll()
        effects += startSession(at: now)
        return effects
    }

    /// Art arda gelen uyku bildirimlerinde ilk an korunur: ara en erken
    /// başladığı yerden ölçülür.
    private mutating func handleSleep(at now: Date) -> [SessionEffect] {
        isAsleep = true
        if sleepStartedAt == nil { sleepStartedAt = now }
        pendingSleepStart = nil
        pendingPlace = nil
        return []
    }

    private mutating func handlePlaceResolved(
        _ place: PlaceRef,
        immediate: Bool,
        at now: Date
    ) -> [SessionEffect] {
        // Uykudan yeni uyanıldı: yer değiştiyse oturum uykuya dalma anında biter.
        let closeAtSleep = pendingSleepStart
        pendingSleepStart = nil

        switch place {
        case .unknown:
            // Wi-Fi düştü ya da hiç yok. Oturum kapanmaz, yalnızca adı değişir;
            // kararlılık adayı da korunur — bilinmeyen an iki yere de yazılmaz.
            currentPlace = .unknown
            return currentSession == nil && !isAway ? startSession(at: now) : []

        case .known(let placeID):
            // Kullanıcı yokken gelen ağ çözümü oturum açmaz; dönüşte açılır.
            guard !isAway else {
                currentPlace = .known(placeID)
                return []
            }
            guard var session = currentSession else {
                pendingPlace = nil
                currentPlace = .known(placeID)
                return startSession(at: now, placeID: placeID)
            }
            if session.placeID == nil || session.placeID == placeID {
                // "Bilinmeyen yer"de başlamıştı, Wi-Fi geç geldi: aynı oturum.
                session.placeID = placeID
                currentSession = session
                currentPlace = .known(placeID)
                pendingPlace = nil
                return []
            }
            if let sleptAt = closeAtSleep {
                return commitPlaceChange(to: placeID, closingAt: sleptAt, startingAt: now)
            }
            if immediate || isReturnToPrevious(placeID, at: now) {
                return commitPlaceChange(to: placeID, closingAt: now, startingAt: now)
            }

            let firstSeen: Date
            if let pending = pendingPlace, pending.placeID == placeID {
                firstSeen = pending.firstSeenAt
            } else {
                firstSeen = now
                pendingPlace = PendingPlace(placeID: placeID, firstSeenAt: now)
            }
            guard now.timeIntervalSince(firstSeen) >= configuration.placeChangeStability else {
                return []
            }
            // Yeni yerdeki ilk dakikalar kaybolmasın: bölünme ilk gözlem anında.
            return commitPlaceChange(to: placeID, closingAt: firstSeen, startingAt: firstSeen)
        }
    }

    private mutating func commitPlaceChange(
        to placeID: UUID,
        closingAt closeTime: Date,
        startingAt startTime: Date
    ) -> [SessionEffect] {
        pendingPlace = nil
        currentPlace = .known(placeID)
        var effects = endSession(at: closeTime)
        effects += startSession(at: startTime, placeID: placeID)
        return effects
    }

    private mutating func handleTick(
        idleSeconds: TimeInterval,
        at now: Date
    ) -> [SessionEffect] {
        guard !isAsleep else { return [] }

        if isAway {
            guard idleSeconds < configuration.gapThreshold else { return [] }
            isAway = false
            return startSession(at: now.addingTimeInterval(-idleSeconds))
        }

        guard var session = currentSession else { return [] }

        // Uyanık ama dokunulmuyor: ekran kapalı, kilitli ya da kullanıcı
        // uzakta. Oturum son girdi anında kapanır, ara süreye yazılmaz.
        if idleSeconds > configuration.gapThreshold {
            isAway = true
            return endSession(at: now.addingTimeInterval(-idleSeconds))
        }

        // Saat sınırları duvar saatine bakar; uykudan sonra biriken sınırlar
        // ilk tick'te toplu olarak yakalanır.
        var effects: [SessionEffect] = []
        if let interval = configuration.notificationInterval, interval > 0 {
            let reached = Int(session.elapsed(at: now) / interval)
            if reached >= 1 {
                for mark in 1...reached where !session.notifiedMarks.contains(mark) {
                    session.notifiedMarks.insert(mark)
                    effects.append(
                        .markReached(
                            index: mark,
                            elapsed: TimeInterval(mark) * interval,
                            placeID: session.placeID
                        )
                    )
                }
            }
        }

        currentSession = session
        return effects
    }

    // MARK: - Oturum yaşam döngüsü

    private var knownCurrentPlaceID: UUID? {
        if case .known(let id) = currentPlace { return id }
        return nil
    }

    private mutating func startSession(at now: Date, placeID: UUID? = nil) -> [SessionEffect] {
        let resolved = placeID ?? knownCurrentPlaceID

        if let match = resumable(placeID: resolved, at: now) {
            var session = match.session
            session.endedAt = nil
            if session.placeID == nil { session.placeID = resolved }
            currentSession = session
            recentlyEnded.removeAll { match.replacing.contains($0.id) }
            return [.sessionResumed(session, replacing: match.replacing)]
        }

        let session = Session(placeID: resolved, startedAt: now)
        currentSession = session
        return [.sessionStarted(session)]
    }

    private mutating func endSession(at time: Date) -> [SessionEffect] {
        guard var session = currentSession else { return [] }
        session.endedAt = max(session.startedAt, time)
        currentSession = nil
        recentlyEnded.append(session)
        if recentlyEnded.count > 2 {
            recentlyEnded.removeFirst(recentlyEnded.count - 2)
        }
        return [.sessionEnded(session)]
    }

    private struct ResumeMatch {
        let session: Session
        let replacing: [UUID]
    }

    /// Yeni açılacak oturumun yerine geri açılabilecek kapanmış oturum.
    ///
    /// İki durum var:
    /// - Son kapanan oturum aynı yerde ve eşik içinde kapandı → o geri açılır.
    /// - Son kapanan oturum kısa bir başka-yer oturumuydu, ondan öncekinin
    ///   hemen ardından başladı (arada uyku yok) ve öncekisi aynı yerde → ikisi
    ///   tek oturum olur. Bant ya da hotspot'a kısa süre takılmak böyle görünür;
    ///   kafeye gidip dönmek ise arada bir uyku bırakır ve katılmaz.
    private func resumable(placeID: UUID?, at now: Date) -> ResumeMatch? {
        guard
            let last = recentlyEnded.last,
            let lastEnd = last.endedAt,
            now.timeIntervalSince(lastEnd) < configuration.gapThreshold
        else { return nil }

        if Self.samePlace(last.placeID, placeID) {
            return ResumeMatch(session: last, replacing: [last.id])
        }

        guard recentlyEnded.count >= 2 else { return nil }
        let previous = recentlyEnded[recentlyEnded.count - 2]
        guard
            let previousEnd = previous.endedAt,
            Self.samePlace(previous.placeID, placeID),
            last.startedAt == previousEnd,
            last.elapsed(at: now) < configuration.gapThreshold
        else { return nil }
        return ResumeMatch(session: previous, replacing: [previous.id, last.id])
    }

    /// Açık oturum, son kapanan oturumun bitişiyle başladıysa, kısaysa ve
    /// kullanıcı o oturumun yerine döndüyse: dönüş kararlılık beklemez.
    private func isReturnToPrevious(_ placeID: UUID, at now: Date) -> Bool {
        guard
            let current = currentSession,
            let previous = recentlyEnded.last,
            previous.placeID == placeID,
            previous.endedAt == current.startedAt
        else { return false }
        return current.elapsed(at: now) < configuration.gapThreshold
    }

    /// Bilinmeyen yer, her iki yere de uyar: "Bilinmeyen yer"de başlayıp
    /// Wi-Fi geç gelen oturum aynı oturumdur.
    private static func samePlace(_ a: UUID?, _ b: UUID?) -> Bool {
        a == nil || b == nil || a == b
    }
}
