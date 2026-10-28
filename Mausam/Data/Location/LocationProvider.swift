import CoreLocation
import Foundation

/// Where the device is, as a `Place`. Tests and demo mode pass a fixed one.
protocol LocationProviding: AnyObject, Sendable {
    func currentPlace() async throws -> Place
}

nonisolated enum LocationError: LocalizedError, Equatable {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            String(localized: "Location access is off. Turn it on in Settings, or search for a city.")
        case .unavailable:
            String(localized: "Your location isn't available right now.")
        }
    }
}

/// One-shot location lookups with `CLLocationManager`, plus a reverse geocode for the city name.
final class CoreLocationProvider: NSObject, LocationProviding {
    /// A fix this recent is reused instead of waking the GPS again.
    private static let maximumAge: TimeInterval = 10 * 60

    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocation, any Error>] = []

    override init() {
        super.init()
        manager.delegate = self
        // City-level accuracy is enough for weather and gets a fix faster.
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func currentPlace() async throws -> Place {
        let location = try await currentLocation()
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return Place(
            id: Place.currentID,
            name: placemark?.locality ?? placemark?.name ?? String(localized: "My Location"),
            detail: [placemark?.administrativeArea, placemark?.country].compactMap(\.self).joined(separator: ", "),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: placemark?.timeZone?.identifier ?? TimeZone.current.identifier
        )
    }

    private func currentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        default:
            break
        }
        if let location = manager.location, -location.timestamp.timeIntervalSinceNow < Self.maximumAge {
            return location
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationWaiters.append(continuation)
            // Pages that ask at the same time share one request.
            if locationWaiters.count == 1 {
                manager.requestLocation()
            }
        }
    }

    private func finishLocationRequest(with result: Result<CLLocation, any Error>) {
        let waiters = locationWaiters
        locationWaiters = []
        waiters.forEach { $0.resume(with: result) }
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {
    // The manager was created on the main thread, so it calls its delegate there.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status != .notDetermined else { return }
            let waiters = authorizationWaiters
            authorizationWaiters = []
            waiters.forEach { $0.resume() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let location = locations.last {
                finishLocationRequest(with: .success(location))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            let denied = (error as? CLError)?.code == .denied
            finishLocationRequest(with: .failure(denied ? LocationError.denied : LocationError.unavailable))
        }
    }
}
