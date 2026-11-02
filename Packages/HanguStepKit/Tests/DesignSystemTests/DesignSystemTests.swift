@testable import DesignSystem
import XCTest

final class DesignSystemTests: XCTestCase {
    func testViewStateValueAndLoading() {
        XCTAssertEqual(ViewState<Int>.loaded(3).value, 3)
        XCTAssertNil(ViewState<Int>.loading.value)
        XCTAssertTrue(ViewState<Int>.loading.isLoading)
        XCTAssertFalse(ViewState<Int>.failed(message: "x").isLoading)
    }

    func testCircledNumbersFollowTOPIKConvention() {
        XCTAssertEqual(CircledNumber.label(for: 0), "①")
        XCTAssertEqual(CircledNumber.label(for: 3), "④")
        XCTAssertEqual(CircledNumber.label(for: 19), "⑳")
        XCTAssertEqual(CircledNumber.label(for: 20), "21")
        XCTAssertEqual(CircledNumber.label(for: -1), "0")
    }

    func testScriptLineSpacingOnlyForKhmer() {
        XCTAssertEqual(Script.khmer.lineSpacing, 4)
        XCTAssertEqual(Script.hangul.lineSpacing, 0)
        XCTAssertEqual(Script.latin.lineSpacing, 0)
    }
}
