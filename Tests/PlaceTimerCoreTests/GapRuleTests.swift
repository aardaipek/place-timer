import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

/// Evde 0. dakikada başlamış bir oturum. Varsayılan ara eşiği 30 dakika.
private func started(
    _ configuration: EngineConfiguration = EngineConfiguration()
) -> SessionEngine {
    var engine = SessionEngine(configuration: configuration)
    engine.handle(.wake, at: at(0))
    engine.handle(.placeResolved(.known(ev)), at: at(0))
    return engine
}

@Suite("Ara eşiği")
struct GapRuleTests {

    @Test("Eşikten kısa uyku oturumu bozmaz, ara süreye dahildir")
    func shortSleepKeepsSession() {
        var engine = started()
        let id = engine.currentSession?.id

        engine.handle(.sleep, at: at(10))
        let effects = engine.handle(.wake, at: at(30))

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == id)
        #expect(engine.elapsed(at: at(30)) == 30 * 60)
    }

    @Test("Eşikten uzun uyku oturumu uykuya dalma anında kapatır")
    func longSleepEndsAtSleep() {
        var engine = started()
        let id = engine.currentSession?.id

        engine.handle(.sleep, at: at(10))
        let effects = engine.handle(.wake, at: at(50))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmadı: \(effects)")
            return
        }
        #expect(ended.id == id)
        #expect(ended.endedAt == at(10))
        #expect(engine.currentSession?.startedAt == at(50))
    }

    @Test("Uyanık ama dokunulmayan Mac oturumu son girdi anında kapatır")
    func idleAwakeEndsAtLastInput() {
        var engine = started()

        // 40. dakikada 31 dakikadır dokunulmuyor: son girdi 9. dakikada.
        let effects = engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))

        guard case .sessionEnded(let ended) = effects.first else {
            Issue.record("oturum kapanmadı: \(effects)")
            return
        }
        #expect(ended.endedAt == at(9))
        #expect(engine.currentSession == nil)
    }

    @Test("Kullanıcı dönünce yeni oturum ilk girdi anında başlar")
    func returnStartsNewSession() {
        var engine = started()
        engine.handle(.tick(idleSeconds: 31 * 60), at: at(40))
        engine.handle(.tick(idleSeconds: 32 * 60), at: at(41))
        #expect(engine.currentSession == nil)

        let effects = engine.handle(.tick(idleSeconds: 2), at: at(120))

        guard case .sessionStarted(let session) = effects.first else {
            Issue.record("oturum açılmadı: \(effects)")
            return
        }
        #expect(session.startedAt == at(120).addingTimeInterval(-2))
        #expect(session.placeID == ev)
    }

    @Test("Eşikten kısa hareketsizlik oturumu bozmaz")
    func shortIdleKeepsSession() {
        var engine = started()
        let effects = engine.handle(.tick(idleSeconds: 29 * 60), at: at(40))
        #expect(effects.isEmpty)
        #expect(engine.currentSession != nil)
    }

    @Test("Uykudayken gelen tick oturumu kapatmaz")
    func ticksWhileAsleepAreIgnored() {
        var engine = started()
        engine.handle(.sleep, at: at(5))
        let effects = engine.handle(.tick(idleSeconds: 3600), at: at(6))
        #expect(effects.isEmpty)
        #expect(engine.currentSession != nil)
    }

    @Test("Eşik değişince yeni değer hemen geçerli olur")
    func thresholdUpdateAppliesImmediately() {
        var engine = started()
        engine.updateConfiguration(EngineConfiguration(gapThreshold: 3600), at: at(1))
        let effects = engine.handle(.tick(idleSeconds: 45 * 60), at: at(50))
        #expect(effects.isEmpty)
        #expect(engine.configuration.gapThreshold == 3600)
    }
}
