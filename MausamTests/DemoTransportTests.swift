import Foundation
import NetworkingKit
import Testing
@testable import Mausam

/// Runs the real Open-Meteo request, decoding and mapping code against the offline demo transport.
struct DemoTransportTests {
    private let transport = DemoTransport(latency: .zero, now: { Date(timeIntervalSince1970: 1_800_000_000) })

    @Test func servesAFullForecast() async throws {
        let client = OpenMeteoConfiguration.makeClient(baseURL: OpenMeteoConfiguration.forecastBaseURL, transport: transport)
        let report = try await OpenMeteoWeatherProvider(client: client, source: .demo).report(for: Fixtures.london)

        #expect(report.hourly.count == OpenMeteoEndpoints.hours)
        #expect(report.daily.count == OpenMeteoEndpoints.days)
        #expect(report.source == .demo)
        #expect(report.daily.allSatisfy { $0.low <= $0.high })
        // London is the rainy demo city.
        #expect(report.hourly.contains { $0.condition.isWet })
    }

    @Test func searchIgnoresCaseAndAccents() async throws {
        let client = OpenMeteoConfiguration.makeClient(baseURL: OpenMeteoConfiguration.geocodingBaseURL, transport: transport)
        let search = OpenMeteoPlaceSearch(client: client, language: "en")

        let places = try await search.places(matching: "reyk")
        #expect(places.map(\.name) == ["Reykjavík"])
        #expect(places.first?.detail == "Capital Region, Iceland")
        #expect(try await search.places(matching: "zzqqx").isEmpty)
    }
}
