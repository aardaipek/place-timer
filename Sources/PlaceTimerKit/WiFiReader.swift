import CoreWLAN
import Foundation

/// Bağlı olunan Wi-Fi ağının adı ve access point adresi.
public struct WiFiSnapshot: Sendable, Equatable {
    public let ssid: String?
    public let bssid: String?

    public var isConnected: Bool { ssid != nil }
}

/// CoreWLAN üzerinden anlık ağ okuması.
///
/// macOS 14'ten beri SSID ve BSSID, Konum Servisleri izni verilmeden `nil`
/// döner — izin yoksa bu, "Wi-Fi yok"tan ayırt edilemez. Bu yüzden çağıran
/// taraf izin durumunu ayrıca kontrol etmelidir.
public enum WiFiReader {
    public static func snapshot() -> WiFiSnapshot {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiSnapshot(ssid: nil, bssid: nil)
        }
        return WiFiSnapshot(ssid: interface.ssid(), bssid: interface.bssid())
    }
}
