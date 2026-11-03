import Domain
import Features
import Foundation
import Observation
import Persistence

/// Composition root. The only place that knows concrete repository types.
@MainActor
@Observable
final class AppContainer {
    enum State {
        case starting
        case ready(AppDependencies, LearnerPreferences)
        case failed(String)
    }

    private(set) var state: State = .starting

    /// Opens the stores, imports bundled content if newer, loads settings and builds the dependency graph.
    func bootstrap() async {
        do {
            let controller = try PersistenceController(mode: .onDisk(directory: Self.storeDirectory()))
            _ = try await CoreDataContentStore(controller: controller).apply(SampleContent.package)

            let vocabulary = CoreDataVocabularyRepository(controller: controller)
            let grammar = CoreDataGrammarRepository(controller: controller)
            let questions = CoreDataQuestionRepository(controller: controller)
            let attempts = CoreDataAttemptRepository(controller: controller)
            let bookmarks = CoreDataBookmarkRepository(controller: controller)
            let sessions = CoreDataStudySessionRepository(controller: controller)
            let notes = CoreDataLearnerNoteRepository(controller: controller)
            let settingsRepository = CoreDataLearnerSettingsRepository(controller: controller)

            let saveSettings = SaveSettings(repository: settingsRepository)
            let dependencies = AppDependencies(
                loadDashboardSummary: LoadDashboardSummary(vocabulary: vocabulary, grammar: grammar, attempts: attempts),
                browseVocabulary: BrowseVocabulary(vocabulary: vocabulary),
                getVocabularyDetail: GetVocabularyDetail(vocabulary: vocabulary, bookmarks: bookmarks, notes: notes),
                browseGrammar: BrowseGrammar(grammar: grammar),
                getGrammarDetail: GetGrammarDetail(grammar: grammar, questions: questions, bookmarks: bookmarks, notes: notes),
                toggleBookmark: ToggleBookmark(bookmarks: bookmarks),
                listBookmarks: ListBookmarks(bookmarks: bookmarks, vocabulary: vocabulary, grammar: grammar),
                saveNote: SaveNote(notes: notes),
                startQuiz: StartQuizSession(questions: questions, sessions: sessions, attempts: attempts, deviceName: Self.deviceName),
                resumeQuiz: ResumeQuizSession(questions: questions, sessions: sessions, attempts: attempts),
                submitAnswer: SubmitAnswer(sessions: sessions, attempts: attempts),
                finishQuiz: FinishQuizSession(sessions: sessions, attempts: attempts, questions: questions),
                listMistakes: ListMistakes(attempts: attempts, vocabulary: vocabulary, grammar: grammar),
                listHistory: ListQuizHistory(sessions: sessions, attempts: attempts),
                loadSettings: LoadSettings(repository: settingsRepository),
                saveSettings: saveSettings,
                pronouncer: SpeechPronouncer()
            )
            let settings = try await settingsRepository.load()
            let preferences = LearnerPreferences(settings: settings, save: saveSettings)
            state = .ready(dependencies, preferences)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    private static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #if DEBUG
        // UI tests start from an empty learner store every run.
        if CommandLine.arguments.contains("--ui-testing") {
            let scratch = base.appendingPathComponent("HanguStep-UITests", isDirectory: true)
            try? FileManager.default.removeItem(at: scratch)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            return scratch
        }
        #endif
        let directory = base.appendingPathComponent("HanguStep", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
