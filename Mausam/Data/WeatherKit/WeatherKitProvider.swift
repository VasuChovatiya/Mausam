import CoreLocation
import Foundation
import WeatherKit

/// Apple WeatherKit. Requests only succeed when the app is signed with an App ID that has the
/// WeatherKit capability; see `Config/Local.example.xcconfig`.
nonisolated struct WeatherKitProvider: WeatherProvider {
    func report(for place: Place) async throws -> WeatherReport {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let (current, hourly, daily) = try await WeatherService.shared.weather(
            for: location,
            including: .current, .hourly, .daily
        )
        return WeatherReport(
            current: WeatherKitMapper.current(from: current),
            hourly: hourly.forecast.prefix(OpenMeteoEndpoints.hours).map(WeatherKitMapper.hour(from:)),
            daily: daily.forecast.prefix(OpenMeteoEndpoints.days).map(WeatherKitMapper.day(from:)),
            fetchedAt: .now,
            source: .weatherKit
        )
    }

    /// Apple's terms require the Apple Weather mark and a link to its legal page next to the data.
    func attribution() async throws -> DataAttribution {
        let attribution = try await WeatherService.shared.attribution
        return DataAttribution(
            serviceName: attribution.serviceName,
            legalURL: attribution.legalPageURL,
            markURL: attribution.combinedMarkDarkURL
        )
    }
}

nonisolated enum WeatherKitMapper {
    static func current(from weather: CurrentWeather) -> CurrentConditions {
        CurrentConditions(
            date: weather.date,
            condition: condition(from: weather.condition),
            isDaylight: weather.isDaylight,
            temperature: weather.temperature.converted(to: .celsius).value,
            apparentTemperature: weather.apparentTemperature.converted(to: .celsius).value,
            humidity: weather.humidity,
            dewPoint: weather.dewPoint.converted(to: .celsius).value,
            windSpeed: weather.wind.speed.converted(to: .kilometersPerHour).value,
            windGust: weather.wind.gust?.converted(to: .kilometersPerHour).value,
            windDirection: weather.wind.direction.converted(to: .degrees).value,
            pressure: weather.pressure.converted(to: .hectopascals).value,
            visibility: weather.visibility.converted(to: .meters).value,
            uvIndex: Double(weather.uvIndex.value),
            precipitation: nil
        )
    }

    static func hour(from weather: HourWeather) -> HourlyForecast {
        HourlyForecast(
            date: weather.date,
            condition: condition(from: weather.condition),
            isDaylight: weather.isDaylight,
            temperature: weather.temperature.converted(to: .celsius).value,
            precipitationChance: weather.precipitationChance
        )
    }

    static func day(from weather: DayWeather) -> DailyForecast {
        DailyForecast(
            date: weather.date,
            condition: condition(from: weather.condition),
            high: weather.highTemperature.converted(to: .celsius).value,
            low: weather.lowTemperature.converted(to: .celsius).value,
            precipitationChance: weather.precipitationChance,
            sunrise: weather.sun.sunrise,
            sunset: weather.sun.sunset,
            uvIndexMax: Double(weather.uvIndex.value)
        )
    }

    static func condition(from condition: WeatherCondition) -> Condition {
        switch condition {
        case .clear, .hot, .frigid: .clear
        case .mostlyClear: .mostlyClear
        case .partlyCloudy: .partlyCloudy
        case .cloudy, .mostlyCloudy: .cloudy
        case .foggy, .haze, .smoky, .blowingDust: .fog
        case .breezy, .windy: .windy
        case .drizzle: .drizzle
        case .rain, .sunShowers: .rain
        case .heavyRain: .heavyRain
        case .freezingDrizzle, .freezingRain, .sleet, .hail, .wintryMix: .freezingRain
        case .snow, .flurries, .sunFlurries, .blowingSnow: .snow
        case .heavySnow, .blizzard: .heavySnow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            .thunderstorm
        @unknown default: .cloudy
        }
    }
}
