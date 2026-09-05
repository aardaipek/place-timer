import Foundation
import Testing
@testable import PlaceTimerCore

private let ofis = UUID()

@Suite("Manuel yer seçimi")
struct ManualPlaceSelectionTests {

    @Test("Aynı ağ üzerinde geçerli kalır")
    func staysOnSameNetwork() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: "Kafe-Misafir"))
    }

    @Test("Ağ değişince düşer")
    func dropsWhenNetworkChanges() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: "Baska-Ag") == false)
    }

    @Test("Ağ kesilince düşer")
    func dropsWhenNetworkDisappears() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: "Kafe-Misafir")
        #expect(secim.applies(to: nil) == false)
    }

    @Test("Wi-Fi yokken yapılan seçim ağsız kaldıkça geçerlidir")
    func offlineSelectionSurvivesWhileOffline() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: nil)
        #expect(secim.applies(to: nil))
    }

    @Test("Wi-Fi yokken yapılan seçim ilk ağ görülünce düşer")
    func offlineSelectionDropsOnFirstNetwork() {
        let secim = ManualPlaceSelection(placeID: ofis, ssid: nil)
        #expect(secim.applies(to: "Herhangi-Ag") == false)
    }
}
