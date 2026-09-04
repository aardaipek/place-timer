import Foundation
import ServiceManagement

/// Açılışta otomatik başlatma.
///
/// Bu olmadan "bilgisayarı açtığım anda başlasın" gereksinimi hiç çalışmaz:
/// uygulama çalışmıyorsa sayacak bir şey de yoktur.
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public static func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            return false
        }
    }

    public static func disable() {
        try? SMAppService.mainApp.unregister()
    }
}
