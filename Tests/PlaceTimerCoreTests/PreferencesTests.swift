import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Tercihler")
struct PreferencesTests {

    @Test("Varsayılanlar v1 davranışını korur")
    func defaultsMatchV1() {
        let prefs = Preferences()

        #expect(prefs.showSeconds == false)
        #expect(prefs.showPlaceNameInMenuBar == true)
        #expect(prefs.sessionResetSleepThreshold == 3600)
        #expect(prefs.idleThreshold == 300)
        #expect(prefs.notificationInterval == .hourly)
    }

    @Test("Bildirim aralıkları saniyeye çevrilir")
    func intervalSeconds() {
        #expect(NotificationInterval.off.seconds == nil)
        #expect(NotificationInterval.every30Minutes.seconds == 1800)
        #expect(NotificationInterval.hourly.seconds == 3600)
    }

    @Test("Diske yazılıp aynen geri okunur")
    func roundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("preferences.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var prefs = Preferences()
        prefs.showSeconds = true
        prefs.notificationInterval = .every30Minutes
        prefs.idleThreshold = 120

        let store = JSONFileStore<Preferences>(url: url)
        try store.save(prefs)

        #expect(try store.load() == prefs)
    }

    @Test("Eksik alanlar varsayılanla dolar")
    func partialJSONDecodes() throws {
        // Ileride yeni bir ayar eklendiginde eski dosya bozulmamali.
        let json = Data(#"{"showSeconds": true}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)

        #expect(decoded.showSeconds == true)
        #expect(decoded.notificationInterval == .hourly)
        #expect(decoded.idleThreshold == 300)
    }
}
