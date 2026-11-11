@testable import Domain
import XCTest

/// Phase 10 optimisation guard: the cached day lookup must agree with
/// `Calendar.startOfDay` for any order of dates, including across DST changes.
final class DayBucketsTests: XCTestCase {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func assertMatchesStartOfDay(_ dates: [Date], calendar: Calendar, file: StaticString = #filePath, line: UInt = #line) {
        var buckets = DayBuckets(calendar: calendar)
        for date in dates {
            XCTAssertEqual(buckets.startOfDay(for: date), calendar.startOfDay(for: date), "\(date)", file: file, line: line)
        }
    }

    func testSortedAndShuffledDatesMatchStartOfDay() {
        let calendar = calendar("Asia/Phnom_Penh")
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let dates = (0..<500).map { start.addingTimeInterval(Double($0) * 4_321) }
        assertMatchesStartOfDay(dates, calendar: calendar)
        var generator = SeededGenerator(seed: 7)
        assertMatchesStartOfDay(dates.shuffled(using: &generator), calendar: calendar)
    }

    func testDaylightSavingTransitionsMatchStartOfDay() {
        // New York: 23-hour day on 8 March 2026, 25-hour day on 1 November 2026.
        let calendar = calendar("America/New_York")
        for (month, day) in [(3, 7), (10, 31)] {
            let start = calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
            let dates = (0..<(3 * 24 * 4)).map { start.addingTimeInterval(Double($0) * 900) }
            assertMatchesStartOfDay(dates, calendar: calendar)
        }
    }

    func testMidnightBoundaryStartsANewDay() {
        let calendar = calendar("Asia/Phnom_Penh")
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2))!
        var buckets = DayBuckets(calendar: calendar)
        XCTAssertEqual(buckets.startOfDay(for: midnight.addingTimeInterval(-1)), calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!)
        XCTAssertEqual(buckets.startOfDay(for: midnight), midnight)
    }
}

/// Deterministic shuffle so a failure reproduces.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
