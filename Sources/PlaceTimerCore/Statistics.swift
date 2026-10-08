import Foundation

extension Calendar {
    /// İstatistiğin takvimi. Arayüz Türkçe: sistem bölgesi en_US olsa bile
    /// "bu hafta" pazar değil pazartesi başlamalı.
    public static var placeTimer: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .current
        return calendar
    }
}

private let turkish = Locale(identifier: "tr_TR")

/// Bir yerin belirli bir dönemdeki toplamı.
public struct PlaceTotal: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let totalSeconds: TimeInterval
    public let sessionCount: Int

    public var id: String { placeID?.uuidString ?? "bilinmeyen" }

    public init(placeID: UUID?, totalSeconds: TimeInterval, sessionCount: Int) {
        self.placeID = placeID
        self.totalSeconds = totalSeconds
        self.sessionCount = sessionCount
    }
}

/// İstatistiğin ölçeği. Dönemler takvim tabanlıdır, kayan pencere değil.
public enum StatsScope: String, Sendable, CaseIterable, Hashable {
    case day, week, month

    public var displayName: String {
        switch self {
        case .day: "Gün"
        case .week: "Hafta"
        case .month: "Ay"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// Belirli bir gün, hafta ya da ay. Geçmişte gezinmek `shifted(by:)` ile.
public struct StatsPeriod: Sendable, Hashable {
    public let scope: StatsScope
    public let interval: DateInterval

    public static func containing(
        _ date: Date,
        scope: StatsScope,
        calendar: Calendar = .placeTimer
    ) -> StatsPeriod {
        let interval = calendar.dateInterval(of: scope.component, for: date)
            ?? DateInterval(start: date, duration: 0)
        return StatsPeriod(scope: scope, interval: interval)
    }

    public func shifted(by steps: Int, calendar: Calendar = .placeTimer) -> StatsPeriod {
        let anchor = calendar.date(byAdding: scope.component, value: steps, to: interval.start)
            ?? interval.start
        return .containing(anchor, scope: scope, calendar: calendar)
    }

    /// Bitiş hariç: gece yarısı ertesi güne aittir.
    public func contains(_ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    /// "Bugün", "Geçen hafta", "22–28 Eyl", "Temmuz 2026".
    public func title(now: Date, calendar: Calendar = .placeTimer) -> String {
        let current = StatsPeriod.containing(now, scope: scope, calendar: calendar)
        if self == current {
            switch scope {
            case .day: return "Bugün"
            case .week: return "Bu hafta"
            case .month: return "Bu ay"
            }
        }
        if self == current.shifted(by: -1, calendar: calendar) {
            switch scope {
            case .day: return "Dün"
            case .week: return "Geçen hafta"
            case .month: return "Geçen ay"
            }
        }

        var style = Date.FormatStyle(locale: turkish, calendar: calendar, timeZone: calendar.timeZone)
        switch scope {
        case .day:
            style = style.weekday(.abbreviated).day().month(.abbreviated)
            return interval.start.formatted(style)
        case .week:
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let sameMonth = calendar.isDate(interval.start, equalTo: last, toGranularity: .month)
            let startText = interval.start.formatted(
                sameMonth ? style.day() : style.day().month(.abbreviated)
            )
            return "\(startText)–\(last.formatted(style.day().month(.abbreviated)))"
        case .month:
            return interval.start.formatted(style.month(.wide).year())
        }
    }
}

// MARK: - Kırpma

/// Oturumun bir aralığa düşen kısmı. Açık oturum `now`'a kadar sayılır.
public func overlap(of session: Session, with interval: DateInterval, now: Date) -> TimeInterval {
    let start = max(session.startedAt, interval.start)
    let end = min(session.endedAt ?? now, interval.end)
    return max(0, end.timeIntervalSince(start))
}

public func totalSeconds(from sessions: [Session], in interval: DateInterval, now: Date) -> TimeInterval {
    sessions.reduce(0) { $0 + overlap(of: $1, with: interval, now: now) }
}

/// Aralıkla kesişen oturumlar, en yenisi başta.
public func sessionsOverlapping(
    _ sessions: [Session],
    interval: DateInterval,
    now: Date
) -> [Session] {
    sessions
        .filter { overlap(of: $0, with: interval, now: now) > 0 }
        .sorted { $0.startedAt > $1.startedAt }
}

// MARK: - Toplamlar

/// Oturumları yere göre toplar; toplam süreye göre azalan.
public func placeTotals(from sessions: [Session], in period: StatsPeriod, now: Date) -> [PlaceTotal] {
    var accumulator: [UUID?: (total: TimeInterval, count: Int)] = [:]
    for session in sessions {
        let seconds = overlap(of: session, with: period.interval, now: now)
        guard seconds > 0 else { continue }
        var entry = accumulator[session.placeID] ?? (0, 0)
        entry.total += seconds
        entry.count += 1
        accumulator[session.placeID] = entry
    }
    return accumulator
        .map { PlaceTotal(placeID: $0.key, totalSeconds: $0.value.total, sessionCount: $0.value.count) }
        .sorted { $0.totalSeconds > $1.totalSeconds }
}

/// Önceki dönemin toplamı. Dönem henüz sürüyorsa önceki dönem de aynı
/// noktaya kadar sayılır: çarşamba öğlen "bu hafta"yı geçen haftanın tamamıyla
/// kıyaslamak her hafta "eksik" gösterirdi.
public func previousComparableTotal(
    from sessions: [Session],
    for period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> TimeInterval {
    let previous = period.shifted(by: -1, calendar: calendar).interval
    guard period.contains(now) else {
        return totalSeconds(from: sessions, in: previous, now: now)
    }
    let elapsed = now.timeIntervalSince(period.interval.start)
    let cutoff = min(previous.end, previous.start.addingTimeInterval(elapsed))
    return totalSeconds(from: sessions, in: DateInterval(start: previous.start, end: cutoff), now: now)
}

/// Bir günde bir yerin payı.
public struct PlaceShare: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let seconds: TimeInterval
    public var id: String { placeID?.uuidString ?? "bilinmeyen" }
}

/// Grafiğin bir çubuğu.
public struct DayTotal: Sendable, Equatable, Identifiable {
    public let day: Date
    public let shares: [PlaceShare]
    public var total: TimeInterval { shares.reduce(0) { $0 + $1.seconds } }
    public var id: Date { day }
}

/// Dönemin her günü (boş günler dahil), eskiden yeniye.
public func dailyTotals(
    from sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [DayTotal] {
    days(in: period.interval, calendar: calendar).map { day in
        var byPlace: [UUID?: TimeInterval] = [:]
        for session in sessions {
            let seconds = overlap(of: session, with: day, now: now)
            if seconds > 0 { byPlace[session.placeID, default: 0] += seconds }
        }
        let shares = byPlace
            .map { PlaceShare(placeID: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
        return DayTotal(day: day.start, shares: shares)
    }
}

/// Oturum listesinin bir bölümü.
public struct SessionDay: Sendable, Equatable, Identifiable {
    public let day: Date
    /// O günle kesişen oturumlar, en yenisi başta. Geceyi aşan bir oturum iki
    /// günde de görünür.
    public let sessions: [Session]
    /// Oturumların o güne düşen toplamı.
    public let total: TimeInterval
    /// O gün kaç farklı yer var; tek yerse satırlar yer adını tekrarlamaz.
    public let placeCount: Int
    public var id: Date { day }
}

/// Dönemin oturumlu günleri, en yeni gün başta. Gelecek ve boş günler yok.
public func sessionDays(
    from sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [SessionDay] {
    days(in: period.interval, calendar: calendar)
        .filter { $0.start <= now }
        .reversed()
        .compactMap { day in
            let daySessions = sessionsOverlapping(sessions, interval: day, now: now)
            guard !daySessions.isEmpty else { return nil }
            return SessionDay(
                day: day.start,
                sessions: daySessions,
                total: totalSeconds(from: daySessions, in: day, now: now),
                placeCount: Set(daySessions.map(\.placeID)).count
            )
        }
}

private func days(in interval: DateInterval, calendar: Calendar) -> [DateInterval] {
    var result: [DateInterval] = []
    var cursor = calendar.startOfDay(for: interval.start)
    while cursor < interval.end {
        guard let day = calendar.dateInterval(of: .day, for: cursor) else { break }
        result.append(day)
        cursor = day.end
    }
    return result
}

// MARK: - Gün şeridi

/// Gün şeridinin tek bir parçası.
public struct DaySegment: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let start: Date
    public let end: Date

    public var id: Date { start }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(placeID: UUID?, start: Date, end: Date) {
        self.placeID = placeID
        self.start = start
        self.end = end
    }
}

/// Bir günün oturumları zaman sırasıyla, güne kırpılmış. Oturumlar arası
/// boşluklar segment üretmez: "bilgisayar kapalıydı" ile "buradaydım" ayrışır.
public func daySegments(
    from sessions: [Session],
    on day: Date,
    now: Date,
    calendar: Calendar = .placeTimer
) -> [DaySegment] {
    guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
    return sessions
        .filter { overlap(of: $0, with: interval, now: now) > 0 }
        .sorted { $0.startedAt < $1.startedAt }
        .map {
            DaySegment(
                placeID: $0.placeID,
                start: max($0.startedAt, interval.start),
                end: min($0.endedAt ?? now, interval.end)
            )
        }
}

// MARK: - Dışa aktarma

/// Dönemin oturumları CSV olarak, eskiden yeniye. Süre döneme kırpılmış
/// dakikadır; saatler oturumun kendi başlangıç ve bitişidir.
public func sessionsCSV(
    _ sessions: [Session],
    in period: StatsPeriod,
    now: Date,
    timeZone: TimeZone = .current,
    placeName: (UUID?) -> String
) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    var lines = ["başlangıç,bitiş,süre_dk,yer"]
    for session in sessionsOverlapping(sessions, interval: period.interval, now: now).reversed() {
        let minutes = Int(overlap(of: session, with: period.interval, now: now) / 60)
        lines.append([
            formatter.string(from: session.startedAt),
            session.endedAt.map(formatter.string(from:)) ?? "",
            String(minutes),
            csvField(placeName(session.placeID)),
        ].joined(separator: ","))
    }
    return lines.joined(separator: "\n") + "\n"
}

private func csvField(_ value: String) -> String {
    guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
    return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
