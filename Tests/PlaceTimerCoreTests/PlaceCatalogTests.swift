import Foundation
import Testing
@testable import PlaceTimerCore

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// Kadıköy civarında iki nokta: ~120 m ve ~2 km uzaklıkta.
private let evKoordinati = Coordinate(latitude: 40.9900, longitude: 29.0250)
private let yakinNokta = Coordinate(latitude: 40.9911, longitude: 29.0250)
private let uzakNokta = Coordinate(latitude: 41.0080, longitude: 29.0250)

private func yer(
    _ isim: String,
    ssids: Set<String>,
    at coordinate: Coordinate? = evKoordinati
) -> Place {
    Place(
        ssids: ssids,
        displayName: isim,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        createdAt: t0
    )
}

@Suite("Yer eşleme")
struct PlaceCatalogTests {

    @Test("Mesafe hesabı makul sonuç veriyor")
    func distanceIsSane() {
        let yakin = evKoordinati.distance(to: yakinNokta)
        #expect(yakin > 100 && yakin < 150)

        let uzak = evKoordinati.distance(to: uzakNokta)
        #expect(uzak > 1500 && uzak < 2500)
    }

    @Test("Bilinen SSID doğrudan eşleşir")
    func knownSSIDMatches() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        let catalog = PlaceCatalog(places: [ev])

        #expect(
            catalog.resolve(ssid: "TURKSAT-DDBB", coordinate: evKoordinati)
                == .matched(ev)
        )
    }

    @Test("Aynı yerin ikinci bandı da eşleşir")
    func secondBandMatches() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB", "TURKSAT-DDBB-5G"])
        let catalog = PlaceCatalog(places: [ev])

        #expect(catalog.resolve(ssid: "TURKSAT-DDBB-5G", coordinate: nil) == .matched(ev))
    }

    @Test("Aynı SSID uzak koordinatta şube adayı sayılır")
    func sameSSIDFarAwayIsBranch() {
        let sube = yer("Kronotrop Kadıköy", ssids: ["Kronotrop"])
        let catalog = PlaceCatalog(places: [sube])

        #expect(
            catalog.resolve(ssid: "Kronotrop", coordinate: uzakNokta)
                == .possibleBranch(of: sube)
        )
    }

    @Test("Koordinat bilinmiyorsa SSID eşleşmesi tek başına yeter")
    func missingCoordinateStillMatches() {
        let sube = yer("Kronotrop Kadıköy", ssids: ["Kronotrop"])
        let catalog = PlaceCatalog(places: [sube])

        #expect(catalog.resolve(ssid: "Kronotrop", coordinate: nil) == .matched(sube))
    }

    @Test("Yeni ağ, yakındaki yerleri birleştirme adayı olarak sunar")
    func unknownNetworkSuggestsNearby() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        let uzakYer = yer("Ofis", ssids: ["Ofis-WiFi"], at: uzakNokta)
        let catalog = PlaceCatalog(places: [ev, uzakYer])

        let sonuc = catalog.resolve(ssid: "TURKSAT-DDBB-5G", coordinate: yakinNokta)

        // 5 GHz bandı yeni bir ağ gibi görünür ama ev 120 m ötede:
        // önce "Burası Ev mi?" diye sorulabilsin.
        #expect(sonuc == .unknownNetwork(nearby: [ev]))
    }

    @Test("Yeni ağ ve yakında hiçbir yer yoksa aday listesi boş gelir")
    func unknownNetworkWithNoNeighbours() {
        let catalog = PlaceCatalog(places: [yer("Ev", ssids: ["TURKSAT-DDBB"])])

        #expect(
            catalog.resolve(ssid: "Kafe-Misafir", coordinate: uzakNokta)
                == .unknownNetwork(nearby: [])
        )
    }

    @Test("Wi-Fi yoksa ağ yok sonucu döner")
    func noNetwork() {
        let catalog = PlaceCatalog(places: [yer("Ev", ssids: ["TURKSAT-DDBB"])])
        #expect(catalog.resolve(ssid: nil, coordinate: evKoordinati) == .noNetwork)
    }

    @Test("Yeni SSID mevcut yere eklenince artık eşleşir")
    func attachingSSIDMakesItMatch() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.attach(ssid: "TURKSAT-DDBB-5G", bssid: "18:48:59:0b:d0:2a", to: ev.id)

        guard case .matched(let eslesen) =
            catalog.resolve(ssid: "TURKSAT-DDBB-5G", coordinate: evKoordinati)
        else {
            Issue.record("eklenen SSID eşleşmeliydi"); return
        }
        #expect(eslesen.id == ev.id)
        #expect(eslesen.bssids.contains("18:48:59:0b:d0:2a"))
    }

    @Test("Silinen yer artık eşleşmez")
    func removedPlaceStopsMatching() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.remove(ev.id)

        #expect(catalog.places.isEmpty)
        #expect(
            catalog.resolve(ssid: "TURKSAT-DDBB", coordinate: evKoordinati)
                == .unknownNetwork(nearby: [])
        )
    }

    @Test("SSID ayrılınca o ağ eşleşmez ama yer durur")
    func detachedSSIDStopsMatchingButPlaceRemains() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB", "TURKSAT-DDBB-5G"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.detach(ssid: "TURKSAT-DDBB-5G", from: ev.id)

        #expect(catalog.place(id: ev.id)?.ssids == ["TURKSAT-DDBB"])
        guard case .matched = catalog.resolve(
            ssid: "TURKSAT-DDBB", coordinate: evKoordinati
        ) else {
            Issue.record("kalan SSID hala eslesmeli"); return
        }
        guard case .unknownNetwork = catalog.resolve(
            ssid: "TURKSAT-DDBB-5G", coordinate: evKoordinati
        ) else {
            Issue.record("ayrilan SSID eslesmemeli"); return
        }
    }

    @Test("Son SSID'si ayrılan yer katalogda kalır")
    func placeSurvivesLosingLastSSID() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        var catalog = PlaceCatalog(places: [ev])

        catalog.detach(ssid: "TURKSAT-DDBB", from: ev.id)

        // Silme ile ayirma farkli islemler: yer duruyor, sadece agsiz kaldi.
        #expect(catalog.place(id: ev.id)?.ssids.isEmpty == true)
        #expect(catalog.places.count == 1)
    }

    @Test("Görünen ad üç durumu ayırır")
    func displayNameDistinguishesThreeCases() {
        let ev = yer("Ev", ssids: ["TURKSAT-DDBB"])
        let catalog = PlaceCatalog(places: [ev])

        #expect(catalog.displayName(for: ev.id) == "Ev")
        #expect(catalog.displayName(for: nil) == "Bilinmeyen yer")
        #expect(catalog.displayName(for: UUID()) == "Silinmiş yer")
    }

    @Test("Yeniden adlandırma kalıcı")
    func renamePersists() {
        let yeni = yer("Bilinmeyen yer", ssids: ["Kafe-Misafir"])
        var catalog = PlaceCatalog(places: [yeni])

        catalog.rename(yeni.id, to: "Petra Roasting")

        #expect(catalog.place(id: yeni.id)?.displayName == "Petra Roasting")
    }
}

