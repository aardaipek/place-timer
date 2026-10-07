import Foundation
import Testing
@testable import PlaceTimerCore

private let ev = UUID()
private let kafe = UUID()

/// Testlerin makinenin bölgesel ayarlarından etkilenmemesi için sabit takvim.
private var takvim: Calendar {
    var calendar = Calendar.placeTimer
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}

private func gun(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
    takvim.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func oturum(_ placeID: UUID?, from start: Date, to end: Date?) -> Session {
    Session(placeID: placeID, startedAt: start, endedAt: end)
}

private func hafta(_ date: Date) -> StatsPeriod {
    .containing(date, scope: .week, calendar: takvim)
}

@Suite("İstatistik dönemi")
struct StatsPeriodTests {

    @Test("Hafta pazartesi başlar, sistem bölgesinden bağımsız")
    func weekStartsMonday() {
        // 20 Eylül 2026 pazar; hafta 14 Eylül pazartesi başlamalı.
        let period = hafta(gun(20, 12))
        #expect(period.interval.start == gun(14, 0))
        #expect(period.interval.end == gun(21, 0))
    }

    @Test("Varsayılan takvim de pazartesi başlar")
    func defaultCalendarStartsMonday() {
        #expect(Calendar.placeTimer.firstWeekday == 2)
    }

    @Test("Önceki ve sonraki dönem")
    func shifting() {
        let period = hafta(gun(16, 12))
        #expect(period.shifted(by: -1, calendar: takvim) == hafta(gun(9, 12)))
        #expect(period.shifted(by: 1, calendar: takvim) == hafta(gun(23, 12)))
    }

    @Test("Başlıklar bugüne göre adlandırılır")
    func titles() {
        let simdi = gun(16, 12)
        let gunDonemi = StatsPeriod.containing(simdi, scope: .day, calendar: takvim)
        #expect(gunDonemi.title(now: simdi, calendar: takvim) == "Bugün")
        #expect(gunDonemi.shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Dün")
        #expect(hafta(simdi).title(now: simdi, calendar: takvim) == "Bu hafta")
        #expect(hafta(simdi).shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Geçen hafta")
        let ay = StatsPeriod.containing(simdi, scope: .month, calendar: takvim)
        #expect(ay.title(now: simdi, calendar: takvim) == "Bu ay")
        #expect(ay.shifted(by: -1, calendar: takvim).title(now: simdi, calendar: takvim) == "Geçen ay")
        #expect(ay.shifted(by: -2, calendar: takvim).title(now: simdi, calendar: takvim).contains("Temmuz"))
    }
}

@Suite("Kırpma ve toplamlar")
struct TotalsTests {

    @Test("Geceyi aşan oturum iki güne bölünür")
    func midnightSplit() {
        let gece = [oturum(ev, from: gun(16, 23), to: gun(17, 1))]
        let gunler = dailyTotals(from: gece, in: hafta(gun(16, 12)), now: gun(18, 12), calendar: takvim)

        #expect(gunler.first { $0.day == gun(16, 0) }?.total == 3600)
        #expect(gunler.first { $0.day == gun(17, 0) }?.total == 3600)

        let carsamba = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        #expect(placeTotals(from: gece, in: carsamba, now: gun(18, 12)).first?.totalSeconds == 3600)
    }

    @Test("Hafta sınırını aşan oturum iki haftaya bölünür")
    func weekBoundarySplit() {
        let gece = [oturum(ev, from: gun(20, 23), to: gun(21, 2))]
        let simdi = gun(22, 12)
        #expect(totalSeconds(from: gece, in: hafta(gun(20, 12)).interval, now: simdi) == 3600)
        #expect(totalSeconds(from: gece, in: hafta(gun(21, 12)).interval, now: simdi) == 2 * 3600)
    }

    @Test("Açık oturum şu ana kadar sayılır")
    func openSessionCountsUntilNow() {
        let acik = [oturum(ev, from: gun(16, 9), to: nil)]
        let bugun = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        #expect(placeTotals(from: acik, in: bugun, now: gun(16, 12)).first?.totalSeconds == 10800)
    }

    @Test("Yerler toplam süreye göre azalan sıralanır, oturum sayısı tutulur")
    func placeTotalsSorted() {
        let oturumlar = [
            oturum(ev, from: gun(16, 9), to: gun(16, 10)),
            oturum(kafe, from: gun(16, 11), to: gun(16, 14)),
            oturum(ev, from: gun(16, 15), to: gun(16, 16)),
        ]
        let bugun = StatsPeriod.containing(gun(16, 12), scope: .day, calendar: takvim)
        let toplamlar = placeTotals(from: oturumlar, in: bugun, now: gun(16, 20))
        #expect(toplamlar.map(\.placeID) == [kafe, ev])
        #expect(toplamlar.last?.sessionCount == 2)
    }

    @Test("Karşılaştırma önceki dönemin aynı anına kadar yapılır")
    func comparisonUsesSamePortion() {
        let oturumlar = [
            oturum(ev, from: gun(7, 9), to: gun(7, 11)),    // geçen pzt 2sa
            oturum(ev, from: gun(11, 9), to: gun(11, 12)),  // geçen cuma 3sa
        ]
        // Bu hafta çarşamba öğlen: geçen haftanın çarşamba öğlenine kadarı.
        let simdi = gun(16, 12)
        #expect(previousComparableTotal(from: oturumlar, for: hafta(simdi), now: simdi, calendar: takvim) == 2 * 3600)
    }

    @Test("Bitmiş dönem önceki dönemin tamamıyla karşılaştırılır")
    func finishedPeriodComparesWhole() {
        let oturumlar = [
            oturum(ev, from: gun(7, 9), to: gun(7, 11)),    // 7–13 Eyl haftası: 2sa
            oturum(ev, from: gun(11, 9), to: gun(11, 12)),  // aynı hafta: 3sa
        ]
        // 14–20 Eyl haftası bitmiş (şimdi 28 Eyl); öncesi bütünüyle 5sa.
        let bitmis = hafta(gun(16, 12))
        #expect(previousComparableTotal(from: oturumlar, for: bitmis, now: gun(28, 12), calendar: takvim) == 5 * 3600)
    }

    @Test("Gün listesi en yeni gün başta, boş gün yok")
    func sessionDaysNewestFirst() {
        let oturumlar = [
            oturum(ev, from: gun(14, 9), to: gun(14, 10)),
            oturum(kafe, from: gun(16, 9), to: gun(16, 10)),
            oturum(ev, from: gun(16, 11), to: gun(16, 12)),
        ]
        let gunler = sessionDays(from: oturumlar, in: hafta(gun(16, 12)), now: gun(16, 20), calendar: takvim)
        #expect(gunler.map(\.day) == [gun(16, 0), gun(14, 0)])
        #expect(gunler.first?.sessions.map(\.startedAt) == [gun(16, 11), gun(16, 9)])
        #expect(gunler.first?.placeCount == 2)
        #expect(gunler.first?.total == 7200)
    }

    @Test("Ayın günleri yaz saati geçişinde de doğru sayılır")
    func monthDaysAcrossDST() {
        var berlin = Calendar.placeTimer
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let ekim = StatsPeriod.containing(
            berlin.date(from: DateComponents(year: 2026, month: 10, day: 10))!,
            scope: .month, calendar: berlin
        )
        #expect(dailyTotals(from: [], in: ekim, now: Date(), calendar: berlin).count == 31)
    }

    @Test("Veri yokken her şey boş döner")
    func emptyInputs() {
        let period = hafta(gun(16, 12))
        #expect(placeTotals(from: [], in: period, now: gun(16, 12)).isEmpty)
        #expect(sessionDays(from: [], in: period, now: gun(16, 12), calendar: takvim).isEmpty)
        #expect(dailyTotals(from: [], in: period, now: gun(16, 12), calendar: takvim).allSatisfy { $0.total == 0 })
    }
}

@Suite("Gün şeridi")
struct DaySegmentTests {

    @Test("Segmentler güne kırpılır ve sıralıdır")
    func clippedAndSorted() {
        let oturumlar = [
            oturum(kafe, from: gun(16, 12), to: gun(16, 14)),
            oturum(ev, from: gun(15, 22), to: gun(16, 2)),
            oturum(ev, from: gun(17, 9), to: gun(17, 10)),
        ]
        let segmentler = daySegments(from: oturumlar, on: gun(16, 12), now: gun(16, 20), calendar: takvim)
        #expect(segmentler.count == 2)
        #expect(segmentler.first?.start == gun(16, 0))
        #expect(segmentler.first?.end == gun(16, 2))
        #expect(segmentler.last?.placeID == kafe)
    }

    @Test("Açık oturum şu ana kadar uzanır")
    func openSessionExtendsToNow() {
        let acik = [oturum(ev, from: gun(16, 9), to: nil)]
        let segmentler = daySegments(from: acik, on: gun(16, 12), now: gun(16, 12), calendar: takvim)
        #expect(segmentler.first?.end == gun(16, 12))
    }

    @Test("Boş günde segment yoktur")
    func emptyDay() {
        #expect(daySegments(from: [], on: gun(16, 12), now: gun(16, 12), calendar: takvim).isEmpty)
    }
}

@Suite("CSV")
struct CSVTests {

    @Test("Dönemin oturumları kırpılmış süreyle yazılır")
    func csvRows() {
        let oturumlar = [
            oturum(ev, from: gun(16, 9), to: gun(16, 10, 30)),
            oturum(kafe, from: gun(20, 23), to: gun(21, 1)),
        ]
        let csv = sessionsCSV(
            oturumlar, in: hafta(gun(16, 12)), now: gun(22, 12),
            timeZone: TimeZone(identifier: "Europe/Istanbul")!
        ) { $0 == ev ? "Ev, \"merkez\"" : "Kafe" }

        let satirlar = csv.split(separator: "\n").map(String.init)
        #expect(satirlar.first == "başlangıç,bitiş,süre_dk,yer")
        #expect(satirlar[1] == #"2026-09-16 09:00,2026-09-16 10:30,90,"Ev, ""merkez""""#)
        #expect(satirlar[2] == "2026-09-20 23:00,2026-09-21 01:00,60,Kafe")
    }

    @Test("Oturum yoksa yalnızca başlık yazılır")
    func emptyCSV() {
        let csv = sessionsCSV([], in: hafta(gun(16, 12)), now: gun(16, 12), timeZone: .current) { _ in "" }
        #expect(csv == "başlangıç,bitiş,süre_dk,yer\n")
    }
}
