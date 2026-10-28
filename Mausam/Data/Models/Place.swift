import CoreLocation
import Foundation

/// A spot the app shows weather for: the device location or a searched city.
nonisolated struct Place: Hashable, Codable, Sendable, Identifiable {
    /// Id of the device-location page. Searched places use their GeoNames id.
    static let currentID = "current"

    let id: String
    let name: String
    /// Region and country, e.g. "Gujarat, India".
    let detail: String?
    let latitude: Double
    let longitude: Double
    /// IANA identifier, used to label hours and days in the place's own time.
    let timeZoneIdentifier: String?

    var isCurrentLocation: Bool { id == Self.currentID }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }
}
