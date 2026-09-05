import SwiftUI

/// Yer kimliğinden kararlı bir renk üretir.
///
/// Renkler diske yazılmaz: aynı UUID her zaman aynı tonu verir, dolayısıyla
/// saklamanın anlamı yok. Doygunluk ve parlaklık sabit tutulur ki şeritteki
/// bütün segmentler aynı aileden görünsün.
public enum PlaceColor {
    public static func color(for placeID: UUID?) -> Color {
        guard let placeID else { return .secondary }

        // UUID'nin ilk baytlarindan kararli bir ton. hashValue kullanmiyoruz:
        // Swift'te calismalar arasi kararli degil.
        let bytes = withUnsafeBytes(of: placeID.uuid) { Array($0.prefix(4)) }
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let hue = Double(value % 360) / 360

        return Color(hue: hue, saturation: 0.62, brightness: 0.82)
    }
}
