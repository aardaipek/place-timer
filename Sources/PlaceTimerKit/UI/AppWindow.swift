import AppKit
import SwiftUI

/// Menubar uygulamasının ara sıra ihtiyaç duyduğu tek başına pencereler.
///
/// `LSUIElement` uygulamalar öne gelemez; bir pencere açıkken uygulama
/// geçici olarak normal moda alınır, son pencere kapanınca menubar'a döner.
@MainActor
public final class AppWindow {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private let title: String
    private static var openCount = 0

    public init(title: String) {
        self.title = title
    }

    public var isOpen: Bool { window != nil }

    public func present(@ViewBuilder content: () -> some View) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        Self.openCount += 1
        NSApp.setActivationPolicy(.regular)

        let controller = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        // Boyut ve konum tek adimda kuruluyor. Once boyutlandirip sonra
        // ortalamak ise yaramiyordu: `window.frame` o an baslik cubugunu daha
        // saymiyor, sonradan 30 punto buyuyunce pencere sol ust kosesinden
        // bagli kalip asagi kayiyordu. Olculdu — hicbir sey yapmayan
        // `center()` ile 848,42; ara adimlarla ekranin 15 punto altinda.
        // `frameRect(forContentRect:)` baslik cubugunu icine katiyor.
        let contentSize = controller.view.fittingSize
        if contentSize.width > 0, contentSize.height > 0 {
            window.setFrame(centeredFrame(for: contentSize, of: window), display: false)
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        // Kullanici pencereyi kirmizi dugmeyle kapattiginda `dismiss()`
        // cagrilmaz; bunu dinlemezsek sayac hic dusmez ve uygulama kalici
        // olarak `.regular` kalir — menubar uygulamasi Dock'ta asili kalirdi.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.release() }
        }
    }

    /// Pencereyi ekranin ortasina koyar.
    ///
    /// `NSWindow.center()` yatayda ortalar ama dikeyde kasitli olarak yukari
    /// kacirir; burada istenen gercek orta. Olcu `visibleFrame`den aliniyor,
    /// yani menubar ve Dock'un disinda kalan alanin ortasi — tam ekran
    /// yuksekligine gore ortalasaydik pencere Dock'un altina dogru kayardi.
    ///
    /// Ekran isaretcinin bulundugu ekran: `window.screen` pencere daha
    /// yerlestirilmeden anlamsiz — olculdu, iki ekranli makinede pencereyi
    /// kullanicinin bakmadigi ust ekrana goturuyordu. Kullanici ayarlari
    /// menubar panelinden aciyor, yani fare tam da dogru ekranda duruyor.
    private func centeredFrame(for contentSize: NSSize, of window: NSWindow) -> NSRect {
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        guard let visible = targetScreen?.visibleFrame else { return frame }
        frame.origin = NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2
        )
        return frame
    }

    private var targetScreen: NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    }

    public func dismiss() {
        guard let window else { return }
        window.close()
        release()
    }

    /// Pencere kapandiktan sonraki temizlik. Hem `dismiss()` hem de kapanma
    /// bildirimi buraya girer; ikinci giris `window` nil oldugu icin bos doner.
    private func release() {
        guard window != nil else { return }
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        window = nil
        Self.openCount = max(0, Self.openCount - 1)
        if Self.openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
