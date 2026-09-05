import Foundation

/// Oturum durum makinesi.
///
/// Bilinçli olarak hiçbir sistem API'sine dokunmaz: girdileri sade
/// `SessionEvent` değerleri, zaman ise her çağrıya dışarıdan geçirilen bir
/// `Date`'tir. Böylece "90 dakika uyuyup uyandı" gibi senaryolar gerçek zaman
/// beklenmeden test edilebilir.
public struct SessionEngine: Sendable {
    public private(set) var currentSession: Session?
    public private(set) var currentPlace: PlaceRef
    public private(set) var isAsleep: Bool
    public private(set) var isScreenLocked: Bool

    public let configuration: EngineConfiguration

    private var sleepStartedAt: Date?
    /// Uyandıktan sonraki ilk yer çözümlemesine kadar taşınır. Yer uyku
    /// sırasında değiştiyse eski oturum uyanma anında değil, uykuya dalma
    /// anında kapanmalı — yoksa yolda geçen süre yeni yerin hanesine yazılır.
    private var pendingSleepStart: Date?
    private var lastTickAt: Date?

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
        self.isScreenLocked = false
    }

    /// Oturumun o yerde geçirdiği duvar saati süresi.
    public func elapsed(at now: Date) -> TimeInterval {
        currentSession?.elapsed(at: now) ?? 0
    }

    public var activeSeconds: TimeInterval {
        currentSession?.activeSeconds ?? 0
    }

    @discardableResult
    public mutating func handle(_ event: SessionEvent, at now: Date) -> [SessionEffect] {
        switch event {
        case .wake:
            return handleWake(at: now)
        case .sleep:
            return handleSleep(at: now)
        case .screenLocked:
            isScreenLocked = true
            lastTickAt = nil
            return []
        case .screenUnlocked:
            isScreenLocked = false
            lastTickAt = nil
            return []
        case .placeResolved(let place):
            return handlePlaceResolved(place, at: now)
        case .tick(let idleSeconds):
            return handleTick(idleSeconds: idleSeconds, at: now)
        }
    }

    // MARK: - Olay işleyicileri

    private mutating func handleWake(at now: Date) -> [SessionEffect] {
        isAsleep = false
        lastTickAt = nil

        guard let sleptAt = sleepStartedAt else {
            // Uykudan değil, soğuk başlangıçtan geliyoruz.
            return currentSession == nil ? [startSession(at: now)] : []
        }
        sleepStartedAt = nil

        if now.timeIntervalSince(sleptAt) > configuration.sessionResetSleepThreshold {
            var effects = endSession(at: sleptAt)
            effects.append(startSession(at: now))
            return effects
        }

        // Kısa mola: oturum sürüyor, ama yerin değişmediğini henüz bilmiyoruz.
        pendingSleepStart = sleptAt
        return currentSession == nil ? [startSession(at: now)] : []
    }

    private mutating func handleSleep(at now: Date) -> [SessionEffect] {
        isAsleep = true
        sleepStartedAt = now
        pendingSleepStart = nil
        lastTickAt = nil
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
            return currentSession == nil ? [startSession(at: now)] : []

        case .known(let placeID):
            currentPlace = .known(placeID)

            guard var session = currentSession else {
                return [startSession(at: now, placeID: placeID)]
            }
            if session.placeID == nil {
                // "Bilinmeyen yer"de başlamıştı, Wi-Fi geç geldi: aynı oturum.
                session.placeID = placeID
                currentSession = session
                return []
            }
            if session.placeID == placeID {
                return []
            }
            var effects = endSession(at: closeAt)
            effects.append(startSession(at: now, placeID: placeID))
            return effects
        }
    }

    private mutating func handleTick(
        idleSeconds: TimeInterval,
        at now: Date
    ) -> [SessionEffect] {
        guard !isAsleep, var session = currentSession else {
            lastTickAt = nil
            return []
        }

        let delta = lastTickAt.map {
            min(max(0, now.timeIntervalSince($0)), configuration.maxTickDelta)
        } ?? 0
        lastTickAt = now

        let isWorking = !isScreenLocked && idleSeconds < configuration.idleThreshold
        if isWorking {
            session.activeSeconds += delta
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

    private mutating func startSession(at now: Date, placeID: UUID? = nil) -> SessionEffect {
        let resolvedPlaceID: UUID? = placeID ?? {
            if case .known(let id) = currentPlace { return id }
            return nil
        }()
        let session = Session(placeID: resolvedPlaceID, startedAt: now)
        currentSession = session
        lastTickAt = nil
        return .sessionStarted(session)
    }

    private mutating func endSession(at now: Date) -> [SessionEffect] {
        guard var session = currentSession else { return [] }
        session.endedAt = max(session.startedAt, now)
        currentSession = nil
        lastTickAt = nil
        return [.sessionEnded(session)]
    }
}
