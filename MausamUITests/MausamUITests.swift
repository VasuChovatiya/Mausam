import XCTest

/// End-to-end smoke tests on the offline demo data, so they pass without network or location access.
@MainActor
final class MausamUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UITestDemoData", "-UITestInMemoryStore"]
        app.launch()
        return app
    }

    func testShowsTheForecastForTheCurrentLocation() {
        let app = launch()

        let header = app.element("forecast-header")
        XCTAssertTrue(header.waitForExistence(timeout: 10), "No forecast header")
        XCTAssertTrue(header.label.contains("Surat"), "Header was \(header.label)")
        let hourly = app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] 'Hourly Forecast'")).firstMatch
        XCTAssertTrue(hourly.waitForExistence(timeout: 5), "No hourly forecast card")
    }

    func testSearchAddsAPlaceAndShowsItsForecast() {
        let app = launch()
        XCTAssertTrue(app.element("forecast-header").waitForExistence(timeout: 10))

        app.buttons["places-button"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Tok")

        let result = app.element("search-result")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        let tokyo = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'forecast-header' AND label CONTAINS 'Tokyo'"))
            .firstMatch
        XCTAssertTrue(tokyo.waitForExistence(timeout: 10))

        app.buttons["places-button"].tap()
        let rows = app.descendants(matching: .any).matching(identifier: "place-row")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 2)
    }
}

extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
