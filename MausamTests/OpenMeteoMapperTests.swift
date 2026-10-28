import Foundation
import NetworkingKit
import Testing
@testable import Mausam

struct OpenMeteoMapperTests {
    private func decodeFixture() throws -> ForecastDTO {
        try JSONDecoder().decode(ForecastDTO.self, from: Data(Fixtures.forecastJSON.utf8))
    }

    @Test func mapsCurrentConditionsToMetricModel() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_793_184_400)
        let report = OpenMeteoMapper.report(from: try decodeFixture(), fetchedAt: fetchedAt)

        #expect(report.current.temperature == 33.0)
        #expect(report.current.condition == .partlyCloudy)
        #expect(report.current.isDaylight)
        #expect(report.current.humidity == 0.21)
        #expect(report.current.windSpeed == 18.5)
        #expect(report.current.pressure == 1008.8)
        #expect(report.current.date == Date(timeIntervalSince1970: 1_793_184_300))
        #expect(report.fetchedAt == fetchedAt)
        #expect(report.source == .openMeteo)
    }

    @Test func dropsHoursWithMissingValues() throws {
        let hours = OpenMeteoMapper.hourly(from: try decodeFixture().hourly)

        #expect(hours.count == 2)
        #expect(hours.map(\.temperature) == [33.8, 31.2])
        #expect(hours[1].condition == .rain)
        #expect(hours[1].precipitationChance == 0.45)
        #expect(!hours[1].isDaylight)
    }

    @Test func mapsDaysWithSunTimes() throws {
        let days = OpenMeteoMapper.daily(from: try decodeFixture().daily)

        #expect(days.count == 2)
        #expect(days[0].high == 34.3)
        #expect(days[0].low == 22.1)
        #expect(days[0].sunrise == Date(timeIntervalSince1970: 1_793_150_100))
        #expect(days[1].condition == .thunderstorm)
        #expect(days[1].precipitationChance == 0.8)
        #expect(days[1].uvIndexMax == nil)
    }

    @Test func placeDetailSkipsPartsThatRepeatTheName() {
        let singapore = PlaceDTO(
            id: 1, name: "Singapore", latitude: 1.29, longitude: 103.85,
            timezone: "Asia/Singapore", country: "Singapore", admin1: nil
        )
        let surat = PlaceDTO(
            id: 2, name: "Surat", latitude: 21.2, longitude: 72.8,
            timezone: "Asia/Kolkata", country: "India", admin1: "Gujarat"
        )

        #expect(OpenMeteoMapper.place(from: singapore).detail == nil)
        #expect(OpenMeteoMapper.place(from: surat).detail == "Gujarat, India")
        #expect(OpenMeteoMapper.place(from: surat).id == "2")
    }

    @Test func forecastRequestAsksForUnixTimesInLocalTime() {
        let endpoint = OpenMeteoEndpoints.forecast(latitude: 21.195_94, longitude: -0.1)
        let query = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value ?? "") })

        #expect(endpoint.path == "/forecast")
        #expect(query["latitude"] == "21.1959")
        #expect(query["longitude"] == "-0.1000")
        #expect(query["timeformat"] == "unixtime")
        #expect(query["timezone"] == "auto")
        #expect(query["forecast_days"] == "10")
    }
}
