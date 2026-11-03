import DesignSystem
import Domain
@testable import Features
import Persistence
import XCTest

@MainActor
final class ProgressViewModelTests: XCTestCase {
    private struct StubLoad: LoadProgressReportUseCase {
        let result: Result<ProgressReport, DomainError>
        func execute() async throws -> ProgressReport { try result.get() }
    }

    private func report(total: Int) -> ProgressReport {
        let summary = ProgressSummary(totals: AttemptSummary(total: total, correct: total), answeredToday: total, correctToday: total, minutesToday: 1, currentStreak: 1, longestStreak: 1, last7Days: [], last30Days: [], weakItems: [])
        return ProgressReport(summary: summary, dueCount: 0, masteredCount: 0, scheduledCount: 0, dailyGoal: 20, weakWords: [], weakGrammar: [])
    }

    func testNoActivityShowsEmptyState() async {
        let viewModel = ProgressViewModel(load: StubLoad(result: .success(report(total: 0))))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state, .empty)
    }

    func testActivityLoadsReport() async {
        let viewModel = ProgressViewModel(load: StubLoad(result: .success(report(total: 4))))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state.value?.summary.totals.total, 4)
    }

    func testFailurePropagatesMessage() async {
        let viewModel = ProgressViewModel(load: StubLoad(result: .failure(.storage(description: "disk"))))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state, .failed(message: "Storage error: disk"))
    }

    /// End to end over in-memory stores: answering a quiz feeds the report and the review queue.
    func testReportAndQueueReflectAnsweredQuiz() async throws {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        let attempts = InMemoryAttemptRepository()
        let sessions = InMemoryStudySessionRepository()
        let schedules = InMemoryReviewScheduleRepository()
        let settings = InMemoryLearnerSettingsRepository()
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let yesterday = Date().addingTimeInterval(-86_400)

        let snapshot = try await StartQuizSession(questions: questions, sessions: sessions, attempts: attempts, schedules: schedules, settings: settings, shuffler: IdentityShuffler(), dates: FixedDateProvider(yesterday), deviceName: "t").execute(QuizConfiguration(pool: .vocabulary, count: 2))
        let submit = SubmitAnswer(sessions: sessions, attempts: attempts, schedules: schedules, dates: FixedDateProvider(yesterday))
        for question in snapshot.questions {
            _ = try await submit.execute(session: snapshot.session, question: question, selectedOptionID: question.correctOptionID, responseTime: 1)
        }

        let report = try await LoadProgressReport(attempts: attempts, sessions: sessions, schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar).execute()
        XCTAssertEqual(report.summary.totals.total, 2)
        XCTAssertEqual(report.summary.currentStreak, 1, "yesterday's activity keeps the streak alive today")
        XCTAssertEqual(report.scheduledCount, 2)
        XCTAssertEqual(report.dueCount, 2, "interval 1 from yesterday is due today")

        let queue = try await ListReviewQueue(schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar).execute()
        XCTAssertEqual(queue.entries.count, 2)
        XCTAssertEqual(queue.remaining, 0)
        XCTAssertEqual(queue.entries.map(\.overdueDays), [0, 0])
        XCTAssertFalse(queue.entries.map(\.title).contains(""))
    }
}
