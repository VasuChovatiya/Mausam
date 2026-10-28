import Foundation
import NetworkingKit
@testable import Mausam

enum Fixtures {
    static let london = Place(
        id: "2643743", name: "London", detail: "England, United Kingdom",
        latitude: 51.50853, longitude: -0.12574, timeZoneIdentifier: "Europe/London"
    )

    static let here = Place(
        id: Place.currentID, name: "Surat", detail: "Gujarat, India",
        latitude: 21.19594, longitude: 72.83023, timeZoneIdentifier: "Asia/Kolkata"
    )

    static let offline = NetworkError.transport(.notConnectedToInternet)
    static let serverError = NetworkError.httpStatus(code: 500, body: Data())

    static func report(temperature: Double = 20, fetchedAt: Date = .now) -> WeatherReport {
        WeatherReport(
            current: CurrentConditions(
                date: fetchedAt, condition: .clear, isDaylight: true, temperature: temperature,
                apparentTemperature: temperature, humidity: 0.5, dewPoint: 10, windSpeed: 12, windGust: 20,
                windDirection: 180, pressure: 1013, visibility: 20_000, uvIndex: 4, precipitation: 0
            ),
            hourly: (0..<25).map { hour in
                HourlyForecast(
                    date: fetchedAt.addingTimeInterval(Double(hour) * 3600), condition: .clear,
                    isDaylight: true, temperature: temperature, precipitationChance: 0
                )
            },
            daily: (0..<10).map { day in
                DailyForecast(
                    date: fetchedAt.addingTimeInterval(Double(day) * 86_400), condition: .clear,
                    high: temperature + 4, low: temperature - 4, precipitationChance: 0,
                    sunrise: nil, sunset: nil, uvIndexMax: 5
                )
            },
            fetchedAt: fetchedAt,
            source: .openMeteo
        )
    }

    /// A trimmed Open-Meteo response for Surat: three hours (one with nulls) and two days.
    static let forecastJSON = """
    {
      "latitude": 21.195, "longitude": 72.787, "utc_offset_seconds": 19800, "timezone": "Asia/Kolkata",
      "current": {
        "time": 1793184300, "interval": 900, "temperature_2m": 33.0, "relative_humidity_2m": 21,
        "apparent_temperature": 29.8, "is_day": 1, "precipitation": 0.0, "weather_code": 2,
        "pressure_msl": 1008.8, "wind_speed_10m": 18.5, "wind_direction_10m": 30, "wind_gusts_10m": 46.1,
        "visibility": 15360.0, "uv_index": 2.15, "dew_point_2m": 8.1
      },
      "hourly": {
        "time": [1793179800, 1793183400, 1793187000],
        "temperature_2m": [33.8, null, 31.2],
        "precipitation_probability": [0, 10, 45],
        "weather_code": [1, 0, 61],
        "is_day": [1, 1, 0]
      },
      "daily": {
        "time": [1793125800, 1793212200],
        "weather_code": [0, 95],
        "temperature_2m_max": [34.3, 33.1],
        "temperature_2m_min": [22.1, 21.4],
        "sunrise": [1793150100, 1793236540],
        "sunset": [1793191200, 1793277560],
        "uv_index_max": [6.4, null],
        "precipitation_probability_max": [0, 80]
      }
    }
    """
}
