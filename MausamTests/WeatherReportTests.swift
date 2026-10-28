import Foundation
import Testing
@testable import Mausam

struct WeatherReportTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func upcomingHoursStartAtTheCurrentHour() {
        let report = Fixtures.report(fetchedAt: start)

        let hours = report.upcomingHours(from: start.addingTimeInterval(3 * 3600 + 600))

        #expect(hours.first?.date == start.addingTimeInterval(3 * 3600))
        #expect(hours.count == 22)
    }

    @Test func upcomingDaysStartTodayInThePlacesTimeZone() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let midnight = calendar.startOfDay(for: start)
        let report = Fixtures.report(fetchedAt: midnight)

        let days = report.upcomingDays(from: midnight.addingTimeInterval(2 * 86_400 + 3600), in: tokyo)

        #expect(days.first?.date == midnight.addingTimeInterval(2 * 86_400))
        #expect(days.count == 8)
    }
}
