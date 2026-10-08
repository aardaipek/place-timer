import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func startedAtHome() -> SessionEngine {
    var engine = SessionEngine()
    engine.handle(.wake, at: at(0))
    engine.handle(.placeResolved(.known(ev)), at: at(0))
    return engine
}

@Suite("Yer kararlılığı")
struct PlaceStabilityTests {

    @Test("Başka ağ 3 dakikadan kısa sürerse oturum bölünmez")
    func briefFlipDoesNotSplit() {
        var engine = startedAtHome()
        let id = engine.currentSession?.id

        var effects: [SessionEffect] = []
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(10))
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(12))
        effects += engine.handle(.placeResolved(.known(ev)), at: at(12.5))
        // Sayaç sıfırlandı: kafe yeniden görülünce bekleme baştan başlar.
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(13))
        effects += engine.handle(.placeResolved(.known(kafe)), at: at(15.9))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.currentSession?.placeID == ev)
    }

    @Test("Yeni yer 3 dakika sürerse oturum ilk gözlem anında bölünür")
    func stableChangeSplitsAtFirstSighting() {
        var engine = startedAtHome()

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.known(kafe)), at: at(11))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(13))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.placeID == ev)
        #expect(ended.endedAt == at(10))
        #expect(started.placeID == kafe)
        #expect(started.startedAt == at(10))
    }

    @Test("Wi-Fi yokluğu kararlılık sayacını sıfırlamaz")
    func unknownDoesNotResetPending() {
        var engine = startedAtHome()

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.unknown), at: at(11))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(13))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
    }

    @Test("Kullanıcının seçtiği yer beklemeden geçerli olur")
    func chosenPlaceAppliesImmediately() {
        var engine = startedAtHome()

        let effects = engine.handle(.placeChosen(kafe), at: at(10))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
        #expect(started.placeID == kafe)
    }

    @Test("Kısa uykudan sonra yer değiştiyse beklemeden uykuya dalma anında bölünür")
    func changeAfterShortSleepSplitsAtSleep() {
        var engine = startedAtHome()

        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(20))
        let effects = engine.handle(.placeResolved(.known(kafe)), at: at(20.1))

        guard
            case .sessionEnded(let ended) = effects.first,
            case .sessionStarted(let started) = effects.last
        else {
            Issue.record("bölünme yok: \(effects)")
            return
        }
        #expect(ended.endedAt == at(10))
        // Yeni yer uyanışta başlar; Wi-Fi'nin çözülmesini beklemek yeni yerdeki
        // ilk anları kaybettirirdi.
        #expect(started.startedAt == at(20))
    }

    @Test("Kullanıcı yokken gelen ağ çözümü oturum açmaz")
    func resolutionWhileAwayDoesNotStart() {
        var engine = startedAtHome()
        engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))
        #expect(engine.currentSession == nil)

        var effects = engine.handle(.placeResolved(.unknown), at: at(41))
        effects += engine.handle(.placeResolved(.known(ev)), at: at(42))

        #expect(effects.isEmpty)
        #expect(engine.currentSession == nil)
    }
}
