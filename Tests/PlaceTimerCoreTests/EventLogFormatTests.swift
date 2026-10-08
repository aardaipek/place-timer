import Foundation
import Testing
@testable import PlaceTimerCore

@Suite("Olay günlüğü biçimi")
struct EventLogFormatTests {

    private let simdi = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("Satır zaman damgası ve mesajdan oluşur, tek satırdır")
    func lineFormat() {
        let satir = EventLogFormat.line("wifi ssid=Ev\nbssid=x", at: simdi)
        #expect(satir.hasSuffix("wifi ssid=Ev bssid=x\n"))
        #expect(satir.filter { $0 == "\n" }.count == 1)
        #expect(satir.hasPrefix("20"))
    }

    @Test("14 günden eski satırlar budanır")
    func prunesOldLines() {
        let eski = EventLogFormat.line("eski", at: simdi.addingTimeInterval(-15 * 86400))
        let yeni = EventLogFormat.line("yeni", at: simdi.addingTimeInterval(-86400))
        let sonuc = EventLogFormat.pruned(eski + yeni, now: simdi)
        #expect(sonuc == yeni)
    }

    @Test("Okunamayan satırlar atılır")
    func dropsGarbage() {
        let yeni = EventLogFormat.line("yeni", at: simdi)
        #expect(EventLogFormat.pruned("bozuk satır\n" + yeni, now: simdi) == yeni)
    }
}
