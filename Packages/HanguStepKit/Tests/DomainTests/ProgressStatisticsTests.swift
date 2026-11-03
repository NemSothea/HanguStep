import Domain
import XCTest

final class ProgressStatisticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 10, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func attempt(_ n: Int, day: Int, hour: Int = 10, correct: Bool = true, target: LearningTarget? = nil) -> Attempt {
        Attempt(id: AttemptID("a\(n)"), sessionID: StudySessionID("s"), questionID: QuestionID("q\(n)"), selectedOptionID: OptionID("o"), isCorrect: correct, answeredAt: date(day, hour: hour), responseTime: 1, target: target)
    }

    func testTotalsTodayAndActivityWindows() {
        let attempts = [
            attempt(1, day: 1), attempt(2, day: 1, correct: false),
            attempt(3, day: 2),
            attempt(4, day: 3, hour: 0), attempt(5, day: 3, hour: 23),
        ]
        let summary = ProgressStatistics.summary(attempts: attempts, sessions: [], now: date(3, hour: 23, month: 11).addingTimeInterval(1800), calendar: calendar)
        XCTAssertEqual(summary.totals.total, 5)
        XCTAssertEqual(summary.totals.correct, 4)
        XCTAssertEqual(summary.answeredToday, 2, "both ends of the local day count as today")
        XCTAssertEqual(summary.correctToday, 2)
        XCTAssertEqual(summary.last7Days.count, 7)
        XCTAssertEqual(summary.last30Days.count, 30)
        XCTAssertEqual(summary.last7Days.map(\.answered), [0, 0, 0, 0, 2, 1, 2])
        XCTAssertEqual(summary.last7Days.last?.day, calendar.startOfDay(for: date(3)))
        XCTAssertEqual(summary.answeredLast7Days, 5)
        XCTAssertEqual(summary.accuracyLast7Days, 0.8, accuracy: 0.0001)
        XCTAssertEqual(summary.last7Days[4].accuracy ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(summary.last7Days[0].accuracy)
    }

    func testStreakCountsThroughTodayOrYesterday() {
        let active = Set([1, 2, 3].map { calendar.startOfDay(for: date($0)) })
        XCTAssertEqual(ProgressStatistics.streaks(activeDays: active, today: calendar.startOfDay(for: date(3)), calendar: calendar).current, 3)
        XCTAssertEqual(ProgressStatistics.streaks(activeDays: active, today: calendar.startOfDay(for: date(4)), calendar: calendar).current, 3, "not broken until the day after a quiet day ends")
        XCTAssertEqual(ProgressStatistics.streaks(activeDays: active, today: calendar.startOfDay(for: date(5)), calendar: calendar).current, 0)
        XCTAssertEqual(ProgressStatistics.streaks(activeDays: [], today: date(5), calendar: calendar).current, 0)
    }

    func testLongestStreakScansHistory() {
        let active = Set([1, 2, 3, 7, 8, 9, 10, 20].map { calendar.startOfDay(for: date($0)) })
        let streaks = ProgressStatistics.streaks(activeDays: active, today: calendar.startOfDay(for: date(20)), calendar: calendar)
        XCTAssertEqual(streaks.current, 1)
        XCTAssertEqual(streaks.longest, 4)
    }

    func testWeakItemsNeedThreeAttemptsAndUnderSixtyPercent() {
        let weak = LearningTarget.vocabulary(VocabularyID("weak"))
        let fine = LearningTarget.vocabulary(VocabularyID("fine"))
        let young = LearningTarget.grammar(GrammarID("young"))
        let attempts = [
            attempt(1, day: 1, correct: false, target: weak), attempt(2, day: 1, correct: true, target: weak), attempt(3, day: 1, correct: false, target: weak),
            attempt(4, day: 1, correct: true, target: fine), attempt(5, day: 1, correct: true, target: fine), attempt(6, day: 1, correct: false, target: fine),
            attempt(7, day: 1, correct: false, target: young), attempt(8, day: 1, correct: false, target: young),
            attempt(9, day: 1, correct: false),
        ]
        let items = ProgressStatistics.weakItems(from: attempts)
        XCTAssertEqual(items.map(\.target), [weak])
        XCTAssertEqual(items.first?.accuracy ?? 0, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testMinutesTodayCountSessionsStartedTodayAndOpenOnesUpToLastAnswer() {
        let now = date(3, hour: 18)
        let openStart = date(3, hour: 11)
        let sessions = [
            StudySession(id: StudySessionID("1"), mode: .quiz, startedAt: date(3, hour: 9), endedAt: date(3, hour: 9).addingTimeInterval(600), questionIDs: [], deviceName: "t"),
            StudySession(id: StudySessionID("open"), mode: .quiz, startedAt: openStart, endedAt: nil, questionIDs: [], deviceName: "t"),
            StudySession(id: StudySessionID("abandoned"), mode: .quiz, startedAt: date(3, hour: 7), endedAt: nil, questionIDs: [], deviceName: "t"),
            StudySession(id: StudySessionID("3"), mode: .quiz, startedAt: date(2, hour: 9), endedAt: date(2, hour: 10), questionIDs: [], deviceName: "t"),
        ]
        let answers = [
            Attempt(id: AttemptID("x1"), sessionID: StudySessionID("open"), questionID: QuestionID("q"), selectedOptionID: OptionID("o"), isCorrect: true, answeredAt: openStart.addingTimeInterval(120), responseTime: 1),
            Attempt(id: AttemptID("x2"), sessionID: StudySessionID("open"), questionID: QuestionID("q2"), selectedOptionID: OptionID("o"), isCorrect: true, answeredAt: openStart.addingTimeInterval(300), responseTime: 1),
        ]
        let summary = ProgressStatistics.summary(attempts: answers, sessions: sessions, now: now, calendar: calendar)
        XCTAssertEqual(summary.minutesToday, 15, "10 finished + 5 up to the last answer; the abandoned sheet with no answers adds nothing")
        XCTAssertTrue(summary.hasActivity)
    }
}
