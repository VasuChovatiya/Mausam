import Foundation

/// The sky in one word. Both providers map their own codes onto this, so the UI has one vocabulary.
nonisolated enum Condition: String, Codable, Sendable, CaseIterable {
    case clear = "clear"
    case mostlyClear = "mostlyClear"
    case partlyCloudy = "partlyCloudy"
    case cloudy = "cloudy"
    case fog = "fog"
    case windy = "windy"
    case drizzle = "drizzle"
    case rain = "rain"
    case heavyRain = "heavyRain"
    case freezingRain = "freezingRain"
    case snow = "snow"
    case heavySnow = "heavySnow"
    case thunderstorm = "thunderstorm"

    /// WMO weather interpretation codes, as Open-Meteo returns them.
    /// https://open-meteo.com/en/docs#weather_variable_documentation
    init(wmoCode: Int) {
        switch wmoCode {
        case 0: self = .clear
        case 1: self = .mostlyClear
        case 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55: self = .drizzle
        case 56, 57, 66, 67: self = .freezingRain
        case 61, 63, 80, 81: self = .rain
        case 65, 82: self = .heavyRain
        case 71, 73, 77, 85: self = .snow
        case 75, 86: self = .heavySnow
        case 95, 96, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    var title: String {
        switch self {
        case .clear: String(localized: "Clear")
        case .mostlyClear: String(localized: "Mostly Clear")
        case .partlyCloudy: String(localized: "Partly Cloudy")
        case .cloudy: String(localized: "Cloudy")
        case .fog: String(localized: "Fog")
        case .windy: String(localized: "Windy")
        case .drizzle: String(localized: "Drizzle")
        case .rain: String(localized: "Rain")
        case .heavyRain: String(localized: "Heavy Rain")
        case .freezingRain: String(localized: "Freezing Rain")
        case .snow: String(localized: "Snow")
        case .heavySnow: String(localized: "Heavy Snow")
        case .thunderstorm: String(localized: "Thunderstorms")
        }
    }

    /// SF Symbol, drawn with `.multicolor` rendering.
    func symbolName(isDaylight: Bool) -> String {
        switch self {
        case .clear: isDaylight ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear, .partlyCloudy: isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .windy: "wind"
        case .drizzle: "cloud.drizzle.fill"
        case .rain: isDaylight ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .freezingRain: "cloud.sleet.fill"
        case .snow: "cloud.snow.fill"
        case .heavySnow: "snowflake"
        case .thunderstorm: "cloud.bolt.rain.fill"
        }
    }

    /// True when precipitation is falling, so the hourly strip shows its chance.
    var isWet: Bool {
        switch self {
        case .drizzle, .rain, .heavyRain, .freezingRain, .snow, .heavySnow, .thunderstorm: true
        default: false
        }
    }
}
