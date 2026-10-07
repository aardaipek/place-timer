import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()
private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func closedAtHome(until end: Double) -> Session {
    Session(placeID: ev, startedAt: at(0), endedAt: at(end))
}

private func resumed(_ effects: [SessionEffect]) -> (Session, [UUID])? {
    for effect in effects {
        if case .sessionResumed(let session, let replacing) = effect {
            return (session, replacing)
        }
    }
    return nil
}

@Suite("Oturumun geri açılması")
struct ResumeTests {

    @Test("Aynı yere eşik içinde dönülünce eski oturum geri açılır")
    func resumesWithinThreshold() {
        let eski = closedAtHome(until: 20)
        var engine = SessionEngine(recentlyEnded: [eski])

        let effects = engine.handle(.wake, at: at(25))

        guard let (session, replacing) = resumed(effects) else {
            Issue.record("geri açılmadı: \(effects)")
            return
        }
        #expect(session.id == eski.id)
        #expect(session.endedAt == nil)
        #expect(replacing == [eski.id])
        #expect(engine.currentSession?.id == eski.id)
        #expect(engine.elapsed(at: at(25)) == 25 * 60)
    }

    @Test("Eşikten sonra dönülürse yeni oturum açılır")
    func newSessionAfterThreshold() {
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        let effects = engine.handle(.wake, at: at(60))
        guard case .sessionStarted = effects.first else {
            Issue.record("yeni oturum yok: \(effects)")
            return
        }
    }

    @Test("Kısa bir başka ağ eski oturuma katılır")
    func briefDetourIsAbsorbed() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        let evID = engine.currentSession!.id

        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        let kafeID = engine.currentSession!.id
        let effects = engine.handle(.placeResolved(.known(ev)), at: at(15))

        guard let (session, replacing) = resumed(effects) else {
            Issue.record("geri açılmadı: \(effects)")
            return
        }
        #expect(session.id == evID)
        #expect(Set(replacing) == [evID, kafeID])
        #expect(engine.elapsed(at: at(15)) == 15 * 60)
    }

    @Test("Önceki yere dönüş kararlılık süresi beklemez")
    func returnSkipsStability() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(10))
        engine.handle(.placeResolved(.known(kafe)), at: at(13))  // kafe onaylandı

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(14))

        #expect(resumed(effects) != nil)
        #expect(engine.currentSession?.placeID == ev)
    }

    @Test("Uykuyla ayrılan bir ziyaret katılmaz")
    func detourAcrossSleepIsKept() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.sleep, at: at(10))
        engine.handle(.wake, at: at(20))
        engine.handle(.placeResolved(.known(kafe)), at: at(20))  // ev 10'da kapandı

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(26))

        #expect(resumed(effects) == nil)
        guard case .sessionStarted = effects.last else {
            Issue.record("yeni oturum yok: \(effects)")
            return
        }
    }

    @Test("Eşikten uzun süren başka yer katılmaz")
    func longDetourIsKept() {
        var engine = SessionEngine(configuration: EngineConfiguration(placeChangeStability: 0))
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))
        engine.handle(.placeResolved(.known(kafe)), at: at(10))

        let effects = engine.handle(.placeResolved(.known(ev)), at: at(45))

        #expect(resumed(effects) == nil)
    }

    @Test("Elle bitirilen oturum geri açılmaz")
    func manualEndIsFinal() {
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(ev)), at: at(0))

        let effects = engine.handle(.endSessionRequested, at: at(10))

        #expect(resumed(effects) == nil)
        #expect(engine.recentlyEnded.isEmpty)
    }

    @Test("Unutulan oturumlar geri açılmaz")
    func forgottenSessionsStayClosed() {
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        engine.forgetRecent()
        let effects = engine.handle(.wake, at: at(25))
        #expect(resumed(effects) == nil)
    }

    @Test("Yeniden başlatmada son kapanan oturumlar korunur")
    func restartKeepsRecentlyEnded() {
        let eski = closedAtHome(until: 20)
        let state = AppState(currentSession: nil, lastHeartbeatAt: at(20), recentlyEnded: [eski])

        let restored = SessionEngine.restored(from: state, now: at(22))

        #expect(resumed(restored.effects)?.0.id == eski.id)
    }

    @Test("1.0'ın durum dosyası okunur")
    func legacyStateDecodes() throws {
        let json = Data(#"{"lastHeartbeatAt": 0}"#.utf8)
        let state = try JSONDecoder().decode(AppState.self, from: json)
        #expect(state.recentlyEnded.isEmpty)
        #expect(state.currentSession == nil)
    }

    @Test("Birleştirilen yer son kapanan oturumlara da yansır")
    func reassignUpdatesRecentlyEnded() {
        let hedef = UUID()
        var engine = SessionEngine(recentlyEnded: [closedAtHome(until: 20)])
        engine.reassignPlace(from: ev, to: hedef)
        #expect(engine.recentlyEnded.first?.placeID == hedef)
    }
}
