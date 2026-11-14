import DesignSystem
import Domain
@testable import Features
import Persistence
import XCTest

/// Drives the quiz view model over real use cases and in-memory repositories.
@MainActor
final class QuizSessionViewModelTests: XCTestCase {
    private var dependencies: AppDependencies!
    private var attempts: InMemoryAttemptRepository!
    private var sessions: InMemoryStudySessionRepository!

    override func setUp() {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        attempts = InMemoryAttemptRepository()
        sessions = InMemoryStudySessionRepository()
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
        let settings = InMemoryLearnerSettingsRepository()
        let schedules = InMemoryReviewScheduleRepository()
        dependencies = AppDependencies(
            loadDashboardSummary: LoadDashboardSummary(vocabulary: vocabulary, grammar: grammar, attempts: attempts, sessions: sessions, schedules: schedules, settings: settings),
            loadProgressReport: LoadProgressReport(attempts: attempts, sessions: sessions, schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar),
            listReviewQueue: ListReviewQueue(schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar),
            browseVocabulary: BrowseVocabulary(vocabulary: vocabulary),
            getVocabularyDetail: GetVocabularyDetail(vocabulary: vocabulary, bookmarks: bookmarks, notes: notes),
            browseGrammar: BrowseGrammar(grammar: grammar),
            getGrammarDetail: GetGrammarDetail(grammar: grammar, questions: questions, bookmarks: bookmarks, notes: notes),
            toggleBookmark: ToggleBookmark(bookmarks: bookmarks),
            listBookmarks: ListBookmarks(bookmarks: bookmarks, vocabulary: vocabulary, grammar: grammar),
            saveNote: SaveNote(notes: notes),
            startQuiz: StartQuizSession(questions: questions, sessions: sessions, attempts: attempts, schedules: schedules, settings: settings, shuffler: IdentityShuffler(), deviceName: "test"),
            resumeQuiz: ResumeQuizSession(questions: questions, sessions: sessions, attempts: attempts),
            submitAnswer: SubmitAnswer(sessions: sessions, attempts: attempts, schedules: schedules),
            finishQuiz: FinishQuizSession(sessions: sessions, attempts: attempts, questions: questions),
            listMistakes: ListMistakes(attempts: attempts, vocabulary: vocabulary, grammar: grammar),
            listHistory: ListQuizHistory(sessions: sessions, attempts: attempts),
            loadSettings: LoadSettings(repository: settings),
            saveSettings: SaveSettings(repository: settings),
            pronouncer: SilentPronouncer()
        )
    }

    func testFullRunThroughTwoQuestions() async throws {
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 2)), dependencies: dependencies)
        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .answering(index: 0))
        XCTAssertEqual(viewModel.progressText, "1 of 2")
        let first = try XCTUnwrap(viewModel.currentQuestion)

        await viewModel.check()
        XCTAssertEqual(viewModel.phase, .answering(index: 0), "check without a selection does nothing")

        viewModel.select(first.correctOptionID)
        await viewModel.check()
        guard case let .feedback(0, feedback) = viewModel.phase else { return XCTFail("expected feedback, got \(viewModel.phase)") }
        XCTAssertTrue(feedback.isCorrect)
        XCTAssertEqual(viewModel.optionState(for: first.options.first { $0.id == first.correctOptionID }!), .correct)

        viewModel.select(first.options[1].id)
        XCTAssertEqual(viewModel.selectedOptionID, first.correctOptionID, "selection is locked after check")

        await viewModel.next()
        XCTAssertEqual(viewModel.phase, .answering(index: 1))
        let second = try XCTUnwrap(viewModel.currentQuestion)
        let wrong = second.options.first { $0.id != second.correctOptionID }!.id
        viewModel.select(wrong)
        await viewModel.check()
        guard case let .feedback(1, last) = viewModel.phase else { return XCTFail("expected feedback") }
        XCTAssertFalse(last.isCorrect)
        XCTAssertTrue(last.isLastQuestion)

        await viewModel.next()
        guard case let .finished(result) = viewModel.phase else { return XCTFail("expected finished") }
        XCTAssertEqual(result.answered, 2)
        XCTAssertEqual(result.correct, 1)
        XCTAssertEqual(result.incorrect.map(\.question.id), [second.id])

        let summary = try await attempts.summary()
        XCTAssertEqual(summary.total, 2)
        let history = try await ListQuizHistory(sessions: sessions, attempts: attempts).execute(limit: 5)
        XCTAssertEqual(history.count, 1)
    }

    func testCloseEarlyKeepsAnsweredQuestions() async throws {
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 3)), dependencies: dependencies)
        await viewModel.load()
        let first = try XCTUnwrap(viewModel.currentQuestion)
        viewModel.select(first.correctOptionID)
        await viewModel.check()
        XCTAssertTrue(viewModel.hasUnansweredQuestions)
        await viewModel.close()
        guard case let .finished(result) = viewModel.phase else { return XCTFail("expected finished") }
        XCTAssertEqual(result.answered, 1)
        XCTAssertEqual(result.total, 3)
        let unfinished = try await dependencies.resumeQuiz.execute()
        XCTAssertNil(unfinished)
    }

    func testResumeLaunchStartsAtFirstUnanswered() async throws {
        let fresh = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 3)), dependencies: dependencies)
        await fresh.load()
        let first = try XCTUnwrap(fresh.currentQuestion)
        fresh.select(first.correctOptionID)
        await fresh.check()
        // App killed here. New view model resumes from storage.
        let maybeSnapshot = try await dependencies.resumeQuiz.execute()
        let snapshot = try XCTUnwrap(maybeSnapshot)
        let resumed = QuizSessionViewModel(launch: QuizLaunch(resume: snapshot), dependencies: dependencies)
        await resumed.load()
        XCTAssertEqual(resumed.phase, .answering(index: 1))
        XCTAssertEqual(resumed.progressText, "2 of 3")
    }

    func testEmptyPoolShowsFailure() async {
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mistakes, count: 5)), dependencies: dependencies)
        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .failed(message: DomainError.emptyPool.localizedDescription))
    }

    func testVocabularyListFiltersAndEmptyState() async throws {
        let viewModel = VocabularyListViewModel(browse: dependencies.browseVocabulary)
        await viewModel.load()
        XCTAssertEqual(viewModel.state.value?.count, SampleContent.vocabulary.count)
        viewModel.query = "zzzz"
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(viewModel.state, .empty)
        viewModel.query = ""
        viewModel.toggle(level: .level3)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(viewModel.state.value?.count, 2)
    }
}
