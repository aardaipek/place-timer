import AppKit
import CoreGraphics
import Foundation

// App Store macOS ekran goruntusu olculerinden biri: 1440x900.
let canvasW = 1440.0
let canvasH = 900.0
// Pencere goruntusu retina yakalandi (2x); tuvale sigacak sekilde kuculuyor.
let targetWindowH = 700.0

// Girdi: `screencapture -l<pencere-id>` ile yakalanmis pencere goruntuleri.
// Cikti: docs/asc/media/tr/APP_DESKTOP/ altinda App Store olculerinde kareler.
let tmp = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let outDir = tmp.appendingPathComponent("media/tr/APP_DESKTOP")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sources = [
    ("genel.png", "01_genel.png"),
    ("istatistik.png", "02_istatistik.png"),
    ("hakkinda.png", "03_hakkinda.png"),
]

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

for (input, output) in sources {
    let inURL = tmp.appendingPathComponent(input)
    guard let window = loadImage(inURL) else {
        print("atlandi (okunamadi): \(input)")
        continue
    }

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(canvasW),
        height: Int(canvasH),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    // Arka plan: uygulamanin simgesindeki mor-lacivert tonlarindan bir gecis.
    let colors = [
        CGColor(srgbRed: 0.10, green: 0.09, blue: 0.20, alpha: 1),
        CGColor(srgbRed: 0.20, green: 0.15, blue: 0.38, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvasH),
            end: CGPoint(x: canvasW, y: 0),
            options: []
        )
    }

    let scale = targetWindowH / Double(window.height)
    let w = Double(window.width) * scale
    let h = targetWindowH
    let rect = CGRect(x: (canvasW - w) / 2, y: (canvasH - h) / 2, width: w, height: h)

    ctx.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 48,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55)
    )
    ctx.draw(window, in: rect)

    guard let image = ctx.makeImage() else { continue }
    let outURL = outDir.appendingPathComponent(output)
    guard let dest = CGImageDestinationCreateWithURL(
        outURL as CFURL, "public.png" as CFString, 1, nil
    ) else { continue }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("yazildi: \(output)  \(Int(canvasW))x\(Int(canvasH))")
}
