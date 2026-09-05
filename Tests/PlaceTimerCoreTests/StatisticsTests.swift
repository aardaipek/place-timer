import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()

/// Testlerin makinenin bölgesel ayarlarından etkilenmemesi için sabit takvim.
private var takvim: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    calendar.firstWeekday = 2   // Pazartesi
    return calendar
}

private func gun(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
    takvim.date(
        from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )
    )!
}

private func oturum(
    _ placeID: UUID?,
    from start: Date,
    to end: Date?,
    active: TimeInterval = 0
) -> Session {
    Session(placeID: placeID, startedAt: start, endedAt: end, activeSeconds: active)
}

@Suite("Yer toplamları")
struct PlaceTotalsTests {

    private let simdi = gun(9, 15)

    // 9 Eylul 2026 Carsamba; takvim haftasi Pazartesi 7'sinde basliyor.
    private var oturumlar: [Session] {
        [
            oturum(ev, from: gun(9, 9), to: gun(9, 11), active: 3600),    // bugun 2sa
            oturum(kafe, from: gun(9, 12), to: gun(9, 14), active: 5400), // bugun 2sa
            oturum(ev, from: gun(7, 9), to: gun(7, 13), active: 7200),    // Pzt, bu hafta 4sa
            oturum(ev, from: gun(2, 9), to: gun(2, 12), active: 3600),    // gecen hafta, bu ay 3sa
            oturum(kafe, from: gun(28, 9, month: 8), to: gun(28, 12, month: 8)), // gecen ay
        ]
    }

    @Test("Bugün yalnızca bugünün oturumlarını sayar")
    func todayOnly() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.count == 2)
        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 2.0 * 3600)
        #expect(toplamlar.first { $0.placeID == kafe }?.totalSeconds == 2.0 * 3600)
    }

    @Test("Hafta takvim haftasıdır, kayan 7 gün değil")
    func weekIsCalendarWeek() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .week, now: simdi, calendar: takvim
        )

        // Pazartesi 7 + Carsamba 9 = 6 saat ev; 2 eylul haftaya girmez.
        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 6.0 * 3600)
        #expect(toplamlar.first { $0.placeID == ev }?.sessionCount == 2)
    }

    @Test("Ay takvim ayıdır")
    func monthIsCalendarMonth() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .month, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first { $0.placeID == ev }?.totalSeconds == 9.0 * 3600)
        // 28 agustos eylul ayina girmez.
        #expect(toplamlar.first { $0.placeID == kafe }?.totalSeconds == 2.0 * 3600)
    }

    @Test("Toplam süreye göre azalan sıralanır")
    func sortedDescending() {
        let uzun = oturum(kafe, from: gun(9, 8), to: gun(9, 14))
        let kisa = oturum(ev, from: gun(9, 15), to: gun(9, 16))

        let toplamlar = placeTotals(
            from: [kisa, uzun], range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.map(\.placeID) == [kafe, ev])
    }

    @Test("Açık oturum şu ana kadar sayılır")
    func openSessionCountsUntilNow() {
        let acik = oturum(kafe, from: gun(9, 14), to: nil)

        let toplamlar = placeTotals(
            from: [acik], range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first?.totalSeconds == 3600)
    }

    @Test("Aktif süre ayrı toplanır")
    func activeSecondsAccumulate() {
        let toplamlar = placeTotals(
            from: oturumlar, range: .today, now: simdi, calendar: takvim
        )

        #expect(toplamlar.first { $0.placeID == ev }?.activeSeconds == 3600)
        #expect(toplamlar.first { $0.placeID == kafe }?.activeSeconds == 5400)
    }

    @Test("Oturum yoksa liste boş döner")
    func emptyWhenNoSessions() {
        #expect(
            placeTotals(from: [], range: .today, now: simdi, calendar: takvim).isEmpty
        )
    }
}

@Suite("Gün şeridi")
struct DaySegmentsTests {

    @Test("Segmentler oturumları izler, boşluklar segment üretmez")
    func gapsProduceNoSegments() {
        let oturumlar = [
            oturum(ev, from: gun(9, 9), to: gun(9, 11)),
            oturum(kafe, from: gun(9, 13), to: gun(9, 15)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        // 11:00-13:00 arasi bosluk; ucuncu bir segment olusmaz.
        #expect(segmentler.count == 2)
        #expect(segmentler[0].placeID == ev)
        #expect(segmentler[0].start == gun(9, 9))
        #expect(segmentler[0].end == gun(9, 11))
        #expect(segmentler[1].start == gun(9, 13))
    }

    @Test("Başka günün oturumları girmez")
    func otherDaysExcluded() {
        let oturumlar = [
            oturum(ev, from: gun(8, 9), to: gun(8, 17)),
            oturum(kafe, from: gun(9, 10), to: gun(9, 12)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        #expect(segmentler.count == 1)
        #expect(segmentler[0].placeID == kafe)
    }

    @Test("Açık oturum şu ana kadar uzanır")
    func openSegmentEndsNow() {
        let simdi = gun(9, 16)
        let segmentler = daySegments(
            from: [oturum(kafe, from: gun(9, 14), to: nil)],
            on: simdi,
            calendar: takvim
        )

        #expect(segmentler.first?.end == simdi)
    }

    @Test("Zamana göre sıralı döner")
    func sortedByTime() {
        let oturumlar = [
            oturum(kafe, from: gun(9, 13), to: gun(9, 15)),
            oturum(ev, from: gun(9, 9), to: gun(9, 11)),
        ]

        let segmentler = daySegments(from: oturumlar, on: gun(9, 16), calendar: takvim)

        #expect(segmentler.map(\.placeID) == [ev, kafe])
    }

    @Test("Boş günde segment yoktur")
    func emptyDay() {
        #expect(daySegments(from: [], on: gun(9, 16), calendar: takvim).isEmpty)
    }
}
