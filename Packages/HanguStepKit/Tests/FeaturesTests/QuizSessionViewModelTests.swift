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
        (dependencies, attempts, sessions) = Self.makeDependencies(questions: SampleContent.questions, pronouncer: SilentPronouncer())
    }

    private nonisolated static func makeDependencies(questions allQuestions: [Question], pronouncer: any Pronouncer) -> (AppDependencies, InMemoryAttemptRepository, InMemoryStudySessionRepository) {
        let questions = InMemoryQuestionRepository(questions: allQuestions)
        let attempts = InMemoryAttemptRepository()
        let sessions = InMemoryStudySessionRepository()
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
        let settings = InMemoryLearnerSettingsRepository()
        let schedules = InMemoryReviewScheduleRepository()
        let dependencies = AppDependencies(
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
            pronouncer: pronouncer
        )
        return (dependencies, attempts, sessions)
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

    // MARK: Listening (TOPIK II 듣기)

    private static func listeningQuestion(_ number: Int) -> Question {
        Question(
            id: QuestionID("q.ls.test.\(number)"), kind: .listening, level: .level3,
            prompt: "다음을 듣고 이어질 수 있는 말을 고르십시오.",
            passage: "남자: 표 두 장 주세요.\n여자: 몇 시 영화로 드릴까요?",
            options: [QuestionOption(id: OptionID("a"), text: "7시요."), QuestionOption(id: OptionID("b"), text: "두 명이요.")],
            correctOptionID: OptionID("a"), explanation: Gloss(english: "Asked for a time.", khmer: "សួរម៉ោង។"),
            source: SampleContent.source, contentVersion: 1
        )
    }

    func testListeningPlaysOnShowRevealsScriptAfterAnswerAndStopsOnNext() async throws {
        let spy = SpyPronouncer()
        (dependencies, attempts, sessions) = Self.makeDependencies(questions: SampleContent.questions + [Self.listeningQuestion(1), Self.listeningQuestion(2)], pronouncer: spy)
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .listening, count: 2)), dependencies: dependencies)
        await viewModel.load()

        XCTAssertTrue(viewModel.isListening)
        XCTAssertNil(viewModel.revealedScript, "script stays hidden while answering")
        try await spy.waitForEvents(1)
        let firstEvents = await spy.events
        XCTAssertEqual(firstEvents, ["script 2"], "audio starts when the question appears")

        let question = try XCTUnwrap(viewModel.currentQuestion)
        viewModel.select(question.correctOptionID)
        await viewModel.check()
        XCTAssertEqual(viewModel.revealedScript?.lines.map(\.speaker), [.man, .woman])

        viewModel.playListening()
        await viewModel.next()
        try await spy.waitForEvents(4)
        let events = await spy.events
        XCTAssertEqual(Array(events.prefix(2)), ["script 2", "script 2"], "replay speaks the script again")
        XCTAssertTrue(events.contains("stop"), "moving on stops the audio")
        XCTAssertEqual(events.last, "script 2", "the next listening question plays")
    }

    func testMixedPoolNeverIncludesListening() async throws {
        (dependencies, attempts, sessions) = Self.makeDependencies(questions: [Self.listeningQuestion(1)] + SampleContent.questions, pronouncer: SilentPronouncer())
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 40)), dependencies: dependencies)
        await viewModel.load()
        let questions = try XCTUnwrap(viewModel.snapshot?.questions)
        XCTAssertFalse(questions.contains { $0.kind == .listening })
        XCTAssertFalse(viewModel.isListening)
    }
}

/// Records what the quiz asked the speech service to do.
actor SpyPronouncer: Pronouncer {
    private(set) var events: [String] = []

    func speak(_ text: String) { events.append("text") }
    func speak(_ script: ListeningScript) { events.append("script \(script.lines.count)") }
    func stop() { events.append("stop") }

    func waitForEvents(_ count: Int) async throws {
        for _ in 0..<100 where events.count < count { try await Task.sleep(for: .milliseconds(10)) }
    }
}
