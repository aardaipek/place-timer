import Foundation

/// Geçmişte yapılan düzeltmeler. Saf: dizi girer, dizi çıkar.
///
/// Otomatik takip bazen yanılır — bilgisayar yanlış ağa bağlanır, bir yer iki
/// ayrı yer sanılır. Kullanıcının bunları sonradan düzeltebilmesi gerekiyor,
/// yoksa istatistik kendi hatasını kalıcı olarak taşır.
public enum SessionHistory {

    /// Birleştirilen yerin oturumlarını hedefe taşır.
    ///
    /// Katalogdan bir yeri silmek yetmiyor: oturumlar hâlâ o kimliği tutuyor
    /// ve istatistikte "Silinmiş yer" diye ayrı bir satır olarak duruyorlar.
    /// Birleştirme, geçmişi de birleştirmek demek.
    public static func reassign(
        _ sessions: [Session],
        from source: UUID,
        to target: UUID
    ) -> [Session] {
        guard source != target else { return sessions }
        return sessions.map { session in
            guard session.placeID == source else { return session }
            var moved = session
            moved.placeID = target
            return moved
        }
    }

    /// Yanlış açılmış tek bir oturumu siler.
    public static func remove(_ sessionID: UUID, from sessions: [Session]) -> [Session] {
        sessions.filter { $0.id != sessionID }
    }

    public enum EditError: Error, Equatable, Sendable {
        case differentPlaces
        case tooFew
        case invalidRange
        case future
        case overlaps
    }

    /// Seçili oturumları tek oturumda toplar: en erken başlangıç, en geç bitiş,
    /// aradaki boşluk dahil. En eski oturumun kimliği kalır. Seçimde açık
    /// oturum varsa sonuç açıktır.
    public static func merge(
        _ ids: Set<UUID>,
        in sessions: [Session]
    ) -> Result<[Session], EditError> {
        let selected = sessions.filter { ids.contains($0.id) }.sorted { $0.startedAt < $1.startedAt }
        guard selected.count >= 2, var merged = selected.first else { return .failure(.tooFew) }
        guard Set(selected.map(\.placeID)).count == 1 else { return .failure(.differentPlaces) }

        if selected.contains(where: { $0.endedAt == nil }) {
            merged.endedAt = nil
        } else {
            merged.endedAt = selected.compactMap(\.endedAt).max()
        }
        merged.notifiedMarks = selected.reduce(into: Set<Int>()) { $0.formUnion($1.notifiedMarks) }

        let others = sessions.filter { !ids.contains($0.id) }
        let mergedEnd = merged.endedAt ?? .distantFuture
        if others.contains(where: { overlaps($0.startedAt, $0.endedAt ?? .distantFuture, merged.startedAt, mergedEnd) }) {
            return .failure(.overlaps)
        }
        return .success((others + [merged]).sorted { $0.startedAt < $1.startedAt })
    }

    /// Bir oturumun saatini ya da yerini değiştirir.
    public static func update(
        _ edited: Session,
        in sessions: [Session],
        now: Date
    ) -> Result<[Session], EditError> {
        guard edited.startedAt <= now else { return .failure(.future) }
        let end = edited.endedAt ?? now
        guard edited.startedAt < end else { return .failure(.invalidRange) }

        let others = sessions.filter { $0.id != edited.id }
        if others.contains(where: { overlaps($0.startedAt, $0.endedAt ?? now, edited.startedAt, end) }) {
            return .failure(.overlaps)
        }
        return .success((others + [edited]).sorted { $0.startedAt < $1.startedAt })
    }

    /// Aynı yerde, bu oturumdan önce biten en yakın oturum.
    public static func previous(of id: UUID, in sessions: [Session]) -> Session? {
        guard let target = sessions.first(where: { $0.id == id }) else { return nil }
        return sessions
            .filter {
                $0.id != id && $0.placeID == target.placeID
                    && ($0.endedAt ?? .distantFuture) <= target.startedAt
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private static func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }
}
