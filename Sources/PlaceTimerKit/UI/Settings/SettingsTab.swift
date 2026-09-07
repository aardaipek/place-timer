import Foundation

/// Ayarlar penceresinin bölümleri.
///
/// Seçim tamsayıya ya da metne değil bu enum'a bağlanıyor: bölüm eklendiğinde
/// veya sırası değiştiğinde kayacak bir indeks yok. Başlık ve simge de burada
/// duruyor; kenar çubuğu ile pencere başlığının aynı adı söylemesinin tek yolu
/// ikisinin de aynı yerden okuması.
enum SettingsTab: Hashable, CaseIterable, Identifiable {
    case genel, yerler, izinler, istatistik

    var id: Self { self }

    var title: String {
        switch self {
        case .genel: "Genel"
        case .yerler: "Yerler"
        case .izinler: "İzinler"
        case .istatistik: "İstatistik"
        }
    }

    var symbol: String {
        switch self {
        case .genel: "gearshape"
        case .yerler: "mappin.and.ellipse"
        case .izinler: "lock.shield"
        case .istatistik: "chart.bar"
        }
    }
}
