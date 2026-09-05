import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)  // sabit başlangıç
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

/// Motoru saniyede bir tick'lemeden aktif süre biriktirmek için yardımcı:
/// `seconds` boyunca `step` aralıklarla tick gönderir.
@discardableResult
private func advance(
    _ engine: inout SessionEngine,
    from start: Date,
    seconds: TimeInterval,
    step: TimeInterval = 1,
    idle: TimeInterval = 0
) -> [SessionEffect] {
    var effects: [SessionEffect] = []
    var elapsed: TimeInterval = 0
    while elapsed < seconds {
        elapsed += step
        effects += engine.handle(
            .tick(idleSeconds: idle),
            at: start.addingTimeInterval(elapsed)
        )
    }
    return effects
}

@Suite("Oturum durum makinesi")
struct SessionEngineTests {

    @Test("Uyanınca oturum başlar ve çözülen yer oturuma yazılır")
    func wakeStartsSession() {
        var engine = SessionEngine()
        let effects = engine.handle(.wake, at: at(0))

        #expect(effects.count == 1)
        #expect(engine.currentSession != nil)

        engine.handle(.placeResolved(.known(kafe)), at: at(0.1))
        #expect(engine.currentSession?.placeID == kafe)
    }

    @Test("45 dakikalık uyku oturumu bozmaz")
    func shortSleepKeepsSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))
        let started = engine.currentSession?.id

        engine.handle(.sleep, at: at(30))
        let effects = engine.handle(.wake, at: at(75))
        engine.handle(.placeResolved(.known(kafe)), at: at(75))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == started)
        // Yerde geçen süre uyku aralığını içerir.
        #expect(engine.elapsed(at: at(75)) == 75 * 60)
    }

    @Test("90 dakikalık uyku oturumu kapatır, yenisini açar")
    func longSleepResetsSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        let firstID = engine.currentSession?.id

        engine.handle(.sleep, at: at(30))
        let effects = engine.handle(.wake, at: at(120))

        #expect(effects.count == 2)
        guard case .sessionEnded(let ended) = effects[0] else {
            Issue.record("ilk etki oturum kapanışı olmalı"); return
        }
        // Kapanış uykuya dalma anında; uyku süresi oturuma yazılmaz.
        #expect(ended.endedAt == at(30))
        #expect(ended.id == firstID)

        guard case .sessionStarted(let fresh) = effects[1] else {
            Issue.record("ikinci etki yeni oturum olmalı"); return
        }
        #expect(fresh.startedAt == at(120))
        #expect(fresh.id != firstID)
        #expect(engine.elapsed(at: at(120)) == 0)
    }

    @Test("Uyku sırasında yer değiştiyse eski oturum uykuya dalma anında biter")
    func placeChangeDuringSleepClosesAtSleepTime() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))

        engine.handle(.sleep, at: at(30))          // evden çıktı
        engine.handle(.wake, at: at(50))           // 20 dk sonra kafede açtı
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(50))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmalıydı"); return
        }
        // Yolda geçen 20 dakika ne evin ne kafenin hanesine yazılır.
        #expect(ended.endedAt == at(30))
        #expect(engine.currentSession?.placeID == kafe)
        #expect(engine.elapsed(at: at(50)) == 0)
    }

    @Test("Uyanıkken yer değişimi oturumu o an kapatır")
    func placeChangeWhileAwakeClosesNow() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(40))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmalıydı"); return
        }
        #expect(ended.endedAt == at(40))
    }

    @Test("Wi-Fi kesilmesi oturumu kapatmaz")
    func losingWiFiKeepsSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))
        let id = engine.currentSession?.id

        let effects = engine.handle(.placeResolved(.unknown), at: at(20))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.currentPlace == .unknown)
        // Yer kimliği korunur; ağ geri gelince aynı oturum sürer.
        #expect(engine.currentSession?.placeID == kafe)
    }

    @Test("Bilinmeyen yerde başlayan oturum, Wi-Fi geç gelince aynı kalır")
    func lateWiFiAdoptsPlaceIntoSameSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        let id = engine.currentSession?.id

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(0.5))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.currentSession?.placeID == kafe)
    }

    @Test("Ekran kilitliyken aktif sayaç durur, yerde geçen süre akar")
    func lockedScreenPausesActiveCounter() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))

        advance(&engine, from: at(0), seconds: 60)
        #expect(engine.activeSeconds == 59)

        engine.handle(.screenLocked, at: at(1))
        advance(&engine, from: at(1), seconds: 120)
        #expect(engine.activeSeconds == 59)          // kilitliyken artmadı
        #expect(engine.elapsed(at: at(3)) == 180)    // ama süre aktı
    }

    @Test("5 dakikalık hareketsizlik aktif sayacı durdurur, girdi gelince sürer")
    func idlePausesActiveCounter() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))

        advance(&engine, from: at(0), seconds: 30, idle: 0)
        #expect(engine.activeSeconds == 29)

        // Eşiğin üstünde hareketsizlik: sayaç donar.
        advance(&engine, from: at(0.5), seconds: 30, idle: 400)
        #expect(engine.activeSeconds == 29)

        // Kullanıcı geri döndü.
        advance(&engine, from: at(1), seconds: 30, idle: 0)
        #expect(engine.activeSeconds == 59)
    }

    @Test("Kaçan tick'ler aktif süreyi şişirmez")
    func missedTicksAreClamped() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))

        engine.handle(.tick(idleSeconds: 0), at: at(0))
        engine.handle(.tick(idleSeconds: 0), at: at(10))  // 10 dakikalık boşluk

        #expect(engine.activeSeconds == 5)  // maxTickDelta
    }

    @Test("Her saat sınırı tam olarak bir bildirim üretir")
    func hourMarksFireExactlyOnce() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))

        #expect(engine.handle(.tick(idleSeconds: 0), at: at(59)).isEmpty)

        let firstHour = engine.handle(.tick(idleSeconds: 0), at: at(60))
        #expect(firstHour == [.markReached(index: 1, elapsed: 3600, placeID: kafe)])

        #expect(engine.handle(.tick(idleSeconds: 0), at: at(61)).isEmpty)
        #expect(engine.handle(.tick(idleSeconds: 0), at: at(119)).isEmpty)

        let secondHour = engine.handle(.tick(idleSeconds: 0), at: at(120))
        #expect(secondHour == [.markReached(index: 2, elapsed: 7200, placeID: kafe)])
    }

    @Test("Uyku boyunca biriken saat sınırları uyanışta toplu düşer")
    func hourMarksCatchUpAfterSleep() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(0))

        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(55))            // 45 dk: oturum sürüyor
        engine.handle(.placeResolved(.known(kafe)), at: at(55))

        let effects = engine.handle(.tick(idleSeconds: 0), at: at(70))
        #expect(effects == [.markReached(index: 1, elapsed: 3600, placeID: kafe)])
    }

    @Test("Yeni oturum saat sınırlarını sıfırdan sayar")
    func hourMarksResetWithNewSession() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.tick(idleSeconds: 0), at: at(60))

        engine.handle(.placeResolved(.known(kafe)), at: at(90))
        #expect(engine.handle(.tick(idleSeconds: 0), at: at(140)).isEmpty)

        let effects = engine.handle(.tick(idleSeconds: 0), at: at(150))
        #expect(effects == [.markReached(index: 1, elapsed: 3600, placeID: kafe)])
    }

    @Test("Diskten geri yüklenen oturum kaldığı yerden devam eder")
    func restoresPersistedSession() {
        let saved = Session(
            placeID: kafe,
            startedAt: at(0),
            activeSeconds: 1200,
            notifiedMarks: [1]
        )
        var engine = SessionEngine(restoring: saved)

        #expect(engine.currentSession?.id == saved.id)
        #expect(engine.elapsed(at: at(90)) == 90 * 60)

        // 1. saat bildirimi tekrar gönderilmez, 2. saat gönderilir.
        let effects = engine.handle(.tick(idleSeconds: 0), at: at(125))
        #expect(effects == [.markReached(index: 2, elapsed: 7200, placeID: kafe)])
    }

    @Test("Uykudayken gelen tick'ler yok sayılır")
    func ticksDuringSleepAreIgnored() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        advance(&engine, from: at(0), seconds: 10)
        let before = engine.activeSeconds

        engine.handle(.sleep, at: at(1))
        advance(&engine, from: at(1), seconds: 60)

        #expect(engine.activeSeconds == before)
    }
}

