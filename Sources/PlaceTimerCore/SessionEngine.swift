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

    /// - Parameter restoring: Diskten okunan açık oturum. Uygulama çökse veya
    ///   güncellense bile oturum kaldığı yerden devam eder.
    public init(
        configuration: EngineConfiguration = EngineConfiguration(),
        restoring session: Session? = nil
    ) {
        self.configuration = configuration
        self.currentSession = session
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
            handlePlaceResolved(place, at: now)
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
        effects += startSession(at: now)
        return effects
    }

    /// Art arda gelen uyku bildirimlerinde ilk an korunur: ara en erken
    /// başladığı yerden ölçülür.
    private mutating func handleSleep(at now: Date) -> [SessionEffect] {
        isAsleep = true
        if sleepStartedAt == nil { sleepStartedAt = now }
        pendingSleepStart = nil
        return []
    }

    private mutating func handlePlaceResolved(
        _ place: PlaceRef,
        at now: Date
    ) -> [SessionEffect] {
        // Yer değişimi uyku sırasında olduysa oturum uykuya dalma anında biter.
        let closeAt = pendingSleepStart ?? now
        pendingSleepStart = nil

        switch place {
        case .unknown:
            // Wi-Fi düştü ya da hiç yok. Oturum kapanmaz, yalnızca adı değişir.
            currentPlace = .unknown
            return currentSession == nil && !isAway ? startSession(at: now) : []

        case .known(let placeID):
            currentPlace = .known(placeID)
            // Kullanıcı yokken gelen ağ çözümü oturum açmaz; dönüşte açılır.
            guard !isAway else { return [] }

            guard var session = currentSession else {
                return startSession(at: now, placeID: placeID)
            }
            if session.placeID == nil || session.placeID == placeID {
                // "Bilinmeyen yer"de başlamıştı, Wi-Fi geç geldi: aynı oturum.
                session.placeID = placeID
                currentSession = session
                return []
            }
            var effects = endSession(at: closeAt)
            effects += startSession(at: now, placeID: placeID)
            return effects
        }
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
        let session = Session(placeID: placeID ?? knownCurrentPlaceID, startedAt: now)
        currentSession = session
        return [.sessionStarted(session)]
    }

    private mutating func endSession(at time: Date) -> [SessionEffect] {
        guard var session = currentSession else { return [] }
        session.endedAt = max(session.startedAt, time)
        currentSession = nil
        return [.sessionEnded(session)]
    }
}
