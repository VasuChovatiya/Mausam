import XCTest

/// Captures the README screenshots in light and dark mode from the demo data. Skipped unless
/// `MAUSAM_CAPTURE=1`:
///
///     TEST_RUNNER_MAUSAM_CAPTURE=1 TEST_RUNNER_MAUSAM_CAPTURE_DIR=$PWD/Screenshots \
///       xcodebuild test -only-testing:MausamUITests/ScreenshotTests ...
@MainActor
final class ScreenshotTests: XCTestCase {
    private func launch(appearance: String) throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MAUSAM_CAPTURE"] == "1", "Set MAUSAM_CAPTURE=1 to capture screenshots.")
        continueAfterFailure = false
        let app = XCUIApplication()
        // `-key value` lands in UserDefaults, which @AppStorage reads.
        app.launchArguments += ["-UITestDemoData", "-UITestInMemoryStore", "-appearance", appearance]
        app.launch()
        return app
    }

    /// Attaches the screenshot to the result bundle and, when `MAUSAM_CAPTURE_DIR` is set, also writes
    /// it there as `<name>.png` (the simulator can write to the Mac's file system).
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let directory = ProcessInfo.processInfo.environment["MAUSAM_CAPTURE_DIR"] {
            let url = URL(fileURLWithPath: directory).appending(path: "\(name).png")
            XCTAssertNoThrow(try screenshot.pngRepresentation.write(to: url))
        }
    }

    private func settle(_ seconds: TimeInterval = 1.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func add(_ city: String, in app: XCUIApplication) {
        app.buttons["places-button"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(city)
        let result = app.element("search-result")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        settle()
    }

    func testCaptureLight() throws {
        try captureScreens(appearance: "light")
    }

    func testCaptureDark() throws {
        try captureScreens(appearance: "dark")
    }

    private func captureScreens(appearance: String) throws {
        let app = try launch(appearance: appearance)
        XCTAssertTrue(app.element("forecast-header").waitForExistence(timeout: 10))
        settle(2)
        capture("forecast-\(appearance)")

        app.swipeUp()
        app.swipeUp()
        settle()
        capture("details-\(appearance)")
        app.swipeDown()
        app.swipeDown()
        settle(0.5)

        add("Lond", in: app)
        capture("rain-\(appearance)")
        add("Reyk", in: app)
        capture("snow-\(appearance)")
        add("New Y", in: app)

        app.buttons["places-button"].tap()
        settle(2)
        capture("places-\(appearance)")
    }
}
