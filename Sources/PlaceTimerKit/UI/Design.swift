import SwiftUI

/// Arayüzün ölçüleri tek yerde.
///
/// Aralıklar ve yarıçaplar dosyalara serpildiğinde her view kendi ritmini
/// uyduruyor ve yüzeyler birbirini tutmuyordu. Burada durunca hem tek noktadan
/// ayarlanıyorlar hem de yeni bir view yazarken "burada kaç boşluk vardı"
/// sorusunun cevabı belli oluyor.
enum Design {
    static let panelWidth: CGFloat = 300

    static let tight: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16

    /// Gün şeridinin kalınlığı. Şerit panelin tabanında ince bir çizgi.
    static let stripHeight: CGFloat = 6

    /// Yer rengini taşıyan nokta. Panelde, yerler listesinde ve istatistikte
    /// aynı çapta: aynı şeyi gösteren üç yerde üç ayrı boyut, göz için üç ayrı
    /// simge demek.
    static let dotSize: CGFloat = 8

    /// Ayarlar penceresi. Ölçü sabit: bölüm başına farklı bir boy pencereyi
    /// her tıklamada zıplatır ve zıplayan pencerede kenar çubuğu da yer
    /// değiştirip ikinci tıklamayı ıskalatır.
    static let settingsSidebarWidth: CGFloat = 170
    static let settingsPaneWidth: CGFloat = 430
    static let settingsWidth: CGFloat = settingsSidebarWidth + settingsPaneWidth
    static let settingsHeight: CGFloat = 460
}
