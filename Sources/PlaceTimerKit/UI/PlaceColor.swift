import SwiftUI

/// Yer kimliğinden kararlı bir renk üretir.
///
/// Serbest hue yerine seçilmiş bir palet: tonu UUID'den hesaplamak "kararlı"
/// ama tasarlanmamış renkler veriyordu — bazı kimlikler çamurlu hardal ya da
/// haki tonlara düşüyordu ve sabit doygunluk/parlaklık karanlık moda hiç
/// uyarlanmıyordu. Sistem renkleri iki temada da kendini ayarlar.
public enum PlaceColor {
    /// Birbirinden ayırt edilebilen, iki temada da okunur tonlar.
    private static let palette: [Color] = [
        .indigo, .teal, .orange, .pink, .green, .blue, .purple, .brown,
    ]

    public static func color(for placeID: UUID?) -> Color {
        guard let placeID else { return .secondary }

        // UUID'nin ilk baytlari kararli bir indeks verir. hashValue
        // kullanmiyoruz: Swift'te calismalar arasi kararli degil.
        let bytes = withUnsafeBytes(of: placeID.uuid) { Array($0.prefix(4)) }
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return palette[Int(value % UInt32(palette.count))]
    }
}
