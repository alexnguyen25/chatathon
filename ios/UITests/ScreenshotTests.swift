import XCTest

/// Walks the flow and screenshots every screen.
///
/// This exists because nobody working on the app has a Mac. "It compiles" is
/// not the same as "it looks right", and the layout numbers in DayTimeline
/// were derived from the mockups arithmetically rather than by eye. These
/// attachments are the only way to check the difference.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        // .keepAlways — the default discards attachments from passing tests,
        // which would throw away the entire point of this suite.
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Waits for `element`, screenshots, then taps it.
    private func tap(_ element: XCUIElement, screenshotFirst name: String?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 15),
            "never appeared: \(element)", file: file, line: line
        )
        if let name { capture(name) }
        element.tap()
    }

    func testWalkTheWholeFlow() {
        // 1 — Live
        XCTAssertTrue(
            app.staticTexts["Live heart rate"].waitForExistence(timeout: 20),
            "Live tab never rendered"
        )
        capture("01-live-heart-rate")

        // 2 — Your day
        tap(app.tabBars.buttons["Example day"], screenshotFirst: nil)
        XCTAssertTrue(
            app.staticTexts["Your day"].waitForExistence(timeout: 15),
            "Your day never rendered"
        )
        // Let the timeline lay out before capturing it.
        sleep(1)
        capture("02-your-day")

        // 3 — Suggestion detail
        tap(app.buttons["Review suggestion"], screenshotFirst: nil)
        XCTAssertTrue(
            app.staticTexts["A little room to reset"].waitForExistence(timeout: 15),
            "Suggestion detail never rendered"
        )
        capture("03-suggestion-idle")
        // The explanation loads on appear; catch the resolved state too.
        sleep(3)
        capture("03b-suggestion-explained")

        // 4 — Add a break
        tap(app.buttons["Review calendar event"], screenshotFirst: nil)
        XCTAssertTrue(
            app.staticTexts["Add a break"].waitForExistence(timeout: 15),
            "Add a break never rendered"
        )
        capture("04-add-a-break")

        // 5 — Confirmation
        tap(app.buttons["Add to example calendar"], screenshotFirst: nil)
        XCTAssertTrue(
            app.staticTexts["Break added"].waitForExistence(timeout: 15),
            "Confirmation never rendered"
        )
        sleep(1)
        capture("05-break-added")

        // 6 — Back to the day, with the break now on the calendar. This is the
        // one state the mockups do not show, so it is the one most likely to
        // be wrong.
        tap(app.buttons["Back to your day"], screenshotFirst: nil)
        XCTAssertTrue(
            app.staticTexts["Your day"].waitForExistence(timeout: 15),
            "did not return to Your day"
        )
        sleep(1)
        capture("06-day-with-break-added")
    }

    /// Dark mode and the largest accessibility text size, on the two screens
    /// with the densest layout. Both are claimed to work and neither has been
    /// looked at.
    func testDarkModeAndLargeText() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIUserInterfaceStyle", "Dark"]
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Live heart rate"].waitForExistence(timeout: 20))
        capture("07-live-dark-large-text")

        let dayTab = app.tabBars.buttons["Example day"]
        if dayTab.waitForExistence(timeout: 10) {
            dayTab.tap()
            _ = app.staticTexts["Your day"].waitForExistence(timeout: 15)
            sleep(1)
            capture("08-day-dark-large-text")
        }
    }
}