@Suite("Bildirim aralığı")
struct NotificationIntervalTests {

    private func engine(interval: TimeInterval?) -> SessionEngine {
        SessionEngine(
            configuration: EngineConfiguration(notificationInterval: interval)
        )
    }

    @Test("Kapalıyken hiç işaret üretilmez")
    func offProducesNothing() {
        var motor = engine(interval: nil)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(60)).isEmpty)
        #expect(motor.handle(.tick(idleSeconds: 0), at: at(180)).isEmpty)
        #expect(motor.currentSession?.notifiedMarks.isEmpty == true)
    }

    @Test("30 dakikalık aralık her yarım saatte bir düşer")
    func halfHourlyMarks() {
        var motor = engine(interval: 30 * 60)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(29)).isEmpty)

        let ilk = motor.handle(.tick(idleSeconds: 0), at: at(30))
        #expect(ilk == [.markReached(index: 1, elapsed: 30 * 60, placeID: kafe)])

        #expect(motor.handle(.tick(idleSeconds: 0), at: at(45)).isEmpty)

        let ikinci = motor.handle(.tick(idleSeconds: 0), at: at(60))
        #expect(ikinci == [.markReached(index: 2, elapsed: 60 * 60, placeID: kafe)])
    }

    @Test("İşaretin bildirdiği süre gerçek geçen süredir")
    func markCarriesElapsed() {
        var motor = engine(interval: 30 * 60)
        motor.handle(.wake, at: at(0))
        motor.handle(.placeResolved(.known(kafe)), at: at(0))

        // 95. dakikada ilk kez tick geliyor: 3 isaret birikmis.
        let etkiler = motor.handle(.tick(idleSeconds: 0), at: at(95))

        #expect(etkiler.count == 3)
        #expect(etkiler[0] == .markReached(index: 1, elapsed: 30 * 60, placeID: kafe))
        #expect(etkiler[2] == .markReached(index: 3, elapsed: 90 * 60, placeID: kafe))
    }
}
