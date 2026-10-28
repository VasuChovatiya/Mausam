import Foundation

/// A source of forecasts. The app ships two (Open-Meteo and WeatherKit) and tests pass a stub.
nonisolated protocol WeatherProvider: Sendable {
    func report(for place: Place) async throws -> WeatherReport
    func attribution() async throws -> DataAttribution
}

/// Finds places by name for the search screen.
nonisolated protocol PlaceSearching: Sendable {
    func places(matching query: String) async throws -> [Place]
}
