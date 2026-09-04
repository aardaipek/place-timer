import CoreLocation
import Foundation
import MapKit
import PlaceTimerCore

/// Konum izni, anlık koordinat ve yakındaki mekân isimleri.
///
/// Konum izni yalnızca isim önerisi için değil, SSID okuyabilmenin de ön
/// şartıdır: izin yoksa CoreWLAN ağ adını `nil` döndürür.
@MainActor
@Observable
public final class LocationService: NSObject, CLLocationManagerDelegate {
    public private(set) var authorizationStatus: CLAuthorizationStatus
    public private(set) var coordinate: Coordinate?

    public var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private let manager = CLLocationManager()

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    public override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func startUpdating() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    public func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    /// Verilen noktanın çevresindeki mekânları yakından uzağa sıralar.
    ///
    /// Ters geocoding sokak adresi döndürdüğü için mekân adı arayan
    /// `MKLocalPointsOfInterestRequest` kullanılır.
    public func nearbyPlaceNames(
        around coordinate: Coordinate,
        limit: Int = 3
    ) async -> [String] {
        let request = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            radius: 150
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .cafe, .restaurant, .bakery, .brewery, .library, .school, .university,
            .museum, .hotel, .store,
        ])

        do {
            let response = try await MKLocalSearch(request: request).start()
            let names = response.mapItems.compactMap(\.name)
            // Aynı isim birden çok kez dönebiliyor (farklı girişler).
            var seen = Set<String>()
            return names.filter { seen.insert($0).inserted }.prefix(limit).map(\.self)
        } catch {
            return []
        }
    }

    // MARK: - CLLocationManagerDelegate

    public nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.authorizationStatus = status
            self.onAuthorizationChange?(status)
            if status == .authorizedAlways {
                // Parametredeki yönetici aktör sınırını geçemez; kendi
                // örneğimizi kullanıyoruz (aynı nesne).
                self.startUpdating()
            }
        }
    }

    public nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        let coordinate = Coordinate(
            latitude: last.coordinate.latitude,
            longitude: last.coordinate.longitude
        )
        MainActor.assumeIsolated {
            self.coordinate = coordinate
        }
    }

    public nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Konum geçici olarak alınamayabilir; yer tespiti SSID'ye dayandığı
        // için bu tek başına akışı bozmaz.
    }
}
