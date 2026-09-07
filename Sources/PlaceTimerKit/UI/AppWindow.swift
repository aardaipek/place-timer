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

        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
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
