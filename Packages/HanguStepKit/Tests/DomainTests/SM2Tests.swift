import Domain
import XCTest

/// Reference values follow the published SM-2 formulation (PRD AC-5, ADR-006):
/// I(1) = 1, I(2) = 6, I(n) = round(I(n-1) × EF); EF' = EF + 0.1 − (5−q)(0.08 + (5−q)0.02), floor 1.3.
final class SM2Tests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func run(_ qualities: [ReviewQuality]) -> [SM2.Outcome] {
        var outcomes: [SM2.Outcome] = []
        var ease = SM2.initialEaseFactor, interval = 0, reps = 0
        for quality in qualities {
            let outcome = SM2.next(easeFactor: ease, intervalDays: interval, repetitions: reps, quality: quality)
            outcomes.append(outcome)
            (ease, interval, reps) = (outcome.easeFactor, outcome.intervalDays, outcome.repetitions)
        }
        return outcomes
    }

    func testPerfectAnswersFollowReferenceTable() {
        let outcomes = run([.perfect, .perfect, .perfect])
        XCTAssertEqual(outcomes.map(\.intervalDays), [1, 6, 16])
        XCTAssertEqual(outcomes.map(\.repetitions), [1, 2, 3])
        XCTAssertEqual(outcomes.map(\.easeFactor), [2.6, 2.7, 2.8], accuracy: 0.0001)
    }

    func testHesitantAnswersKeepEaseFactor() {
        let outcomes = run([.correctHesitant, .correctHesitant, .correctHesitant])
        XCTAssertEqual(outcomes.map(\.intervalDays), [1, 6, 15])
        XCTAssertEqual(outcomes.map(\.easeFactor), [2.5, 2.5, 2.5], accuracy: 0.0001)
    }

    func testHardAnswersLowerEaseFactor() {
        let outcomes = run([.correctHard, .correctHard, .correctHard])
        XCTAssertEqual(outcomes.map(\.intervalDays), [1, 6, 13])
        XCTAssertEqual(outcomes.map(\.easeFactor), [2.36, 2.22, 2.08], accuracy: 0.0001)
    }

    func testFailureResetsRepetitionsAndFloorsEase() {
        let outcomes = run([.perfect, .perfect, .incorrectRemembered, .blackout, .blackout])
        XCTAssertEqual(outcomes[2].repetitions, 0)
        XCTAssertEqual(outcomes[2].intervalDays, 1)
        XCTAssertEqual(outcomes[2].easeFactor, 2.7 - 0.54, accuracy: 0.0001)
        XCTAssertEqual(outcomes[4].easeFactor, SM2.minimumEaseFactor, accuracy: 0.0001)
        // Recovery starts the table again.
        let recovered = SM2.next(easeFactor: outcomes[4].easeFactor, intervalDays: outcomes[4].intervalDays, repetitions: 0, quality: .perfect)
        XCTAssertEqual(recovered.intervalDays, 1)
        XCTAssertEqual(recovered.repetitions, 1)
    }

    func testReviewSchedulesNextDateAtStartOfDay() {
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12, minute: 30))!
        let target = LearningTarget.vocabulary(VocabularyID("v1"))
        let first = SM2.review(nil, target: target, id: ReviewScheduleID("s1"), quality: .perfect, on: noon, calendar: calendar)
        XCTAssertEqual(first.id.rawValue, "s1")
        XCTAssertEqual(first.nextReviewDate, calendar.date(from: DateComponents(year: 2026, month: 11, day: 4))!)
        XCTAssertEqual(first.lastReviewedAt, noon)
        XCTAssertFalse(first.isMastered)

        let nextDay = calendar.date(byAdding: .day, value: 1, to: noon)!
        let second = SM2.review(first, target: target, id: ReviewScheduleID("ignored"), quality: .perfect, on: nextDay, calendar: calendar)
        XCTAssertEqual(second.id.rawValue, "s1", "upsert keeps the original row id")
        XCTAssertEqual(second.intervalDays, 6)
        XCTAssertEqual(second.nextReviewDate, calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!)
        XCTAssertEqual(second.overdueDays(on: calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 8))!, calendar: calendar), 3)
        XCTAssertEqual(second.overdueDays(on: nextDay, calendar: calendar), 0)
    }

    func testSecondPassingAnswerSameDayKeepsSchedule() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 9))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 21))!
        let target = LearningTarget.vocabulary(VocabularyID("v1"))
        let first = SM2.review(nil, target: target, id: ReviewScheduleID("s1"), quality: .perfect, on: morning, calendar: calendar)
        let again = SM2.review(first, target: target, id: ReviewScheduleID("x"), quality: .correctHesitant, on: evening, calendar: calendar)
        XCTAssertEqual(again.repetitions, 1)
        XCTAssertEqual(again.intervalDays, 1)
        XCTAssertEqual(again.easeFactor, first.easeFactor)
        XCTAssertEqual(again.nextReviewDate, first.nextReviewDate)
        XCTAssertEqual(again.lastReviewedAt, evening)
        let failed = SM2.review(again, target: target, id: ReviewScheduleID("x"), quality: .incorrectRemembered, on: evening, calendar: calendar)
        XCTAssertEqual(failed.repetitions, 0, "a failure always resets, even on the same day")
    }

    func testSameInputsGiveSameOutput() {
        let a = SM2.next(easeFactor: 2.2, intervalDays: 14, repetitions: 4, quality: .correctHesitant)
        let b = SM2.next(easeFactor: 2.2, intervalDays: 14, repetitions: 4, quality: .correctHesitant)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.intervalDays, 31)
        XCTAssertTrue(ReviewSchedule(id: ReviewScheduleID("m"), target: .grammar(GrammarID("g")), intervalDays: 21, nextReviewDate: .now).isMastered)
    }

    func testQualityMappingFromMultipleChoice() {
        XCTAssertEqual(ReviewQuality.forAnswer(isCorrect: false, responseTime: 1), .incorrectRemembered)
        XCTAssertEqual(ReviewQuality.forAnswer(isCorrect: true, responseTime: 2), .perfect)
        XCTAssertEqual(ReviewQuality.forAnswer(isCorrect: true, responseTime: 9), .correctHesitant)
        XCTAssertFalse(ReviewQuality.incorrectEasy.isPassing)
        XCTAssertTrue(ReviewQuality.correctHard.isPassing)
    }
}

private func XCTAssertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
    for (a, b) in zip(lhs, rhs) { XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line) }
}
