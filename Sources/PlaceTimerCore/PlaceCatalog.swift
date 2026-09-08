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

    public mutating func remove(_ placeID: UUID) {
        places.removeAll { $0.id == placeID }
    }

    /// İki yeri birleştirir: kaynağın ağları hedefe geçer, kaynak katalogdan
    /// çıkar. Router'ın 2.4 ve 5 GHz bantları ayrı yer olarak kaydedildiğinde
    /// ya da aynı mekân iki farklı adla tanındığında gereken şey bu.
    ///
    /// Hedefin adı ve koordinatı korunur — kullanıcı hangisinin kalacağını
    /// hedefi seçerek söylüyor. Tek istisna, hedefin hiç koordinatı olmaması:
    /// o zaman kaynağınki alınıyor, çünkü koordinat zincir şube ayrımının tek
    /// dayanağı ve elde varken atmanın anlamı yok.
    ///
    /// Geçmişteki oturumların yer kimliği burada değişmez; onu
    /// `SessionHistory.reassign` yapıyor. Katalog oturumları tanımıyor.
    public mutating func merge(_ source: UUID, into target: UUID) {
        guard source != target,
            let sourceIndex = places.firstIndex(where: { $0.id == source }),
            let targetIndex = places.firstIndex(where: { $0.id == target })
        else { return }

        let moved = places[sourceIndex]
        places[targetIndex].ssids.formUnion(moved.ssids)
        places[targetIndex].bssids.formUnion(moved.bssids)
        if places[targetIndex].coordinate == nil {
            places[targetIndex].latitude = moved.latitude
            places[targetIndex].longitude = moved.longitude
        }
        places.remove(at: sourceIndex)
    }

    /// Bir ağı yerden ayırır. Yerin son SSID'si olsa bile yer silinmez —
    /// silmek ile ayırmak farklı işlemlerdir; kullanıcı hangisini istediğini
    /// kendisi söyler.
    public mutating func detach(ssid: String, from placeID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].ssids.remove(ssid)
    }

    /// Bir oturumun yer adı. Üç durum ayrı ayrı adlandırılır: yer hiç
    /// bilinmiyordu, yer sonradan silindi, ya da yer duruyor. Silinmiş bir yeri
    /// sessizce "Bilinmeyen yer"e karıştırmak geçmişi yanlış anlatırdı.
    public func displayName(for placeID: UUID?) -> String {
        guard let placeID else { return "Bilinmeyen yer" }
        return place(id: placeID)?.displayName ?? "Silinmiş yer"
    }
}

extension Place {
    public var coordinate: Coordinate? {
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}
