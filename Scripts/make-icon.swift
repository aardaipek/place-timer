// PlaceTimer simgesi: konum ignesi, basi bir saat kadrani.
//
// Simge ikili dosya olarak depoya girmez; bu betikle uretilir. Rengini ya da
// formunu degistirmek icin asagidaki sabitleri duzenleyip yeniden calistirin.
//
// Kullanim: swift Scripts/make-icon.swift <cikti-klasoru>

import AppKit

let arkaUst = NSColor(srgbRed: 0.42, green: 0.25, blue: 0.72, alpha: 1)    // mor
let arkaAlt = NSColor(srgbRed: 0.11, green: 0.16, blue: 0.45, alpha: 1)    // derin mavi
let kadranRengi = NSColor(srgbRed: 0.09, green: 0.13, blue: 0.36, alpha: 1)

func iconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    // Arka plan: macOS'un yuvarlak kare orani (~22.37%), kenarlarda hafif bosluk.
    let inset = size * 0.06
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let background = NSBezierPath(
        roundedRect: rect,
        xRadius: rect.width * 0.2237,
        yRadius: rect.width * 0.2237
    )
    background.addClip()
    NSGradient(starting: arkaUst, ending: arkaAlt)?.draw(in: rect, angle: -90)

    // Igne: merkez daire + asagi bakan ucgen uc.
    //
    // Ikisi AYRI AYRI dolduruluyor. Tek bir NSBezierPath'e alt yol olarak
    // eklendiklerinde ters yonde ciziliyorlar ve nonzero kurali kesisimi
    // bosaltip dairenin altinda koyu bir bant birakiyor.
    let merkez = NSPoint(x: size / 2, y: size * 0.58)
    let yaricap = size * 0.23

    NSColor.white.setFill()

    NSBezierPath(
        ovalIn: NSRect(
            x: merkez.x - yaricap, y: merkez.y - yaricap,
            width: yaricap * 2, height: yaricap * 2
        )
    ).fill()

    let ucgen = NSBezierPath()
    ucgen.move(to: NSPoint(x: merkez.x - yaricap * 0.72, y: merkez.y - yaricap * 0.62))
    ucgen.line(to: NSPoint(x: merkez.x + yaricap * 0.72, y: merkez.y - yaricap * 0.62))
    ucgen.line(to: NSPoint(x: merkez.x, y: size * 0.13))
    ucgen.close()
    ucgen.fill()

    // Kadran: ignenin icinde koyu bir daire. 16 pikselde bile beyaz igne
    // uzerinde koyu bir nokta olarak okunur.
    let kadranYaricap = yaricap * 0.62
    kadranRengi.setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: merkez.x - kadranYaricap, y: merkez.y - kadranYaricap,
            width: kadranYaricap * 2, height: kadranYaricap * 2
        )
    ).fill()

    // Akrep ve yelkovan yalnizca buyuk boyutlarda ciziliyor: 64 pikselin
    // altinda birbirine karisip kadrani bulaniklastiriyorlar.
    if size >= 64 {
        NSColor.white.setStroke()
        let kalinlik = max(1, size * 0.022)

        let yelkovan = NSBezierPath()
        yelkovan.move(to: merkez)
        yelkovan.line(to: NSPoint(x: merkez.x, y: merkez.y + kadranYaricap * 0.72))
        yelkovan.lineWidth = kalinlik
        yelkovan.lineCapStyle = .round
        yelkovan.stroke()

        let akrep = NSBezierPath()
        akrep.move(to: merkez)
        akrep.line(
            to: NSPoint(
                x: merkez.x + kadranYaricap * 0.52,
                y: merkez.y + kadranYaricap * 0.18
            )
        )
        akrep.lineWidth = kalinlik
        akrep.lineCapStyle = .round
        akrep.stroke()
    }

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try png.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("kullanim: make-icon.swift <cikti-klasoru>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(
    at: outputDirectory, withIntermediateDirectories: true
)

// iconutil'in bekledigi isimlendirme.
let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let image = iconImage(size: variant.pixels)
    try writePNG(image, to: outputDirectory.appendingPathComponent("\(variant.name).png"))
}

print("\(variants.count) boyut uretildi: \(outputDirectory.path)")
