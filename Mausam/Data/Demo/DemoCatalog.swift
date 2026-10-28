import Foundation

/// Real cities with made-up, repeatable weather, served by `DemoTransport` to UI tests and previews.
/// Each city gets a different climate so every background and symbol shows up somewhere.
nonisolated enum DemoCatalog {
    enum Climate: Sendable {
        case sunny, rainy, mild, stormy, snowy, foggy
    }

    struct City: Sendable {
        let id: Int
        let name: String
        let admin1: String
        let country: String
        let latitude: Double
        let longitude: Double
        let timeZone: String
        let climate: Climate
        /// Average temperature in °C; days and hours swing around it.
        let baseTemperature: Double
    }

    static let cities = [
        City(id: 1_255_364, name: "Surat", admin1: "Gujarat", country: "India",
             latitude: 21.19594, longitude: 72.83023, timeZone: "Asia/Kolkata", climate: .sunny, baseTemperature: 29),
        City(id: 2_643_743, name: "London", admin1: "England", country: "United Kingdom",
             latitude: 51.50853, longitude: -0.12574, timeZone: "Europe/London", climate: .rainy, baseTemperature: 11),
        City(id: 1_850_147, name: "Tokyo", admin1: "Tokyo", country: "Japan",
             latitude: 35.6895, longitude: 139.69171, timeZone: "Asia/Tokyo", climate: .mild, baseTemperature: 17),
        City(id: 5_128_581, name: "New York", admin1: "New York", country: "United States",
             latitude: 40.71427, longitude: -74.00597, timeZone: "America/New_York", climate: .stormy, baseTemperature: 14),
        City(id: 3_413_829, name: "Reykjavík", admin1: "Capital Region", country: "Iceland",
             latitude: 64.13548, longitude: -21.89541, timeZone: "Atlantic/Reykjavik", climate: .snowy, baseTemperature: -2),
        City(id: 5_391_959, name: "San Francisco", admin1: "California", country: "United States",
             latitude: 37.77493, longitude: -122.41942, timeZone: "America/Los_Angeles", climate: .foggy, baseTemperature: 15),
        City(id: 1_275_339, name: "Mumbai", admin1: "Maharashtra", country: "India",
             latitude: 19.07283, longitude: 72.88261, timeZone: "Asia/Kolkata", climate: .rainy, baseTemperature: 28),
        City(id: 2_147_714, name: "Sydney", admin1: "New South Wales", country: "Australia",
             latitude: -33.86785, longitude: 151.20732, timeZone: "Australia/Sydney", climate: .mild, baseTemperature: 20),
    ]

    /// Where demo mode says the device is.
    static let home = cities[0]

    static var homePlace: Place {
        Place(
            id: Place.currentID,
            name: home.name,
            detail: "\(home.admin1), \(home.country)",
            latitude: home.latitude,
            longitude: home.longitude,
            timeZoneIdentifier: home.timeZone
        )
    }

    /// Prefix match ignoring case and accents, so "reyk" finds Reykjavík.
    static func search(_ query: String) -> [City] {
        let term = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !term.isEmpty else { return [] }
        return cities.filter { fold($0.name).hasPrefix(term) }
    }

    static func city(nearestLatitude latitude: Double, longitude: Double) -> City {
        cities.min { lhs, rhs in
            hypot(lhs.latitude - latitude, lhs.longitude - longitude) < hypot(rhs.latitude - latitude, rhs.longitude - longitude)
        } ?? home
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension DemoCatalog.Climate {
    /// WMO codes cycled through by hour and by day. The first is the city's signature weather, shown now.
    nonisolated var hourlyCodes: [Int] {
        switch self {
        case .sunny: [0, 0, 1, 0, 0, 1]
        case .rainy: [61, 63, 61, 3, 80, 61, 3, 3]
        case .mild: [2, 2, 1, 3, 2, 1]
        case .stormy: [95, 95, 80, 3, 3, 61]
        case .snowy: [73, 71, 71, 3, 73, 75]
        case .foggy: [45, 45, 45, 2, 2, 1]
        }
    }

    nonisolated var dailyCodes: [Int] {
        switch self {
        case .sunny: [0, 1, 0, 2, 0, 1, 3, 0, 61, 0]
        case .rainy: [63, 61, 3, 80, 61, 2, 3, 61, 65, 3]
        case .mild: [2, 1, 3, 61, 2, 1, 0, 2, 3, 1]
        case .stormy: [95, 80, 3, 2, 61, 95, 1, 0, 3, 2]
        case .snowy: [73, 75, 71, 3, 71, 1, 73, 75, 3, 71]
        case .foggy: [45, 45, 2, 1, 3, 45, 2, 0, 1, 45]
        }
    }

    /// Half the gap between the day's high and low, in °C.
    nonisolated var dailySwing: Double {
        switch self {
        case .sunny: 5
        case .snowy, .rainy: 3
        case .mild, .stormy, .foggy: 4
        }
    }

    nonisolated var humidity: Double {
        switch self {
        case .sunny: 38
        case .rainy, .foggy: 88
        case .mild: 62
        case .stormy: 80
        case .snowy: 84
        }
    }

    /// Local hours of sunrise and sunset.
    nonisolated var daylight: ClosedRange<Double> {
        self == .snowy ? 9.5...16.5 : 6.5...18.25
    }
}
