import Foundation
import NetworkingKit

/// An offline `HTTPTransport` that answers Open-Meteo-shaped JSON from `DemoCatalog`.
///
/// Because it sits below `APIClient`, demo mode exercises the same request building, decoding and
/// mapping code as the live app; only the bytes come from memory.
nonisolated struct DemoTransport: HTTPTransport {
    var latency: Duration = .milliseconds(300)
    var now: @Sendable () -> Date = { .now }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(for: latency)

        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        let query = Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }) { first, _ in first }

        let (status, body): (Int, Any)
        switch components.path {
        case "/v1/search":
            let matches = DemoCatalog.search(query["name"] ?? "")
            // Like the real API, "results" is left out when nothing matches.
            (status, body) = (200, matches.isEmpty ? ["generationtime_ms": 0.1] : ["results": matches.map(placeJSON)])
        case "/v1/forecast":
            guard let latitude = query["latitude"].flatMap(Double.init), let longitude = query["longitude"].flatMap(Double.init) else {
                (status, body) = (400, ["error": true, "reason": "Missing coordinates"])
                break
            }
            let city = DemoCatalog.city(nearestLatitude: latitude, longitude: longitude)
            (status, body) = (200, DemoForecast(city: city, now: now()).json)
        default:
            (status, body) = (404, ["error": true, "reason": "Unknown demo endpoint"])
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        )
        return (data, response ?? URLResponse())
    }

    private func placeJSON(_ city: DemoCatalog.City) -> [String: Any] {
        [
            "id": city.id,
            "name": city.name,
            "latitude": city.latitude,
            "longitude": city.longitude,
            "timezone": city.timeZone,
            "country": city.country,
            "admin1": city.admin1,
        ]
    }
}

/// A forecast for one demo city, laid out like Open-Meteo's response with `timeformat=unixtime`.
nonisolated private struct DemoForecast {
    let city: DemoCatalog.City
    let now: Date
    private let calendar: Calendar

    init(city: DemoCatalog.City, now: Date) {
        self.city = city
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: city.timeZone) ?? .gmt
        self.calendar = calendar
    }

    var json: [String: Any] {
        let hours = (0..<OpenMeteoEndpoints.hours).map(hour(at:))
        let days = (0..<OpenMeteoEndpoints.days).map(day(at:))
        let first = hours[0]
        let quarterHour = (now.timeIntervalSince1970 / 900).rounded(.down) * 900

        return [
            "timezone": city.timeZone,
            "utc_offset_seconds": calendar.timeZone.secondsFromGMT(for: now),
            "current": [
                "time": quarterHour,
                "temperature_2m": first.temperature,
                "relative_humidity_2m": city.climate.humidity,
                "apparent_temperature": first.temperature + (city.climate == .sunny ? 2.4 : -1.8),
                "is_day": first.isDay,
                "precipitation": Condition(wmoCode: first.code).isWet ? 0.6 : 0,
                "weather_code": first.code,
                "pressure_msl": city.climate == .stormy ? 998.4 : 1014.2,
                "wind_speed_10m": city.climate == .stormy ? 34.0 : 12.5,
                "wind_direction_10m": 225,
                "wind_gusts_10m": city.climate == .stormy ? 61.0 : 24.0,
                "visibility": city.climate == .foggy ? 800 : 24_000,
                "uv_index": first.isDay == 1 ? (city.climate == .sunny ? 7.2 : 2.1) : 0,
                "dew_point_2m": first.temperature - (100 - city.climate.humidity) / 5,
            ] as [String: Any],
            "hourly": [
                "time": hours.map(\.time),
                "temperature_2m": hours.map(\.temperature),
                "precipitation_probability": hours.map(\.precipitationChance),
                "weather_code": hours.map(\.code),
                "is_day": hours.map(\.isDay),
            ],
            "daily": [
                "time": days.map(\.time),
                "weather_code": days.map(\.code),
                "temperature_2m_max": days.map(\.high),
                "temperature_2m_min": days.map(\.low),
                "sunrise": days.map(\.sunrise),
                "sunset": days.map(\.sunset),
                "uv_index_max": days.map(\.uvIndex),
                "precipitation_probability_max": days.map(\.precipitationChance),
            ],
        ]
    }

    private struct Hour {
        let time: TimeInterval
        let temperature: Double
        let code: Int
        let isDay: Int
        let precipitationChance: Int
    }

    private struct Day {
        let time: TimeInterval
        let code: Int
        let high: Double
        let low: Double
        let sunrise: TimeInterval
        let sunset: TimeInterval
        let uvIndex: Double
        let precipitationChance: Int
    }

    private func hour(at index: Int) -> Hour {
        let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let date = start.addingTimeInterval(TimeInterval(index) * 3600)
        let localHour = Double(calendar.component(.hour, from: date))
        // Warmest at 3 pm, coolest at 3 am.
        let temperature = city.climate.dailySwing * cos((localHour - 15) / 24 * 2 * .pi) + city.baseTemperature + dayOffset(0)
        let codes = city.climate.hourlyCodes
        let code = codes[index % codes.count]
        return Hour(
            time: date.timeIntervalSince1970,
            temperature: (temperature * 10).rounded() / 10,
            code: code,
            isDay: city.climate.daylight.contains(localHour) ? 1 : 0,
            precipitationChance: Condition(wmoCode: code).isWet ? 55 + (index * 7) % 40 : (index * 3) % 15
        )
    }

    private func day(at index: Int) -> Day {
        let start = calendar.date(byAdding: .day, value: index, to: calendar.startOfDay(for: now)) ?? now
        let code = city.climate.dailyCodes[index % city.climate.dailyCodes.count]
        let mean = city.baseTemperature + dayOffset(index)
        return Day(
            time: start.timeIntervalSince1970,
            code: code,
            high: ((mean + city.climate.dailySwing) * 10).rounded() / 10,
            low: ((mean - city.climate.dailySwing) * 10).rounded() / 10,
            sunrise: start.timeIntervalSince1970 + city.climate.daylight.lowerBound * 3600,
            sunset: start.timeIntervalSince1970 + city.climate.daylight.upperBound * 3600,
            uvIndex: city.climate == .sunny ? 8.4 : 3.1,
            precipitationChance: Condition(wmoCode: code).isWet ? 60 + (index * 11) % 35 : (index * 5) % 20
        )
    }

    /// Warmer and cooler spells across the ten days, different per city.
    private func dayOffset(_ index: Int) -> Double {
        sin(Double(index) * 1.3 + Double(city.id % 7)) * 2.5
    }
}

/// The device location in demo mode: always `DemoCatalog.home`, with no permission prompt.
final class DemoLocationProvider: LocationProviding {
    func currentPlace() async throws -> Place {
        DemoCatalog.homePlace
    }
}
