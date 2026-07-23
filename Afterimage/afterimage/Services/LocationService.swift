import Foundation
import CoreLocation

/// One-shot location capture used to stamp a shot with where it was taken. The
/// camera attaches this to the shot; the `onShotCreated` Cloud Function copies
/// the first located shot's place onto the album (for the map).
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Requests permission (when-in-use) if needed and returns a single fix, or
    /// nil if denied/unavailable.
    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted { return nil }
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    /// One-shot fix + reverse-geocoded place name for attaching to a shot.
    /// Returns nil if location is unavailable/denied.
    func currentPlace() async -> (latitude: Double, longitude: Double, name: String?)? {
        guard let loc = await currentLocation() else { return nil }
        let name = await reverseGeocode(loc)
        return (loc.coordinate.latitude, loc.coordinate.longitude, name)
    }

    private func reverseGeocode(_ loc: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
        guard let p = placemarks?.first else { return nil }
        let city = p.locality ?? p.subAdministrativeArea
        let region = p.administrativeArea
        switch (city, region) {
        case let (c?, r?): return "\(c), \(r)"
        case let (c?, nil): return c
        case let (nil, r?): return r
        default: return p.name
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.continuation?.resume(returning: locations.last)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }
}
