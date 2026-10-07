import Foundation
import PlaceTimerCore

/// Ayarlardaki eşik seçenekleri.
///
/// Eşikler serbest sayı değil, birkaç makul seçenek: kullanıcının "37 dakika"
/// girmesine izin vermek karar yükünü artırır, karşılığı yok.
///
/// `(String, TimeInterval)` demeti yerine adlandırılmış bir tip: `ForEach`
/// kimliği artık `\.1` değil, `Identifiable` üzerinden geliyor.
struct ThresholdOption: Identifiable, Hashable {
    let title: String
    let seconds: TimeInterval

    var id: TimeInterval { seconds }

    static let gap: [ThresholdOption] = Preferences.gapOptions.map { seconds in
        let minutes = Int(seconds / 60)
        let title = minutes < 60 ? "\(minutes) dakika" : "\(minutes / 60) saat"
        return ThresholdOption(title: title, seconds: seconds)
    }
}
