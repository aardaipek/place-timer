import SwiftUI

/// Ayarlar penceresinin bölümleri.
///
/// Seçim tamsayıya ya da metne değil bu enum'a bağlanıyor: bölüm eklendiğinde
/// veya sırası değiştiğinde kayacak bir indeks yok. Başlık ve simge de burada
/// duruyor; kenar çubuğu ile pencere başlığının aynı adı söylemesinin tek yolu
/// ikisinin de aynı yerden okuması.
enum SettingsTab: Hashable, CaseIterable, Identifiable {
    case genel, yerler, izinler, istatistik, hakkinda

    var id: Self { self }

    var title: String {
        switch self {
        case .genel: "Genel"
        case .yerler: "Yerler"
        case .izinler: "İzinler"
        case .istatistik: "İstatistik"
        case .hakkinda: "Hakkında"
        }
    }

    var symbol: String {
        switch self {
        case .genel: "gearshape"
        case .yerler: "mappin.and.ellipse"
        case .izinler: "lock.shield"
        case .istatistik: "chart.bar"
        case .hakkinda: "info.circle"
        }
    }

    /// Simgenin arkasındaki renk. Sistem Ayarları'ndaki gibi her bölüm kendi
    /// renginde: liste göz ucuyla, okumadan taranıyor.
    var tint: Color {
        switch self {
        case .genel: .gray
        case .yerler: .blue
        case .izinler: .green
        case .istatistik: .orange
        case .hakkinda: .indigo
        }
    }

    /// ⌘1 … ⌘5.
    var shortcut: KeyEquivalent {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return KeyEquivalent(Character(String(index + 1)))
    }
}
