import Foundation
import NetworkingKit

nonisolated enum OpenMeteoEndpoints {
    static let hours = 25
    static let days = 10

    static let currentFields = [
        "temperature_2m", "relative_humidity_2m", "apparent_temperature", "is_day", "precipitation",
        "weather_code", "pressure_msl", "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
        "visibility", "uv_index", "dew_point_2m",
    ]
    static let hourlyFields = ["temperature_2m", "precipitation_probability", "weather_code", "is_day"]
    static let dailyFields = [
        "weather_code", "temperature_2m_max", "temperature_2m_min", "sunrise", "sunset",
        "uv_index_max", "precipitation_probability_max",
    ]

    /// One request for the whole screen. Unix times keep parsing time-zone free; `timezone=auto`
    /// still aligns hours and days to the place's local clock.
    static func forecast(latitude: Double, longitude: Double) -> Endpoint<ForecastDTO> {
        .get("/forecast", query: [
            "latitude": coordinate(latitude),
            "longitude": coordinate(longitude),
            "current": currentFields.joined(separator: ","),
            "hourly": hourlyFields.joined(separator: ","),
            "daily": dailyFields.joined(separator: ","),
            "forecast_hours": String(hours),
            "forecast_days": String(days),
            "timezone": "auto",
            "timeformat": "unixtime",
        ])
    }

    static func search(_ name: String, language: String, count: Int = 15) -> Endpoint<GeocodingDTO> {
        .get("/search", query: [
            "name": name,
            "count": String(count),
            "language": language,
            "format": "json",
        ])
    }

    /// Four decimals is about 11 m, plenty for weather, and keeps URLs short and stable.
    private static func coordinate(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
