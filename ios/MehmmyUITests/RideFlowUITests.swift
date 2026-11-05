import XCTest

final class RideFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSwitchingToLogModeShowsLogScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-sample"]
        app.launch()
        app.buttons["✅ Log"].tap()
        XCTAssertTrue(app.staticTexts["Log a ride"].waitForExistence(timeout: 5))
        app.buttons["🔔 Request"].tap()
        XCTAssertTrue(app.staticTexts["Need a ride?"].waitForExistence(timeout: 5))
    }
}

final class RideStressUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testRapidModeAndRouteChangesWhileMeasuring() {
        let app = XCUIApplication()
        app.launchArguments = ["-sample"]
        app.launch()
        for _ in 0..<4 {
            app.buttons["✅ Log"].tap()
            app.buttons["🔔 Request"].tap()
        }
        app.buttons["✅ Log"].tap()
        let places = ["EWR", "Gym", "Home", "Work"]
        for p in places {
            let chips = app.buttons.matching(identifier: p)
            if chips.count > 1 { chips.element(boundBy: 1).tap() }
        }
        app.buttons["🔔 Request"].tap()
        app.buttons["✅ Log"].tap()
        sleep(8)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.staticTexts["Log a ride"].exists)
    }
}
