import Domain
@testable import Persistence
import XCTest

final class LoadDashboardSummaryTests: XCTestCase {
    private struct FailingAttempts: AttemptRepository {
        func record(_ attempt: Attempt) async throws {}
        func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt] { [] }
        func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt] { [] }
        func summary() async throws -> AttemptSummary { throw DomainError.storage(description: "disk") }
        func allAttempts() async throws -> [Attempt] { throw DomainError.storage(description: "disk") }
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var vocabulary: InMemoryVocabularyRepository!
    private var grammar: InMemoryGrammarRepository!
    private var attempts: InMemoryAttemptRepository!
    private var sessions: InMemoryStudySessionRepository!
    private var schedules: InMemoryReviewScheduleRepository!
    private var settings: InMemoryLearnerSettingsRepository!

    override func setUp() {
        vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        attempts = InMemoryAttemptRepository()
        sessions = InMemoryStudySessionRepository()
        schedules = InMemoryReviewScheduleRepository()
        settings = InMemoryLearnerSettingsRepository()
    }

    private func useCase(attempts: any AttemptRepository) -> LoadDashboardSummary {
        LoadDashboardSummary(vocabulary: vocabulary, grammar: grammar, attempts: attempts, sessions: sessions, schedules: schedules, settings: settings, dates: FixedDateProvider(now), calendar: .current)
    }

    /// AC-4: dashboard totals equal a direct count of attempt records.
    func testTotalsEqualAttemptRecordsAndCountsComeFromSchedules() async throws {
        for index in 0..<7 {
            try await attempts.record(Attempt(id: AttemptID("a\(index)"), sessionID: StudySessionID("s"), questionID: QuestionID("q\(index)"), selectedOptionID: OptionID("o"), isCorrect: index % 2 == 0, answeredAt: now.addingTimeInterval(Double(-index) * 60), responseTime: 1))
        }
        try await schedules.upsert(ReviewSchedule(id: ReviewScheduleID("due"), target: .vocabulary(VocabularyID("a")), nextReviewDate: now.addingTimeInterval(-60)))
        try await schedules.upsert(ReviewSchedule(id: ReviewScheduleID("later"), target: .vocabulary(VocabularyID("b")), nextReviewDate: now.addingTimeInterval(86_400)))
        try await schedules.upsert(ReviewSchedule(id: ReviewScheduleID("mastered"), target: .grammar(GrammarID("c")), intervalDays: 30, nextReviewDate: now.addingTimeInterval(20 * 86_400)))
        try await settings.save(LearnerSettings(dailyGoal: 10))

        let summary = try await useCase(attempts: attempts).execute()
        XCTAssertEqual(summary.vocabularyCount, SampleContent.vocabulary.count)
        XCTAssertEqual(summary.grammarCount, SampleContent.grammar.count)
        XCTAssertEqual(summary.attempts.total, 7)
        XCTAssertEqual(summary.attempts.correct, 4)
        XCTAssertEqual(summary.progress.answeredToday, 7)
        XCTAssertEqual(summary.progress.currentStreak, 1)
        XCTAssertEqual(summary.dueCount, 1)
        XCTAssertEqual(summary.masteredCount, 1)
        XCTAssertEqual(summary.dailyGoal, 10)
        XCTAssertEqual(summary.goalProgress, 0.7, accuracy: 0.0001)
        XCTAssertFalse(summary.isGoalReached)
    }

    func testEmptyStoreGivesZeroes() async throws {
        let summary = try await useCase(attempts: attempts).execute()
        XCTAssertEqual(summary.attempts.accuracy, 0)
        XCTAssertEqual(summary.progress, .empty.withWindows(now: now))
        XCTAssertEqual(summary.dueCount, 0)
        XCTAssertEqual(summary.goalProgress, 0)
    }

    func testRepositoryErrorPropagates() async {
        do {
            _ = try await useCase(attempts: FailingAttempts()).execute()
            XCTFail("expected error")
        } catch let error as DomainError {
            XCTAssertEqual(error, .storage(description: "disk"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}

private extension ProgressSummary {
    /// `.empty` has no day windows; a computed summary always has 7 and 30.
    func withWindows(now: Date) -> ProgressSummary {
        ProgressStatistics.summary(attempts: [], sessions: [], now: now, calendar: .current)
    }
}
