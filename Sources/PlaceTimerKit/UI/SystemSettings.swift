import AppKit
import Foundation

/// Sistem Ayarları'nın ilgili paneline doğrudan gider.
///
/// TCC diyaloğu her zaman çıkmaz: izin bir kez reddedildiyse macOS sessizce
/// geçer. Bu durumda kullanıcıyı doğru panele götürmek tek çıkış yoludur.
public enum SystemSettings {
    public enum Pane {
        case locationServices
        case notifications
        case loginItems

        var url: URL? {
            switch self {
            case .locationServices:
                URL(string: "x-apple.systempreferences:com.apple.preference.security"
                    + "?Privacy_LocationServices")
            case .notifications:
                URL(string: "x-apple.systempreferences:"
                    + "com.apple.Notifications-Settings.extension")
            case .loginItems:
                URL(string: "x-apple.systempreferences:"
                    + "com.apple.LoginItems-Settings.extension")
            }
        }
    }

    public static func open(_ pane: Pane) {
        guard let url = pane.url else { return }
        NSWorkspace.shared.open(url)
    }
}
