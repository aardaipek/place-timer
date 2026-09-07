import AppKit

/// Menubar başlığını metin yerine görüntü olarak çizer.
///
/// SwiftUI'nin `MenuBarExtra` etiketi `Text`in biçimini menubar öğesine
/// taşımıyor. Önce `.monospacedDigit()` view değiştiricisi denendi, sonra
/// `Text`in kendi `font` metodu; ikisinde de öğenin genişliği saniyede bir
/// oynamaya devam etti — ölçüldü, 101–106 px arası. Menubar'da bir öğenin eni
/// değişince solundaki bütün simgeler onunla birlikte kayıyor, saat de dahil.
///
/// Metni kendimiz çizince punto ve rakam genişliği bizde kalıyor: aynı hane
/// sayısı her zaman aynı genişlik demek.
enum MenuBarLabel {
    /// Görüntü `isTemplate`: menubar açık/koyu temada ve öğe tıklanıp
    /// vurgulandığında rengi sistemden alsın diye. Aksi hâlde siyah piksel
    /// koyu menubar'da kaybolurdu.
    static func image(for title: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
            weight: .regular
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]

        let text = title as NSString
        let measured = text.size(withAttributes: attributes)
        let size = NSSize(width: ceil(measured.width), height: ceil(measured.height))

        let image = NSImage(size: size, flipped: false) { _ in
            text.draw(at: .zero, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        // Etiket artık metin değil; ekran okuyucunun okuyacağı bir şey kalsın.
        image.accessibilityDescription = title
        return image
    }
}
