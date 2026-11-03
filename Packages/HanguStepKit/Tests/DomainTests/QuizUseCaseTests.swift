import Domain
@testable import Persistence
import XCTest

/// Integration-style tests of the quiz lifecycle over the in-memory repositories.
final class QuizUseCaseTests: XCTestCase {
    private struct SequentialIDs: IDGenerator {
        let counter = Counter()
        func next() -> String { "id-\(counter.increment())" }
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func increment() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
        }
    }

    private var questions: InMemoryQuestionRepository!
    private var sessions: InMemoryStudySessionRepository!
    private var attempts: InMemoryAttemptRepository!
    private let clock = FixedDateProvider(Date(timeIntervalSince1970: 1_700_000_000))

    override func setUp() {
        questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        sessions = InMemoryStudySessionRepository()
        attempts = InMemoryAttemptRepository()
    }

    private func start(_ configuration: QuizConfiguration) async throws -> QuizSessionSnapshot {
        try await StartQuizSession(
            questions: questions, sessions: sessions, attempts: attempts,
            shuffler: IdentityShuffler(), ids: SequentialIDs(), dates: clock, deviceName: "test"
        ).execute(configuration)
    }

    private var submit: SubmitAnswer { SubmitAnswer(sessions: sessions, attempts: attempts, ids: SequentialIDs(), dates: clock) }
    private var finish: FinishQuizSession { FinishQuizSession(sessions: sessions, attempts: attempts, questions: questions, dates: clock) }
    private var resume: ResumeQuizSession { ResumeQuizSession(questions: questions, sessions: sessions, attempts: attempts, dates: clock) }

    func testStartFiltersByPoolAndPersistsSession() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .vocabulary, count: 10))
        XCTAssertEqual(snapshot.questions.count, 5, "4 meaning + 1 meaning-to-word")
        XCTAssertTrue(snapshot.isShortfall)
        XCTAssertTrue(snapshot.questions.allSatisfy { [.vocabularyMeaning, .meaningToWord].contains($0.kind) })
        let stored = try await sessions.session(id: snapshot.session.id)
        XCTAssertEqual(stored?.questionIDs, snapshot.questions.map(\.id))
        XCTAssertEqual(stored?.mode, .quiz)
    }

    func testStartRespectsCountAndLevel() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, levels: [.level1], count: 2))
        XCTAssertEqual(snapshot.questions.count, 2)
        XCTAssertFalse(snapshot.isShortfall)
        XCTAssertTrue(snapshot.questions.allSatisfy { $0.level == .level1 })
    }

    func testStartExcludesInvalidQuestionsAndThrowsOnEmptyPool() async throws {
        var broken = SampleContent.questions[0]
        broken.correctOptionID = OptionID("nope")
        questions = InMemoryQuestionRepository(questions: [broken])
        do {
            _ = try await start(QuizConfiguration(pool: .mixed, count: 5))
            XCTFail("expected emptyPool")
        } catch let error as DomainError {
            XCTAssertEqual(error, .emptyPool)
        }
    }

    func testFixedQuestionListKeepsOrderAndAll() async throws {
        let ids = [QuestionID("question.sample.0006"), QuestionID("question.sample.0001")]
        let snapshot = try await start(QuizConfiguration(pool: .questions(ids), count: 1))
        XCTAssertEqual(snapshot.questions.map(\.id), ids)
        XCTAssertFalse(snapshot.isShortfall)
    }

    func testSubmitRecordsAttemptAdvancesAndRejectsDuplicate() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 3))
        let first = snapshot.questions[0]
        let feedback = try await submit.execute(session: snapshot.session, question: first, selectedOptionID: first.correctOptionID, responseTime: 1.5)
        XCTAssertTrue(feedback.isCorrect)
        XCTAssertEqual(feedback.nextIndex, 1)
        XCTAssertFalse(feedback.isLastQuestion)
        XCTAssertEqual(feedback.attempt.target, first.learningTarget)

        do {
            _ = try await submit.execute(session: snapshot.session, question: first, selectedOptionID: first.options[1].id, responseTime: 1)
            XCTFail("expected duplicateSubmission")
        } catch let error as DomainError {
            XCTAssertEqual(error, .duplicateSubmission(questionID: first.id))
        }
        let stored = try await sessions.session(id: snapshot.session.id)
        XCTAssertEqual(stored?.currentIndex, 1)
        let summary = try await attempts.summary()
        XCTAssertEqual(summary.total, 1)
    }

    func testSubmitRejectsUnknownOption() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 1))
        do {
            _ = try await submit.execute(session: snapshot.session, question: snapshot.questions[0], selectedOptionID: OptionID("zzz"), responseTime: 1)
            XCTFail("expected notFound")
        } catch let error as DomainError {
            guard case .notFound = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testFinishScoresAndListsIncorrect() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 3))
        let q = snapshot.questions
        _ = try await submit.execute(session: snapshot.session, question: q[0], selectedOptionID: q[0].correctOptionID, responseTime: 1)
        let wrong = q[1].options.first { $0.id != q[1].correctOptionID }!.id
        _ = try await submit.execute(session: snapshot.session, question: q[1], selectedOptionID: wrong, responseTime: 3)
        _ = try await submit.execute(session: snapshot.session, question: q[2], selectedOptionID: q[2].correctOptionID, responseTime: 2)

        let result = try await finish.execute(sessionID: snapshot.session.id)
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.answered, 3)
        XCTAssertEqual(result.correct, 2)
        XCTAssertEqual(result.accuracy, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.averageResponseTime, 2, accuracy: 0.0001)
        XCTAssertEqual(result.incorrect.map(\.question.id), [q[1].id])
        XCTAssertEqual(result.incorrect[0].selectedOptionID, wrong)
        XCTAssertTrue(result.session.isFinished)

        let again = try await finish.execute(sessionID: snapshot.session.id)
        XCTAssertEqual(again.session.endedAt, result.session.endedAt, "finish is idempotent")
        let unfinished = try await resume.execute()
        XCTAssertNil(unfinished)
    }

    func testResumeRestoresPositionFromAttempts() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 4))
        let q = snapshot.questions
        _ = try await submit.execute(session: snapshot.session, question: q[0], selectedOptionID: q[0].correctOptionID, responseTime: 1)
        _ = try await submit.execute(session: snapshot.session, question: q[1], selectedOptionID: q[1].correctOptionID, responseTime: 1)

        // Simulate a stale index written before a crash.
        var stale = snapshot.session
        stale.currentIndex = 0
        try await sessions.save(stale)

        let resumed = try await resume.execute()
        XCTAssertEqual(resumed?.session.currentIndex, 2)
        XCTAssertEqual(resumed?.currentQuestion?.id, q[2].id)
        XCTAssertEqual(resumed?.attempts.count, 2)
        XCTAssertEqual(resumed?.questions.map(\.id), q.map(\.id))
    }

    func testDiscardUnfinishedClosesSession() async throws {
        _ = try await start(QuizConfiguration(pool: .mixed, count: 2))
        try await resume.discardUnfinished()
        let unfinished = try await resume.execute()
        XCTAssertNil(unfinished)
        let history = try await ListQuizHistory(sessions: sessions, attempts: attempts).execute(limit: 10)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].answered, 0)
    }

    func testResumeClosesSessionWhoseQuestionsWereRetired() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 2))
        questions = InMemoryQuestionRepository(questions: [])
        let resumed = try await ResumeQuizSession(questions: questions, sessions: sessions, attempts: attempts, dates: clock).execute()
        XCTAssertNil(resumed)
        let stored = try await sessions.session(id: snapshot.session.id)
        XCTAssertTrue(stored?.isFinished == true)
    }

    func testMistakePoolUsesOnlyMissedTargets() async throws {
        let snapshot = try await start(QuizConfiguration(pool: .mixed, count: 7))
        let q = snapshot.questions
        let wrong = q[0].options.first { $0.id != q[0].correctOptionID }!.id
        _ = try await submit.execute(session: snapshot.session, question: q[0], selectedOptionID: wrong, responseTime: 1)
        for question in q.dropFirst() {
            _ = try await submit.execute(session: snapshot.session, question: question, selectedOptionID: question.correctOptionID, responseTime: 1)
        }
        _ = try await finish.execute(sessionID: snapshot.session.id)

        let mistakes = try await start(QuizConfiguration(pool: .mistakes, count: 10))
        XCTAssertEqual(mistakes.session.mode, .mistakes)
        XCTAssertTrue(mistakes.questions.allSatisfy { $0.learningTarget == q[0].learningTarget })
        XCTAssertFalse(mistakes.questions.isEmpty)
    }
}
