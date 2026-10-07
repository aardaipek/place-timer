import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Menubar görünümü")
struct MenuBarStyleTests {

    @Test("Varsayılan görünüm halka")
    func defaultIsRing() {
        #expect(Preferences().menuBarStyle == .ring)
    }

    @Test("Eski tercih dosyası halkaya düşer")
    func legacyFileDefaultsToRing() throws {
        let json = Data(#"{"showSeconds":true}"#.utf8)
        let prefs = try JSONDecoder().decode(Preferences.self, from: json)
        #expect(prefs.menuBarStyle == .ring)
        #expect(prefs.showSeconds)
    }

    @Test("Seçilen görünüm diske yazılıp geri okunur")
    func roundTrip() throws {
        var prefs = Preferences()
        prefs.menuBarStyle = .pill
        let data = try JSONEncoder().encode(prefs)
        #expect(try JSONDecoder().decode(Preferences.self, from: data).menuBarStyle == .pill)
    }

    @Test(
        "Halka içinde bulunulan saatin dolan kısmını gösterir",
        arguments: [
            (0.0, 0.0),
            (900.0, 0.25),
            (1800.0, 0.5),
            (3600.0, 0.0),
            (5400.0, 0.5),
            (-10.0, 0.0),
        ]
    )
    func hourProgress(elapsed: Double, expected: Double) {
        #expect(MenuBarStyle.hourProgress(elapsed) == expected)
    }
}
