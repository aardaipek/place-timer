import Foundation

/// Ayarlar penceresinin sekmeleri.
///
/// `TabView(selection:)` tamsayıya ya da metne değil bu enum'a bağlanıyor:
/// sekme eklendiğinde veya sırası değiştiğinde kayacak bir indeks yok.
enum SettingsTab: Hashable, CaseIterable {
    case genel, yerler, izinler, istatistik
}
