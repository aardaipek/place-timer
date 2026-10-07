import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Tercihler")
struct PreferencesTests {

    @Test("Varsayılanlar")
    func defaults() {
        let prefs = Preferences()

        #expect(prefs.showSeconds == false)
        #expect(prefs.showPlaceNameInMenuBar == true)
        #expect(prefs.gapThreshold == 1800)
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
        prefs.gapThreshold = 3600

        let store = JSONFileStore<Preferences>(url: url)
        try store.save(prefs)

        #expect(try store.load() == prefs)
    }

    @Test("Eksik alanlar varsayılanla dolar")
    func partialJSONDecodes() throws {
        let json = Data(#"{"showSeconds": true}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)

        #expect(decoded.showSeconds == true)
        #expect(decoded.notificationInterval == .hourly)
        #expect(decoded.gapThreshold == 1800)
    }

    @Test(
        "1.0'ın uyku eşiği en yakın ara seçeneğine taşınır",
        arguments: [
            (0.0, 900.0), (300.0, 900.0), (900.0, 900.0), (1800.0, 1800.0),
            (3600.0, 3600.0), (7200.0, 7200.0), (14400.0, 7200.0),
        ]
    )
    func legacySleepThresholdMigrates(old: Double, expected: Double) throws {
        let json = Data(
            #"{"sessionResetSleepThreshold": \#(old), "idleThreshold": 300}"#.utf8
        )
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)
        #expect(decoded.gapThreshold == expected)
    }

    @Test("Yeni anahtar eskisine üstün gelir")
    func newKeyWins() throws {
        let json = Data(#"{"gapThreshold": 3600, "sessionResetSleepThreshold": 0}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: json)
        #expect(decoded.gapThreshold == 3600)
    }

    @Test("Eski anahtarlar diske yazılmaz")
    func legacyKeysAreNotWritten() throws {
        let data = try JSONEncoder().encode(Preferences())
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("sessionResetSleepThreshold"))
        #expect(!text.contains("idleThreshold"))
        #expect(text.contains("gapThreshold"))
    }
}
