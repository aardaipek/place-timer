import Foundation
import Testing
@testable import PlaceTimerCore

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func yer(
    _ isim: String,
    ssids: Set<String>,
    bssids: Set<String> = [],
    at coordinate: Coordinate? = nil
) -> Place {
    Place(
        ssids: ssids,
        bssids: bssids,
        displayName: isim,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        createdAt: t0
    )
}

private func oturum(_ placeID: UUID?, from: Double, to: Double) -> Session {
    Session(placeID: placeID, startedAt: at(from), endedAt: at(to))
}

@Suite("Yer birleştirme")
struct PlaceMergeTests {

    @Test("Kaynağın ağları hedefe geçer, kaynak katalogdan çıkar")
    func mergeMovesNetworks() {
        let ev = yer("Ev", ssids: ["EV-2.4"], bssids: ["aa:00"])
        let ev5 = yer("Ev 5G", ssids: ["EV-5"], bssids: ["bb:11"])
        var catalog = PlaceCatalog()
        catalog.add(ev)
        catalog.add(ev5)

        catalog.merge(ev5.id, into: ev.id)

        #expect(catalog.places.count == 1)
        #expect(catalog.place(id: ev5.id) == nil)
        #expect(catalog.place(id: ev.id)?.ssids == ["EV-2.4", "EV-5"])
        #expect(catalog.place(id: ev.id)?.bssids == ["aa:00", "bb:11"])
    }

    @Test("Hedefin adı ve koordinatı korunur")
    func mergeKeepsTargetIdentity() {
        let kadikoy = Coordinate(latitude: 40.9900, longitude: 29.0250)
        let hedef = yer("Ev", ssids: ["EV-2.4"], at: kadikoy)
        let kaynak = yer("Ev 5G", ssids: ["EV-5"], at: Coordinate(latitude: 41.1, longitude: 29.9))
        var catalog = PlaceCatalog()
        catalog.add(hedef)
        catalog.add(kaynak)

        catalog.merge(kaynak.id, into: hedef.id)

        let kalan = catalog.place(id: hedef.id)
        #expect(kalan?.displayName == "Ev")
        #expect(kalan?.latitude == kadikoy.latitude)
        #expect(kalan?.longitude == kadikoy.longitude)
    }

    /// Hedefin koordinatı yoksa kaynağınki işe yarar: yer o zamana kadar
    /// yalnızca elle seçilmiş olabilir ve hiç konum görmemiştir.
    @Test("Hedefin koordinatı yoksa kaynağınki alınır")
    func mergeAdoptsCoordinateWhenTargetHasNone() {
        let kadikoy = Coordinate(latitude: 40.9900, longitude: 29.0250)
        let hedef = yer("Ev", ssids: ["EV-2.4"], at: nil)
        let kaynak = yer("Ev 5G", ssids: ["EV-5"], at: kadikoy)
        var catalog = PlaceCatalog()
        catalog.add(hedef)
        catalog.add(kaynak)

        catalog.merge(kaynak.id, into: hedef.id)

        #expect(catalog.place(id: hedef.id)?.latitude == kadikoy.latitude)
    }

    @Test("Kendisiyle birleştirme hiçbir şey yapmaz")
    func mergeIntoItselfIsIgnored() {
        let ev = yer("Ev", ssids: ["EV-2.4"])
        var catalog = PlaceCatalog()
        catalog.add(ev)

        catalog.merge(ev.id, into: ev.id)

        #expect(catalog.places.count == 1)
        #expect(catalog.place(id: ev.id)?.ssids == ["EV-2.4"])
    }

    @Test("Bilinmeyen kimlikler katalogu bozmaz")
    func mergeWithUnknownIDIsIgnored() {
        let ev = yer("Ev", ssids: ["EV-2.4"])
        var catalog = PlaceCatalog()
        catalog.add(ev)

        catalog.merge(UUID(), into: ev.id)
        catalog.merge(ev.id, into: UUID())

        #expect(catalog.places.count == 1)
        #expect(catalog.place(id: ev.id)?.ssids == ["EV-2.4"])
    }
}

@Suite("Geçmiş düzeltmeleri")
struct SessionHistoryTests {

