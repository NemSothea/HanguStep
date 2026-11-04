import Domain
@testable import Features
import Persistence
import XCTest

@MainActor
final class AssistantModelTests: XCTestCase {
    func testSourceReflectsSettingsAndKeyOnEveryCall() async throws {
        let store = InMemoryAssistantSettingsStore()
        let secrets = InMemorySecretStore()
        let source = ConfiguredAssistantProviderSource(settings: store, secrets: secrets) { kind, key in
            switch kind {
            case .mock: return MockAssistantProvider()
            case .claude: return NamedProvider(name: "claude:\(key ?? "")")
            }
        }
        let model = AssistantModel(store: store, secrets: secrets)
        XCTAssertFalse(model.isEnabled)
        XCTAssertFalse(model.isReady)
        await expectAssistantError(.disabled, from: source)

        model.setEnabled(true)
        XCTAssertTrue(model.isReady, "mock needs no key")
        let mock = try await source.currentProvider()
        XCTAssertEqual(mock.name, "Built-in assistant")

        model.setProvider(.claude)
        XCTAssertFalse(model.isReady)
        await expectAssistantError(.notConfigured(.claude), from: source)

        model.saveClaudeKey("  sk-abc  ")
        XCTAssertTrue(model.hasClaudeKey)
        XCTAssertTrue(model.isReady)
        let claude = try await source.currentProvider()
        XCTAssertEqual(claude.name, "claude:sk-abc", "key is trimmed and passed to the factory, never stored in settings")
        XCTAssertNil(try secrets.secret(for: "assistant.settings"))

        model.removeClaudeKey()
        XCTAssertFalse(model.hasClaudeKey)
        await expectAssistantError(.notConfigured(.claude), from: source)

        // A second model over the same stores sees the persisted choice.
        let reloaded = AssistantModel(store: store, secrets: secrets)
        XCTAssertEqual(reloaded.settings, AssistantSettings(isEnabled: true, provider: .claude))
    }

    func testUserDefaultsStoreRoundTrips() {
        let suite = "AssistantModelTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAssistantSettingsStore(suiteName: suite)
        XCTAssertEqual(store.load(), AssistantSettings())
        store.save(AssistantSettings(isEnabled: true, provider: .claude))
        XCTAssertEqual(UserDefaultsAssistantSettingsStore(suiteName: suite).load(), AssistantSettings(isEnabled: true, provider: .claude))
    }

