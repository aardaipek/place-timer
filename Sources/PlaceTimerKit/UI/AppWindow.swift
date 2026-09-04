import AppKit
import SwiftUI

/// Menubar uygulamasının ara sıra ihtiyaç duyduğu tek başına pencereler.
///
/// `LSUIElement` uygulamalar öne gelemez; bir pencere açıkken uygulama
/// geçici olarak normal moda alınır, son pencere kapanınca menubar'a döner.
@MainActor
public final class AppWindow {
    private var window: NSWindow?
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
    }

    public func dismiss() {
        guard window != nil else { return }
        window?.close()
        window = nil
        Self.openCount = max(0, Self.openCount - 1)
        if Self.openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
