import Domain
import Persistence
import XCTest

final class InMemoryRepositoryTests: XCTestCase {
    func testSearchMatchesKhmerEnglishRomanizationAndHangul() async throws {
        let repository = InMemoryVocabularyRepository(items: SampleContent.vocabulary)

        let byKhmer = try await repository.search("ទឹក", filter: .all)
        XCTAssertEqual(byKhmer.map(\.hangul), ["물"])

        let byEnglish = try await repository.search("FRIEND", filter: .all)
        XCTAssertEqual(byEnglish.map(\.hangul), ["친구"])

        let byRomanization = try await repository.search("hak", filter: .all)
        XCTAssertEqual(byRomanization.map(\.hangul), ["학교"])

        let byHangul = try await repository.search("학", filter: .all)
        XCTAssertEqual(byHangul.map(\.hangul), ["학교"])
    }

    func testFilterByLevelAndPartOfSpeech() async throws {
        let repository = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let level2 = try await repository.items(matching: VocabularyFilter(levels: [.level2]))
        XCTAssertTrue(level2.isEmpty)
        let nouns = try await repository.items(matching: VocabularyFilter(partsOfSpeech: [.noun]))
        XCTAssertEqual(nouns.count, 3)
    }

    func testDuplicateAttemptInSameSessionIsRejected() async throws {
        let repository = InMemoryAttemptRepository()
        let attempt = Attempt(
            id: AttemptID("a1"), sessionID: StudySessionID("s1"), questionID: QuestionID("q1"),
            selectedOptionID: OptionID("a"), isCorrect: true, answeredAt: Date(), responseTime: 1
        )
        try await repository.record(attempt)

        let duplicate = Attempt(
            id: AttemptID("a2"), sessionID: StudySessionID("s1"), questionID: QuestionID("q1"),
            selectedOptionID: OptionID("b"), isCorrect: false, answeredAt: Date(), responseTime: 1
        )
        do {
            try await repository.record(duplicate)
            XCTFail("expected duplicateSubmission")
        } catch let error as DomainError {
            XCTAssertEqual(error, .duplicateSubmission(questionID: QuestionID("q1")))
        }

        let summary = try await repository.summary()
        XCTAssertEqual(summary.total, 1)
        XCTAssertEqual(summary.correct, 1)
    }

    func testSameQuestionInDifferentSessionsIsAllowed() async throws {
        let repository = InMemoryAttemptRepository()
        for session in ["s1", "s2"] {
            try await repository.record(Attempt(
                id: AttemptID(session), sessionID: StudySessionID(session), questionID: QuestionID("q1"),
                selectedOptionID: OptionID("a"), isCorrect: true, answeredAt: Date(), responseTime: 1
            ))
        }
        let forQuestion = try await repository.attempts(forQuestion: QuestionID("q1"))
        XCTAssertEqual(forQuestion.count, 2)
    }

    func testDueSchedulesRespectDateAndLimit() async throws {
        let repository = InMemoryReviewScheduleRepository()
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        for (index, offset) in [-2.0, -1.0, 0.0, 1.0].enumerated() {
            try await repository.upsert(ReviewSchedule(
                id: ReviewScheduleID("r\(index)"),
                target: .vocabulary(VocabularyID("v\(index)")),
                nextReviewDate: today.addingTimeInterval(offset * 86_400)
            ))
        }
        let due = try await repository.due(onOrBefore: today, limit: 2)
        XCTAssertEqual(due.map(\.id.rawValue), ["r0", "r1"])
    }

    func testSampleContentIsValid() {
        for question in SampleContent.questions {
            XCTAssertTrue(question.isValid, "\(question.id): \(question.validate())")
        }
        XCTAssertEqual(Set(SampleContent.vocabulary.map(\.id)).count, SampleContent.vocabulary.count)
    }
}
