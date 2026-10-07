import Foundation
import Testing
@testable import PlaceTimerCore

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func yer(_ name: String, lat: Double? = nil, lon: Double? = nil, created: Double = 0) -> Place {
    Place(ssids: [UUID().uuidString], displayName: name, latitude: lat, longitude: lon, createdAt: at(created))
}

private func oturum(_ placeID: UUID?, _ start: Double, _ end: Double?) -> Session {
    Session(placeID: placeID, startedAt: at(start), endedAt: end.map(at))
}

@Suite("Öneriler")
struct SuggestionsTests {

    @Test("Aynı adlı iki yer için birleştirme önerilir, eski olan kalır")
    func sameNameSuggestsMerge() {
        let eski = yer("Home", created: 0)
        let yeni = yer(" home ", created: 10)
        let sonuc = suggestions(places: [yeni, eski], sessions: [], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.samePlace(keep: eski.id, merge: yeni.id)])
    }

    @Test("Aksan farkı aynı ad sayılır")
    func diacriticsIgnored() {
        let a = yer("Ofis Çalışma", created: 0)
        let b = yer("ofis calisma", created: 1)
        #expect(suggestions(places: [a, b], sessions: [], dismissed: [], gapThreshold: 1800).count == 1)
    }

    @Test("150 metre içindeki iki yer için birleştirme önerilir")
    func nearbySuggestsMerge() {
        let a = yer("Ev", lat: 41.0, lon: 29.0, created: 0)
        let b = yer("Ev-5G", lat: 41.0005, lon: 29.0, created: 1)   // ~55 m
        let c = yer("Kafe", lat: 41.01, lon: 29.0, created: 2)      // ~1 km
        let sonuc = suggestions(places: [a, b, c], sessions: [], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.samePlace(keep: a.id, merge: b.id)])
    }

    @Test("Aynı yerde kısa arayla bölünmüş oturumlar önerilir")
    func splitSessionSuggested() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let b = oturum(ev, 100, 160)     // 40 dk ara, 3×30 = 90 dk altında
        let c = oturum(ev, 300, 360)     // 140 dk ara: önerilmez
        let sonuc = suggestions(places: [], sessions: [a, b, c], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.splitSession(first: a.id, second: b.id)])
    }

    @Test("Açık oturum bölünmüş çiftin ikincisi olabilir")
    func openSessionCanBeSecond() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let acik = oturum(ev, 70, nil)
        #expect(suggestions(places: [], sessions: [a, acik], dismissed: [], gapThreshold: 1800)
            == [.splitSession(first: a.id, second: acik.id)])
    }

    @Test("İki dakikadan kısa kapanmış oturum silinmek üzere önerilir")
    func emptySessionSuggested() {
        let ev = UUID()
        let bos = oturum(ev, 0, 1)
        let sonuc = suggestions(places: [], sessions: [bos], dismissed: [], gapThreshold: 1800)
        #expect(sonuc == [.emptySession(bos.id)])
    }

    @Test("Boş oturum bölünmüş çifte girmez")
    func emptyNotInSplit() {
        let ev = UUID()
        let a = oturum(ev, 0, 60)
        let bos = oturum(ev, 65, 66)
        #expect(suggestions(places: [], sessions: [a, bos], dismissed: [], gapThreshold: 1800)
            == [.emptySession(bos.id)])
    }

    @Test("Reddedilen öneri bir daha çıkmaz")
    func dismissedHidden() {
        let ev = UUID()
        let bos = oturum(ev, 0, 1)
        let oneri = Suggestion.emptySession(bos.id)
        #expect(suggestions(places: [], sessions: [bos], dismissed: [oneri.id], gapThreshold: 1800).isEmpty)
    }

    @Test("Kimlik kararlıdır: yer sırası değişse de aynıdır")
    func stableIDs() {
        let a = UUID(), b = UUID()
        #expect(Suggestion.samePlace(keep: a, merge: b).id == Suggestion.samePlace(keep: b, merge: a).id)
    }

    @Test("Veri yokken öneri yoktur")
    func emptyInput() {
        #expect(suggestions(places: [], sessions: [], dismissed: [], gapThreshold: 1800).isEmpty)
    }

    @Test("Durum dosyası eksik alanla okunur")
    func stateDecodes() throws {
        let state = try JSONDecoder().decode(SuggestionState.self, from: Data("{}".utf8))
        #expect(state.dismissed.isEmpty)
        #expect(state.acceptedSplits == 0)
    }
}