    @Test("Birleştirilen yerin oturumları hedefe taşınır")
    func reassignMovesSessions() {
        let hedef = UUID()
        let kaynak = UUID()
        let baska = UUID()
        let sessions = [
            oturum(kaynak, from: 0, to: 60),
            oturum(hedef, from: 60, to: 120),
            oturum(baska, from: 120, to: 180),
            oturum(nil, from: 180, to: 240),
        ]

        let sonuc = SessionHistory.reassign(sessions, from: kaynak, to: hedef)

        #expect(sonuc.count == 4)
        #expect(sonuc[0].placeID == hedef)
        #expect(sonuc[1].placeID == hedef)
        #expect(sonuc[2].placeID == baska)
        #expect(sonuc[3].placeID == nil)
        // Taşınan oturumun kimliği ve zamanları değişmez.
        #expect(sonuc[0].id == sessions[0].id)
        #expect(sonuc[0].startedAt == sessions[0].startedAt)
    }

    @Test("Silinen oturum listeden çıkar, ötekiler durur")
    func removeDropsOnlyThatSession() {
        let ev = UUID()
        let sessions = [
            oturum(ev, from: 0, to: 60),
            oturum(ev, from: 60, to: 120),
            oturum(ev, from: 120, to: 180),
        ]

        let sonuc = SessionHistory.remove(sessions[1].id, from: sessions)

        #expect(sonuc.count == 2)
        #expect(sonuc.map(\.id) == [sessions[0].id, sessions[2].id])
    }

    @Test("Olmayan oturumu silmek listeyi değiştirmez")
    func removeUnknownIsNoop() {
        let sessions = [oturum(UUID(), from: 0, to: 60)]
        #expect(SessionHistory.remove(UUID(), from: sessions).count == 1)
    }
}

@Suite("Birleştirmenin açık oturuma yansıması")
struct EngineReassignTests {

    @Test("Açık oturumun yeri taşınır, oturum kapanmaz")
    func reassignKeepsSessionOpen() {
        let kaynak = UUID()
        let hedef = UUID()
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(kaynak)), at: at(0))
        let id = engine.currentSession?.id

        engine.reassignPlace(from: kaynak, to: hedef)

        #expect(engine.currentSession?.id == id)
        #expect(engine.currentSession?.placeID == hedef)
        #expect(engine.currentPlace == .known(hedef))
        // Sure kesilmedi.
        #expect(engine.elapsed(at: at(40)) == 40 * 60)
    }

    @Test("Başka bir yerdeyken birleştirme oturuma dokunmaz")
    func reassignLeavesOtherPlacesAlone() {
        let kaynak = UUID()
        let hedef = UUID()
        let baska = UUID()
        var engine = SessionEngine()
        engine.handle(.wake, at: at(0))
        engine.handle(.placeResolved(.known(baska)), at: at(0))

        engine.reassignPlace(from: kaynak, to: hedef)

        #expect(engine.currentSession?.placeID == baska)
    }
}

@Suite("Aralıktaki oturumlar")
struct SessionsInRangeTests {

    @Test("Bugünün oturumları en yenisi başta gelir")
    func todaySessionsNewestFirst() {
        let ev = UUID()
        let bugun = [
            oturum(ev, from: 0, to: 60),
            oturum(ev, from: 120, to: 180),
            oturum(ev, from: 60, to: 120),
        ]
        // Baska bir gunun oturumu: araliga girmemeli.
        let dun = Session(
            placeID: ev,
            startedAt: at(0).addingTimeInterval(-48 * 3600),
            endedAt: at(0).addingTimeInterval(-47 * 3600)
        )

        let sonuc = sessionsIn(.today, from: bugun + [dun], now: at(180))

        #expect(sonuc.count == 3)
        #expect(sonuc.map(\.startedAt) == [at(120), at(60), at(0)])
    }

    @Test("Aralıkta oturum yoksa boş döner")
    func emptyWhenNothingInRange() {
        let uzak = Session(
            placeID: UUID(),
            startedAt: at(0).addingTimeInterval(-90 * 86400),
            endedAt: at(0).addingTimeInterval(-90 * 86400 + 600)
        )
        #expect(sessionsIn(.today, from: [uzak], now: at(0)).isEmpty)
    }
}
