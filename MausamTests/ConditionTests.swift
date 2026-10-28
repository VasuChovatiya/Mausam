import Testing
import UIKit
@testable import Mausam

struct ConditionTests {
    @Test(arguments: [
        (0, Condition.clear), (1, .mostlyClear), (2, .partlyCloudy), (3, .cloudy), (45, .fog),
        (53, .drizzle), (57, .freezingRain), (63, .rain), (65, .heavyRain), (73, .snow),
        (75, .heavySnow), (82, .heavyRain), (95, .thunderstorm), (99, .thunderstorm), (42, .cloudy),
    ])
    func mapsWMOCodes(code: Int, expected: Condition) {
        #expect(Condition(wmoCode: code) == expected)
    }

    @Test(arguments: Condition.allCases)
    func everySymbolExists(condition: Condition) {
        #expect(UIImage(systemName: condition.symbolName(isDaylight: true)) != nil)
        #expect(UIImage(systemName: condition.symbolName(isDaylight: false)) != nil)
    }

    @Test func onlyFallingWeatherIsWet() {
        #expect(Condition.rain.isWet)
        #expect(Condition.snow.isWet)
        #expect(!Condition.fog.isWet)
        #expect(!Condition.clear.isWet)
    }
}