    func testQuizViewModelExplainsOnlyInFeedbackAndResetsPerQuestion() async throws {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        let attempts = InMemoryAttemptRepository()
        let sessions = InMemoryStudySessionRepository()
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let settings = InMemoryLearnerSettingsRepository()
        let schedules = InMemoryReviewScheduleRepository()
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
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
            pronouncer: SilentPronouncer(),
            explainAnswer: ExplainAnswer(providers: FixedAssistantProviderSource(MockAssistantProvider()), vocabulary: vocabulary, grammar: grammar)
        )
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 2)), dependencies: dependencies)
        await viewModel.load()
        await viewModel.explainCurrentAnswer(language: .english)
        XCTAssertEqual(viewModel.assistantExplanation, .idle, "nothing to explain before an answer")

        let first = try XCTUnwrap(viewModel.currentQuestion)
        let wrong = try XCTUnwrap(first.options.first { $0.id != first.correctOptionID })
        viewModel.select(wrong.id)
        await viewModel.check()
        await viewModel.explainCurrentAnswer(language: .english)
        guard case let .loaded(explanation) = viewModel.assistantExplanation else { return XCTFail("\(viewModel.assistantExplanation)") }
        XCTAssertTrue(explanation.text.contains(wrong.text))

        await viewModel.next()
        XCTAssertEqual(viewModel.assistantExplanation, .idle, "reset for the next question")
    }

    func testQuizViewModelSurfacesAssistantErrors() async throws {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        let attempts = InMemoryAttemptRepository()
        let sessions = InMemoryStudySessionRepository()
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let settings = InMemoryLearnerSettingsRepository()
        let schedules = InMemoryReviewScheduleRepository()
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
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
            pronouncer: SilentPronouncer()
        )
        let viewModel = QuizSessionViewModel(launch: QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 1)), dependencies: dependencies)
        await viewModel.load()
        let first = try XCTUnwrap(viewModel.currentQuestion)
        viewModel.select(first.correctOptionID)
        await viewModel.check()
        await viewModel.explainCurrentAnswer(language: .english)
        XCTAssertEqual(viewModel.assistantExplanation, .failed(message: AssistantError.disabled.localizedDescription))
    }

    func testVocabularyDetailGeneratesPracticeAndReportsErrors() async throws {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let generate = GeneratePracticeQuestions(providers: FixedAssistantProviderSource(MockAssistantProvider()), vocabulary: vocabulary, grammar: grammar, store: questions, shuffler: IdentityShuffler())
        let dependencies = AppDependencies(
            loadDashboardSummary: UnusedDashboard(), loadProgressReport: UnusedProgress(), listReviewQueue: UnusedQueue(),
            browseVocabulary: BrowseVocabulary(vocabulary: vocabulary),
            getVocabularyDetail: GetVocabularyDetail(vocabulary: vocabulary, bookmarks: InMemoryBookmarkRepository(), notes: InMemoryLearnerNoteRepository()),
            browseGrammar: BrowseGrammar(grammar: grammar),
            getGrammarDetail: GetGrammarDetail(grammar: grammar, questions: questions, bookmarks: InMemoryBookmarkRepository(), notes: InMemoryLearnerNoteRepository()),
            toggleBookmark: ToggleBookmark(bookmarks: InMemoryBookmarkRepository()),
            listBookmarks: ListBookmarks(bookmarks: InMemoryBookmarkRepository(), vocabulary: vocabulary, grammar: grammar),
            saveNote: SaveNote(notes: InMemoryLearnerNoteRepository()),
            startQuiz: UnusedStart(), resumeQuiz: UnusedResume(), submitAnswer: UnusedSubmit(), finishQuiz: UnusedFinish(),
            listMistakes: ListMistakes(attempts: InMemoryAttemptRepository(), vocabulary: vocabulary, grammar: grammar),
            listHistory: UnusedHistory(),
            loadSettings: LoadSettings(repository: InMemoryLearnerSettingsRepository()),
            saveSettings: SaveSettings(repository: InMemoryLearnerSettingsRepository()),
            pronouncer: SilentPronouncer(),
            generatePractice: generate
        )
        let viewModel = VocabularyDetailViewModel(id: VocabularyID("vocab.sample.0001"), dependencies: dependencies)
        await viewModel.load()
        let ids = await viewModel.generatePracticeQuestions(count: 2)
        XCTAssertEqual(ids.count, 2)
        XCTAssertNil(viewModel.practiceError)
        XCTAssertFalse(viewModel.isGeneratingPractice)

        let again = await viewModel.generatePracticeQuestions(count: 5)
        XCTAssertEqual(again.count, 1, "one unused mock draft remained")
        let third = await viewModel.generatePracticeQuestions(count: 5)
        XCTAssertTrue(third.isEmpty)
        XCTAssertEqual(viewModel.practiceError, AssistantError.nothingUsable.localizedDescription)
    }
}

// MARK: - Helpers

private struct NamedProvider: AssistantProvider {
    let name: String
    func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation { AssistantExplanation(text: name, language: request.language, providerName: name) }
    func generate(_ request: PracticeRequest) async throws -> [DraftQuestion] { [] }
}

private func expectAssistantError(_ expected: AssistantError, from source: any AssistantProviderSource, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await source.currentProvider()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch let error as AssistantError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("unexpected \(error)", file: file, line: line)
    }
}

private struct UnusedDashboard: LoadDashboardSummaryUseCase { func execute() async throws -> DashboardSummary { fatalError("unused") } }
private struct UnusedProgress: LoadProgressReportUseCase { func execute() async throws -> ProgressReport { fatalError("unused") } }
private struct UnusedQueue: ListReviewQueueUseCase { func execute() async throws -> ReviewQueue { fatalError("unused") } }
private struct UnusedStart: StartQuizSessionUseCase { func execute(_ configuration: QuizConfiguration) async throws -> QuizSessionSnapshot { fatalError("unused") } }
private struct UnusedResume: ResumeQuizSessionUseCase { func execute() async throws -> QuizSessionSnapshot? { fatalError("unused") }; func discardUnfinished() async throws { fatalError("unused") } }
private struct UnusedSubmit: SubmitAnswerUseCase { func execute(session: StudySession, question: Question, selectedOptionID: OptionID, responseTime: TimeInterval) async throws -> AnswerFeedback { fatalError("unused") } }
private struct UnusedFinish: FinishQuizSessionUseCase { func execute(sessionID: StudySessionID) async throws -> QuizResult { fatalError("unused") } }
private struct UnusedHistory: ListQuizHistoryUseCase { func execute(limit: Int) async throws -> [SessionSummary] { fatalError("unused") } }
