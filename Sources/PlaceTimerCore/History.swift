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
}
