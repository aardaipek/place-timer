import Foundation

/// Bir yerin belirli bir aralıktaki toplamı.
public struct PlaceTotal: Sendable, Equatable, Identifiable {
    public let placeID: UUID?
    public let totalSeconds: TimeInterval
    public let activeSeconds: TimeInterval
    public let sessionCount: Int

    public var id: String { placeID?.uuidString ?? "bilinmeyen" }

    public init(
        placeID: UUID?,
        totalSeconds: TimeInterval,
        activeSeconds: TimeInterval,
        sessionCount: Int
    ) {
        self.placeID = placeID
        self.totalSeconds = totalSeconds
        self.activeSeconds = activeSeconds
        self.sessionCount = sessionCount
    }
}

/// Takvim tabanlı aralıklar. `week` içinde bulunulan takvim haftası,
/// `month` içinde bulunulan takvim ayıdır — kayan 7/30 günlük pencere değil.
/// "Bu hafta" ifadesi takvim haftasını çağrıştırır.
public enum StatsRange: Sendable, CaseIterable {
    case today, week, month

    public var displayName: String {
        switch self {
        case .today: "Bugün"
        case .week: "Bu hafta"
        case .month: "Bu ay"
        }
    }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .today: calendar.dateInterval(of: .day, for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)
        case .month: calendar.dateInterval(of: .month, for: date)
        }
    }
}

/// Oturumları yere göre toplar. Toplam süreye göre azalan sıralı döner.
///
/// Açık oturumlar (`endedAt == nil`) `now`'a kadar sayılır.
public func placeTotals(
    from sessions: [Session],
    range: StatsRange,
    now: Date,
    calendar: Calendar = .current
) -> [PlaceTotal] {
    guard let interval = range.interval(containing: now, calendar: calendar) else {
        return []
    }

    var accumulator: [UUID?: (total: TimeInterval, active: TimeInterval, count: Int)] = [:]

    for session in sessions where interval.contains(session.startedAt) {
        var entry = accumulator[session.placeID] ?? (0, 0, 0)
        entry.total += session.elapsed(at: now)
        entry.active += session.activeSeconds
        entry.count += 1
        accumulator[session.placeID] = entry
    }

    return accumulator
        .map {
            PlaceTotal(
                placeID: $0.key,
                totalSeconds: $0.value.total,
                activeSeconds: $0.value.active,
                sessionCount: $0.value.count
            )
        }
        .sorted { $0.totalSeconds > $1.totalSeconds }
}

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

/// Bir günün oturumlarını zaman sırasına dizer.
///
/// Oturumlar arası boşluklar segment üretmez; şeritte boş alan olarak
/// görünürler. Böylece "bilgisayar kapalıydı" ile "buradaydım" ayrışır.
///
/// - Parameter day: Hem hangi günün isteneceğini hem de "şimdi"nin ne olduğunu
///   belirler; açık oturum bu ana kadar uzatılır. Bugün için `Date()` geçin.
public func daySegments(
    from sessions: [Session],
    on day: Date,
    calendar: Calendar = .current
) -> [DaySegment] {
    sessions
        .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
        .sorted { $0.startedAt < $1.startedAt }
        .map {
            DaySegment(
                placeID: $0.placeID,
                start: $0.startedAt,
                end: $0.endedAt ?? day
            )
        }
}
