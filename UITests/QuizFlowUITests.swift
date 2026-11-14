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

        // Phase 5: today's answers light the streak and the goal ring on Home.
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(row(startingWith: "1 day streak").waitForExistence(timeout: 5), "streak badge did not update")
        XCTAssertTrue(row(startingWith: "Daily goal, 5 of").waitForExistence(timeout: 5), "goal tile did not update")
        snapshot("05b-home-after-quiz")

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

    /// Phase 8: enable the built-in assistant, get an explanation in a quiz, generate
    /// practice from a word and start it. Offline: the mock provider needs no key.
    func testAssistantExplainsAndGeneratesPractice() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        app.buttons["settings"].firstMatch.tap()
        let toggle = app.switches["assistant.enabled"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "assistant toggle did not appear")
        toggle.tap()
        if (toggle.value as? String) != "1" { toggle.switches.firstMatch.tap() }
        XCTAssertEqual(toggle.value as? String, "1", "assistant toggle did not switch on")
        let picker = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Provider'")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "provider picker did not appear after enabling")
        snapshot("11-settings-assistant")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Quiz"].tap()
        XCTAssertTrue(app.buttons["Start quiz"].waitForExistence(timeout: 5))
        app.buttons["Start quiz"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1'")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        app.buttons["Check"].tap()
        let explain = app.buttons["assistant.explain"].firstMatch
        XCTAssertTrue(explain.waitForExistence(timeout: 5), "explain button did not appear in feedback")
        explain.tap()
        XCTAssertTrue(app.otherElements["assistant.explanation"].firstMatch.waitForExistence(timeout: 10)
                      || app.staticTexts["Built-in assistant"].waitForExistence(timeout: 1), "explanation did not appear")
        snapshot("12-assistant-explanation")
        app.buttons["Close"].tap()
        app.buttons["End quiz"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "results did not appear after ending the quiz")
        app.buttons["Done"].tap()

        app.tabBars.buttons["Learn"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("hakgyo")
        XCTAssertTrue(row(startingWith: "학교").waitForExistence(timeout: 5))
        row(startingWith: "학교").tap()
        let generate = app.buttons["assistant.generatePractice"].firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 5), "generate button did not appear")
        generate.tap()
        XCTAssertTrue(app.buttons["Check"].waitForExistence(timeout: 10), "generated practice session did not start")
        snapshot("13-generated-practice")
        app.buttons["Close"].tap()
        app.buttons["End quiz"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "results did not appear after ending the quiz")
        app.buttons["Done"].tap()
    }

    /// TOPIK II batch 1 (ADR-010): level 3 words, Wiktionary attribution on the word and in Settings.
    func testTopikTwoContentAndAttribution() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Learn"].tap()
        let levelThree = app.buttons["L3"].firstMatch
        XCTAssertTrue(levelThree.waitForExistence(timeout: 5), "level 3 filter did not appear")
        levelThree.tap()
        snapshot("13-level3-list")
        levelThree.tap()
        let levelFour = app.buttons["L4"].firstMatch
        levelFour.tap()
        XCTAssertTrue(row(startingWith: "가득").waitForExistence(timeout: 5), "level 4 word 가득 did not appear")
        snapshot("13b-level4-list")
        levelFour.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("gyeongje")
        XCTAssertTrue(row(startingWith: "경제").waitForExistence(timeout: 5), "경제 row did not appear")
        row(startingWith: "경제").tap()
        let source = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Source: Wiktionary'")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5), "attribution line did not appear")
        snapshot("14-level3-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Home"].tap()
        app.buttons["settings"].firstMatch.tap()
        let credit = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Includes material from Wiktionary'")).firstMatch
        for _ in 0..<6 where !credit.exists { app.swipeUp() }
        XCTAssertTrue(credit.waitForExistence(timeout: 5), "Settings credit did not appear")
        snapshot("15-settings-credits")
    }

    /// Listening pool (ADR-011): audio control first, script only after answering.
    func testListeningQuestionHidesScriptUntilAnswered() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Quiz"].tap()
        XCTAssertTrue(app.buttons["Start quiz"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Listening"].firstMatch.tap()
        app.segmentedControls.buttons["5"].firstMatch.tap()
        app.buttons["Start quiz"].tap()

        let play = app.buttons["listening.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "listening controls did not appear")
        XCTAssertFalse(app.descendants(matching: .any)["listening.script"].exists, "script visible before answering")
        snapshot("16-listening-question")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1'")).firstMatch.tap()
        app.buttons["Check"].tap()
        let script = app.descendants(matching: .any)["listening.script"]
        for _ in 0..<4 where !script.exists { app.swipeUp() }
        XCTAssertTrue(script.waitForExistence(timeout: 5), "script did not appear after answering")
        snapshot("17-listening-feedback")
        app.buttons["Close"].tap()
        let end = app.buttons["End quiz"]
        if end.waitForExistence(timeout: 3) { end.tap() }
    }
}

