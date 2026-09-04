import Foundation

/// Bir Wi-Fi gözleminin kayıtlı yerlerle eşleşme sonucu.
public enum PlaceResolution: Sendable, Equatable {
    /// Ağ tanındı, aynı yer. Hiçbir şey sorulmaz.
    case matched(Place)
    /// SSID tanıdık ama koordinat kayıtlı yerden uzak — zincir şube olabilir.
    case possibleBranch(of: Place)
    /// Yeni ağ. `nearby`, yakında olduğu için birleştirme adayı olan yerler
    /// (router'ın 2.4/5 GHz bandı gibi); mesafeye göre sıralı.
    case unknownNetwork(nearby: [Place])
    /// Wi-Fi yok.
    case noNetwork
}

/// Kayıtlı yerlerin listesi ve eşleme kuralları. Saf değer tipi.
public struct PlaceCatalog: Codable, Sendable, Equatable {
    public private(set) var places: [Place]

    /// Aynı SSID'nin farklı şube sayılması için gereken asgari mesafe.
    public static let branchDistanceThreshold: Double = 300

    public init(places: [Place] = []) {
        self.places = places
    }

    public func place(id: UUID) -> Place? {
        places.first { $0.id == id }
    }

    /// Bir Wi-Fi gözlemini kayıtlı yerlerle eşler.
    ///
    /// - Parameters:
    ///   - ssid: Bağlı olunan ağın adı; `nil` ise Wi-Fi yok.
    ///   - coordinate: Bilinen konum. `nil` ise mesafe kontrolü atlanır ve
    ///     SSID eşleşmesi tek başına yeterli sayılır.
    public func resolve(ssid: String?, coordinate: Coordinate?) -> PlaceResolution {
        guard let ssid else { return .noNetwork }

        if let match = places.first(where: { $0.ssids.contains(ssid) }) {
            guard
                let coordinate,
                let known = match.coordinate,
                coordinate.distance(to: known) > Self.branchDistanceThreshold
            else {
                return .matched(match)
            }
            return .possibleBranch(of: match)
        }

        return .unknownNetwork(nearby: placesNear(coordinate))
    }

    /// Verilen noktanın eşik mesafesi içindeki yerler, yakından uzağa.
    public func placesNear(_ coordinate: Coordinate?) -> [Place] {
        guard let coordinate else { return [] }
        return places
            .compactMap { place -> (Place, Double)? in
                guard let known = place.coordinate else { return nil }
                let distance = coordinate.distance(to: known)
                guard distance <= Self.branchDistanceThreshold else { return nil }
                return (place, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    // MARK: - Mutasyonlar

    public mutating func add(_ place: Place) {
        places.append(place)
    }

    /// Var olan bir yere yeni bir ağ ekler — router'ın ikinci bandı ya da
    /// aynı mekânın ek access point'i için.
    public mutating func attach(ssid: String, bssid: String?, to placeID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].ssids.insert(ssid)
        if let bssid { places[index].bssids.insert(bssid) }
    }

    public mutating func rename(_ placeID: UUID, to displayName: String) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].displayName = displayName
    }
}

extension Place {
    public var coordinate: Coordinate? {
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}
