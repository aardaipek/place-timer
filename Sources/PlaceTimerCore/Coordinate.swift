import Foundation

/// Enlem/boylam çifti. CoreLocation'a bağımlı olmamak için kendi tipimiz —
/// çekirdek mantık böylece sistem çerçevesi olmadan test edilebiliyor.
public struct Coordinate: Codable, Sendable, Equatable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// İki nokta arasındaki yaklaşık mesafe (metre), haversine formülü.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let φ1 = latitude * .pi / 180
        let φ2 = other.latitude * .pi / 180
        let Δφ = (other.latitude - latitude) * .pi / 180
        let Δλ = (other.longitude - longitude) * .pi / 180

        let a = sin(Δφ / 2) * sin(Δφ / 2)
            + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
