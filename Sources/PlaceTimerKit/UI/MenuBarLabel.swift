import AppKit
import PlaceTimerCore

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
///
/// Görüntü her stilde `isTemplate`: renk yok, yalnızca saydamlık. Menubar
/// açık/koyu temada ve öğe tıklanıp vurgulandığında rengi sistemden alsın
/// diye. Halkanın izi ve kapsülün içindeki oyuk metin de saydamlıkla çiziliyor.
enum MenuBarLabel {
    static func image(for title: String, style: MenuBarStyle, progress: Double) -> NSImage {
        let image: NSImage
        switch style {
        case .text: image = textImage(title)
        case .ring: image = ringImage(title, progress: progress)
        case .pill: image = pillImage(title)
        }
        image.isTemplate = true
        // Etiket artık metin değil; ekran okuyucunun okuyacağı bir şey kalsın.
        image.accessibilityDescription = title
        return image
    }

    // MARK: - Ölçüler

    private static var menuBarFontSize: CGFloat { NSFont.menuBarFont(ofSize: 0).pointSize }
    /// Görüntü menubar'ın tam yüksekliğinde: halka ve kapsül dikeyde ortada
    /// dursun, metnin taban çizgisine göre kaymasın.
    private static var barHeight: CGFloat { max(NSStatusBar.system.thickness, 22) }

    private static let ringDiameter: CGFloat = 13
    private static let ringLineWidth: CGFloat = 1.75
    private static let ringGap: CGFloat = 5
    private static let pillHeight: CGFloat = 17
    private static let pillPadding: CGFloat = 7

    private static func attributes(weight: NSFont.Weight, size: CGFloat? = nil) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size ?? menuBarFontSize, weight: weight),
            .foregroundColor: NSColor.black,
        ]
    }

    // MARK: - Stiller

    private static func textImage(_ title: String) -> NSImage {
        let attrs = attributes(weight: .regular)
        let text = title as NSString
        let measured = text.size(withAttributes: attrs)
        let size = NSSize(width: ceil(measured.width), height: ceil(measured.height))
        return NSImage(size: size, flipped: false) { _ in
            text.draw(at: .zero, withAttributes: attrs)
            return true
        }
    }

    /// İlerleme halkası ve süre. Halka saat 12'den başlayıp saat yönünde dolar.
    private static func ringImage(_ title: String, progress: Double) -> NSImage {
        let attrs = attributes(weight: .medium)
        let text = title as NSString
        let measured = text.size(withAttributes: attrs)
        let height = barHeight
        let width = ceil(ringDiameter + ringGap + measured.width)

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let inset = ringLineWidth / 2
            let ringRect = NSRect(
                x: inset,
                y: (height - ringDiameter) / 2 + inset,
                width: ringDiameter - ringLineWidth,
                height: ringDiameter - ringLineWidth
            )
            let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
            let radius = ringRect.width / 2

            let track = NSBezierPath(ovalIn: ringRect)
            track.lineWidth = ringLineWidth
            NSColor.black.withAlphaComponent(0.28).setStroke()
            track.stroke()

            let clamped = min(max(progress, 0), 1)
            if clamped > 0 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - 360 * clamped,
                    clockwise: true
                )
                arc.lineWidth = ringLineWidth
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            let textOrigin = NSPoint(
                x: ringDiameter + ringGap,
                y: (height - measured.height) / 2
            )
            text.draw(at: textOrigin, withAttributes: attrs)
            return true
        }
    }

    /// Dolu kapsül, süre içinden oyulmuş. Menubar koyuyken kapsül açık,
    /// metin menubar renginde görünür.
    private static func pillImage(_ title: String) -> NSImage {
        let attrs = attributes(weight: .semibold, size: menuBarFontSize - 1)
        let text = title as NSString
        let measured = text.size(withAttributes: attrs)
        let height = barHeight
        let pillWidth = ceil(measured.width + pillPadding * 2)

        return NSImage(size: NSSize(width: pillWidth, height: height), flipped: false) { _ in
            let pillRect = NSRect(x: 0, y: (height - pillHeight) / 2, width: pillWidth, height: pillHeight)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

            guard let context = NSGraphicsContext.current else { return true }
            context.saveGraphicsState()
            context.compositingOperation = .destinationOut
            text.draw(
                at: NSPoint(x: pillPadding, y: pillRect.midY - measured.height / 2),
                withAttributes: attrs
            )
            context.restoreGraphicsState()
            return true
        }
    }
}
