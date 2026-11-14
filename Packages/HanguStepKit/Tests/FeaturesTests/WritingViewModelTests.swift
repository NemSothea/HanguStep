import DesignSystem
import Domain
@testable import Features
import Persistence
import XCTest

@MainActor
final class WritingViewModelTests: XCTestCase {
    private let task = WritingTask(
        id: WritingTaskID("w.53.test"), type: .describeData, level: .level4, prompt: "p", material: "m",
        lengthRange: 10...20, modelAnswer: "모범", tips: Gloss(english: "t", khmer: "ត")
    )

    private func dependencies(attempts: InMemoryWritingAttemptRepository) -> AppDependencies {
        let questions = InMemoryQuestionRepository(questions: SampleContent.questions)
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let learnerAttempts = InMemoryAttemptRepository()
        let sessions = InMemoryStudySessionRepository()
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
        let settings = InMemoryLearnerSettingsRepository()
        let schedules = InMemoryReviewScheduleRepository()
        return AppDependencies(
            loadDashboardSummary: LoadDashboardSummary(vocabulary: vocabulary, grammar: grammar, attempts: learnerAttempts, sessions: sessions, schedules: schedules, settings: settings),
            loadProgressReport: LoadProgressReport(attempts: learnerAttempts, sessions: sessions, schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar),
            listReviewQueue: ListReviewQueue(schedules: schedules, settings: settings, vocabulary: vocabulary, grammar: grammar),
            browseVocabulary: BrowseVocabulary(vocabulary: vocabulary),
            getVocabularyDetail: GetVocabularyDetail(vocabulary: vocabulary, bookmarks: bookmarks, notes: notes),
            browseGrammar: BrowseGrammar(grammar: grammar),
            getGrammarDetail: GetGrammarDetail(grammar: grammar, questions: questions, bookmarks: bookmarks, notes: notes),
            toggleBookmark: ToggleBookmark(bookmarks: bookmarks),
            listBookmarks: ListBookmarks(bookmarks: bookmarks, vocabulary: vocabulary, grammar: grammar),
            saveNote: SaveNote(notes: notes),
            startQuiz: StartQuizSession(questions: questions, sessions: sessions, attempts: learnerAttempts, schedules: schedules, settings: settings, shuffler: IdentityShuffler(), deviceName: "test"),
            resumeQuiz: ResumeQuizSession(questions: questions, sessions: sessions, attempts: learnerAttempts),
            submitAnswer: SubmitAnswer(sessions: sessions, attempts: learnerAttempts, schedules: schedules),
            finishQuiz: FinishQuizSession(sessions: sessions, attempts: learnerAttempts, questions: questions),
            listMistakes: ListMistakes(attempts: learnerAttempts, vocabulary: vocabulary, grammar: grammar),
            listHistory: ListQuizHistory(sessions: sessions, attempts: learnerAttempts),
            loadSettings: LoadSettings(repository: settings),
            saveSettings: SaveSettings(repository: settings),
            pronouncer: SilentPronouncer(),
            saveWritingAttempt: SaveWritingAttempt(attempts: attempts, dates: SystemDateProvider()),
            reviewWriting: ReviewWriting(providers: FixedAssistantProviderSource(MockAssistantProvider()), attempts: attempts),
            writingAttempts: attempts
        )
    }

    func testDraftLengthSaveAndFeedback() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "writing-tests-\(UUID().uuidString)"))
        let attempts = InMemoryWritingAttemptRepository()
        let deps = dependencies(attempts: attempts)

        let first = WritingTaskViewModel(task: task, dependencies: deps, drafts: defaults)
        XCTAssertFalse(first.canSave)
        first.text = "짧은 글"
        XCTAssertEqual(first.lengthStatus, .short)
        first.text = "조사 결과를 정리한 글이다"
        XCTAssertEqual(first.lengthStatus, .ok)

        let reopened = WritingTaskViewModel(task: task, dependencies: deps, drafts: defaults)
        XCTAssertEqual(reopened.text, "조사 결과를 정리한 글이다", "draft survives leaving the screen")

        await reopened.submit()
        XCTAssertEqual(reopened.text, "", "saving clears the editor")
        XCTAssertEqual(reopened.attempts.count, 1)
        XCTAssertNil(defaults.string(forKey: "writing.draft.w.53.test").flatMap { $0.isEmpty ? nil : $0 }, "draft cleared")

        await reopened.requestFeedback(language: .english)
        guard case let .loaded(feedback) = reopened.review else { return XCTFail("expected feedback, got \(reopened.review)") }
        XCTAssertEqual(feedback.providerName, "Built-in assistant")
        let stored = try await attempts.allAttempts()
        XCTAssertEqual(stored.first?.feedback, feedback)

        reopened.revise(try XCTUnwrap(reopened.attempts.first))
        XCTAssertEqual(reopened.text, "조사 결과를 정리한 글이다")
    }
}
