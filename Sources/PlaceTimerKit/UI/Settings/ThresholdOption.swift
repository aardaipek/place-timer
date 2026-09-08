import Foundation

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

    /// "Hemen" gercek bir secenek: esik sifirken her uyku oturumu kapatir ve
    /// oturum uyanista degil, uykuya dalinan anda biter. Kapagi kapatinca
    /// sayacin durmasini isteyen kullanicinin istedigi tam olarak bu.
    static let sleep: [ThresholdOption] = [
        ThresholdOption(title: "Hemen", seconds: 0),
        ThresholdOption(title: "5 dakika", seconds: 5 * 60),
        ThresholdOption(title: "15 dakika", seconds: 15 * 60),
        ThresholdOption(title: "30 dakika", seconds: 30 * 60),
        ThresholdOption(title: "1 saat", seconds: 60 * 60),
        ThresholdOption(title: "2 saat", seconds: 2 * 60 * 60),
        ThresholdOption(title: "4 saat", seconds: 4 * 60 * 60),
    ]

    static let idle: [ThresholdOption] = [
        ThresholdOption(title: "2 dakika", seconds: 2 * 60),
        ThresholdOption(title: "5 dakika", seconds: 5 * 60),
        ThresholdOption(title: "10 dakika", seconds: 10 * 60),
        ThresholdOption(title: "15 dakika", seconds: 15 * 60),
    ]
}
