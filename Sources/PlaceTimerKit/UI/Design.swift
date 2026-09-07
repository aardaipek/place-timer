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

    static let settingsWidth: CGFloat = 540
    static let settingsHeight: CGFloat = 500
}
