import Foundation
import Testing
@testable import Mausam

struct WeatherFormatterTests {
    private let celsius = WeatherFormatter(temperatureUnit: .celsius, locale: Locale(identifier: "en_GB"))
    private let fahrenheit = WeatherFormatter(temperatureUnit: .fahrenheit, locale: Locale(identifier: "en_US"))

    @Test func roundsTemperatures() {
        #expect(celsius.temperature(21.4) == "21°")
        #expect(celsius.temperature(21.6) == "22°")
        #expect(fahrenheit.temperature(0) == "32°")
        #expect(fahrenheit.temperature(37) == "99°")
    }

    @Test func neverShowsMinusZero() {
        #expect(celsius.temperature(-0.4) == "0°")
    }

    @Test func labelsHoursInThePlacesTimeZone() throws {
        let date = Date(timeIntervalSince1970: 1_793_181_600)  // 10:00 UTC
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let london = try #require(TimeZone(identifier: "Europe/London"))

        #expect(normalized(fahrenheit.hour(date, in: tokyo)) == "7 PM")
        #expect(normalized(fahrenheit.hour(date, in: london)) == "10 AM")
    }

    @Test(arguments: [(0.0, "N"), (44, "NE"), (180, "S"), (230, "SW"), (350, "N"), (-90, "W")])
    func namesCompassPoints(degrees: Double, expected: String) {
        #expect(WeatherFormatter.compassPoint(degrees) == expected)
    }

    @Test(arguments: [(1.0, "Low"), (4, "Moderate"), (7, "High"), (9, "Very High"), (12, "Extreme")])
    func bandsUVIndex(index: Double, expected: String) {
        #expect(WeatherFormatter.uvCategory(index) == expected)
    }

    @Test func systemUnitFollowsTheRegion() {
        #expect(TemperatureUnit.system.resolved(for: Locale(identifier: "en_US")) == .fahrenheit)
        #expect(TemperatureUnit.system.resolved(for: Locale(identifier: "en_IN")) == .celsius)
        #expect(TemperatureUnit.celsius.resolved(for: Locale(identifier: "en_US")) == .celsius)
    }

    /// Date formatting puts a narrow no-break space before AM/PM.
    private func normalized(_ string: String) -> String {
        string.replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
