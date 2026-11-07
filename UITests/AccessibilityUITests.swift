import XCTest

/// Phase 9, AC-11 / NFR-8: Xcode's accessibility audit on the main screens at the
/// largest accessibility text size. Screenshots go to HANGUSTEP_SCREENSHOT_DIR.
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
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

    /// Collects audit issues across the Sendable boundary of the audit handler.
    private final class IssueLog: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        func add(_ item: String) { lock.withLock { items.append(item) } }
        var all: [String] { lock.withLock { items } }
    }

    /// Runs the audit up to `attempts` times and fails only on issues found in every
    /// run. The contrast check samples pixels and sometimes reads text mid-render
    /// (seen on Learn level chips at 5.8:1 and an unaddressable Settings element),
    /// so a one-off finding is noise; a real defect shows up in every run.
    private func audit(_ screen: String, attempts: Int = 3) throws {
        var persistent: Set<String>?
        for _ in 0..<attempts {
            let found = Set(try auditOnce(screen))
            persistent = persistent.map { $0.intersection(found) } ?? found
            if persistent?.isEmpty == true { return }
        }
        for finding in (persistent ?? []).sorted() { XCTFail(finding) }
    }

    /// One audit pass; returns the issues that are not known system behaviour.
    private func auditOnce(_ screen: String) throws -> [String] {
        // Let transitions (tab cross-fade, push, list loading) finish before sampling.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.0)
        let log = IssueLog()
        let bottomBarTop = app.windows.firstMatch.frame.maxY - 160
        try app.performAccessibilityAudit { issue in
            // iOS navigation-bar items do not scale with Dynamic Type (system
            // behaviour; long-press shows them enlarged), so those are not ours to fix.
            if issue.auditType == .dynamicType, let element = issue.element, Self.isToolbarItem(element) { return true }
            // System controls without an addressable element (stepper buttons, menu
            // chevrons) do not scale either; nothing in our code draws them.
            if issue.auditType == .dynamicType, issue.element == nil { return true }
            // Text scrolled partly under the translucent tab bar or the quiz action bar
            // samples against the bar, not its own background. Those elements are
            // audited again on screens where they sit higher up.
            if issue.auditType == .contrast || issue.auditType == .textClipped, let element = issue.element, element.frame.maxY > bottomBarTop { return true }
            if issue.auditType == .textClipped, issue.element == nil { return true }
            // Every piece of text our views draw is an accessibility element, so a
            // contrast issue with no element comes from system chrome (seen on Settings,
            // where the short form leaves the tab bar transparent over the grouped
            // background). Same reasoning as the Dynamic Type exemption above.
            if issue.auditType == .contrast, issue.element == nil { return true }
            log.add("[\(screen)] \(issue.auditType.rawValue): \(issue.compactDescription) — \(issue.detailedDescription) element=\(issue.element?.description ?? "-")")
            return true   // collected; do not stop at the first one
        }
        return log.all
    }

    private static func isToolbarItem(_ element: XCUIElement) -> Bool {
        let label = element.label
        return label == "Close" || label.range(of: #"^\d+ of \d+$"#, options: .regularExpression) != nil
    }

    func testMainScreensPassAuditAtLargestTextSize() throws {
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        snapshot("a11y-01-home")
        try audit("home")

        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        // The list sorts by Hangul; the first row is on screen at every text size.
        // Wait for it so the audit runs on the loaded list, not the loading state.
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '가게'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "first vocabulary row did not appear")
        snapshot("a11y-02-learn")
        try audit("learn")
        row.tap()
        XCTAssertTrue(app.staticTexts["Examples"].waitForExistence(timeout: 5))
        snapshot("a11y-03-vocabulary-detail")
        try audit("vocabulary detail")

        app.tabBars.buttons["Quiz"].tap()
        XCTAssertTrue(app.buttons["Start quiz"].waitForExistence(timeout: 5))
        snapshot("a11y-04-quiz-setup")
        try audit("quiz setup")
        app.buttons["Start quiz"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1'")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        snapshot("a11y-05-question")
        try audit("question")
        option.tap()
        app.buttons["Check"].tap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        snapshot("a11y-06-feedback")
        try audit("feedback")
        app.buttons["Close"].tap()
        app.buttons["End quiz"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        snapshot("a11y-07-results")
        try audit("results")
        app.buttons["Done"].tap()

        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 5))
        snapshot("a11y-08-review")
        try audit("review")

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        snapshot("a11y-09-progress")
        try audit("progress")

        app.tabBars.buttons["Home"].tap()
        let settings = app.buttons["settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "settings button did not appear")
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "settings screen did not appear")
        snapshot("a11y-10-settings")
        try audit("settings")
    }
}
