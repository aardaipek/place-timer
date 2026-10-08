import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func startedAtHome(_ configuration: EngineConfiguration = EngineConfiguration()) -> SessionEngine {
    var engine = SessionEngine(configuration: configuration)
    engine.handle(.wake, at: at(0))
    engine.handle(.placeResolved(.known(ev)), at: at(0))
    return engine
}

@Suite("İnceleme düzeltmeleri")
struct ReviewFixTests {

    @Test("Uzun uykudan başka bir yerde uyanınca yeni oturum beklemeden yeni yeri alır")
    func longSleepWakeAdoptsNewPlace() {
        var engine = startedAtHome()
        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(50))

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(50.1))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.placeID == kafe)
        #expect(engine.currentSession?.startedAt == at(50))
    }

    @Test("Kısa uykudan sonra Wi-Fi geç gelirse yol yine eski yere yazılmaz")
    func lateWiFiAfterShortSleepClosesAtSleep() {
        var engine = startedAtHome()
        engine.handle(.sleep, at: at(60))
        engine.handle(.wake, at: at(80))
        engine.handle(.placeResolved(.unknown), at: at(80.1))

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(80.3))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(60))
        #expect(started.startedAt == at(80))
        #expect(started.placeID == kafe)
    }

    @Test("Yeni yer adlandırılınca oturum uykuda kapanır, yeni yer uyanışta başlar")
    func namingNewPlaceAfterShortSleep() {
        var engine = startedAtHome()
        engine.handle(.sleep, at: at(60))
        engine.handle(.wake, at: at(80))
        engine.handle(.placeResolved(.unknown), at: at(80.1))

        let effects = engine.handle(.placeChosen(kafe), at: at(90))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(60))
        #expect(started.startedAt == at(80))
    }

    @Test("Hareketsizlik ve ardından uyku tek ara sayılır")
    func idleThenSleepIsOneGap() {
        var engine = startedAtHome()
        engine.handle(.tick(idleSeconds: 0), at: at(20))
        engine.handle(.tick(idleSeconds: 25 * 60), at: at(45))
        engine.handle(.sleep, at: at(45))

        let effects = engine.handle(.wake, at: at(70))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmadı: \(effects)")
            return
        }
        #expect(ended.endedAt == at(20))
    }

    @Test("Uzaktayken kalan yer adayı dönüşte geçmişe yazılmaz")
    func stalePendingPlaceAfterAwayIsDropped() {
        var engine = startedAtHome()
        engine.handle(.placeResolved(.known(kafe)), at: at(10))     // aday
        engine.handle(.tick(idleSeconds: 31 * 60), at: at(45))      // uzakta
        engine.handle(.tick(idleSeconds: 0), at: at(60))            // döndü
        engine.handle(.placeResolved(.unknown), at: at(60.1))       // Wi-Fi henüz yok

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(300))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.placeID == ev)
    }

    @Test("Sayaç sıfırlanınca eski yer adayı unutulur")
    func pendingPlaceDroppedOnManualReset() {
        var engine = startedAtHome()
        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.endSessionRequested, at: at(11))

        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(13))

        #expect(effects.isEmpty)
    }
}
