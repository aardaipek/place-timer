import Foundation

/// Kullanıcının "burası aslında şurası" düzeltmesi.
///
/// Seçim bir ağa bağlanır: aynı ağda kaldığın sürece otomatik eşleşmeyi
/// bastırır. Böyle bir bağ olmasaydı seçim, 10 saniyelik ağ yoklamasının ilk
/// turunda kendiliğinden geri alınırdı.
public struct ManualPlaceSelection: Sendable, Equatable {
    public let placeID: UUID
    /// Seçimin yapıldığı andaki ağ. `nil`, seçimin Wi-Fi yokken yapıldığını
    /// gösterir; o durumda ilk ağ görülene kadar geçerli kalır.
    public let ssid: String?

    public init(placeID: UUID, ssid: String?) {
        self.placeID = placeID
        self.ssid = ssid
    }

    public func applies(to observedSSID: String?) -> Bool {
        ssid == observedSSID
    }
}
