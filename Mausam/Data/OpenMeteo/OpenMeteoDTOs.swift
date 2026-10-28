import Foundation

// Open-Meteo JSON. Keys are mapped explicitly: `.convertFromSnakeCase` would turn "temperature_2m"
// into "temperature2M", which reads worse than naming the fields plainly.
// Series values are optional because the API sends null for hours a model doesn't cover.

nonisolated struct ForecastDTO: Decodable, Sendable {
    let timezone: String
    let current: CurrentDTO
    let hourly: HourlyDTO
    let daily: DailyDTO
}

nonisolated struct CurrentDTO: Decodable, Sendable {
    let time: TimeInterval
    let temperature: Double
    let humidity: Double
    let apparentTemperature: Double
    let isDay: Int
    let precipitation: Double?
    let weatherCode: Int
    let pressure: Double?
    let windSpeed: Double
    let windDirection: Double?
    let windGusts: Double?
    let visibility: Double?
    let uvIndex: Double?
    let dewPoint: Double?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case humidity = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case isDay = "is_day"
        case precipitation
        case weatherCode = "weather_code"
        case pressure = "pressure_msl"
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
        case windGusts = "wind_gusts_10m"
        case visibility
        case uvIndex = "uv_index"
        case dewPoint = "dew_point_2m"
    }
}

nonisolated struct HourlyDTO: Decodable, Sendable {
    let time: [TimeInterval]
    let temperature: [Double?]
    let precipitationProbability: [Double?]
    let weatherCode: [Int?]
    let isDay: [Int?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
        case isDay = "is_day"
    }
}

nonisolated struct DailyDTO: Decodable, Sendable {
    let time: [TimeInterval]
    let weatherCode: [Int?]
    let temperatureMax: [Double?]
    let temperatureMin: [Double?]
    let sunrise: [TimeInterval?]
    let sunset: [TimeInterval?]
    let uvIndexMax: [Double?]
    let precipitationProbabilityMax: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case sunrise
        case sunset
        case uvIndexMax = "uv_index_max"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}

nonisolated struct GeocodingDTO: Decodable, Sendable {
    /// Missing (not empty) when nothing matches.
    let results: [PlaceDTO]?
}

nonisolated struct PlaceDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: String?
    let country: String?
    let admin1: String?
}
