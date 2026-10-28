import Foundation

/// Everything one forecast screen shows. Values are stored in metric units (°C, km/h, hPa, metres)
/// and converted for display, so the cache doesn't depend on the user's unit setting.
nonisolated struct WeatherReport: Codable, Sendable, Equatable {
    let current: CurrentConditions
    /// Starts at the current hour.
    let hourly: [HourlyForecast]
    /// Starts today.
    let daily: [DailyForecast]
    /// When the provider answered. Drives "Updated 5 min ago" and the cache's freshness check.
    let fetchedAt: Date
    let source: WeatherSource

    /// The next `limit` hours from the hour containing `now`, so a cached report never starts in the past.
    func upcomingHours(from now: Date, limit: Int = 24) -> [HourlyForecast] {
        let start = now.addingTimeInterval(-3600)
        return Array(hourly.lazy.filter { $0.date > start }.prefix(limit))
    }

    /// Days from the one containing `now`, in the place's time zone.
    func upcomingDays(from now: Date, in timeZone: TimeZone) -> [DailyForecast] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        return daily.filter { $0.date >= today }
    }

    /// Today's forecast, for the high and low under the current temperature.
    func today(from now: Date, in timeZone: TimeZone) -> DailyForecast? {
        upcomingDays(from: now, in: timeZone).first
    }
}

nonisolated enum WeatherSource: String, Codable, Sendable {
    case openMeteo = "openMeteo"
    case weatherKit = "weatherKit"
    /// The offline transport used by UI tests and previews.
    case demo = "demo"
}

nonisolated struct CurrentConditions: Codable, Sendable, Equatable {
    let date: Date
    let condition: Condition
    let isDaylight: Bool
    /// °C
    let temperature: Double
    /// °C
    let apparentTemperature: Double
    /// 0...1
    let humidity: Double
    /// °C
    let dewPoint: Double?
    /// km/h
    let windSpeed: Double
    /// km/h
    let windGust: Double?
    /// Degrees the wind blows from, 0 = north.
    let windDirection: Double?
    /// hPa at sea level
    let pressure: Double?
    /// metres
    let visibility: Double?
    let uvIndex: Double?
    /// mm over the last hour
    let precipitation: Double?
}

nonisolated struct HourlyForecast: Codable, Sendable, Equatable, Identifiable {
    let date: Date
    let condition: Condition
    let isDaylight: Bool
    /// °C
    let temperature: Double
    /// 0...1
    let precipitationChance: Double

    var id: Date { date }
}

nonisolated struct DailyForecast: Codable, Sendable, Equatable, Identifiable {
    /// Local midnight of the day.
    let date: Date
    let condition: Condition
    /// °C
    let high: Double
    /// °C
    let low: Double
    /// 0...1
    let precipitationChance: Double
    let sunrise: Date?
    let sunset: Date?
    let uvIndexMax: Double?

    var id: Date { date }
}

/// The credit a provider's terms require under its data.
nonisolated struct DataAttribution: Sendable, Equatable {
    let serviceName: String
    let legalURL: URL
    /// Logo for dark backgrounds, when the provider has one.
    let markURL: URL?
}
