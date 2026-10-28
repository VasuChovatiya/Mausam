import Foundation
import NetworkingKit

nonisolated struct OpenMeteoWeatherProvider: WeatherProvider {
    let client: APIClient
    var source = WeatherSource.openMeteo

    func report(for place: Place) async throws -> WeatherReport {
        let dto = try await client.send(OpenMeteoEndpoints.forecast(latitude: place.latitude, longitude: place.longitude))
        return OpenMeteoMapper.report(from: dto, fetchedAt: .now, source: source)
    }

    func attribution() async throws -> DataAttribution {
        OpenMeteoConfiguration.attribution
    }
}

nonisolated struct OpenMeteoPlaceSearch: PlaceSearching {
    let client: APIClient
    var language = Locale.current.language.languageCode?.identifier ?? "en"

    func places(matching query: String) async throws -> [Place] {
        let dto = try await client.send(OpenMeteoEndpoints.search(query, language: language))
        return (dto.results ?? []).map(OpenMeteoMapper.place(from:))
    }
}

/// DTO → model conversion. Pure functions, covered by `OpenMeteoMapperTests`.
nonisolated enum OpenMeteoMapper {
    static func report(from dto: ForecastDTO, fetchedAt: Date, source: WeatherSource = .openMeteo) -> WeatherReport {
        WeatherReport(
            current: current(from: dto.current),
            hourly: hourly(from: dto.hourly),
            daily: daily(from: dto.daily),
            fetchedAt: fetchedAt,
            source: source
        )
    }

    static func current(from dto: CurrentDTO) -> CurrentConditions {
        CurrentConditions(
            date: Date(timeIntervalSince1970: dto.time),
            condition: Condition(wmoCode: dto.weatherCode),
            isDaylight: dto.isDay == 1,
            temperature: dto.temperature,
            apparentTemperature: dto.apparentTemperature,
            humidity: dto.humidity / 100,
            dewPoint: dto.dewPoint,
            windSpeed: dto.windSpeed,
            windGust: dto.windGusts,
            windDirection: dto.windDirection,
            pressure: dto.pressure,
            visibility: dto.visibility,
            uvIndex: dto.uvIndex,
            precipitation: dto.precipitation
        )
    }

    /// Hours missing a temperature or code are dropped rather than shown as zero.
    static func hourly(from dto: HourlyDTO) -> [HourlyForecast] {
        dto.time.indices.compactMap { index in
            guard let temperature = dto.temperature[safe: index] ?? nil,
                  let code = dto.weatherCode[safe: index] ?? nil else { return nil }
            return HourlyForecast(
                date: Date(timeIntervalSince1970: dto.time[index]),
                condition: Condition(wmoCode: code),
                isDaylight: (dto.isDay[safe: index] ?? nil) != 0,
                temperature: temperature,
                precipitationChance: ((dto.precipitationProbability[safe: index] ?? nil) ?? 0) / 100
            )
        }
    }

    static func daily(from dto: DailyDTO) -> [DailyForecast] {
        dto.time.indices.compactMap { index in
            guard let high = dto.temperatureMax[safe: index] ?? nil,
                  let low = dto.temperatureMin[safe: index] ?? nil,
                  let code = dto.weatherCode[safe: index] ?? nil else { return nil }
            return DailyForecast(
                date: Date(timeIntervalSince1970: dto.time[index]),
                condition: Condition(wmoCode: code),
                high: high,
                low: low,
                precipitationChance: ((dto.precipitationProbabilityMax[safe: index] ?? nil) ?? 0) / 100,
                sunrise: (dto.sunrise[safe: index] ?? nil).map(Date.init(timeIntervalSince1970:)),
                sunset: (dto.sunset[safe: index] ?? nil).map(Date.init(timeIntervalSince1970:)),
                uvIndexMax: dto.uvIndexMax[safe: index] ?? nil
            )
        }
    }

    static func place(from dto: PlaceDTO) -> Place {
        // "Singapore, Singapore" reads oddly, so a region that repeats the name is left out.
        let parts = [dto.admin1, dto.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != dto.name }
        var seen = Set<String>()
        let detail = parts.filter { seen.insert($0).inserted }.joined(separator: ", ")
        return Place(
            id: String(dto.id),
            name: dto.name,
            detail: detail.isEmpty ? nil : detail,
            latitude: dto.latitude,
            longitude: dto.longitude,
            timeZoneIdentifier: dto.timezone
        )
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