@Suite("Diskten geri yükleme")
struct AppStateRestoreTests {

    @Test("Kısa kapalı kalma oturumu sürdürür")
    func shortDowntimeKeepsSession() {
        let acikOturum = Session(placeID: UUID(), startedAt: t0)
        let state = AppState(
            currentSession: acikOturum,
            lastHeartbeatAt: t0.addingTimeInterval(30 * 60)
        )

        let (engine, effects) = SessionEngine.restored(
            from: state,
            now: t0.addingTimeInterval(50 * 60)
        )

        #expect(effects.isEmpty)
        #expect(engine.currentSession?.id == acikOturum.id)
    }

    @Test("Uzun kapalı kalma oturumu son yaşam belirtisinde kapatır")
    func longDowntimeClosesSession() {
        let acikOturum = Session(placeID: UUID(), startedAt: t0)
        let heartbeat = t0.addingTimeInterval(30 * 60)
        let state = AppState(currentSession: acikOturum, lastHeartbeatAt: heartbeat)

        let (engine, effects) = SessionEngine.restored(
            from: state,
            now: t0.addingTimeInterval(10 * 60 * 60)  // ertesi sabah
        )

        guard case .sessionEnded(let kapanan) = effects.first else {
            Issue.record("oturum kapanmalıydı"); return
        }
        #expect(kapanan.endedAt == heartbeat)
        #expect(engine.currentSession?.id != acikOturum.id)
        #expect(engine.elapsed(at: t0.addingTimeInterval(10 * 60 * 60)) == 0)
    }

    @Test("Açık oturum yoksa yenisi başlar")
    func coldStartOpensSession() {
        let (engine, effects) = SessionEngine.restored(from: AppState(), now: t0)

        #expect(effects.count == 1)
        #expect(engine.currentSession?.startedAt == t0)
    }
}

@Suite("JSON dosya deposu")
struct JSONFileStoreTests {

    private func geciciURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("test.json")
    }

    @Test("Yazılan değer aynen geri okunur")
    func roundTrip() throws {
        let url = geciciURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = JSONFileStore<PlaceCatalog>(url: url)
        let catalog = PlaceCatalog(places: [
            Place(ssids: ["Ev", "Ev-5G"], displayName: "Ev", createdAt: t0)
        ])

        try store.save(catalog)
        #expect(try store.load() == catalog)
    }

    @Test("Dosya yoksa nil döner, hata atmaz")
    func missingFileIsNotAnError() throws {
        let store = JSONFileStore<AppState>(url: geciciURL())
        #expect(try store.load() == nil)
    }

    @Test("Boş dosya nil döner")
    func emptyFileIsNotAnError() throws {
        let url = geciciURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: url)

        let store = JSONFileStore<AppState>(url: url)
        #expect(try store.load() == nil)
    }
}
