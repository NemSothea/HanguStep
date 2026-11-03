import XCTest

/// End-to-end smoke test: launch, run a 5-question quiz, reach results, check history and mistakes.
final class QuizFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["HANGUSTEP_SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        }
    }

    func testQuizRoundTripAndHistory() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15), "dashboard did not appear")
        snapshot("01-home")

        app.tabBars.buttons["Quiz"].tap()
        XCTAssertTrue(app.buttons["Start quiz"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["5"].firstMatch.tap()
        snapshot("02-quiz-setup")
        app.buttons["Start quiz"].tap()

        for index in 1...5 {
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1'")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5), "question \(index) did not appear")
            option.tap()
            if index == 1 { snapshot("03-question-selected") }
            app.buttons["Check"].tap()
            if index == 1 { snapshot("04-feedback") }
            let next = index == 5 ? app.buttons["See results"] : app.buttons["Next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }

        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 5))
        snapshot("05-results")
        app.buttons["Done"].tap()

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["5 of 5"].firstMatch.waitForExistence(timeout: 5) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of 5'")).firstMatch.waitForExistence(timeout: 5))
        snapshot("06-history")

        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 5))
        snapshot("07-review")
    }

    /// List rows combine their children into one accessibility element, so the
    /// Hangul is the prefix of the row label rather than a standalone static text.
    private func row(startingWith hangul: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", hangul))
            .firstMatch
    }

    func testLearnSearchAndDetail() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Learn"].tap()
        // The list sorts by Hangul, so 학교 starts off screen; search by romanization
        // (ASCII keeps the simulator keyboard predictable) to bring it into view.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "search field did not appear")
        search.tap()
        search.typeText("hakgyo")
        XCTAssertTrue(row(startingWith: "학교").waitForExistence(timeout: 5), "vocabulary row did not appear")
        row(startingWith: "학교").tap()
        XCTAssertTrue(app.staticTexts["Examples"].waitForExistence(timeout: 5))
        snapshot("08-vocabulary-detail")
        app.buttons["Bookmark"].tap()
        XCTAssertTrue(app.buttons["Remove bookmark"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls.buttons["Bookmarks"].tap()
        XCTAssertTrue(row(startingWith: "학교").waitForExistence(timeout: 5), "bookmark row did not appear")
        snapshot("09-bookmarks")
        app.segmentedControls.buttons["Grammar"].tap()
        XCTAssertTrue(row(startingWith: "-아/어요").waitForExistence(timeout: 5), "grammar row did not appear")
        row(startingWith: "-아/어요").tap()
        XCTAssertTrue(app.staticTexts["How to form it"].waitForExistence(timeout: 5))
        snapshot("10-grammar-detail")
    }
}
